import Foundation

public struct WasabiListBucketResult: CustomStringConvertible {
	public let prefix: String
	public let delimiter: String
	public let nextContinuation: String?

	public let files: [WasabiFileMetadata]
	public let folders: [WasabiFolder]

	public var description: String {
	"""
	S3 Result: \(prefix)
		delimiter: \(delimiter)
		files:
	\(files.map(\.description).map { $0.addIndentation(count: 2)}.joined(separator: "\n"))
		folders:
	\(folders.map(\.description).map { $0.addIndentation(count: 2)}.joined(separator: "\n"))
	"""
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
