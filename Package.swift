// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "S3 Assistant",
	platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
		.package(url: "https://github.com/mredig/NetworkHandler.git", .upToNextMinor(from: "2.3.0")),
		.package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
		.package(url: "https://github.com/mredig/SwiftlyDotEnv.git", from: "0.1.0"),
		.package(url: "https://github.com/CoreOffice/XMLCoder.git", from: "0.17.1")
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "S3Assistant",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
				"S3AssistantCore",
				.product(name: "Algorithms", package: "swift-algorithms"),
				"SwiftlyDotEnv",
				"XMLCoder",
            ]
        ),
		.target(
			name: "S3AssistantCore",
			dependencies: [
				"NetworkHandler",
				"XMLCoder",
			]),
		.testTarget(
			name: "S3AssistantTests",
			dependencies: [
				"S3AssistantCore",
				"XMLCoder",
			],
			resources: [
				.copy("TestAssets"),
			])

    ]
)
