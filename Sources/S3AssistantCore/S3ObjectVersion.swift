import Foundation

public struct S3ObjectVersion: Codable, Sendable, Hashable, CustomStringConvertible, Delimiterable {
	public let eTag: String?
	public let key: String
	public var name: String {
		guard let delimiter else { return key }
		return key.split(separator: delimiter).last.flatMap { String($0) } ?? ""
	}
	public package(set) var delimiter: String?
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
		delimiter: String?,
		lastModified: Date,
		size: Int,
		storageClass: String,
		versioning: Versioning?
	) {
		self.eTag = eTag
		self.key = key
		self.delimiter = delimiter
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
			delimiter: nil,
			lastModified: lastModified,
			size: size,
			storageClass: storageClass,
			versioning: versioning)
	}

	public var description: String {
		var accum: [String] = []
		accum.append("Object Version: \(name)")
		accum.append("\tkey: \(key)")
		accum.append("\tlastModified: \(Formatters.dateFormatter.string(from: lastModified))")
		accum.append("\tsize: \(size)")

		guard let versioning = versioning else { return accum.joined(separator: "\n") }
		accum.append("\tVersioning:")
		accum.append("\t\tisLatest: \(versioning.isLatest)")
		accum.append("\t\tversionID: \(versioning.versionID)")
		return accum.joined(separator: "\n")
	}
}

extension S3ObjectVersion: S3ObjectIdentifierProvider {
	public var objectIdentifier: S3ObjectIdentifier {
		S3ObjectIdentifier(key: key, versionID: versioning?.versionID)
	}
}
