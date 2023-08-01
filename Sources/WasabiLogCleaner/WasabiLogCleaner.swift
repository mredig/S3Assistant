import ArgumentParser
import WasabiLogCleanerCore
import Foundation
import Algorithms
import SwiftlyDotEnv

@main
struct WasabiLogCleaner: AsyncParsableCommand {

//	static private let controller

    mutating func run() async throws {
		try SwiftlyDotEnv.loadDotEnv()

		let controller = WasabiController(
			authKey: SwiftlyDotEnv["authKey"]!,
			authSecret: SwiftlyDotEnv["authSecret"]!,
			serviceURL: SwiftlyDotEnv["serviceURL"]!,
			region: "\(SwiftlyDotEnv["region"]!)")

//		try await listAccumulatedFileInfo()
		try await getRecentFiles(on: controller)

//		try await deleteOldFileLoop()
    }

	func deleteOldFileLoop(on controller: WasabiController) async throws {
		var deletedFileCount = 0

		var oldFiles = try await accumulateOldFiles(on: controller)

		while oldFiles.isEmpty == false {
			let chunks = oldFiles.chunks(ofCount: 1000)

			try await withThrowingTaskGroup(of: Int.self) { group in
//				let oneMinuteLater = ContinuousClock.now.advanced(by: .seconds(61))
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

//				print("sleeping for a minute or so... \(ContinuousClock.now.duration(to: oneMinuteLater)) left")
//				try await Task.sleep(until: oneMinuteLater)
			}

			oldFiles = try await accumulateOldFiles(on: controller)
		}
	}

	func accumulateOldFiles(on controller: WasabiController) async throws -> [WasabiFileMetadata] {
		var continuationToken: String?

		var oldFiles: [WasabiFileMetadata] = []

		let ninetyDaysAgo = Date().addingTimeInterval(86400 * -90)

		print("gathering...")

		repeat {
			let result = try await controller
				.getListing(
					in: "logs",
					delimiter: "/",
//					pageLimit: 10,
					continuationToken: continuationToken)

			let newOldFiles = result.files.filter { $0.lastModified < ninetyDaysAgo }
			oldFiles.append(contentsOf: newOldFiles)
			print("got \(oldFiles.count) files")
			continuationToken = result.nextContinuation

		} while continuationToken != nil && oldFiles.count < 10000

		print("K got enough \(oldFiles.count)")

		return Array(oldFiles.prefix(10000))
	}

	func listAccumulatedFileInfo(on controller: WasabiController) async throws {
		var size: Int64 = 0
		var files: [WasabiFileMetadata] = []
		var oldFileCount = 0
		var recentFileCount = 0

		let sizeFormatter = ByteCountFormatter()
		sizeFormatter.countStyle = .file

		let ninetyDaysAgo = Date().addingTimeInterval(86400 * -90)

		var continuationToken: String?
		repeat {
			let result = try await controller
				.getListing(
					in: "logs",
					delimiter: "/",
//					pageLimit: 10,
					continuationToken: continuationToken)

			let additionalFiles = result.files
			files.append(contentsOf: additionalFiles)
			let additionalSize = additionalFiles.map(\.size).reduce(Int64(0), { $0 + Int64($1) })
			size += additionalSize
			let counts = {
				var old = 0
				var new = 0
				for file in additionalFiles {
					if file.lastModified < ninetyDaysAgo {
						old += 1
					} else {
						new += 1
					}
				}
				return (old, new)
			}()
			oldFileCount += counts.0
			recentFileCount += counts.1

			print("\(files.count) files (\(oldFileCount) old files, \(recentFileCount) recent files)")
			print(sizeFormatter.string(fromByteCount: size))
			print()

			continuationToken = result.nextContinuation

		} while continuationToken != nil
	}

	func getRecentFiles(on controller: WasabiController) async throws {

		let oneDayAgo = Date().addingTimeInterval(-86400)

		let files = try await controller.listAllFiles(
			in: "logs",
//			prefix: <#T##String?#>,
			delimiter: "/",
//			pageLimit: <#T##Int?#>,
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
