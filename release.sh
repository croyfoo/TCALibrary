#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# Release TCALibrary as a binary XCFramework
# ──────────────────────────────────────────────
# This script:
#   1. Prompts for a version number
#   2. Builds the XCFramework (calls build-xcframework.sh)
#   3. Updates Package.swift with the URL and checksum
#   4. Commits, tags, and pushes
#   5. Creates a GitHub Release with the artifact
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

# Derive owner/repo from the first git remote URL
REPO=$(git -C "${SCRIPT_DIR}" remote get-url "$(git -C "${SCRIPT_DIR}" remote | head -1)" \
  | sed -E 's#(.*github\.com[:/])##; s#\.git$##')
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

# ── Prompt for version ──
CURRENT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "none")
echo ""
echo "📋 Current latest tag: ${CURRENT_TAG}"
echo ""
read -rp "Enter the version number for this release (e.g. 1.0.0): " VERSION

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

RELEASE_URL="https://github.com/${REPO}/releases/download/${VERSION}/${FRAMEWORK_NAME}.xcframework.zip"

echo ""
echo "════════════════════════════════════════════════"
echo "  Version:  ${VERSION}"
echo "  Repo:     ${REPO}"
echo "  URL:      ${RELEASE_URL}"
echo "════════════════════════════════════════════════"
echo ""
read -rp "Proceed with this release? (y/N): " CONFIRM
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

# ── Step 1: Build XCFramework ──
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 1/5: Building XCFramework"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd "${SCRIPT_DIR}"
./build-xcframework.sh

if [ ! -f "${ZIP_PATH}" ]; then
  echo "❌ Build failed — ${ZIP_PATH} not found."
  exit 1
fi

# ── Step 2: Compute checksum ──
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 2/5: Computing checksum"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CHECKSUM=$(swift package compute-checksum "${ZIP_PATH}")
echo "  Checksum: ${CHECKSUM}"

# ── Step 3: Update Package.swift ──
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 3/5: Updating Package.swift"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Update useBinaryTarget to true
sed -i '' 's/^let useBinaryTarget = false/let useBinaryTarget = true/' "${PACKAGE_SWIFT}"

# Update the binary URL
sed -i '' "s|^let binaryURL = .*|let binaryURL = \"${RELEASE_URL}\"|" "${PACKAGE_SWIFT}"

# Update the checksum
sed -i '' "s|^let binaryChecksum = .*|let binaryChecksum = \"${CHECKSUM}\"|" "${PACKAGE_SWIFT}"

echo "  ✅ Package.swift updated"
echo ""
echo "  useBinaryTarget = true"
echo "  binaryURL       = ${RELEASE_URL}"
echo "  binaryChecksum  = ${CHECKSUM}"

# ── Step 4: Commit and tag ──
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 4/5: Committing and tagging"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
git add "${PACKAGE_SWIFT}"
git commit -m "Release ${VERSION} — binary XCFramework distribution"
git tag "${VERSION}"

# Detect the remote name (github, origin, etc.)
REMOTE=$(git remote | head -1)
echo "  Pushing to remote '${REMOTE}'..."
git push "${REMOTE}" main --tags

echo "  ✅ Pushed commit and tag ${VERSION}"

# ── Step 5: Create GitHub Release ──
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 5/5: Creating GitHub Release"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
gh release create "${VERSION}" \
  "${ZIP_PATH}" \
  --repo "${REPO}" \
  --title "${VERSION}" \
  --notes "TCALibrary ${VERSION} binary XCFramework release."

echo ""
echo "════════════════════════════════════════════════"
echo "🎉 Release ${VERSION} published!"
echo ""
echo "  GitHub Release: https://github.com/${REPO}/releases/tag/${VERSION}"
echo ""
echo "  Consumers can add this dependency:"
echo ""
echo "    .package(url: \"https://github.com/${REPO}\", from: \"${VERSION}\")"
echo "════════════════════════════════════════════════"
