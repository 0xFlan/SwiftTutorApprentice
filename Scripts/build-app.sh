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
REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=check-source-provenance.sh
source "${REPO_ROOT}/Scripts/check-source-provenance.sh"

assert_clean_source_provenance "$REPO_ROOT"
SOURCE_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"

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

# Prove the assembled executable is the exact release artifact before signing.
# Signing mutates the Mach-O, so this equality check must happen here.
UNSIGNED_RELEASE_SHA="$(shasum -a 256 "$BIN_PATH" | awk '{print $1}')"
UNSIGNED_BUNDLE_SHA="$(shasum -a 256 "${APP_DIR}/Contents/MacOS/${BINARY}" | awk '{print $1}')"
if [[ "$UNSIGNED_RELEASE_SHA" != "$UNSIGNED_BUNDLE_SHA" ]]; then
    echo "!! Copied bundle executable does not match the unsigned release binary" >&2
    exit 1
fi

# Re-check after compilation and copying so modified source cannot be sealed as
# a clean commit. Also reject a clean HEAD change that happened during build.
assert_clean_source_provenance "$REPO_ROOT"
POST_BUILD_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
if [[ "$POST_BUILD_COMMIT" != "$SOURCE_COMMIT" ]]; then
    echo "!! Source HEAD changed during build: $SOURCE_COMMIT -> $POST_BUILD_COMMIT" >&2
    exit 1
fi
cat > "${APP_DIR}/Contents/Resources/BuildManifest.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SourceCommit</key>             <string>${SOURCE_COMMIT}</string>
    <key>SourceWorkingTreeState</key>   <string>clean</string>
    <key>UnsignedExecutableSHA256</key> <string>${UNSIGNED_RELEASE_SHA}</string>
</dict>
</plist>
PLIST

# Copy the app icon in, if it exists.
ICON_LINE=""
if [[ -f "Resources/AppIcon.icns" ]]; then
    cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
    ICON_LINE="    <key>CFBundleIconFile</key>       <string>AppIcon</string>"
fi

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
${ICON_LINE}
</dict>
</plist>
PLIST

# Ad-hoc code signature so macOS is happy launching it locally.
# (No Apple Developer account needed for personal use.) A failed signature is
# a failed build because the verifier relies on the sealed bundle resources.
codesign --force --deep --sign - "$APP_DIR"

# Signing is an external process and is the final mutation boundary. Verify the
# signature it produced, then prove source provenance and HEAD stayed fixed
# before printing any success claim.
CODESIGN_VERIFY_OUTPUT="$(codesign --verify --deep --strict --verbose=2 "$APP_DIR" 2>&1)" \
    || {
        echo "!! codesign verification failed: $CODESIGN_VERIFY_OUTPUT" >&2
        exit 1
    }
assert_clean_source_provenance "$REPO_ROOT"
FINAL_SOURCE_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
if [[ "$FINAL_SOURCE_COMMIT" != "$SOURCE_COMMIT" ]]; then
    echo "!! Source HEAD changed during bundle assembly: $SOURCE_COMMIT -> $FINAL_SOURCE_COMMIT" >&2
    exit 1
fi

echo ""
echo "==> Done."
echo "    App: ${PWD}/${APP_DIR}"
echo "    Double-click it in Finder, or run:  open \"${APP_DIR}\""
