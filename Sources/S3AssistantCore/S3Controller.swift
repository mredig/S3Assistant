import Foundation
@preconcurrency import XMLCoder
@preconcurrency import NetworkHandler
import SwiftPizzaSnips

public final class S3Controller: Sendable {
	private let authKey: String
	private let authSecret: String
	private let serviceURL: URL
	private let region: AWSV4Signature.AWSRegion

	private let lock = NSLock()
	nonisolated(unsafe)
	private var _printXML = false
	public var printXML: Bool {
		get { lock.withLock { _printXML } }
		set { lock.withLock { _printXML = newValue }}
	}

	private let decoder = XMLDecoder().with {
		$0.keyDecodingStrategy = .convertFromCapitalized
		$0.dateDecodingStrategy = .custom({ decoder in
			let container = try decoder.singleValueContainer()

			let dateStr = try container.decode(String.self)

			return try Formatters.isoFormatter.date(from: dateStr).unwrap("No valid date")
		})
	}
	private let encoder = XMLEncoder().with {
		$0.dateEncodingStrategy = .custom({ date, encoder in
			let dateStr = Formatters.isoFormatter.string(from: date)

			var container = encoder.singleValueContainer()
			try container.encode(dateStr)
		})
		$0.keyEncodingStrategy = .capitalized
	}

