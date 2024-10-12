public struct S3Owner: Codable, Hashable, Sendable {
	public let id: String
	public let displayName: String

	enum CodingKeys: String, CodingKey {
		case id = "iD"
		case displayName
	}
}
