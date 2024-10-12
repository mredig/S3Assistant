import Foundation

public struct S3Object: Codable, CustomStringConvertible {
	public let key: String
	public var name: String {
		guard let delimiter else { return key }
		return key.split(separator: delimiter).last.flatMap { String($0) } ?? "" 
	}
	public let delimiter: String?
	public let eTag: String
	public let lastModified: Date
	public let size: Int
	public let storageClass: String
	public let versioning: Versioning?

	public struct Versioning: Codable {
		let isLatest: Bool
		let versionID: String
	}

	public var description: String {
		var accum: [String] = []
		accum.append("File Metadata: \(name)")
		accum.append("\tkey: \(key)")
		accum.append("\tlastModified: \(Self.dateFormatter.string(from: lastModified))")
		accum.append("\tsize: \(size)")

		guard let versioning = versioning else { return accum.joined(separator: "\n") }
		accum.append("\tVersioning:")
		accum.append("\t\tisLatest: \(versioning.isLatest)")
		accum.append("\t\tversionID: \(versioning.versionID)")
		return accum.joined(separator: "\n")
	}

	private static let isoFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.timeZone = .init(secondsFromGMT: 0)
		formatter.formatOptions = [.withColonSeparatorInTime, .withDashSeparatorInDate, .withInternetDateTime, .withFractionalSeconds]
		return formatter
	}()

	private static let dateFormatter: DateFormatter = {
		let f = DateFormatter()
		f.dateStyle = .medium
		f.timeStyle = .short
		return f
	}()

	public init(
		key: String,
		delimiter: String?,
		eTag: String,
		lastModified: Date,
		size: Int,
		storageClass: String,
		versioning: Versioning?) {
			self.key = key
			self.delimiter = delimiter
			self.eTag = eTag
			self.lastModified = lastModified
			self.size = size
			self.storageClass = storageClass
			self.versioning = versioning
		}

	init(from xmlNode: XMLNode, delimiter: String?) throws {
		guard
			let keyNode = xmlNode.children?.first(where: { $0.name == "Key" }),
			let keyValue = keyNode.stringValue,
			keyValue.isEmpty == false
		else { throw S3FileMetadataError.invalidXMLNode(reason: "Invalid Key Node", node: xmlNode) }
		let key = keyValue

		guard
			let lastModifiedNode = xmlNode.children?.first(where: { $0.name == "LastModified" }),
			let lastModifiedValue = lastModifiedNode.stringValue,
			let modifiedDate = Self.isoFormatter.date(from: lastModifiedValue)
		else { throw S3FileMetadataError.invalidXMLNode(reason: "Invalid LastModified Node", node: xmlNode) }
		let lastModified = modifiedDate

		guard
			let eTagNode = xmlNode.children?.first(where: { $0.name == "ETag" }),
			let eTagValue = eTagNode.stringValue,
			eTagValue.isEmpty == false
		else { throw S3FileMetadataError.invalidXMLNode(reason: "Invalid ETag Node", node: xmlNode) }
		let eTag = eTagValue

		guard
			let sizeNode = xmlNode.children?.first(where: { $0.name == "Size" }),
			let sizeValueStr = sizeNode.stringValue,
			let sizeValue = Int(sizeValueStr)
		else { throw S3FileMetadataError.invalidXMLNode(reason: "Invalid Size Node", node: xmlNode) }
		let size = sizeValue

		guard
			let storageClassNode = xmlNode.children?.first(where: { $0.name == "StorageClass" }),
			let storageClassValue = storageClassNode.stringValue,
			storageClassValue.isEmpty == false
		else { throw S3FileMetadataError.invalidXMLNode(reason: "Invalid StorageClass Node", node: xmlNode) }
		let storageClass = storageClassValue

		let versioning: Versioning?
		if
			let versionNode = xmlNode.children?.first(where: { $0.name == "VersionId" }),
			let isLatestNode = xmlNode.children?.first(where: { $0.name == "IsLatest" }),
			let versionValue = versionNode.stringValue,
			let isLatestValue = isLatestNode.stringValue {

			versioning = Versioning(isLatest: isLatestValue.lowercased() == "true", versionID: versionValue)
		} else {
			versioning = nil
		}

		self.init(
			key: key,
			delimiter: delimiter,
			eTag: eTag,
			lastModified: lastModified,
			size: size,
			storageClass: storageClass,
			versioning: versioning)
	}

	enum S3FileMetadataError: Error {
		case invalidXMLNode(reason: String, node: XMLNode)
	}
}
