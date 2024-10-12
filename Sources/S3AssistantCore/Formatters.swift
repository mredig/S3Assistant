import Foundation

enum Formatters {
	static let isoFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.timeZone = .init(secondsFromGMT: 0)
		formatter.formatOptions = [.withColonSeparatorInTime, .withDashSeparatorInDate, .withInternetDateTime, .withFractionalSeconds]
		return formatter
	}()

	static let dateFormatter: DateFormatter = {
		let f = DateFormatter()
		f.dateStyle = .medium
		f.timeStyle = .short
		return f
	}()
}
