import Foundation

public struct S3ListBucketResult: Sendable, Codable, Hashable, CustomStringConvertible {
	static let rootKey = "ListBucketResult"

	public let name: String?
	public let prefix: String?
	public let delimiter: String?
	public let isTruncated: Bool
	public let nextContinuation: String?

	public let files: [S3ObjectVersion]
	public let folders: [S3Folder]

	public var description: String {
		var accum: [String] = []
		if let prefix {
			accum.append("S3ListBucketResult: \(prefix)")
		} else {
			accum.append("S3ListBucketResult:")
		}
		delimiter.map { accum.append("\tdelimiter: \($0)")}
		accum.append("\tfiles:")
		accum.append(files.map(\.description).map { $0.addIndentation(count: 2) }.joined(separator: "\n"))
		accum.append("\tfolders:")
		accum.append(folders.map(\.description).map { $0.addIndentation(count: 2) }.joined(separator: "\n"))

		return accum.joined(separator: "\n")
	}
}

extension String {
	func addIndentation(count: Int) -> String {
		let indentation = String(repeating: "\t", count: count)
		let lines = split(separator: "\n")
			.map(String.init)
			.map { "\(indentation)\($0)" }
			.joined(separator: "\n")

		return lines
	}
}

extension S3ListBucketResult {
	enum CodingKeys: String, CodingKey {
		case name
		case prefix
		case delimiter
		case isTruncated
		case nextContinuation = "nextContinuationToken"
		case files = "contents"
		case folders = "commonPrefixes"
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let name = try container.decodeIfPresent(String.self, forKey: .name)
		let prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
		let delimiter = try container.decodeIfPresent(String.self, forKey: .delimiter)
		let isTruncated = try container.decodeIfPresent(Bool.self, forKey: .isTruncated)
		let nextContinuation = try container.decodeIfPresent(String.self, forKey: .nextContinuation)
		let files = try container.decode([S3ObjectVersion].self, forKey: .files).withDelimiter(delimiter)
		let folders = try container.decode([S3Folder].self, forKey: .folders).withDelimiter(delimiter)
		self.init(
			name: name,
			prefix: prefix,
			delimiter: delimiter,
			isTruncated: isTruncated ?? false,
			nextContinuation: nextContinuation,
			files: files,
			folders: folders)
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(name, forKey: .name)
		try container.encode(`prefix`, forKey: .prefix)
		try container.encode(delimiter, forKey: .delimiter)
		try container.encode(isTruncated, forKey: .isTruncated)
		try container.encode(nextContinuation, forKey: .nextContinuation)
		try container.encode(files, forKey: .files)
	}
}
