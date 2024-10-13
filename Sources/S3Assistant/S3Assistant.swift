import ArgumentParser
import S3AssistantCore
import Foundation
import Algorithms
import SwiftlyDotEnv
import SwiftPizzaSnips
import SwiftCurses

typealias ENV = SwiftlyDotEnv

@main
struct S3Assistant: AsyncParsableCommand {
	@Flag(name: [.customLong("printXML"), .short], help: "Print out raw response xml")
	var printXML = false

    mutating func run() async throws {
		try SwiftlyDotEnv.loadDotEnv()

		try await getSizeOfSubdirectory(inBucket: "logs", listingOption: .bucket)
    }

	private func getController() throws -> S3Controller {
		try S3Controller(
			authKey: SwiftlyDotEnv["authKey"].unwrap("Missing 'authKey' in environment"),
			authSecret: SwiftlyDotEnv["authSecret"].unwrap("Missing 'authSecret' in environment"),
			serviceURL: SwiftlyDotEnv["serviceURL"].unwrap("Missing 'serviceURL' in environment"),
			region: "\(SwiftlyDotEnv["region"].unwrap("Missing 'region' in environment"))").with { instance in
				instance.printXML = printXML
			}
	}

//	func deleteOldFiles(on controller: S3Controller) async throws {
//		let stream = try await controller.listAllObjectVersions(in: "logs", prefix: nil, delimiter: nil)
//
//		try await withThrowingTaskGroup(of: Int.self) { group in
//			for chunk in chunks {
//				group.addTask {
//					try await controller.delete(
//						items: Array(chunk),
//						inBucket: "logs",
//						quiet: false)
//					return chunk.count
//				}
//			}
//
//			for try await addtlDeletedCount in group {
//				deletedFileCount += addtlDeletedCount
//				print("Deleted \(deletedFileCount) logs")
//			}
//		}
//	}

	enum ListingOption {
		case bucket
		case prefix(String, delimiter: String?)
	}

	func getSizeOfSubdirectory(inBucket bucket: String, listingOption: ListingOption) async throws {
		let controller = try getController()
		let stream: AsyncThrowingStream<S3ListObjectVersionsResult.ContentOption, Error>
		let summaryTitle: String
		switch listingOption {
		case .bucket:
			stream = try await controller.listAllObjectVersions(in: bucket)
			summaryTitle = bucket
		case .prefix(let prefix, let delimiter):
			stream = try await controller.listAllObjectVersions(in: bucket, prefix: prefix, delimiter: delimiter)
			summaryTitle = "\(bucket):\(prefix)" + (delimiter.map { " (\($0))"} ?? "")
		}

		var summary: (size: Int, objectCount: Int, deleteMarkerCount: Int) = (0, 0, 0)

		var total: Int { summary.objectCount + summary.deleteMarkerCount }

		try await initScreenAsync(
			settings: TermSetting.defaultSettings,
			windowSettings: WindowSetting.defaultSettings) { window in
				for try await item in stream {
					let note: String
					switch item {
					case .deleteMarker(let marker):
						summary.deleteMarkerCount += 1
						note = "delete marker: \(marker.key)"
					case .version(let version):
						summary.objectCount += 1
						summary.size += version.size
						note = "version: \(version.key)"
					}

					window.erase()
					try window.print(note)
					window.refresh()
				}
				try window.print("\n")

				let formatter = ByteCountFormatter()
				formatter.countStyle = .decimal
				formatter.allowedUnits = .useAll
				formatter.formattingContext = .standalone

				try window.print("\(summaryTitle) summary:\n")
				try window.print("\tObject Count: \(summary.objectCount)\n")
				if summary.deleteMarkerCount > 0 {
					try window.print("\tDelete Marker Count: \(summary.deleteMarkerCount)\n")
				}
				try window.print("\tTotal Item Count: \(total)\n")
				try window.print("\tTotal Size: \(formatter.string(fromByteCount: Int64(summary.size)))\n")

				while try window.getChar() != .char("q") {
					try window.print("Hit 'q' to quit\n")
				}
			}
	}

	/// not very useful since it just prints out the byte size, but decent proof of concept at least
	func getFile(withKey key: String, on controller: S3Controller) async throws {
		let data = try await controller
			.getObject(
				in: ENV["bucket"]!,
				withKey: key)

		print(data)
	}

	func moveFiles(
		in bucket: String,
		operation: S3Controller.WasabiMoveOperation,
		on controller: S3Controller) async throws {
			let data = try await controller
				.wasabiRenameFiles(
					in: bucket,
					operation: operation)

			let xml = try XMLDocument(data: data)
			print(xml.xmlString(options: .nodePrettyPrint))
	}

	func enumerateObjectVersions(
		in bucket: String,
		prefix: String?) async throws {
			let controller = try getController()

			let stream = try await controller.listAllObjectVersions(in: bucket, prefix: prefix, delimiter: nil)

			var accumulator: (size: Int, count: Int, oldest: Date) = (0, 0, .now)
			for try await object in stream {
				print(object)
				accumulator.count += 1
				switch object {
				case .version(let version):
					accumulator.size += version.size
					accumulator.oldest = min(accumulator.oldest, version.lastModified)
				case .deleteMarker(let deleteMarker):
					guard let lastModified = deleteMarker.lastModified else { continue }
					accumulator.oldest = min(accumulator.oldest, lastModified)
				}
			}

			print(accumulator)
		}
}
