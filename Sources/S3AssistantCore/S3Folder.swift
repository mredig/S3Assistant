import Foundation

public struct S3Folder: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible, Delimiterable {
	public let rawValue: String
	public var prefix: String { rawValue }
	public var name: String {
		guard let delimiter else { return prefix }
		return prefix.split(separator: delimiter).last.flatMap { String($0) } ?? ""
	}
	public var delimiter: String?

	public var description: String {
		"""
		Folder Metadata: \(name)
			prefix: \(prefix)
		"""
	}

	public init(rawValue: String, delimiter: String?) {
		self.rawValue = rawValue
		self.delimiter = delimiter
	}

	public init(rawValue: String) {
		self.init(rawValue: rawValue, delimiter: "/")
	}

	enum CodingKeys: String, CodingKey {
		case prefix
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let prefix = try container.decode(String.self, forKey: .prefix)

		self.init(rawValue: prefix)
	}
}
