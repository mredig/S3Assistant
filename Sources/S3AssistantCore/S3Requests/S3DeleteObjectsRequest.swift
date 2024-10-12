public struct S3DeleteObjectsRequest: Codable, Hashable, Sendable {
	static let rootKey = "Delete"

	let quiet: Bool
	let objects: [S3ObjectIdentifier]

	enum CodingKeys: String, CodingKey {
		case quiet
		case objects = "object"
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		if quiet {
			try container.encode(self.quiet, forKey: .quiet)
		}
		try container.encode(self.objects, forKey: .objects)
	}
}
