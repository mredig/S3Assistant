import Foundation

public struct S3ListBucketResult: CustomStringConvertible {
	public let prefix: String?
	public let delimiter: String?
	public let nextContinuation: String?

	public let files: [S3Object]
	public let folders: [S3Folder]

	public var description: String {
	"""
	S3 Result: \(prefix ?? "##noprefix##")
		delimiter: \(delimiter ?? "##nodelimiter##")
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
