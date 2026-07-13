#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(git rev-parse --show-toplevel)"
# shellcheck source=check-source-provenance.sh
source "${REPO_ROOT}/Scripts/check-source-provenance.sh"

assert_clean_source_provenance "$REPO_ROOT"
VERIFICATION_START_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"

APP_DIR="dist/SwiftTutor Apprentice.app"
EXECUTABLE="${APP_DIR}/Contents/MacOS/SwiftTutorApprentice"
INFO_PLIST="${APP_DIR}/Contents/Info.plist"
MANIFEST="${APP_DIR}/Contents/Resources/BuildManifest.plist"
EXPECTED_BUNDLE_ID="com.local.swifttutorapprentice"
EXPECTED_EXECUTABLE_NAME="SwiftTutorApprentice"

if [[ ! -d "$APP_DIR" ]]; then
    echo "$APP_DIR is missing" >&2
    exit 1
fi

fail() {
    echo "Bundle verification failed: $*" >&2
    exit 1
}

[[ -x "$EXECUTABLE" ]] || fail "$EXECUTABLE is missing or not executable"
[[ -f "$INFO_PLIST" ]] || fail "$INFO_PLIST is missing"
[[ -f "$MANIFEST" ]] || fail "$MANIFEST is missing"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST" 2>/dev/null)" \
    || fail "CFBundleIdentifier is missing from $INFO_PLIST"
[[ "$BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] \
    || fail "expected bundle ID $EXPECTED_BUNDLE_ID, found $BUNDLE_ID"
INFO_EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST" 2>/dev/null)" \
    || fail "CFBundleExecutable is missing from $INFO_PLIST"
[[ "$INFO_EXECUTABLE_NAME" == "$EXPECTED_EXECUTABLE_NAME" ]] \
    || fail "expected CFBundleExecutable $EXPECTED_EXECUTABLE_NAME, found $INFO_EXECUTABLE_NAME"

# Strict verification proves the executable and every resource covered by the
# bundle seal (including BuildManifest.plist) still match the signature.
CODESIGN_VERIFY_OUTPUT="$(codesign --verify --deep --strict --verbose=2 "$APP_DIR" 2>&1)" \
    || fail "codesign verification failed: $CODESIGN_VERIFY_OUTPUT"
CODESIGN_METADATA="$(codesign -d --verbose=4 "$APP_DIR" 2>&1)" \
    || fail "could not read codesign metadata"
CODESIGN_IDENTIFIER_LINES="$(printf '%s\n' "$CODESIGN_METADATA" | sed -n 's/^Identifier=//p')"
CODESIGN_IDENTIFIER_COUNT="$(printf '%s\n' "$CODESIGN_METADATA" | awk '/^Identifier=/{count++} END{print count+0}')"
[[ "$CODESIGN_IDENTIFIER_COUNT" == "1" ]] \
    || fail "codesign metadata must contain exactly one identifier"
[[ "$CODESIGN_IDENTIFIER_LINES" == "$EXPECTED_BUNDLE_ID" ]] \
    || fail "codesign metadata identifier $CODESIGN_IDENTIFIER_LINES does not exactly match $EXPECTED_BUNDLE_ID"
[[ "$CODESIGN_METADATA" == *"Signature=adhoc"* ]] \
    || fail "bundle does not have the required ad-hoc signature"
[[ "$CODESIGN_METADATA" == *"Sealed Resources version="* ]] \
    || fail "codesign metadata does not report sealed resources"

SOURCE_COMMIT="$(/usr/libexec/PlistBuddy -c 'Print :SourceCommit' "$MANIFEST" 2>/dev/null)" \
    || fail "SourceCommit is missing from $MANIFEST"
MANIFEST_UNSIGNED_SHA="$(/usr/libexec/PlistBuddy -c 'Print :UnsignedExecutableSHA256' "$MANIFEST" 2>/dev/null)" \
    || fail "UnsignedExecutableSHA256 is missing from $MANIFEST"
require_clean_manifest_provenance "$MANIFEST" \
    || fail "manifest does not seal clean source provenance"
CURRENT_COMMIT="$VERIFICATION_START_COMMIT"

[[ "$SOURCE_COMMIT" == "$CURRENT_COMMIT" ]] \
    || fail "bundle source commit $SOURCE_COMMIT does not match current HEAD $CURRENT_COMMIT"
[[ "$MANIFEST_UNSIGNED_SHA" =~ ^[[:xdigit:]]{64}$ ]] \
    || fail "manifest unsigned SHA must be exactly 64 hexadecimal digits"

COMMIT_EPOCH="$(git show -s --format=%ct "$CURRENT_COMMIT")"
EXECUTABLE_EPOCH="$(stat -f %m "$EXECUTABLE")"
MANIFEST_EPOCH="$(stat -f %m "$MANIFEST")"
(( EXECUTABLE_EPOCH >= COMMIT_EPOCH )) \
    || fail "bundle executable is older than current source commit"
(( MANIFEST_EPOCH >= COMMIT_EPOCH )) \
    || fail "bundle manifest is older than current source commit"

SIGNED_EXECUTABLE_SHA="$(shasum -a 256 "$EXECUTABLE" | awk '{print $1}')"

assert_clean_source_provenance "$REPO_ROOT"
VERIFICATION_END_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
[[ "$VERIFICATION_END_COMMIT" == "$VERIFICATION_START_COMMIT" ]] \
    || fail "source HEAD changed during verification: $VERIFICATION_START_COMMIT -> $VERIFICATION_END_COMMIT"

printf 'Verified bundle: %s\n' "${PWD}/${APP_DIR}"
printf 'Signed executable SHA-256: %s\n' "$SIGNED_EXECUTABLE_SHA"
printf 'Manifest unsigned SHA-256: %s\n' "$MANIFEST_UNSIGNED_SHA"
printf 'Source commit: %s\n' "$SOURCE_COMMIT"
