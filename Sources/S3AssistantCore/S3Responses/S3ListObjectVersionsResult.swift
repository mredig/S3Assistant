public struct S3ListObjectVersionsResult: Decodable, CustomStringConvertible {
	public let name: String
	public let prefix: String?
	public let delimiter: String?
	public let versions: [S3ObjectVersion]
	public let deleteMarkers: [S3ObjectVersionDeleteMarker]
	public let nextMarker: NextMarker?

	public var content: [ContentOption] {
		versions.map(ContentOption.version) + deleteMarkers.map(ContentOption.deleteMarker)
	}

	public enum ContentOption: S3ObjectIdentifierProvider {
		case version(S3ObjectVersion)
		case deleteMarker(S3ObjectVersionDeleteMarker)

		public var objectIdentifier: S3ObjectIdentifier {
			switch self {
			case .version(let s3ObjectVersion):
				s3ObjectVersion.objectIdentifier
			case .deleteMarker(let s3ObjectVersionDeleteMarker):
				s3ObjectVersionDeleteMarker.objectIdentifier
			}
		}
	}

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
		let versions = try container.decode([S3ObjectVersion].self, forKey: .versions).withDelimiter(delimiter)
		let deleteMarkers = try container.decode([S3ObjectVersionDeleteMarker].self, forKey: .deleteMarkers).withDelimiter(delimiter)
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
		var accum: [String] = []
		if let prefix {
			accum.append("S3 ListObjectVersionsResult: \(prefix)")
		} else {
			accum.append("S3 ListObjectVersionsResult:")
		}
		delimiter.map { accum.append("\tdelimiter: \($0)")}
		nextMarker.map { accum.append("\tnextMarker: \($0)")}
		accum.append("\tversions:")
		accum.append(versions.map(\.description).map { $0.addIndentation(count: 2) }.joined(separator: "\n"))
		accum.append("\tdelete markers:")
		accum.append(deleteMarkers.map(\.description).map { $0.addIndentation(count: 2) }.joined(separator: "\n"))

		return accum.joined(separator: "\n")
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
