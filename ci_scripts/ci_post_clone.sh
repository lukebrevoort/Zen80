#!/bin/sh
set -euo pipefail

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"

cd "$REPO_ROOT"

echo "==> Flutter version"
flutter --version

echo "==> Resolving Dart dependencies"
flutter pub get

echo "==> Generating iOS Flutter config files"
flutter build ios --config-only --no-codesign

echo "==> Installing CocoaPods dependencies"
cd "$REPO_ROOT/ios"
pod install

echo "==> Post-clone setup complete"
