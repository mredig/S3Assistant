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
