import XCTest
@testable import S3AssistantCore
import XMLCoder

final class S3AssistantTests: XCTestCase {

	func testCoder() throws {
		let sampleXMLURL = Bundle.module.url(forResource: "sample", withExtension: "xml", subdirectory: "TestAssets")!
		let data = try Data(contentsOf: sampleXMLURL)

		let dateFormatter = ISO8601DateFormatter()
		dateFormatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withDashSeparatorInDate, .withFractionalSeconds]
		let decoder = XMLDecoder()
		decoder.dateDecodingStrategy = .custom({ decoder in
			let dateString = try decoder.singleValueContainer().decode(String.self)
			guard
				let date = dateFormatter.date(from: dateString)
			else { throw CocoaError.error(.coderReadCorrupt) }
			return date
		})
		decoder.keyDecodingStrategy = .convertFromCapitalized

		let test = try decoder.decode(S3ListVersionResult.self, from: data)

		print(test)
	}

}
