import Foundation

public struct S3ObjectVersion: Codable {
	public let eTag: String?
	public let key: String
	public let lastModified: Date
	public let size: Int
	public let storageClass: String
	public let versioning: Versioning?

	public struct Versioning: Codable, Hashable, Sendable {
		public let isLatest: Bool
		public let versionID: String

		enum CodingKeys: String, CodingKey {
			case isLatest
			case versionID = "versionId"
		}
	}

	enum CodingKeys: String, CodingKey {
		case eTag
		case key
		case lastModified
		case size
		case storageClass
	}

	public init(
		eTag: String?,
		key: String,
		lastModified: Date,
		size: Int,
		storageClass: String,
		versioning: Versioning?
	) {
		self.eTag = eTag
		self.key = key
		self.lastModified = lastModified
		self.size = size
		self.storageClass = storageClass
		self.versioning = versioning
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		let eTag = try container.decodeIfPresent(String.self, forKey: .eTag)
		let key = try container.decode(String.self, forKey: .key)
		let lastModified = try container.decode(Date.self, forKey: .lastModified)
		let size = try container.decode(Int.self, forKey: .size)
		let storageClass = try container.decode(String.self, forKey: .storageClass)
		let versioning = try? Versioning(from: decoder)

		self.init(
			eTag: eTag,
			key: key,
			lastModified: lastModified,
			size: size,
			storageClass: storageClass,
			versioning: versioning)
	}
}

public struct S3ObjectVersionDeleteMarker: Sendable, Hashable, Codable {
	public let key: String?
	public let versionID: String?
	public let isLatest: Bool?
	public let lastModified: Date?
	public let owner: S3Owner?

	enum CodingKeys: String, CodingKey {
		case isLatest
		case key
		case versionID = "versionId"
		case lastModified
		case owner
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.isLatest = try container.decodeIfPresent(Bool.self, forKey: .isLatest)
		self.key = try container.decodeIfPresent(String.self, forKey: .key)
		self.versionID = try container.decodeIfPresent(String.self, forKey: .versionID)
		self.lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified)
		self.owner = try container.decodeIfPresent(S3Owner.self, forKey: .owner)
	}
}

public struct S3ListVersionResult: Decodable, CustomStringConvertible {
	public let name: String
	public let prefix: String?
	public let delimiter: String?
	public let versions: [S3ObjectVersion]
	public let deleteMarkers: [S3ObjectVersionDeleteMarker]
	public let nextMarker: NextMarker?

	public init(
		name: String,
		prefix: String?,
		delimiter: String?,
		versions: [S3ObjectVersion],
		deleteMarkers: [S3ObjectVersionDeleteMarker],
		nextMarker: NextMarker?
	) {
		self.name = name
		self.prefix = prefix
		self.delimiter = delimiter
		self.versions = versions
		self.deleteMarkers = deleteMarkers
		self.nextMarker = nextMarker
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let name = try container.decode(String.self, forKey: .name)
		let prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
		let delimiter = try container.decodeIfPresent(String.self, forKey: .delimiter)
		let versions = try container.decode([S3ObjectVersion].self, forKey: .versions)
		let deleteMarkers = try container.decode([S3ObjectVersionDeleteMarker].self, forKey: .deleteMarkers)
		let nextMarker = try? NextMarker(from: decoder)

		self.init(
			name: name,
			prefix: prefix,
			delimiter: delimiter,
			versions: versions,
			deleteMarkers: deleteMarkers,
			nextMarker: nextMarker)
	}

	public struct NextMarker: Sendable, Hashable, Codable {
		public let nextVersionIDMarker: String
		public let nextKeyMarker: String

		enum CodingKeys: String, CodingKey {
			case nextVersionIDMarker = "nextVersionIdMarker"
			case nextKeyMarker
		}
	}

	public var description: String {
		"""
		S3ListVersionResult: \(name)
			Prefix: \(prefix ?? "##noprefix##")
			Delimiter: \(delimiter ?? "##no delimiter##")
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
		case versions = "version"
		case deleteMarkers = "deleteMarker"
		case listVersionResult
	}
}
