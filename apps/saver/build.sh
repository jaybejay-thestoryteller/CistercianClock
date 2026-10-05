#!/usr/bin/env bash
# Dev build: single-arch (arm64), ad-hoc signed, outputs CistercianSaver.saver.
# Install locally with `open build/CistercianSaver.saver`.
# For a signed/notarized distribution, use release.sh.
set -euo pipefail
cd "$(dirname "$0")"

SWIFTC="/Library/Developer/CommandLineTools/usr/bin/swiftc"
[[ -x "$SWIFTC" ]] || SWIFTC="$(xcrun -f swiftc)"

SDK_ROOT=""
for candidate in \
    /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
    /Library/Developer/CommandLineTools/SDKs/MacOSX27.sdk \
    /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk; do
    [[ -d "$candidate" ]] && { SDK_ROOT="$candidate"; break; }
done
[[ -n "$SDK_ROOT" ]] || { echo "No SDK found" >&2; exit 1; }

SAVER="build/CistercianSaver.saver"
BIN_DIR="$SAVER/Contents/MacOS"
RES_DIR="$SAVER/Contents/Resources"

rm -rf build
mkdir -p "$BIN_DIR" "$RES_DIR"

# Screen savers are loaded as Mach-O bundles (not dylibs, not executables).
# `-emit-library -Xlinker -bundle` produces an MH_BUNDLE binary that the
# ScreenSaverEngine can load via NSBundle/principalClass.
"$SWIFTC" \
    -O \
    -sdk "$SDK_ROOT" \
    -target arm64-apple-macos13.0 \
    -module-name CistercianSaver \
    -emit-library \
    -Xlinker -bundle \
    -framework AppKit \
    -framework ScreenSaver \
    -o "$BIN_DIR/CistercianSaver" \
    ../../shared/CistercianRenderer.swift \
    Sources/CistercianSaverView.swift

cp Resources/Info.plist "$SAVER/Contents/Info.plist"

codesign --force --sign - "$SAVER" >/dev/null

echo "Built (dev): $SAVER"
echo "Install: open $SAVER"
