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
