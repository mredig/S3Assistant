import Foundation
import NetworkHandler

public class WasabiController {
	private(set) var items: [String] = []

	private let authKey: String
	private let authSecret: String
	private let serviceURL: URL
	private let region: AWSV4Signature.AWSRegion

	public init(authKey: String, authSecret: String, serviceURL: String, region: AWSV4Signature.AWSRegion) {
		self.authKey = authKey
		self.authSecret = authSecret
		self.serviceURL = URL(string: "https://\(serviceURL)")!
		self.region = region
	}

	public func getListing(
		in bucket: String,
		prefix: [String],
		delimiter: String,
		pageLimit: Int? = nil,
		continuationToken: String? = nil) async throws -> WasabiListBucketResult {
			try await getListing(
				in: bucket,
				prefix: "\(prefix.joined(separator: delimiter))\(delimiter)",
				delimiter: delimiter,
				pageLimit: pageLimit,
				continuationToken: continuationToken)
		}

	public func getListing(
		in bucket: String,
		prefix: String? = nil,
		delimiter: String? = nil,
		pageLimit: Int? = nil,
		continuationToken: String? = nil) async throws -> WasabiListBucketResult {
			let url = serviceURL
				.appending(component: bucket)
				.appending(queryItems: [
					URLQueryItem(name: "list-type", value: "2"),
					delimiter.flatMap { URLQueryItem(name: "delimiter", value: $0) },
					prefix.flatMap { URLQueryItem(name: "prefix", value: $0) },
					pageLimit.flatMap { URLQueryItem(name: "max-keys", value: "\($0)") },
					continuationToken.flatMap { URLQueryItem(name: "continuation-token", value: $0) },
				].compactMap { $0 })

			var request = url.request

			let awsAuth = AWSV4Signature(
				requestMethod: .get,
				url: url,
				awsKey: authKey,
				awsSecret: authSecret,
				awsRegion: region,
				awsService: .s3,
				payloadData: Data(),
				additionalSignedHeaders: [:])

			request = try awsAuth.processRequest(request)

			let response = try await NetworkHandler.default.transferMahDatas(for: request)

			let xml = try XMLDocument(data: response.data)

			let resultNode = xml.child(at: 0)
			let delimiterNode = resultNode?.children?.first(where: { $0.name == "Delimiter" })
			let continuationNode = resultNode?.children?.first(where: { $0.name == "NextContinuationToken" })
			let prefixNode = resultNode?.children?.first(where: { $0.name == "Prefix" })
			let filesNodes = resultNode?.children?.filter { $0.name == "Contents" } ?? []
			let foldersNodes = resultNode?.children?.filter { $0.name == "CommonPrefixes" }.flatMap { $0.children ?? [] } ?? []

			guard
				let responseDelimiter = delimiterNode?.stringValue,
				let responsePrefix = prefixNode?.stringValue
			else { fatalError() }
			let files = try filesNodes.map { try WasabiFileMetadata(from: $0, delimiter: responseDelimiter) }
			let folders = foldersNodes.compactMap(\.stringValue).map { WasabiFolder(rawValue: $0, delimiter: responseDelimiter) }

			return WasabiListBucketResult(prefix: responsePrefix, delimiter: responseDelimiter, nextContinuation: continuationNode?.stringValue, files: files, folders: folders)
		}

	public func listAllFiles(
		in bucket: String,
		prefix: String? = nil,
		delimiter: String? = nil,
		pageLimit: Int? = nil,
		filter: (WasabiListBucketResult, inout Bool) -> [WasabiFileMetadata] = { result, _ in result.files } ) async throws -> [WasabiFileMetadata] {

			var accumulatedFiles: [WasabiFileMetadata] = []
			var shouldContinue = true
			var continuationToken: String?
			repeat {
				let result = try await getListing(
					in: bucket,
					prefix: prefix,
					delimiter: delimiter,
					pageLimit: pageLimit,
					continuationToken: continuationToken)

				accumulatedFiles.append(contentsOf: filter(result, &shouldContinue))
				continuationToken = result.nextContinuation

			} while continuationToken != nil && shouldContinue == true

			return accumulatedFiles
		}

	public func delete(
		items: [WasabiFileMetadata],
		inBucket bucket: String,
		quiet: Bool = false) async throws {
			let itemXml = try items.deleteList(quiet: quiet)

			let xmlData = itemXml.xmlData()

			let url = serviceURL
				.appending(component: bucket)
				.appending(queryItems: [
					URLQueryItem(name: "delete", value: nil)
				])
			var request = url.request
			request.httpMethod = .post
			request.payload = .data(xmlData)
			request.setContentType(.xml)

			let awsAuth = AWSV4Signature(
				requestMethod: .post,
				url: url,
				awsKey: authKey,
				awsSecret: authSecret,
				awsRegion: region,
				awsService: .s3,
				payloadData: xmlData,
				additionalSignedHeaders: [:])

			request = try awsAuth.processRequest(request)

			let response = try await NetworkHandler.default.transferMahDatas(for: request)

			let responseXml = try XMLDocument(data: response.data)
			print(responseXml.xmlString(options: .nodePrettyPrint))
		}

}
