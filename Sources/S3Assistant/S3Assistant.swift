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

		try await listAccumulatedFileInfo(in: "logs", prefix: "plex-folder/", on: controller)
//		try await getRecentFiles(on: controller)
//		try await deleteOldFileLoop()
//		try await getFile(on: controller)
//		try await moveFiles(
//			in: "logs",
//			operation: .prefix(sourcePrefix: <#T##String#>, destinationPrefix: <#T##String#>, overwrite: <#T##Bool#>),
//			on: <#T##S3Controller#>)
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

	func listAccumulatedFileInfo(
		in bucket: String,
		prefix: String?,
		on controller: S3Controller) async throws {
			let results = try await controller
				.listAllFiles(
					in: bucket,
					prefix: prefix,
					delimiter: "/",
					recurse: false)

			print(results.prettyPrinted)
		}

	func getRecentFiles(on controller: S3Controller) async throws {

		let oneDayAgo = Date().addingTimeInterval(-86400 * 5)

		let files = try await controller.listAllFiles(
			in: "logs",
//			prefix: ,
			delimiter: "/",
			recurse: false,
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

	func getSizeOfFolder(named folderName: String, on controller: S3Controller) async throws {
		let sizeFormatter = ByteCountFormatter()
		sizeFormatter.countStyle = .file

		var totalSize: Int = 0
		_ = try await controller
			.listAllFiles(
				in: ENV["bucket"]!,
				prefix: folderName,
				delimiter: "/",
				pageLimit: nil,
				recurse: true) { result, _ in
					let thisSize = result.files.map(\.size).reduce(0, +)
					print("added page size of \(sizeFormatter.string(fromByteCount: Int64(thisSize)))")
					totalSize += thisSize
					return result.files
				}

		print("Total size of directory: \(sizeFormatter.string(fromByteCount: Int64(totalSize)))")
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
}
