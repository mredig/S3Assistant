import Foundation

public struct S3ObjectVersionDeleteMarker: Sendable, Hashable, Codable, CustomStringConvertible {
	public let key: String
	public var name: String? {
		guard let delimiter else { return key }
		return key.split(separator: delimiter).last.flatMap { String($0) } ?? ""
	}
	public package(set) var delimiter: String?
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
		self.key = try container.decode(String.self, forKey: .key)
		self.versionID = try container.decodeIfPresent(String.self, forKey: .versionID)
		self.lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified)
		self.owner = try container.decodeIfPresent(S3Owner.self, forKey: .owner)
	}

	public var description: String {
		var accum: [String] = []
		if let name {
			accum.append("Delete Marker: \(name)")
		} else {
			accum.append("Delete Marker: ")
		}
		accum.append("\tkey: \(key)")
		lastModified.map { accum.append("\tlastModified: \(Formatters.dateFormatter.string(from: $0))") }
		isLatest.map { accum.append("\tisLatest: \($0)") }
		versionID.map { accum.append("\tversionID: \($0)") }
		return accum.joined(separator: "\n")
	}

	package func withDelimiter(_ delimiter: String?) -> S3ObjectVersionDeleteMarker {
		var new = self
		new.delimiter = delimiter
		return new
	}
}

extension S3ObjectVersionDeleteMarker: S3ObjectIdentifierProvider {
	public var objectIdentifier: S3ObjectIdentifier {
		S3ObjectIdentifier(key: key, versionID: versionID)
	}
}
