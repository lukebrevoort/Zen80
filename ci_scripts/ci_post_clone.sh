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

POD_INSTALL_MAX_ATTEMPTS="${POD_INSTALL_MAX_ATTEMPTS:-4}"
POD_INSTALL_BASE_DELAY_SECONDS="${POD_INSTALL_BASE_DELAY_SECONDS:-15}"
pod_install_succeeded=0
attempt=1

while [ "$attempt" -le "$POD_INSTALL_MAX_ATTEMPTS" ]; do
	if [ "$attempt" -eq "$POD_INSTALL_MAX_ATTEMPTS" ]; then
		echo "==> pod install attempt $attempt/$POD_INSTALL_MAX_ATTEMPTS (with repo update)"
		if pod install --repo-update; then
			pod_install_succeeded=1
			break
		fi
	else
		echo "==> pod install attempt $attempt/$POD_INSTALL_MAX_ATTEMPTS"
		if pod install; then
			pod_install_succeeded=1
			break
		fi
	fi

	if [ "$attempt" -lt "$POD_INSTALL_MAX_ATTEMPTS" ]; then
		sleep_seconds=$((POD_INSTALL_BASE_DELAY_SECONDS * attempt))
		echo "==> pod install failed; retrying in ${sleep_seconds}s"
		sleep "$sleep_seconds"
	fi
	attempt=$((attempt + 1))
done

if [ "$pod_install_succeeded" -ne 1 ]; then
	echo "==> pod install failed after $POD_INSTALL_MAX_ATTEMPTS attempts"
	exit 1
fi

echo "==> Post-clone setup complete"
