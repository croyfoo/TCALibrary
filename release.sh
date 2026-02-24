#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# Release TCALibrary
# ──────────────────────────────────────────────
# This script supports two release modes:
#
#   Binary (XCFramework):
#     1. Builds the XCFramework (calls build-xcframework.sh)
#     2. Computes checksum
#     3. Updates Package.swift for binary distribution
#     4. Commits, tags, and pushes
#     5. Creates a GitHub Release with the artifact
#
#   Source:
#     1. Updates Package.swift for source distribution
#     2. Commits, tags, and pushes
#     3. Creates a GitHub Release (no artifact)
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Clean working tree (no uncommitted changes)
#
# Usage:
#   ./release.sh
# ──────────────────────────────────────────────

FRAMEWORK_NAME="TCALibrary"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Release repo — where the GitHub Release and binary artifact are published.
# Consumers add this repo as their SPM dependency.
RELEASE_REPO="croyfoo/TCALibrary"
PACKAGE_SWIFT="${SCRIPT_DIR}/Package.swift"
BUILD_DIR="${SCRIPT_DIR}/build"
ZIP_PATH="${BUILD_DIR}/${FRAMEWORK_NAME}.xcframework.zip"

# ── Preflight checks ──
echo "🔍 Running preflight checks..."

if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI (gh) is not installed. Install with: brew install gh"
  exit 1
fi

if ! gh auth status &> /dev/null; then
  echo "❌ GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️  You have uncommitted changes:"
  git status --short
  echo ""
  echo "What would you like to do?"
  echo "  1) Commit all changes before releasing"
  echo "  2) Continue without committing (changes stay uncommitted)"
  echo "  3) Abort"
  echo ""
  read -rp "Choose [1/2/3]: " DIRTY_CHOICE
  case "${DIRTY_CHOICE}" in
    1)
      echo ""
      read -rp "Enter commit message: " COMMIT_MSG
      if [[ -z "${COMMIT_MSG}" ]]; then
        echo "❌ Commit message cannot be empty."
        exit 1
      fi
      git add -A
      git commit -m "${COMMIT_MSG}"
      echo "  ✅ Changes committed"
      ;;
    2)
      echo "  Continuing with uncommitted changes..."
      ;;
    *)
      echo "Aborted."
      exit 1
      ;;
  esac
fi

# ── Prompt for release type ──
echo ""
echo "What type of release would you like to create?"
echo "  1) Binary  — build XCFramework and attach artifact"
echo "  2) Source  — tag and release from source only"
echo ""
read -rp "Choose [1/2]: " RELEASE_TYPE_CHOICE
case "${RELEASE_TYPE_CHOICE}" in
  1) RELEASE_TYPE="binary" ;;
  2) RELEASE_TYPE="source" ;;
  *)
    echo "❌ Invalid choice."
    exit 1
    ;;
esac

# ── Prompt for version ──
CURRENT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")

