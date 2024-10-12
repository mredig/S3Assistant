public protocol S3ObjectIdentifierProvider {
	var objectIdentifier: S3ObjectIdentifier { get }
}

public struct S3ObjectIdentifier: Codable, Hashable, Sendable {
	public let key: String
	public let versionID: String?

	enum CodingKeys: String, CodingKey {
		case key
		case versionID = "VersionId"
	}
}

extension S3ObjectIdentifier: S3ObjectIdentifierProvider {
	public var objectIdentifier: S3ObjectIdentifier { self }
}
