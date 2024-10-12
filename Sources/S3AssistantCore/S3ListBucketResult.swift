import Foundation

public struct S3ListBucketResult: CustomStringConvertible {
	public let prefix: String?
	public let delimiter: String?
	public let nextContinuation: String?

	public let files: [S3Object]
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

