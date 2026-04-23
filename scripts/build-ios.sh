#!/usr/bin/env bash
# Build VoiceCloneAAC for the iOS Simulator (CLI).
# Prerequisites:
#   - Xcode from the App Store
#   - Accept the license: sudo xcodebuild -license accept
#   - Optional: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
#   - At least one iOS Simulator runtime installed (Xcode → Settings → Platforms),
#     ~8GB+ free disk for the download; or use a physical device destination in Xcode.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$ROOT"
DEST="${1:-platform=iOS Simulator,name=iPhone 17}"
xcodebuild \
  -project VoiceCloneAAC.xcodeproj \
  -scheme VoiceCloneAAC \
  -destination "$DEST" \
  -configuration Debug \
  build
