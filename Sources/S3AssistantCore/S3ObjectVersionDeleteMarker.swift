import Foundation

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
