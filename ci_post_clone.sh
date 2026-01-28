#!/bin/sh
set -e

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}"
FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"

if [ ! -d "$FLUTTER_ROOT" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter --version
flutter precache --ios

cd "$REPO_ROOT"
flutter pub get

cd "$REPO_ROOT/ios"
pod install
