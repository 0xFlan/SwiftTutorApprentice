#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="${REPO_ROOT}/Scripts/check-source-provenance.sh"
BUILD_SCRIPT="${REPO_ROOT}/Scripts/build-app.sh"
VERIFY_SCRIPT="${REPO_ROOT}/Scripts/verify-app-bundle.sh"

fail() {
    echo "source-provenance test failed: $*" >&2
    exit 1
}

assert_passes() {
    local description="$1"
    shift
    local output
    if ! output="$("$@" 2>&1)"; then
        fail "$description (unexpected failure: $output)"
    fi
}

assert_fails_with() {
    local description="$1"
    local expected="$2"
    shift 2
    local output
    if output="$("$@" 2>&1)"; then
        fail "$description (unexpected success)"
    fi
    [[ "$output" == *"$expected"* ]] \
        || fail "$description (missing '$expected' in: $output)"
}

assert_build_fails_without_success() {
    local description="$1"
    local hook="$2"
    local checkout="$3"
    local fake_bin="$4"
    local output

    if output="$(PATH="${fake_bin}:$PATH" PROVENANCE_TEST_HOOK="$hook" \
        "$checkout/Scripts/build-app.sh" 2>&1)"; then
        fail "$description (unexpected success: $output)"
    fi
    [[ "$output" != *"==> Done."* ]] \
        || fail "$description (printed success after provenance changed: $output)"
}

new_fixture() {
    local fixture
    fixture="$(mktemp -d "${TMPDIR:-/tmp}/swift-tutor-provenance.XXXXXX")"
    git -C "$fixture" init -q
    git -C "$fixture" config user.email "provenance-tests@example.invalid"
    git -C "$fixture" config user.name "Provenance Tests"
    mkdir -p "$fixture/Sources/App" "$fixture/docs"
    printf '// package\n' > "$fixture/Package.swift"
    printf 'print("clean")\n' > "$fixture/Sources/App/main.swift"
    printf '.build/\ndist/\n' > "$fixture/.gitignore"
    git -C "$fixture" add .
    git -C "$fixture" commit -qm "fixture"
    printf '%s\n' "$fixture"
}

[[ -x "$GUARD" ]] || fail "shared provenance guard is missing or not executable"
# shellcheck source=../../Scripts/check-source-provenance.sh
source "$GUARD"

fixture="$(new_fixture)"
invalid_repo="$(mktemp -d "${TMPDIR:-/tmp}/swift-tutor-not-repo.XXXXXX")"
trap 'rm -rf "$fixture" "$invalid_repo"' EXIT
assert_passes "clean checkout passes" "$GUARD" "$fixture"

set +e
invalid_output="$(assert_clean_source_provenance "$invalid_repo" 2>&1)"
invalid_status=$?
set -e
(( invalid_status != 0 )) \
    || fail "invalid repository must return nonzero without relying on caller set -e"
[[ "$invalid_output" == *"not a Git working tree"* ]] \
    || fail "invalid repository failure must be explicit: $invalid_output"

printf '// dirty\n' >> "$fixture/Sources/App/main.swift"
assert_fails_with "tracked unstaged source fails" "Sources/App/main.swift" "$GUARD" "$fixture"
git -C "$fixture" restore Sources/App/main.swift

printf '// staged\n' >> "$fixture/Package.swift"
git -C "$fixture" add Package.swift
assert_fails_with "tracked staged package manifest fails" "Package.swift" "$GUARD" "$fixture"
git -C "$fixture" restore --staged Package.swift
git -C "$fixture" restore Package.swift

printf 'print("untracked")\n' > "$fixture/Sources/App/Untracked.swift"
assert_fails_with "untracked Swift source fails" "Sources/App/Untracked.swift" "$GUARD" "$fixture"
rm "$fixture/Sources/App/Untracked.swift"

mkdir -p "$fixture/Sources/App/Resources"
printf 'resource\n' > "$fixture/Sources/App/Resources/payload.txt"
assert_fails_with "untracked SwiftPM resource fails" "Sources/App/Resources/payload.txt" "$GUARD" "$fixture"
rm -rf "$fixture/Sources/App/Resources"

printf 'Sources/App/Ignored.swift\nSources/App/Resources/ignored payload.txt\n' >> "$fixture/.git/info/exclude"
printf 'print("ignored source")\n' > "$fixture/Sources/App/Ignored.swift"
mkdir -p "$fixture/Sources/App/Resources"
printf 'ignored resource\n' > "$fixture/Sources/App/Resources/ignored payload.txt"
assert_fails_with "ignored untracked Swift source still fails" "Sources/App/Ignored.swift" \
    "$GUARD" "$fixture"
