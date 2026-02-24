#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# Build XCFramework for TCALibrary
# ──────────────────────────────────────────────
# This script builds TCALibrary as an XCFramework
# for iOS (device + simulator), then
# zips it and computes the checksum for SPM
# binary target distribution.
#
# Usage:
#   ./build-xcframework.sh
#
# Output:
#   build/TCALibrary.xcframework.zip
#   (checksum printed to stdout)
# ──────────────────────────────────────────────

SCHEME="TCALibrary"
FRAMEWORK_NAME="TCALibrary"
BUILD_DIR="$(pwd)/build"
ARCHIVE_DIR="${BUILD_DIR}/archives"
XCFRAMEWORK_DIR="${BUILD_DIR}/${FRAMEWORK_NAME}.xcframework"
ZIP_PATH="${BUILD_DIR}/${FRAMEWORK_NAME}.xcframework.zip"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_SWIFT="${SCRIPT_DIR}/Package.swift"

# ── Helper: copy .swiftmodule into framework bundle ──
# xcodebuild archive places .swiftmodule directories in DerivedData
# rather than inside the .framework bundle. We copy them into
# <framework>/Modules so that xcodebuild -create-xcframework
# picks them up and consumers get the Swift module interfaces.
# Must be called immediately after each archive build before the
# next build overwrites the intermediates.
copy_swiftmodule() {
  local ARCHIVE_NAME="$1"   # e.g. ios-device
  local BUILD_CONFIG="$2"   # e.g. Release-iphoneos
  local ARCH_TRIPLE="$3"    # e.g. arm64-apple-ios

  local FRAMEWORK_DIR="${ARCHIVE_DIR}/${ARCHIVE_NAME}.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework"
  local SWIFTMODULE_SRC="${BUILD_DIR}/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/${SCHEME}/BuildProductsPath/${BUILD_CONFIG}/${FRAMEWORK_NAME}.swiftmodule"
  local INTERMEDIATES_DIR="${BUILD_DIR}/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/${SCHEME}/IntermediateBuildFilesPath/${FRAMEWORK_NAME}.build/${BUILD_CONFIG}/${FRAMEWORK_NAME}.build/Objects-normal/arm64"

  if [ ! -d "${FRAMEWORK_DIR}" ]; then
    echo "  ⚠️  ${ARCHIVE_NAME}: framework not found, skipping"
    return
  fi

  local DEST="${FRAMEWORK_DIR}/Modules/${FRAMEWORK_NAME}.swiftmodule"
  mkdir -p "${DEST}"

  # Copy .swiftmodule, .swiftdoc, .abi.json from BuildProductsPath (already arch-prefixed)
  if [ -d "${SWIFTMODULE_SRC}" ]; then
    cp -a "${SWIFTMODULE_SRC}/"* "${DEST}/"
  fi

  # Copy .swiftinterface files from IntermediateBuildFilesPath (need arch prefix)
  for EXT in swiftinterface private.swiftinterface package.swiftinterface; do
    local SRC_FILE="${INTERMEDIATES_DIR}/${FRAMEWORK_NAME}.${EXT}"
    if [ -f "${SRC_FILE}" ]; then
      cp "${SRC_FILE}" "${DEST}/${ARCH_TRIPLE}.${EXT}"
    fi
  done

  echo "  ✅ ${ARCHIVE_NAME}: copied .swiftmodule + .swiftinterface"
  ls "${DEST}/" | sed 's/^/     /'
}

# ── Inject library-evolution flags into TCALibrary target only ──
# BUILD_LIBRARY_FOR_DISTRIBUTION=YES can't be passed globally because
# ComposableArchitecture doesn't compile with library evolution.
# Instead we temporarily add swiftSettings to the TCALibrary target
# in Package.swift so only our code gets the flags.
echo "🔧 Injecting library-evolution swiftSettings into Package.swift..."
cp "${PACKAGE_SWIFT}" "${PACKAGE_SWIFT}.bak"
restore_package_swift() {
  if [ -f "${PACKAGE_SWIFT}.bak" ]; then
    mv "${PACKAGE_SWIFT}.bak" "${PACKAGE_SWIFT}"
  fi
}
trap restore_package_swift EXIT

