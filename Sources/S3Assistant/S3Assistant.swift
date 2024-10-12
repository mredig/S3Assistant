import ArgumentParser
import S3AssistantCore
import Foundation
import Algorithms
import SwiftlyDotEnv
import SwiftPizzaSnips

typealias ENV = SwiftlyDotEnv

@main
struct S3Assistant: AsyncParsableCommand {
    mutating func run() async throws {
		try SwiftlyDotEnv.loadDotEnv()

		let controller = S3Controller(
			authKey: SwiftlyDotEnv["authKey"]!,
			authSecret: SwiftlyDotEnv["authSecret"]!,
			serviceURL: SwiftlyDotEnv["serviceURL"]!,
			region: "\(SwiftlyDotEnv["region"]!)")

		try await enumerateObjectVersions(in: "logs", prefix: nil, on: controller)
    }

//	func deleteOldFiles(on controller: S3Controller) async throws {
//		var deletedFileCount = 0
//		let ninetyDaysAgo = Date().addingTimeInterval(86400 * -90)
//
//		let oldFiles = try await accumulateOldFiles(
//			before: ninetyDaysAgo,
//			in: "logs",
//			prefix: nil,
//			recurse: true,
//			on: controller)
//
//		let chunks = oldFiles.chunks(ofCount: 1000)
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
		prefix: String?,
		on controller: S3Controller) async throws {

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
