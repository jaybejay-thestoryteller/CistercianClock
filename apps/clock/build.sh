#!/usr/bin/env bash
# Dev build: single-arch (arm64), ad-hoc signed, meant for `open build/CistercianClock.app`.
# For a signed/notarized distribution DMG, use release.sh instead.
set -euo pipefail

cd "$(dirname "$0")"

SWIFTC="/Library/Developer/CommandLineTools/usr/bin/swiftc"
if [[ ! -x "$SWIFTC" ]]; then
    SWIFTC="$(xcrun -f swiftc)"
fi

SDK_ROOT=""
for candidate in \
    /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
    /Library/Developer/CommandLineTools/SDKs/MacOSX27.sdk \
    /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk; do
    if [[ -d "$candidate" ]]; then
        SDK_ROOT="$candidate"
        break
    fi
done
if [[ -z "$SDK_ROOT" ]]; then
    echo "No SDK found under /Library/Developer/CommandLineTools/SDKs" >&2
    exit 1
fi

APP="build/CistercianClock.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

rm -rf build
mkdir -p "$BIN_DIR" "$RES_DIR"

"$SWIFTC" \
    -O \
    -sdk "$SDK_ROOT" \
    -target arm64-apple-macos13.0 \
    -framework AppKit \
    -framework ServiceManagement \
    -o "$BIN_DIR/CistercianClock" \
    Sources/CistercianRenderer.swift \
    Sources/AppDelegate.swift \
    Sources/main.swift

cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$RES_DIR/AppIcon.icns"
fi

codesign --force --sign - "$APP" >/dev/null

echo "Built (dev): $APP"