sed -i '' '/"DDSCommon"/{
n
s|        \]|        ],\
        swiftSettings: [\
          .unsafeFlags(["-enable-library-evolution", "-emit-module-interface"]),\
        ]|
}' "${PACKAGE_SWIFT}"

# Clean previous build artifacts
echo "🧹 Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
mkdir -p "${ARCHIVE_DIR}"

# ── iOS Device ──
echo "📱 Building for iOS (arm64)..."
xcodebuild archive \
  -skipMacroValidation \
  -scheme "${SCHEME}" \
  -destination "generic/platform=iOS" \
  -archivePath "${ARCHIVE_DIR}/ios-device" \
  -derivedDataPath "${BUILD_DIR}/DerivedData" \
  SKIP_INSTALL=NO \
  SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  INSTALL_PATH=/Library/Frameworks \
  2>&1 | tail -5
copy_swiftmodule "ios-device" "Release-iphoneos" "arm64-apple-ios"

# ── iOS Simulator ──
echo "📱 Building for iOS Simulator (arm64 + x86_64)..."
xcodebuild archive \
  -skipMacroValidation \
  -scheme "${SCHEME}" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "${ARCHIVE_DIR}/ios-simulator" \
  -derivedDataPath "${BUILD_DIR}/DerivedData" \
  SKIP_INSTALL=NO \
  SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  INSTALL_PATH=/Library/Frameworks \
  2>&1 | tail -5
copy_swiftmodule "ios-simulator" "Release-iphonesimulator" "arm64-apple-ios-simulator"

# ── Create XCFramework ──
echo "📦 Creating XCFramework..."

# Locate the .framework inside each archive
IOS_FRAMEWORK="${ARCHIVE_DIR}/ios-device.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework"
SIM_FRAMEWORK="${ARCHIVE_DIR}/ios-simulator.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework"

ARGS=()

if [ -d "${IOS_FRAMEWORK}" ]; then
  ARGS+=(-framework "${IOS_FRAMEWORK}")
fi

if [ -d "${SIM_FRAMEWORK}" ]; then
  ARGS+=(-framework "${SIM_FRAMEWORK}")
fi

if [ ${#ARGS[@]} -eq 0 ]; then
  echo "❌ No frameworks found in archives. Build may have failed."
  echo ""
  echo "Checking archive contents..."
  find "${ARCHIVE_DIR}" -name "*.framework" -type d 2>/dev/null || echo "  (none found)"
  exit 1
fi

xcodebuild -create-xcframework \
  "${ARGS[@]}" \
  -output "${XCFRAMEWORK_DIR}"

# ── Zip and checksum ──
echo "🗜️  Zipping XCFramework..."
cd "${BUILD_DIR}"
zip -r -q "${FRAMEWORK_NAME}.xcframework.zip" "${FRAMEWORK_NAME}.xcframework"
cd - > /dev/null

echo "🔑 Computing checksum..."
CHECKSUM=$(swift package compute-checksum "${ZIP_PATH}")

echo ""
echo "════════════════════════════════════════════════"
echo "✅ Build complete!"
echo ""
echo "  XCFramework: ${XCFRAMEWORK_DIR}"
echo "  Zip:         ${ZIP_PATH}"
echo "  Checksum:    ${CHECKSUM}"
echo ""
echo "Update your Package.swift binaryTarget with:"
echo ""
echo "  .binaryTarget("
echo "    name: \"${FRAMEWORK_NAME}\","
echo "    url: \"https://github.com/croyfoo/TCALibrary/releases/download/<VERSION>/${FRAMEWORK_NAME}.xcframework.zip\","
echo "    checksum: \"${CHECKSUM}\""
echo "  )"
echo "════════════════════════════════════════════════"