assert_fails_with "ignored untracked resource with spaces still fails" \
    "Sources/App/Resources/ignored payload.txt" "$GUARD" "$fixture"
rm "$fixture/Sources/App/Ignored.swift"
rm -rf "$fixture/Sources/App/Resources"

mkdir -p "$fixture/.build" "$fixture/dist"
printf 'ignored\n' > "$fixture/.build/output"
printf 'ignored\n' > "$fixture/dist/output"
printf 'handoff\n' > "$fixture/docs/CODEX_HANDOFF.md"
assert_passes "ignored outputs and untracked docs pass" "$GUARD" "$fixture"

# Exercise the production entrypoints in the isolated checkout. Both must stop
# on provenance before attempting a build or inspecting an existing bundle.
mkdir -p "$fixture/Scripts"
cp "$GUARD" "$BUILD_SCRIPT" "$VERIFY_SCRIPT" "$fixture/Scripts/"
git -C "$fixture" add Scripts
git -C "$fixture" commit -qm "add production scripts"
printf '// changed before entrypoint\n' >> "$fixture/Sources/App/main.swift"
assert_fails_with "build entrypoint rejects dirty source" "Sources/App/main.swift" \
    "$fixture/Scripts/build-app.sh"
assert_fails_with "verifier entrypoint rejects dirty source" "Sources/App/main.swift" \
    "$fixture/Scripts/verify-app-bundle.sh"
git -C "$fixture" restore Sources/App/main.swift

# Fake Swift and codesign let the real build entrypoint reach signing without
# compiling. The signing hook then changes provenance; the build must not claim
# success even though signing itself returns zero.
fake_bin="$fixture/fake-bin"
fake_products="$fixture/fake-products"
mkdir -p "$fake_bin" "$fake_products"
printf '#!/bin/bash\nif [[ " $* " == *" --show-bin-path "* ]]; then printf "%%s\\n" "$PROVENANCE_FAKE_PRODUCTS"; fi\n' \
    > "$fake_bin/swift"
printf '#!/bin/bash\nif [[ " $* " == *" --sign "* ]]; then\n  if [[ "$PROVENANCE_TEST_HOOK" == dirty ]]; then printf "// signing mutation\\n" >> Sources/App/main.swift; fi\n  if [[ "$PROVENANCE_TEST_HOOK" == head ]]; then git commit --allow-empty -qm "signing head switch"; fi\nfi\n' \
    > "$fake_bin/codesign"
printf '#!/bin/bash\nexit 0\n' > "$fake_products/SwiftTutorApprentice"
chmod +x "$fake_bin/swift" "$fake_bin/codesign" "$fake_products/SwiftTutorApprentice"

export PROVENANCE_FAKE_PRODUCTS="$fake_products"
assert_build_fails_without_success "build rejects tracked mutation during signing" \
    dirty "$fixture" "$fake_bin"
git -C "$fixture" restore Sources/App/main.swift
rm -rf "$fixture/dist"
assert_build_fails_without_success "build rejects clean HEAD switch during signing" \
    head "$fixture" "$fake_bin"

build_guard_calls="$(grep -c 'assert_clean_source_provenance' "$BUILD_SCRIPT" || true)"
(( build_guard_calls >= 2 )) \
    || fail "build-app.sh must call the shared guard before build and before manifest/signing"
verify_guard_calls="$(grep -c 'assert_clean_source_provenance' "$VERIFY_SCRIPT" || true)"
(( verify_guard_calls >= 2 )) \
    || fail "verify-app-bundle.sh must call the shared guard at start and end"

grep -q '<key>SourceWorkingTreeState</key>.*<string>clean</string>' "$BUILD_SCRIPT" \
    || fail "build manifest must seal SourceWorkingTreeState=clean"
grep -q 'require_clean_manifest_provenance' "$VERIFY_SCRIPT" \
    || fail "bundle verifier must require the shared clean-manifest validator"

manifest="${fixture}/BuildManifest.plist"
cat > "$manifest" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>SourceWorkingTreeState</key><string>clean</string>
</dict></plist>
PLIST
assert_passes "exact clean manifest state passes" require_clean_manifest_provenance "$manifest"
/usr/libexec/PlistBuddy -c 'Set :SourceWorkingTreeState dirty' "$manifest"
assert_fails_with "non-clean manifest state fails" "must be exactly clean" require_clean_manifest_provenance "$manifest"
/usr/libexec/PlistBuddy -c 'Delete :SourceWorkingTreeState' "$manifest"
assert_fails_with "missing manifest state fails" "SourceWorkingTreeState is missing" require_clean_manifest_provenance "$manifest"

echo "source provenance tests passed"
