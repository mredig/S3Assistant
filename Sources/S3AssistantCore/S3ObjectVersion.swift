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


