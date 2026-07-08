#!/bin/bash
# build-app.sh
# ------------------------------------------------------------
# Builds SwiftTutor Apprentice and wraps it in a normal macOS
# .app bundle you can double-click from Finder (no Terminal
# needed to launch it).
#
# Usage:
#     ./Scripts/build-app.sh
#
# Result:
#     dist/SwiftTutor Apprentice.app   <- double-click this
#
# Re-run this script any time you change the code to rebuild.
# ------------------------------------------------------------
set -euo pipefail

# Move to the project root (this script lives in Scripts/).
cd "$(dirname "$0")/.."

APP_NAME="SwiftTutor Apprentice"     # what you see in Finder
BINARY="SwiftTutorApprentice"        # the built executable's name
BUNDLE_ID="com.local.swifttutorapprentice"
APP_DIR="dist/${APP_NAME}.app"

echo "==> Building release binary…"
# --disable-sandbox is harmless on a normal Mac and is required in
# some restricted shells; keeping it makes the build work everywhere.
swift build -c release --disable-sandbox

BIN_PATH="$(swift build -c release --disable-sandbox --show-bin-path)/${BINARY}"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "!! Could not find the built binary at: $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy the executable into the bundle.
cp "$BIN_PATH" "${APP_DIR}/Contents/MacOS/${BINARY}"

# Write the Info.plist that tells macOS how to treat this bundle.
cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>     <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>      <string>${BINARY}</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>LSApplicationCategoryType</key> <string>public.app-category.education</string>
</dict>
</plist>
PLIST

# Ad-hoc code signature so macOS is happy launching it locally.
# (No Apple Developer account needed for personal use.)
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || \
    echo "   (codesign skipped — app will still run for local personal use)"

echo ""
echo "==> Done."
echo "    App: ${PWD}/${APP_DIR}"
echo "    Double-click it in Finder, or run:  open \"${APP_DIR}\""