# Compute a suggested next version by incrementing the patch number
SUGGESTED_VERSION=""
if [[ "${CURRENT_TAG}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
  SUGGESTED_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
fi

echo ""
echo "📋 Current latest tag: ${CURRENT_TAG}"
if [[ -n "${SUGGESTED_VERSION}" ]]; then
  echo "   Suggested next:     ${SUGGESTED_VERSION}"
fi
echo ""

if [[ -n "${SUGGESTED_VERSION}" ]]; then
  read -rp "Enter the version number for this release [${SUGGESTED_VERSION}]: " VERSION
  VERSION="${VERSION:-${SUGGESTED_VERSION}}"
else
  read -rp "Enter the version number for this release (e.g. 1.0.0): " VERSION
fi

if [[ -z "${VERSION}" ]]; then
  echo "❌ Version cannot be empty."
  exit 1
fi

# Validate semver format
if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Invalid version format. Use semantic versioning (e.g. 1.0.0)"
  exit 1
fi

# Check if tag already exists
if git rev-parse "${VERSION}" &> /dev/null; then
  echo "❌ Tag '${VERSION}' already exists."
  exit 1
fi

RELEASE_URL="https://github.com/${RELEASE_REPO}/releases/download/${VERSION}/${FRAMEWORK_NAME}.xcframework.zip"

echo ""
echo "════════════════════════════════════════════════"
echo "  Type:     ${RELEASE_TYPE}"
echo "  Version:  ${VERSION}"
echo "  Release:  ${RELEASE_REPO}"
if [[ "${RELEASE_TYPE}" == "binary" ]]; then
  echo "  URL:      ${RELEASE_URL}"
fi
echo "════════════════════════════════════════════════"
echo ""
read -rp "Proceed with this release? [Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

if [[ "${RELEASE_TYPE}" == "binary" ]]; then
  TOTAL_STEPS=5
else
  TOTAL_STEPS=3
fi
STEP=0

# ════════════════════════════════════════════════
#  Binary release steps
# ════════════════════════════════════════════════
if [[ "${RELEASE_TYPE}" == "binary" ]]; then

  # ── Build XCFramework ──
  STEP=$((STEP + 1))
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Step ${STEP}/${TOTAL_STEPS}: Building XCFramework"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Ensure we build from source, not from a stale binary target
  sed -i '' 's/^let useBinaryTarget = true/let useBinaryTarget = false/' "${PACKAGE_SWIFT}"

  cd "${SCRIPT_DIR}"
  ./build-xcframework.sh

  if [ ! -f "${ZIP_PATH}" ]; then
    echo "❌ Build failed — ${ZIP_PATH} not found."
    exit 1
  fi

  # ── Compute checksum ──
  STEP=$((STEP + 1))
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Step ${STEP}/${TOTAL_STEPS}: Computing checksum"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  CHECKSUM=$(swift package compute-checksum "${ZIP_PATH}")
  echo "  Checksum: ${CHECKSUM}"

  # ── Update Package.swift for binary ──
  STEP=$((STEP + 1))
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Step ${STEP}/${TOTAL_STEPS}: Updating Package.swift"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  sed -i '' 's/^let useBinaryTarget = false/let useBinaryTarget = true/' "${PACKAGE_SWIFT}"
  sed -i '' "s|^let binaryURL = .*|let binaryURL = \"${RELEASE_URL}\"|" "${PACKAGE_SWIFT}"
  sed -i '' "s|^let binaryChecksum = .*|let binaryChecksum = \"${CHECKSUM}\"|" "${PACKAGE_SWIFT}"

  echo "  ✅ Package.swift updated"
  echo "    useBinaryTarget = true"
  echo "    binaryURL       = ${RELEASE_URL}"
  echo "    binaryChecksum  = ${CHECKSUM}"

fi

# ════════════════════════════════════════════════
#  Source release steps
# ════════════════════════════════════════════════
if [[ "${RELEASE_TYPE}" == "source" ]]; then

  # ── Update Package.swift for source ──
  STEP=$((STEP + 1))
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Step ${STEP}/${TOTAL_STEPS}: Updating Package.swift"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  sed -i '' 's/^let useBinaryTarget = true/let useBinaryTarget = false/' "${PACKAGE_SWIFT}"

  echo "  ✅ Package.swift updated"
  echo "    useBinaryTarget = false"

fi

# ════════════════════════════════════════════════
#  Common: commit, tag, push, GitHub release
# ════════════════════════════════════════════════

# ── Commit and tag ──
STEP=$((STEP + 1))
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step ${STEP}/${TOTAL_STEPS}: Committing and tagging"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "${RELEASE_TYPE}" == "binary" ]]; then
  COMMIT_MSG="Release ${VERSION} — binary XCFramework distribution"
else
  COMMIT_MSG="Release ${VERSION} — source distribution"
fi

git add "${PACKAGE_SWIFT}"
git commit -m "${COMMIT_MSG}"
git tag "${VERSION}"

# Push to the source remote (DoubleDogSoftware/TCALibrary)
SOURCE_REMOTE=$(git remote | head -1)
echo "  Pushing to source remote '${SOURCE_REMOTE}'..."
git push "${SOURCE_REMOTE}" main --tags

# Ensure the release remote exists and push the tag + commit there too
RELEASE_REMOTE_URL="https://github.com/${RELEASE_REPO}.git"
if ! git remote get-url release &> /dev/null; then
  echo "  Adding 'release' remote → ${RELEASE_REMOTE_URL}"
  git remote add release "${RELEASE_REMOTE_URL}"
fi
echo "  Pushing to release remote '${RELEASE_REPO}'..."
git push release main --tags --force

echo "  ✅ Pushed commit and tag ${VERSION} to both remotes"

# ── Create GitHub Release ──
STEP=$((STEP + 1))
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step ${STEP}/${TOTAL_STEPS}: Creating GitHub Release"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "${RELEASE_TYPE}" == "binary" ]]; then
  gh release create "${VERSION}" \
    "${ZIP_PATH}" \
    --repo "${RELEASE_REPO}" \
    --title "${VERSION}" \
    --notes "TCALibrary ${VERSION} binary XCFramework release."
else
  gh release create "${VERSION}" \
    --repo "${RELEASE_REPO}" \
    --title "${VERSION}" \
    --notes "TCALibrary ${VERSION} source release."
fi

echo ""
echo "════════════════════════════════════════════════"
echo "🎉 Release ${VERSION} published! (${RELEASE_TYPE})"
echo ""
echo "  GitHub Release: https://github.com/${RELEASE_REPO}/releases/tag/${VERSION}"
echo ""
echo "  Consumers can add this dependency:"
echo ""
echo "    .package(url: \"https://github.com/${RELEASE_REPO}\", from: \"${VERSION}\")"
echo "════════════════════════════════════════════════"
