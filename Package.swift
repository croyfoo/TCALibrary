// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "TCALibrary",
  platforms: [
    .iOS(.v18),
    .macOS(.v15)
  ],
  products: [
    .library(
      name: "TCALibrary",
      targets: ["TCALibrary"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.0")),
    .package(url: "https://github.com/croyfoo/DDSCommon", .upToNextMajor(from: "1.0.0")),
  ],
  targets: [
    .target(
      name: "TCALibrary",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "DDSCommon", package: "DDSCommon"),
      ]
    ),
    .testTarget(
      name: "TCALibraryTests",
      dependencies: ["TCALibrary"]
    ),
  ]
)
