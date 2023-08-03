import ArgumentParser
import S3AssistantCore
import Foundation
import Algorithms
import SwiftlyDotEnv

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

		try await listAccumulatedFileInfo(on: controller)
//		try await getRecentFiles(on: controller)
//		try await deleteOldFileLoop()
//		try await getSizeOfWeddingFootage(on: controller)
//		try await getFile(on: controller)
//		try await moveFiles(on: controller)
    }

	func deleteOldFileLoop(on controller: S3Controller) async throws {
		var deletedFileCount = 0

		var oldFiles = try await accumulateOldFiles(on: controller)

		while oldFiles.isEmpty == false {
			let chunks = oldFiles.chunks(ofCount: 1000)

			try await withThrowingTaskGroup(of: Int.self) { group in
				for chunk in chunks {
					group.addTask {
						try await controller.delete(
							items: Array(chunk),
							inBucket: "logs",
							quiet: false)
						return chunk.count
					}
				}

				for try await addtlDeletedCount in group {
					deletedFileCount += addtlDeletedCount
					print("Deleted \(deletedFileCount) logs")
				}
			}

			oldFiles = try await accumulateOldFiles(on: controller)
		}
	}

	func accumulateOldFiles(on controller: S3Controller) async throws -> [S3FileMetadata] {
		var continuationToken: String?

		var oldFiles: [S3FileMetadata] = []

		let ninetyDaysAgo = Date().addingTimeInterval(86400 * -90)

		print("gathering...")

		repeat {
			let result = try await controller
				.getListing(
					in: "logs",
					delimiter: "/",
					continuationToken: continuationToken)

			let newOldFiles = result.files.filter { $0.lastModified < ninetyDaysAgo }
			oldFiles.append(contentsOf: newOldFiles)
			print("got \(oldFiles.count) files")
			continuationToken = result.nextContinuation

		} while continuationToken != nil && oldFiles.count < 10000

		print("K got enough \(oldFiles.count)")

		return Array(oldFiles.prefix(10000))
	}

	func listAccumulatedFileInfo(on controller: S3Controller) async throws {
		let results = try await controller
			.listAllFiles(
				in: "logs",
				prefix: "plex-folder/plex-folder/",
				delimiter: "/",
				recurse: false)

		print(results.prettyPrinted)
	}

	func getRecentFiles(on controller: S3Controller) async throws {

		let oneDayAgo = Date().addingTimeInterval(-86400)

		let files = try await controller.listAllFiles(
			in: "logs",
			delimiter: "/",
			filter: { result, _ in
				let recentFiles = result.files.filter { $0.lastModified > oneDayAgo }
				print("found \(recentFiles.count)...")
				return recentFiles
			})

		files
			.filter { $0.name.contains("plex") == false }
			.sorted(by: { $0.lastModified < $1.lastModified } )
			.forEach { print($0) }
	}
}
