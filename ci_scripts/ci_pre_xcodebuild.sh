#!/bin/sh
set -euo pipefail

# Defensive fallback: if post-clone didn't run, prepare Flutter + Pods now.
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"

cd "$REPO_ROOT"

if [ ! -f "ios/Flutter/Generated.xcconfig" ]; then
  echo "==> [pre-xcodebuild] Missing Generated.xcconfig, generating iOS Flutter config"
  flutter pub get
  flutter build ios --config-only --no-codesign
fi

if [ ! -f "ios/Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Release-input-files.xcfilelist" ]; then
  echo "==> [pre-xcodebuild] Missing Pods xcfilelists, running pod install"
  cd "$REPO_ROOT/ios"
  pod install
fi

echo "==> [pre-xcodebuild] Environment ready"
