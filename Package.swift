// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "TCALibrary",
  platforms: [
    .iOS(.v17),
    .macOS(.v15)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "TCALibrary",
      targets: ["TCALibrary"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.17.0")),
//    .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.6.0")),
//    .package(url: "https://github.com/pointfreeco/swift-gen", from: "0.3.1"),
//    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "0.8.4")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "TCALibrary",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        // Add any other product dependencies here
      ]
    ),
    .testTarget(
      name: "TCALibraryTests",
      dependencies: ["TCALibrary"]
    ),
  ]
)
