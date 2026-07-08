#!/bin/bash
# make-icon.sh
# ------------------------------------------------------------
# Regenerates the app icon (Resources/AppIcon.icns) from
# make-icon.swift, using only built-in macOS tools (sips,
# iconutil). Run this if you want to change the icon; otherwise
# the committed AppIcon.icns is used by build-app.sh.
# ------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p Resources
WORK="$(mktemp -d)"
PNG="$WORK/icon_1024.png"
ICONSET="$WORK/AppIcon.iconset"

echo "==> Rendering 1024x1024 icon…"
swift Scripts/make-icon.swift "$PNG"

echo "==> Building iconset at all required sizes…"
mkdir -p "$ICONSET"
sips -z 16 16     "$PNG" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$PNG" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$PNG" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$PNG" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$PNG" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$PNG" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$PNG" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$PNG"                "$ICONSET/icon_512x512@2x.png"

echo "==> Converting to .icns…"
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns

rm -rf "$WORK"
echo "==> Done: Resources/AppIcon.icns"
