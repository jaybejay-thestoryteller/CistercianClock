#!/usr/bin/env bash
# Release pipeline for CistercianSaver.saver:
# universal binary → Developer ID sign (hardened runtime) → notarize .saver
# → staple → build DMG → sign + notarize + staple DMG.
#
# Same prerequisites as apps/clock/release.sh. Uses the same keychain profile.
#
# Usage:
#   DEVELOPER_ID="Developer ID Application: ... (TEAMID)" \
#   NOTARY_PROFILE="CistercianClockNotary" \
#   ./release.sh
set -euo pipefail
cd "$(dirname "$0")"

: "${DEVELOPER_ID:?Set DEVELOPER_ID env var}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE env var}"

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

SAVER_NAME="CistercianSaver"
VOLUME_NAME="Cistercian Saver"
BUNDLE_ID="dev.jaewoos.CistercianSaver"
ENTITLEMENTS="../clock/Resources/Entitlements.plist"   # empty-plist, shared

VERSION="${APP_VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)}"

OUT=build/release
SAVER="$OUT/$SAVER_NAME.saver"
BIN_DIR="$SAVER/Contents/MacOS"
RES_DIR="$SAVER/Contents/Resources"

echo "=== Clean"
rm -rf "$OUT"
mkdir -p "$BIN_DIR" "$RES_DIR" "$OUT/arm64" "$OUT/x86_64"

echo "=== Compile arm64 (bundle)"
"$SWIFTC" -O -sdk "$SDK_ROOT" -target arm64-apple-macos13.0 \
    -module-name "$SAVER_NAME" \
    -emit-library -Xlinker -bundle \
    -framework AppKit -framework ScreenSaver \
    -o "$OUT/arm64/$SAVER_NAME" \
    ../../shared/CistercianRenderer.swift Sources/CistercianSaverView.swift

echo "=== Compile x86_64 (bundle)"
"$SWIFTC" -O -sdk "$SDK_ROOT" -target x86_64-apple-macos13.0 \
    -module-name "$SAVER_NAME" \
    -emit-library -Xlinker -bundle \
    -framework AppKit -framework ScreenSaver \
    -o "$OUT/x86_64/$SAVER_NAME" \
    ../../shared/CistercianRenderer.swift Sources/CistercianSaverView.swift

echo "=== Fuse universal"
lipo -create "$OUT/arm64/$SAVER_NAME" "$OUT/x86_64/$SAVER_NAME" -output "$BIN_DIR/$SAVER_NAME"
file "$BIN_DIR/$SAVER_NAME"

echo "=== Assemble bundle"
cp Resources/Info.plist "$SAVER/Contents/Info.plist"

echo "=== Sign .saver"
codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID" \
    --entitlements "$ENTITLEMENTS" \
    --identifier "$BUNDLE_ID" \
    "$SAVER"

echo "=== Verify"
codesign --verify --deep --strict --verbose=2 "$SAVER"

echo "=== Notarize .saver"
ZIP="$OUT/${SAVER_NAME}.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$SAVER" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "=== Staple .saver"
xcrun stapler staple "$SAVER"
xcrun stapler validate "$SAVER"

echo "=== Build DMG"
DMG="$OUT/${SAVER_NAME}-${VERSION}.dmg"
STAGE="$OUT/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$SAVER" "$STAGE/"
# Users just double-click the .saver — macOS prompts to install it automatically.

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG"

echo "=== Sign DMG"
codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG"

echo "=== Notarize + staple DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo
echo "Done. Distribute: $DMG"
