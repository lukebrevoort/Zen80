#!/bin/sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$SCRIPT_DIR/ci_common.sh"

cd "$REPO_ROOT"
ensure_flutter

echo "==> Flutter version"
"$FLUTTER_BIN" --version

echo "==> Resolving Dart dependencies"
"$FLUTTER_BIN" pub get

echo "==> Generating iOS Flutter config files"
"$FLUTTER_BIN" build ios --config-only --no-codesign

echo "==> Installing CocoaPods dependencies"
cd "$REPO_ROOT/ios"
pod install

echo "==> Post-clone setup complete"
