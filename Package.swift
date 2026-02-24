// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// ──────────────────────────────────────────────────────────────
// Toggle between source and binary distribution:
//
//   • For development / building from source:
//     Set useBinaryTarget = false
//
//   • For binary distribution (XCFramework):
//     Set useBinaryTarget = true and update the url + checksum
//     after running ./build-xcframework.sh
// ──────────────────────────────────────────────────────────────
let useBinaryTarget = false

// Update these after running ./build-xcframework.sh
let binaryURL = "https://github.com/croyfoo/TCALibrary/releases/download/1.0.2/TCALibrary.xcframework.zip"
let binaryChecksum = "b2737cf84a2e9d1e3cf42bd38ac51b36fb95507a7e45ec0bc0241f4ce9d8c8fe"

let package = Package(
  name: "TCALibrary",
  platforms: [
    .iOS(.v18),
    .macOS(.v15)
  ],
  products: useBinaryTarget
    ? [
      .library(
        name: "TCALibrary",
        targets: ["TCALibrary"]),
    ]
    : [
      .library(
        name: "TCALibrary",
        type: .dynamic,
        targets: ["TCALibrary"]),
    ],
  dependencies: useBinaryTarget ? [] : [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.0")),
    .package(url: "https://github.com/croyfoo/DDSCommon", .upToNextMajor(from: "1.0.0")),
  ],
  targets: useBinaryTarget
    ? [
      .binaryTarget(
        name: "TCALibrary",
        url: binaryURL,
        checksum: binaryChecksum
      ),
    ]
    : [
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
