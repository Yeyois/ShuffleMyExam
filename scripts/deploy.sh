#!/usr/bin/env bash
#
# Build, install, and launch JCT MixExam on a connected Android device.
#
# Usage:
#   ./scripts/deploy.sh            # release build (default)
#   ./scripts/deploy.sh --debug    # debug build
#
# Assumes the target device is already connected (USB or paired over Wi-Fi).
# Check with `adb devices`; re-pair wireless devices with `adb connect <ip>:<port>`.

set -euo pipefail

export PATH="$PATH:$HOME/development/flutter/bin"

PACKAGE="il.ac.jct.jct_mixexam"
MODE="release"
[[ "${1:-}" == "--debug" ]] && MODE="debug"

# Fail early with a clear message if no device is attached.
if ! adb get-state >/dev/null 2>&1; then
  echo "No device connected. Run 'adb devices' (or 'adb connect <ip>:<port>' for Wi-Fi)." >&2
  exit 1
fi

echo "==> Building $MODE APK..."
flutter build apk --"$MODE"

APK="build/app/outputs/flutter-apk/app-$MODE.apk"

echo "==> Installing $APK..."
adb install -r "$APK"

echo "==> Launching $PACKAGE..."
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null

echo "==> Done."
