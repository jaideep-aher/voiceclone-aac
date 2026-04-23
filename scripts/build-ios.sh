#!/usr/bin/env bash
# Build VoiceCloneAAC for the iOS Simulator (CLI).
# Prerequisites:
#   - Xcode from the App Store
#   - Accept the license: sudo xcodebuild -license accept
#   - Optional: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$ROOT"
DEST="${1:-platform=iOS Simulator,name=iPhone 16}"
xcodebuild \
  -project VoiceCloneAAC.xcodeproj \
  -scheme VoiceCloneAAC \
  -destination "$DEST" \
  -configuration Debug \
  build
