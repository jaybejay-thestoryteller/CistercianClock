#!/usr/bin/env bash
# Builds an ad-hoc-signed DMG for local preview (no Developer ID required).
# Install UX: user mounts the DMG, drags the app to Applications,
# then has to right-click → Open (or allow in System Settings) on first launch
# because the app isn't notarized.
#
# For a shippable DMG that opens cleanly on anyone's Mac, use release.sh instead.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CistercianClock"
VOLUME_NAME="Cistercian Clock"

# Fresh dev build (also copies the icon into the bundle).
./build.sh

OUT=build
APP="$OUT/$APP_NAME.app"
STAGE="$OUT/dmg-stage"
DMG="$OUT/${APP_NAME}-preview.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

echo
echo "Preview DMG: $DMG"
echo "Install: double-click to mount → drag ${APP_NAME} to Applications →"
echo "         right-click ${APP_NAME} in Applications and choose 'Open' the first time."
