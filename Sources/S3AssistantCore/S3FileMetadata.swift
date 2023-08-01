import Foundation

public struct S3FileMetadata: Codable, CustomStringConvertible {
	public let key: String
	public var name: String { key.split(separator: delimiter).last.flatMap { String($0) } ?? "" }
	public let delimiter: String
	public let eTag: String
	public let lastModified: Date
	public let size: Int
	public let storageClass: String

	public var description: String {
		"""
		File Metadata: \(name)
			key: \(key)
			lastModified: \(Self.dateFormatter.string(from: lastModified))
			size: \(size)
		"""
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
		delimiter: String,
		eTag: String,
		lastModified: Date,
		size: Int,
		storageClass: String) {
			self.key = key
			self.delimiter = delimiter
			self.eTag = eTag
			self.lastModified = lastModified
			self.size = size
			self.storageClass = storageClass
		}

	init(from xmlNode: XMLNode, delimiter: String) throws {
		self.delimiter = delimiter
		guard
			let keyNode = xmlNode.children?.first(where: { $0.name == "Key" }),
			let keyValue = keyNode.stringValue,
			keyValue.isEmpty == false
		else { throw S3FileMetadataError.invalidXMLNode(reason: "Invalid Key Node", node: xmlNode) }
		self.key = keyValue

		guard
			let lastModifiedNode = xmlNode.children?.first(where: { $0.name == "LastModified" }),
			let lastModifiedValue = lastModifiedNode.stringValue,
			let modifiedDate = Self.isoFormatter.date(from: lastModifiedValue)
		else { throw S3FileMetadataError.invalidXMLNode(reason: "Invalid LastModified Node", node: xmlNode) }
		self.lastModified = modifiedDate

		guard
			let eTagNode = xmlNode.children?.first(where: { $0.name == "ETag" }),
			let eTagValue = eTagNode.stringValue,
			eTagValue.isEmpty == false
		else { throw S3FileMetadataError.invalidXMLNode(reason: "Invalid ETag Node", node: xmlNode) }
		self.eTag = eTagValue

		guard
			let sizeNode = xmlNode.children?.first(where: { $0.name == "Size" }),
			let sizeValueStr = sizeNode.stringValue,
			let sizeValue = Int(sizeValueStr)
		else { throw S3FileMetadataError.invalidXMLNode(reason: "Invalid Size Node", node: xmlNode) }
		self.size = sizeValue

		guard
			let storageClassNode = xmlNode.children?.first(where: { $0.name == "StorageClass" }),
			let storageClassValue = storageClassNode.stringValue,
			storageClassValue.isEmpty == false
		else { throw S3FileMetadataError.invalidXMLNode(reason: "Invalid StorageClass Node", node: xmlNode) }
		self.storageClass = storageClassValue
	}

	enum S3FileMetadataError: Error {
		case invalidXMLNode(reason: String, node: XMLNode)
	}
}
