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
let binaryURL = "https://github.com/croyfoo/TCALibrary/releases/download/0.1.36/TCALibrary.xcframework.zip"
let binaryChecksum = "d4e8604526e761bd2b2ad17906ed0eb5d3a4af0e5e064975c43fbb048a3ee56b"

let package = Package(
  name: "TCALibrary",
  platforms: [
    .iOS(.v18),
    .macOS(.v15)
  ],
  products: [
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
        ],
        swiftSettings: [
          .unsafeFlags([
            "-enable-library-evolution",
            "-emit-module-interface",
            "-no-verify-emitted-module-interface",
          ]),
        ]
      ),
      .testTarget(
        name: "TCALibraryTests",
        dependencies: ["TCALibrary"]
      ),
    ]
)