	// TODO: make AWSV4Signature.isoFormatter public instead
	private static let isoFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.timeZone = .init(secondsFromGMT: 0)
		formatter.formatOptions = [.withColonSeparatorInTime, .withDashSeparatorInDate, .withInternetDateTime]
		return formatter
	}()

	public init(authKey: String, authSecret: String, serviceURL: String, region: AWSV4Signature.AWSRegion) {
		self.authKey = authKey
		self.authSecret = authSecret
		self.serviceURL = URL(string: "https://\(serviceURL)")!
		self.region = region
	}

	public func listObjects(
		in bucket: String,
		prefix: [String],
		delimiter: String,
		pageLimit: Int? = nil,
		continuationToken: String? = nil) async throws -> S3ListBucketResult {
			try await listObjects(
				in: bucket,
				prefix: "\(prefix.joined(separator: delimiter))\(delimiter)",
				delimiter: delimiter,
				pageLimit: pageLimit,
				continuationToken: continuationToken)
		}

	public func listObjects(
		in bucket: String,
		prefix: String? = nil,
		delimiter: String? = nil,
		pageLimit: Int? = nil,
		continuationToken: String? = nil) async throws -> S3ListBucketResult {
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
				url: url,
				awsKey: authKey,
				awsSecret: authSecret,
				awsRegion: region,
				awsService: .s3,
				hexContentHash: .unsignedPayload,
				additionalSignedHeaders: [:])

			request = try awsAuth.processRequest(request)

			let response = try await NetworkHandler.default.transferMahDatas(for: request)

			if printXML { printXMLResponse(response.data) }

			let result = try decoder.decode(S3ListBucketResult.self, from: response.data)

			return result
		}

	public func listAllObjects(
		in bucket: String,
		prefix: String? = nil,
		delimiter: String? = nil,
		pageLimit: Int? = nil,
		recurse: Bool = false
	) async throws -> AsyncThrowingStream<S3ListBucketResult, Error> {
		let (stream, continuation) = AsyncThrowingStream<S3ListBucketResult, Error>.makeStream()

		Task {
			var visitedSubdirectories: Set<S3Folder> = []
			var subdirectories: Set<S3Folder> = []
			var currentDirectory = S3Folder(rawValue: prefix ?? "")
			var continuationToken: String?
			var keepGoing = true
			repeat {
				do {
					let results = try await listObjects(
						in: bucket,
						prefix: currentDirectory.prefix,
						delimiter: delimiter,
						pageLimit: pageLimit,
						continuationToken: continuationToken)
					continuation.yield(results)
					let newDirectories = results.folders.filter { visitedSubdirectories.contains($0) == false }
					subdirectories.formUnion(newDirectories)

					if let nextContinuation = results.nextContinuation {
						continuationToken = nextContinuation
					} else if let nextDirectory = subdirectories.popFirst() {
						visitedSubdirectories.insert(currentDirectory)
						currentDirectory = nextDirectory
					} else {
						continuation.finish()
					}
				} catch {
					keepGoing = false
					continuation.finish(throwing: error)
				}
			} while keepGoing
		}

		return stream
	}

	@available(*, deprecated)
	public func listAllObjects(
		in bucket: String,
		prefix: String? = nil,
		delimiter: String? = nil,
		pageLimit: Int? = nil,
		recurse: Bool = false,
		filter: (S3ListBucketResult, inout Bool) -> [S3ObjectVersion] = { result, _ in result.files }
	) async throws -> [S3ObjectVersion] {
		var accumulatedFiles: [S3ObjectVersion] = []
		var shouldContinue = true
		var continuationToken: String?
		repeat {
			let result = try await listObjects(
				in: bucket,
				prefix: prefix,
				delimiter: delimiter,
				pageLimit: pageLimit,
				continuationToken: continuationToken)

			accumulatedFiles.append(contentsOf: filter(result, &shouldContinue))
			continuationToken = result.nextContinuation

			if recurse, result.folders.isEmpty == false {
				for folder in result.folders {
					let folderFiles = try await listAllObjects(
						in: bucket,
						prefix: folder.prefix,
						delimiter: delimiter,
						pageLimit: pageLimit,
						recurse: recurse,
						filter: filter)
					accumulatedFiles.append(contentsOf: folderFiles)
				}
			}

		} while continuationToken != nil && shouldContinue == true

		return accumulatedFiles
	}

	public func listObjectVersions(
		in bucket: String,
		prefix: String? = nil,
		delimiter: String? = nil,
		pageLimit: Int? = nil,
		keyMarker: String? = nil,
		versionIDMarker: String? = nil
	) async throws -> S3ListObjectVersionsResult {

		let url = serviceURL
			.appending(component: bucket)
			.appending(queryItems: [
				URLQueryItem(name: "versions", value: nil),
				delimiter.flatMap { URLQueryItem(name: "delimiter", value: $0) },
				prefix.flatMap { URLQueryItem(name: "prefix", value: $0) },
				pageLimit.flatMap { URLQueryItem(name: "max-keys", value: "\($0)") },
				keyMarker.flatMap { URLQueryItem(name: "key-marker", value: $0) },
				versionIDMarker.flatMap { URLQueryItem(name: "version-id-marker", value: $0) },
			].compactMap { $0 })

		var request = url.request

		let awsAuth = AWSV4Signature(
			requestMethod: .get,
			url: url,
			date: .now,
			awsKey: authKey,
			awsSecret: authSecret,
			awsRegion: region,
			awsService: .s3,
			hexContentHash: .unsignedPayload,
			additionalSignedHeaders: [:])

		request = try awsAuth.processRequest(request)

		let response = try await NetworkHandler.default.transferMahDatas(for: request)
		if printXML { printXMLResponse(response.data) }

		return try decoder.decode(S3ListObjectVersionsResult.self, from: response.data)
	}

	public func listAllObjectVersions(
		in bucket: String,
		prefix: String? = nil,
		delimiter: String? = nil
	) async throws -> AsyncThrowingStream<S3ListObjectVersionsResult.ContentOption, Error> {
		let (stream, continuation) = AsyncThrowingStream<S3ListObjectVersionsResult.ContentOption, Error>.makeStream()

		Task {
			var keyMarker: String?
			var versionIDMarker: String?
			var keepGoing = true
			repeat {
				do {
					let results = try await listObjectVersions(
						in: bucket,
						prefix: prefix,
						delimiter: delimiter,
						pageLimit: 250,
						keyMarker: keyMarker,
						versionIDMarker: versionIDMarker)
					for item in results.content {
						continuation.yield(item)
					}
					guard let nextMarker = results.nextMarker else {
						return continuation.finish()
					}
					keyMarker = nextMarker.nextKeyMarker
					versionIDMarker = nextMarker.nextVersionIDMarker
				} catch {
					keepGoing = false
					continuation.finish(throwing: error)
				}
			} while keepGoing
		}

		return stream
	}

	public func delete(
		items: [S3ObjectIdentifierProvider],
		inBucket bucket: String,
		quiet: Bool = false) async throws {
			let identifiers = items.map(\.objectIdentifier)
			let deleteRequest = S3DeleteObjectsRequest(quiet: quiet, objects: identifiers)

			let xmlData = try encoder.encode(
				deleteRequest,
				withRootKey: S3DeleteObjectsRequest.rootKey,
				rootAttributes: ["xmlns": "http://s3.amazonaws.com/doc/2006-03-01/"])

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
				hexContentHash: .unsignedPayload,
				additionalSignedHeaders: [:])

			request = try awsAuth.processRequest(request)

			let response = try await NetworkHandler.default.transferMahDatas(for: request)
			if printXML { printXMLResponse(response.data) }

			let responseXml = try XMLDocument(data: response.data)
			print(responseXml.xmlString(options: .nodePrettyPrint))
		}

	public enum ETagRequest {
		case match(String)
		case noneMatch(String)

		var key: String {
			switch self {
			case .match: "If-Match"
			case .noneMatch: "If-None-Match"
			}
		}
		var value: String {
			switch self {
			case .match(let etag), .noneMatch(let etag):
				etag
			}
		}
	}
	public enum ModificationRequest {
		case modifiedSince(Date)
		case unmodifiedSince(Date)

		var key: String {
			switch self {
			case .modifiedSince: "If-Modified-Since"
			case .unmodifiedSince: "If-Unmodified-Since"
			}
		}
		var value: String {
			switch self {
			case .modifiedSince(let date), .unmodifiedSince(let date):
				S3Controller.isoFormatter.string(from: date)
			}
		}
	}
	public enum ByteRange {
		case startingFrom(offset: Int)
		case startingAtBytesFromEnd(offset: Int)
		case range(Range<Int>)

		var value: String {
			switch self {
			case .startingFrom(let offset):
				"bytes=\(offset)-"
			case .startingAtBytesFromEnd(let offset):
				"bytes=-\(offset)"
			case .range(let range):
				"bytes=\(range.lowerBound)-\(range.upperBound - 1)"
			}
		}
	}
	public func getObject(
		in bucket: String,
		withKey key: String,
		etagRequest: ETagRequest? = nil,
		modificationRequest: ModificationRequest? = nil,
		versionID: String? = nil,
		checksum: Bool = false,
		byteRange: ByteRange? = nil) async throws -> Data {

			let url = serviceURL
				.appending(component: bucket)
				.appending(queryItems: [
					URLQueryItem(name: "key", value: key),
					versionID.flatMap { URLQueryItem(name: "versionId", value: $0) },
				].compactMap { $0 })

			var request = url.request

			if let byteRange {
				print("byteRange is known not working - fix it!")
				request.setValue("\(byteRange.value)", forHTTPHeaderField: .range)
			}

			var awsAuth = AWSV4Signature(
				requestMethod: .get,
				url: url,
				awsKey: authKey,
				awsSecret: authSecret,
				awsRegion: region,
				awsService: .s3,
				payloadData: Data(),
				additionalSignedHeaders: [:])
			if let etagRequest {
				awsAuth.additionalSignedHeaders["\(etagRequest.key)"] = "\(etagRequest.value)"
			}
			if let modificationRequest {
				awsAuth.additionalSignedHeaders["\(modificationRequest.key)"] = "\(modificationRequest.value)"
			}
			if checksum {
				print("checksum is known not working - fix it!")
				awsAuth.additionalSignedHeaders["x-amz-checksum-mode"] = "ENABLED"
			}


			request = try awsAuth.processRequest(request)

			let response = try await NetworkHandler.default.transferMahDatas(for: request)

			return response.data
		}

	public enum WasabiMoveOperation {
		/// Only move the file that exactly matches the `sourceKey`
		case exact(sourceKey: String, destinationKey: String, overwrite: Bool)
		/// Move every file that starts with the `sourcePrefix`.
		case prefix(sourcePrefix: String, destinationPrefix: String, overwrite: Bool)

		var source: String {
			switch self {
			case .exact(let source, _, _), .prefix(let source, _, _):
				source
			}
		}

		var destination: String {
			switch self {
			case .exact(_, let destination, _), .prefix(_, let destination, _):
				destination
			}
		}

		var overwrite: Bool {
			switch self {
			case .exact(_, _, let ow), .prefix(_, _, let ow):
				ow
			}
		}

		var isPrefix: Bool {
			switch self {
			case .exact:
				false
			case .prefix:
				true
			}
		}
	}
	@discardableResult
	public func wasabiRenameFiles(
		in bucket: String,
		operation: WasabiMoveOperation) async throws -> Data {
			let url = serviceURL
				.appending(component: bucket)
				.appending(path: operation.source, directoryHint: .notDirectory)

			var request = url.request
			request.httpMethod = "MOVE"

			request.setValue("\(operation.destination)", forHTTPHeaderField: "Destination")
			request.setValue("\(operation.overwrite)", forHTTPHeaderField: "Overwrite")
			request.setValue("\(operation.isPrefix)", forHTTPHeaderField: "X-Wasabi-Prefix")

			let awsAuth = try AWSV4Signature(
				for: request,
				awsKey: authKey,
				awsSecret: authSecret,
				awsRegion: region,
				awsService: .s3,
				hexContentHash: .emptyPayload)

			request = try awsAuth.processRequest(request)

			let response = try await NetworkHandler.default.transferMahDatas(for: request)
			if printXML { printXMLResponse(response.data) }

			return response.data
		}
}

extension S3Controller {
	private func printXMLResponse(_ xmlData: Data) {
		let xmlStr = String(decoding: xmlData, as: UTF8.self)

		guard
			let xmlDoc = try? XMLDocument(xmlString: xmlStr)
		else { return print(xmlStr) }

		print(xmlDoc.xmlString(options: .nodePrettyPrint))
	}
}
