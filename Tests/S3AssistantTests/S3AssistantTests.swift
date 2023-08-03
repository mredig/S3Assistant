import XCTest
@testable import S3AssistantCore
import XMLCoder
import CryptoKit

final class S3AssistantTests: XCTestCase {

	func testCoder() throws {
		let sampleXMLURL = Bundle.module.url(forResource: "sample2", withExtension: "xml", subdirectory: "TestAssets")!
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

	func testModSamples() throws {
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

		var test = try decoder.decode(S3ListVersionResult.self, from: data)

		func randomString() -> String {
			Insecure
				.MD5
				.hash(data: (0..<10).map({ _ in UInt8.random(in: 0..<UInt8.max) }))
				.description
				.split(separator: " ")
				.last
				.flatMap(String.init)!
		}

		test.name = "sample"
		test.nextKeyMarker = "asldhga"
		test.versions = test.versions.map({ version in
			var new = version
			new.eTag = "\"\(randomString())\""
			new.lastModified = new.lastModified.addingTimeInterval(TimeInterval.random(in: 0...(86400*5)))
			new.key = new.key.replacingOccurrences(of: ##"\w+$"##, with: randomString(), options: .regularExpression, range: nil)
			new.versionID = randomString()
			return new
		})
		test.deleteMarkers = test.deleteMarkers.map({ marker in
			var new = marker
			new.lastModified = new.lastModified.addingTimeInterval(TimeInterval.random(in: 0...(86400*5)))
			new.key = new.key.replacingOccurrences(of: ##"\w+$"##, with: randomString(), options: .regularExpression, range: nil)
			if new.versionID != nil && new.versionID != "null" {
				new.versionID = randomString()
			}
			return new
		})

		let encoder = XMLEncoder()
		encoder.dateEncodingStrategy = .custom({ date, encoder in
			let dateString = dateFormatter.string(from: date)
			var container = encoder.singleValueContainer()
			try container.encode(dateString)
		})
		encoder.keyEncodingStrategy = .capitalized
		encoder.charactersEscapedInElements = encoder
			.charactersEscapedInElements
			.filter({ (a, _) in
				a != "\""
			})
		encoder.outputFormatting = [.prettyPrinted]
		let xmlOut = try encoder.encode(
			test,
			withRootKey: "ListVersionsResult",
			rootAttributes: ["xmlns": "http://s3.amazonaws.com/doc/2006-03-01/"],
			header: XMLHeader(version: 1, encoding: "UTF-8", standalone: "yes"),
			doctype: nil)

		let sampleXMLURL2 = URL(filePath: "/Users/mredig/Developer/SwapDev/S3Assistant/Tests/S3AssistantTests/TestAssets/sample2.xml")
		try xmlOut.write(to: sampleXMLURL2)
	}

}
