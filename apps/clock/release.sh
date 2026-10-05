#!/usr/bin/env bash
# Release pipeline: universal binary → Developer ID sign (hardened runtime)
# → notarize .app → staple → build DMG → sign + notarize + staple DMG.
#
# Prerequisites (one-time):
#   1. Apple Developer Program membership.
#   2. Developer ID Application certificate installed in your login keychain.
#        Check with:  security find-identity -v -p codesigning | grep "Developer ID Application"
#   3. Notary credentials stored as a keychain profile. Create with:
#        xcrun notarytool store-credentials "CistercianClockNotary" \
#            --apple-id "you@example.com" \
#            --team-id "ABCDE12345" \
#            --password "app-specific-password"   # from appleid.apple.com
#
# Required env vars when running:
#   DEVELOPER_ID        e.g. "Developer ID Application: Jaewoo Kim (ABCDE12345)"
#   NOTARY_PROFILE      the profile name you used with notarytool store-credentials
#
# Optional:
#   APP_VERSION         e.g. "1.0.0" (defaults to Info.plist's CFBundleShortVersionString)
#
# Usage:
#   DEVELOPER_ID="Developer ID Application: ... (TEAMID)" \
#   NOTARY_PROFILE="CistercianClockNotary" \
#   ./release.sh

set -euo pipefail
cd "$(dirname "$0")"

: "${DEVELOPER_ID:?Set DEVELOPER_ID env var (see header of this script)}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE env var (see header of this script)}"

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

APP_NAME="CistercianClock"
VOLUME_NAME="Cistercian Clock"
BUNDLE_ID="dev.jaewoos.CistercianClock"
ENTITLEMENTS="Resources/Entitlements.plist"

VERSION="${APP_VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)}"

OUT=build/release
APP="$OUT/$APP_NAME.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

echo "=== Clean"
rm -rf "$OUT"
mkdir -p "$BIN_DIR" "$RES_DIR" "$OUT/arm64" "$OUT/x86_64"

echo "=== Compile arm64"
"$SWIFTC" -O -sdk "$SDK_ROOT" -target arm64-apple-macos13.0 \
    -framework AppKit -framework ServiceManagement \
    -o "$OUT/arm64/$APP_NAME" \
    Sources/CistercianRenderer.swift Sources/AppDelegate.swift Sources/main.swift

echo "=== Compile x86_64"
"$SWIFTC" -O -sdk "$SDK_ROOT" -target x86_64-apple-macos13.0 \
    -framework AppKit -framework ServiceManagement \
    -o "$OUT/x86_64/$APP_NAME" \
    Sources/CistercianRenderer.swift Sources/AppDelegate.swift Sources/main.swift

echo "=== Fuse into a universal binary"
lipo -create "$OUT/arm64/$APP_NAME" "$OUT/x86_64/$APP_NAME" -output "$BIN_DIR/$APP_NAME"
file "$BIN_DIR/$APP_NAME"

echo "=== Assemble bundle"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ ! -f Resources/AppIcon.icns ]]; then
    echo "Resources/AppIcon.icns missing — run ./build_icon.sh first" >&2
    exit 1
fi
cp Resources/AppIcon.icns "$RES_DIR/AppIcon.icns"

echo "=== Sign .app (hardened runtime, Developer ID)"
codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID" \
    --entitlements "$ENTITLEMENTS" \
    --identifier "$BUNDLE_ID" \
    "$APP"

echo "=== Verify signature"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP" || true  # may say "unknown" until notarized

echo "=== Notarize .app (zip → notarytool → wait)"
ZIP="$OUT/${APP_NAME}.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "=== Staple the .app"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "=== Build DMG"
DMG="$OUT/${APP_NAME}-${VERSION}.dmg"
STAGE="$OUT/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

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
