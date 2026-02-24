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
let binaryURL = "https://github.com/croyfoo/TCALibrary/releases/download/1.0.0/TCALibrary.xcframework.zip"
let binaryChecksum = "dc9a7eda872cae9d5c50a77e249d35dc18d479aab22431436bbdcaa497faf9cc"

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
