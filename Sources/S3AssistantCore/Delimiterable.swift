import SwiftPizzaSnips

protocol Delimiterable: Withable {
	var delimiter: String? { get set }
}

extension Delimiterable {
	func withDelimiter(_ delim: String?) -> Self {
		self.with {
			$0.delimiter = delim
		}
	}
}

extension Collection where Element: Delimiterable {
	func withDelimiter(_ delim: String?) -> [Element] {
		map { $0.withDelimiter(delim) }
	}
}
