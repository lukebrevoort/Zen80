#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not on PATH."
  exit 1
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "CocoaPods is not installed or not on PATH."
  exit 1
fi

cd "$ROOT_DIR"

flutter pub get

pushd ios >/dev/null
pod install
popd >/dev/null

mkdir -p "$ROOT_DIR/build"

CODE_SIGNING_ALLOWED=${CODE_SIGNING_ALLOWED:-NO}
CODE_SIGNING_REQUIRED=${CODE_SIGNING_REQUIRED:-NO}
CODE_SIGN_IDENTITY=${CODE_SIGN_IDENTITY:-}
CODE_SIGN_STYLE=${CODE_SIGN_STYLE:-Automatic}
DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM:-Q5T8FJNX57}

xcodebuild archive \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -destination generic/platform=iOS \
  -archivePath "$ROOT_DIR/build/Zen80.xcarchive" \
  -derivedDataPath "$ROOT_DIR/build/DerivedData" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" \
  CODE_SIGNING_REQUIRED="$CODE_SIGNING_REQUIRED" \
  CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  CODE_SIGN_STYLE="$CODE_SIGN_STYLE" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  -hideShellScriptEnvironment
