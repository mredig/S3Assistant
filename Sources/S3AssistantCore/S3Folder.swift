import Foundation

public struct S3Folder: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
	public let rawValue: String
	public var prefix: String { rawValue }
	public var name: String {
		guard let delimiter else { return prefix }
		return prefix.split(separator: delimiter).last.flatMap { String($0) } ?? ""
	}
	public let delimiter: String?

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

	public init?(rawValue: String) {
		self.init(rawValue: rawValue, delimiter: "/")
	}
}
