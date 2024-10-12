import Foundation

public extension Array where Element: CustomStringConvertible {
	var prettyPrinted: String {
		"""
		[
		\(self.map(\.description).joined(separator: ",\n").addIndentation(count: 1))
		]
		"""
	}
}

public extension Array where Element: CustomDebugStringConvertible {
	var prettyDebugPrinted: String {
		"""
		[
		\(self.map(\.debugDescription).joined(separator: ",\n").addIndentation(count: 1))
		]
		"""
	}
}
