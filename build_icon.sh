#!/usr/bin/env bash
# Regenerate Resources/AppIcon.icns from Sources/icon_gen.swift.
# Only needs to be rerun if the icon design or CistercianRenderer changes.
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

mkdir -p build
"$SWIFTC" -O -sdk "$SDK_ROOT" -target arm64-apple-macos13.0 \
    -framework AppKit \
    -o build/icon_gen \
    Sources/CistercianRenderer.swift Sources/icon_gen.swift

./build/icon_gen
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns ($(stat -f%z Resources/AppIcon.icns) bytes)"
