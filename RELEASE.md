# TCALibrary — Build & Publish Guide

This document describes how to build the TCALibrary XCFramework and publish it as a Swift Package Manager binary package.

---

## Prerequisites

- Xcode 16+ with command line tools installed
- Swift 6.0+
- GitHub CLI (`gh`) installed — `brew install gh`
- Push access to `github.com/croyfoo/TCALibrary`

---

## 1. Develop & Test (Source Mode)

During development, `Package.swift` uses source targets by default (`useBinaryTarget = false`). Work on source files normally, run tests, and iterate.

```bash
# Run tests from the repo root
swift test
```

---

## 2. Build the XCFramework

When you're ready to publish a new version, run the build script from the repo root:

```bash
./build-xcframework.sh
```

This will:

1. Archive the library for **iOS device**, **iOS Simulator**, and **macOS**
2. Combine them into `build/TCALibrary.xcframework`
3. Zip it to `build/TCALibrary.xcframework.zip`
4. Compute and print the **SPM checksum**

The output will look like:

```
════════════════════════════════════════════════
✅ Build complete!

  XCFramework: .../build/TCALibrary.xcframework
  Zip:         .../build/TCALibrary.xcframework.zip
  Checksum:    abc123def456...

Update your Package.swift binaryTarget with:

  .binaryTarget(
    name: "TCALibrary",
    url: "https://github.com/croyfoo/TCALibrary/releases/download/<VERSION>/TCALibrary.xcframework.zip",
    checksum: "abc123def456..."
  )
════════════════════════════════════════════════
```

---

## 3. Update Package.swift

Open `Package.swift` and update these two values with the output from the script:

```swift
let useBinaryTarget = true

let binaryURL = "https://github.com/croyfoo/TCALibrary/releases/download/1.0.0/TCALibrary.xcframework.zip"
let binaryChecksum = "abc123def456..."
```

Replace `1.0.0` with your actual version tag.

---

## 4. Commit and Tag

```bash
git add Package.swift
git commit -m "Release 1.0.0 — binary XCFramework distribution"
git tag 1.0.0
git push github main --tags
```

---

## 5. Create a GitHub Release & Upload the Artifact

Using the GitHub CLI:

```bash
gh release create 1.0.0 \
  build/TCALibrary.xcframework.zip \
  --repo croyfoo/TCALibrary \
  --title "1.0.0" \
  --notes "TCALibrary 1.0.0 binary XCFramework release."
```

Or manually:

1. Go to **Releases** on the GitHub repo
2. Click **Draft a new release**
3. Set the tag to `1.0.0`
4. Attach `build/TCALibrary.xcframework.zip`
5. Publish

---

## 6. Verify the Release

In a consuming project, add or update the dependency:

```swift
.package(url: "https://github.com/croyfoo/TCALibrary", from: "1.0.0")
```

Then resolve packages and build to confirm the binary framework is downloaded and linked correctly.

---

## Switching Back to Source Mode

To return to source-based development, set the toggle back:

```swift
let useBinaryTarget = false
```

No other changes are needed — the source targets and dependencies will be used automatically.

---

## Quick Reference

| Step | Command |
|------|---------|
| Build XCFramework | `./build-xcframework.sh` |
| Tag a release | `git tag <VERSION> && git push github main --tags` |
| Create GitHub release | `gh release create <VERSION> build/TCALibrary.xcframework.zip --repo croyfoo/TCALibrary --title "<VERSION>"` |
| Compute checksum manually | `swift package compute-checksum build/TCALibrary.xcframework.zip` |
