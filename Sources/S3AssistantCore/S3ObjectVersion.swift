import Foundation

public struct S3ObjectVersion: Codable {
	public let eTag: String?
	public let isLatest: Bool
	public let key: String
	public let lastModified: Date
	public let size: Int
	public let storageClass: String
	public let versionID: String

	enum CodingKeys: String, CodingKey {
		case eTag = "etag"
		case isLatest
		case key
		case lastModified
		case size
		case storageClass
		case versionID = "versionId"
	}
}

public struct S3ObjectVersionDeleteMarker: Codable {
	public let key: String
	public let versionID: String?
	public let isLatest: Bool
	public let lastModified: Date

	enum CodingKeys: String, CodingKey {
		case isLatest
		case key
		case versionID = "versionId"
		case lastModified
	}
}

public struct S3ListVersionResult: Codable, CustomStringConvertible {
	public let name: String
	public let prefix: String?
	public let delimiter: String?
	public let nextVersionIDMarker: String?
	public let nextKeyMarker: String?
	public let versions: [S3ObjectVersion]
	public let deleteMarkers: [S3ObjectVersionDeleteMarker]

	public var description: String {
		"""
		S3ListVersionResult: \(name)
			Prefix: \(prefix ?? "##noprefix##")
			Delimiter: \(delimiter ?? "##no delimiter##")
			NextVersionID/KeyMarker: \(nextVersionIDMarker ?? "##no version##") \(nextKeyMarker ?? "##no key##")
			Versions:
		\(versions.map({"\($0)"}).joined(separator: "\n").addIndentation(count: 2))
			DeleteMarkers:
		\(deleteMarkers.map({"\($0)"}).joined(separator: "\n").addIndentation(count: 2))

		"""
	}

	enum CodingKeys: String, CodingKey {
		case name
		case prefix
		case delimiter
		case nextVersionIDMarker = "nextVersionIdMarker"
		case nextKeyMarker
		case versions = "version"
		case deleteMarkers = "deleteMarker"
	}
}
