public struct S3ListObjectVersionsResult: Sendable, CustomStringConvertible {
	public let prefix: String?
	public let delimiter: String?
	public let nextMarker: (key: String, versionID: String)?

	public let versions: [S3Object]

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

		return accum.joined(separator: "\n")
	}
}
