#!/bin/bash
set -euo pipefail

SCRIPT="${1:?smoke-state script path required}"
TEMP_PARENT="$(cd "${TMPDIR%/}" && pwd -P)"
ROOT="$TEMP_PARENT/SwiftTutorApprentice-restore-tests.$$"
mkdir -p "$ROOT"
trap 'rm -rf -- "$ROOT"' EXIT

make_mock_bin() {
    local bin="$1"
    mkdir -p "$bin"
    cat > "$bin/defaults" <<'MOCK'
#!/bin/bash
set -euo pipefail
command_name="$1"
shift
case "$command_name" in
    export)
        shift
        [[ -f "$MOCK_PREFERENCES" ]] || exit 1
        cp "$MOCK_PREFERENCES" "$1"
        ;;
    import)
        shift
        if [[ -n "${MOCK_REQUIRE_DELETE_BEFORE_IMPORT:-}" ]]; then
            [[ -n "${MOCK_DEFAULTS_DELETE_MARKER:-}" \
                && -f "$MOCK_DEFAULTS_DELETE_MARKER" ]] || exit 1
            rm -f -- "$MOCK_DEFAULTS_DELETE_MARKER"
        fi
        if [[ -n "${MOCK_FAIL_ROLLBACK_IMPORT_ONCE:-}" \
            && -e "$MOCK_FAIL_ROLLBACK_IMPORT_ONCE" \
            && "$1" == *preferences.rollback.plist ]]
        then
            rm -f -- "$MOCK_FAIL_ROLLBACK_IMPORT_ONCE"
            exit 1
        fi
        cp "$1" "$MOCK_PREFERENCES"
        ;;
    delete)
        rm -f -- "$MOCK_PREFERENCES"
        [[ -z "${MOCK_DEFAULTS_DELETE_MARKER:-}" ]] \
            || : > "$MOCK_DEFAULTS_DELETE_MARKER"
        ;;
    *) exit 64 ;;
esac
MOCK
    cat > "$bin/osascript" <<'MOCK'
#!/bin/bash
[[ -z "${MOCK_QUIT_MARKER:-}" ]] || : > "$MOCK_QUIT_MARKER"
exit 0
MOCK
    cat > "$bin/pgrep" <<'MOCK'
#!/bin/bash
exit 1
MOCK
    chmod 700 "$bin/defaults" "$bin/osascript" "$bin/pgrep"
}

write_preferences() {
    local path="$1" value="$2"
    mkdir -p "$(dirname "$path")"
    cat > "$path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>state</key><string>$value</string></dict></plist>
PLIST
}

seed_tree() {
    local path="$1" value="$2"
    mkdir -p "$path/nested"
    printf '%s\n' "$value-root" > "$path/root.txt"
    printf '%s\n' "$value-nested" > "$path/nested/value.txt"
}

assert_tree() {
    local path="$1" value="$2"
    [[ -d "$path" && ! -L "$path" ]]
    [[ "$(cat "$path/root.txt")" == "$value-root" ]]
    [[ "$(cat "$path/nested/value.txt")" == "$value-nested" ]]
}

assert_tree_modes() {
    local path="$1" root_mode="$2" nested_mode="$3"
    [[ "$(stat -f %Lp "$path/root.txt")" == "$root_mode" ]]
    [[ "$(stat -f %Lp "$path/nested")" == "$nested_mode" ]]
}

assert_consistent_present_state() {
    local app="$1" workspace="$2" prefs="$3"
    if grep -q 'disposable-preferences' "$prefs"; then
        assert_tree "$app" disposable-data
        assert_tree "$workspace" disposable-workspace
    elif grep -q 'original-preferences' "$prefs"; then
        assert_tree "$app" original-data
        assert_tree "$workspace" original-workspace
    else
        echo "preferences are neither complete disposable nor complete original state" >&2
        return 1
    fi
}

run_case() {
    local name="$1" desired_data="$2" desired_workspace="$3" desired_preferences="$4"
    local failure_phase="$5" signal_phase="$6" expected_status="$7" expected_live="$8"
    local case_root="$ROOT/$name" home="$ROOT/$name/home" temp="$ROOT/$name/tmp"
    local mock_bin="$ROOT/$name/bin" prefs="$ROOT/$name/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"

    [[ "$desired_data" == absent ]] || seed_tree "$app" original-data
    [[ "$desired_workspace" == absent ]] || seed_tree "$workspace" original-workspace
    [[ "$desired_preferences" == absent ]] || write_preferences "$prefs" original-preferences

    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    [[ -d "$session" ]]

    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences
    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_FAIL_PHASE="$failure_phase" \
        SMOKE_STATE_TEST_SIGNAL_PHASE="$signal_phase" \
        SMOKE_STATE_TEST_SIGNAL_NAME="${TEST_SIGNAL_NAME:-TERM}" \
        SMOKE_STATE_TEST_KILL_PHASE='' \
        SMOKE_STATE_TEST_FAIL_ONCE_PHASE="${TEST_FAIL_ONCE_PHASE:-}" \
        SMOKE_STATE_TEST_HOOK_LOG="$case_root/hooks.log" \
        bash "$SCRIPT" restore "$session" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -eq $expected_status ]] || {
        echo "$name: expected status $expected_status, got $status" >&2
        return 1
    }

    if [[ "$expected_live" == disposable ]]; then
        assert_tree "$app" disposable-data
        assert_tree "$workspace" disposable-workspace
        grep -q 'disposable-preferences' "$prefs"
        [[ -d "$session" ]]
    else
        if [[ "$desired_data" == absent ]]; then
            [[ ! -e "$app" && ! -L "$app" ]]
        else
            assert_tree "$app" original-data
        fi
        if [[ "$desired_workspace" == absent ]]; then
            [[ ! -e "$workspace" && ! -L "$workspace" ]]
        else
            assert_tree "$workspace" original-workspace
        fi
        if [[ "$desired_preferences" == absent ]]; then
            [[ ! -e "$prefs" ]]
        else
            grep -q 'original-preferences' "$prefs"
        fi
        if [[ $expected_status -eq 0 ]]; then
            [[ ! -e "$session" ]]
        else
            [[ -d "$session" ]]
        fi
    fi
}

run_rollback_fault_case() {
    local name="$1" rollback_phase="$2" failure_mode="${3:-once}"
    local case_root="$ROOT/$name" home="$ROOT/$name/home" temp="$ROOT/$name/tmp"
    local mock_bin="$ROOT/$name/bin" prefs="$ROOT/$name/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session status once_phase='' always_phase=''
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences
    if [[ "$failure_mode" == once ]]; then
        once_phase="$rollback_phase"
    else
        always_phase="$rollback_phase"
    fi

    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_FAIL_PHASE=verification \
        SMOKE_STATE_TEST_FAIL_ONCE_PHASE="$once_phase" \
        SMOKE_STATE_TEST_ALWAYS_FAIL_PHASE="$always_phase" \
        SMOKE_STATE_TEST_HOOK_LOG="$case_root/hooks.log" \
        bash "$SCRIPT" restore "$session" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]]
    grep -qx "$rollback_phase" "$case_root/hooks.log"
    assert_consistent_present_state "$app" "$workspace" "$prefs"
    [[ -d "$session" ]]
}

run_copy_tree_boundary_cases() {
    local case_root="$ROOT/copy-tree-boundaries" source destination locked status
    mkdir -p "$case_root"
    source="$case_root/source"
    destination="$case_root/destination"
    seed_tree "$source" boundary

    set +e
    COPY_SOURCE="$source" COPY_DESTINATION="$destination" bash -c '
        source "$1"
        restore_test_hook() { return 1; }
        set +e
        status=0
        copy_tree "$COPY_SOURCE" "$COPY_DESTINATION" forced-hook-failure || status=$?
        exit "$status"
    ' _ "$SCRIPT" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]] || {
        echo "copy_tree masked a failing restore hook" >&2
        return 1
    }

    rm -rf -- "$destination"
    set +e
    COPY_SOURCE="$source" COPY_DESTINATION="$destination" bash -c '
        source "$1"
        restore_test_hook() { printf tampered >> "$COPY_DESTINATION/root.txt"; }
        set +e
        status=0
        copy_tree "$COPY_SOURCE" "$COPY_DESTINATION" force-verification-failure || status=$?
        exit "$status"
    ' _ "$SCRIPT" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]] || {
        echo "copy_tree masked a failing verification" >&2
        return 1
    }

    locked="$case_root/locked"
    mkdir "$locked"
    chmod 500 "$locked"
    set +e
    COPY_SOURCE="$source" COPY_DESTINATION="$locked/destination" bash -c '
        source "$1"
        set +e
        status=0
        copy_tree "$COPY_SOURCE" "$COPY_DESTINATION" || status=$?
        exit "$status"
    ' _ "$SCRIPT" >/dev/null 2>&1
    status=$?
    set -e
    chmod 700 "$locked"
    [[ $status -ne 0 ]] || {
        echo "copy_tree masked a failing ditto" >&2
        return 1
    }

    COPY_SCRIPT="$SCRIPT" bash -c '
        source "$COPY_SCRIPT"
        body="$(declare -f copy_tree)"
        [[ "$body" == *"/usr/bin/ditto --noqtn \"\$source\" \"\$destination\" || return 1"* ]]
        [[ "$body" == *"restore_test_hook \"\$test_phase\" || return 1"* ]]
        [[ "$body" == *"diff -qr \"\$source\" \"\$destination\" > /dev/null || return 1"* ]]
    '
}

run_rollback_copy_fault_case() {
    local name="$1" rollback_phase="$2" failure_mode="${3:-once}"
    local case_root="$ROOT/$name"
    local home="$case_root/home" temp="$case_root/tmp"
    local mock_bin="$case_root/bin" prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session journal status once_phase='' always_phase=''
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    chmod 640 "$app/root.txt" "$workspace/root.txt"
    chmod 750 "$app/nested" "$workspace/nested"
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    chmod 600 "$app/root.txt" "$workspace/root.txt"
    chmod 700 "$app/nested" "$workspace/nested"
    write_preferences "$prefs" disposable-preferences
    if [[ "$failure_mode" == once ]]; then
        once_phase="$rollback_phase"
    else
        always_phase="$rollback_phase"
    fi

    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_FAIL_PHASE=verification \
        SMOKE_STATE_TEST_FAIL_ONCE_PHASE="$once_phase" \
        SMOKE_STATE_TEST_ALWAYS_FAIL_PHASE="$always_phase" \
        SMOKE_STATE_TEST_HOOK_LOG="$case_root/hooks.log" \
        bash "$SCRIPT" restore "$session" >"$case_root/restore.log" 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]]
    [[ "$(grep -cx "$rollback_phase" "$case_root/hooks.log")" == 2 ]]
    journal="$session/restore-transaction"
    if [[ "$failure_mode" == once ]]; then
        if ! assert_tree "$app" disposable-data \
            || ! assert_tree "$workspace" disposable-workspace
        then
            cat "$case_root/restore.log" >&2
            cat "$case_root/hooks.log" >&2
            [[ ! -f "$journal/phase" ]] || cat "$journal/phase" >&2
            return 1
        fi
        assert_tree_modes "$app" 600 700
        assert_tree_modes "$workspace" 600 700
        grep -q disposable-preferences "$prefs"
        [[ ! -e "$journal" && ! -L "$journal" ]]
    else
        assert_tree "$app" original-data
        assert_tree "$workspace" original-workspace
        assert_tree_modes "$app" 640 750
        assert_tree_modes "$workspace" 640 750
        grep -q original-preferences "$prefs"
        [[ "$(<"$journal/phase")" == rollback-failed-desired-restored ]]
    fi
    [[ -d "$session" ]]
}

run_managed_mode_tamper_case() {
    local name="$1" unsafe_component="$2" case_root="$ROOT/$1"
    local home="$case_root/home" temp="$case_root/tmp" mock_bin="$case_root/bin"
    local prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session output status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences
    chmod 777 "$home/$unsafe_component"
    set +e
    output="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" restore "$session" 2>&1)"
    status=$?
    set -e
    [[ $status -ne 0 && "$output" == *"permissions or owner are unsafe"* ]]
    assert_tree "$app" disposable-data
    assert_tree "$workspace" disposable-workspace
    grep -q disposable-preferences "$prefs"
    [[ -d "$session" ]]
}

run_journal_mode_tamper_case() {
    local name="$1" target="$2" mode="$3" case_root="$ROOT/$1"
    local home="$case_root/home" temp="$case_root/tmp" mock_bin="$case_root/bin"
    local prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session journal output status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences
    journal="$session/restore-transaction"
    mkdir "$journal"
    chmod 700 "$journal"
    printf 'staging\n' > "$journal/phase"
    chmod 600 "$journal/phase"
    if [[ "$target" == orphan ]]; then
        : > "$journal/.phase.new.123"
        chmod "$mode" "$journal/.phase.new.123"
    else
        chmod "$mode" "$journal/$target"
    fi
    set +e
    output="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" restore "$session" 2>&1)"
    status=$?
    set -e
    [[ $status -ne 0 && "$output" == *"restore transaction"* ]]
    assert_tree "$app" disposable-data
    assert_tree "$workspace" disposable-workspace
    grep -q disposable-preferences "$prefs"
    [[ -d "$session" ]]
}

run_temp_journal_mode_tamper_case() {
    local case_root="$ROOT/temp-journal-mode" home="$ROOT/temp-journal-mode/home"
    local temp="$case_root/tmp" mock_bin="$case_root/bin" prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session temporary output status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences
    temporary="$session/.restore-transaction.new"
    mkdir "$temporary"
    chmod 755 "$temporary"
    set +e
    output="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" restore "$session" 2>&1)"
    status=$?
    set -e
    [[ $status -ne 0 && "$output" == *"temporary journal is unsafe"* ]]
    [[ -d "$temporary" && "$(stat -f %Lp "$temporary")" == 755 ]]
    assert_tree "$app" disposable-data
    assert_tree "$workspace" disposable-workspace
    grep -q disposable-preferences "$prefs"
    [[ -d "$session" ]]
}

run_snapshot_digest_mode_tamper_case() {
    local case_root="$ROOT/snapshot-digest-mode" home="$ROOT/snapshot-digest-mode/home"
    local temp="$case_root/tmp" mock_bin="$case_root/bin" prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local state_file="$app/progress.json" session digest output status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    printf '{"progress":"synthetic"}\n' > "$state_file"
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    digest="$session/snapshots/safe-label.sha256"
    shasum -a 256 "$state_file" | awk '{print $1}' > "$digest"
    chmod 644 "$digest"
    set +e
    output="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" assert-unchanged \
        "$session" "$state_file" safe-label 2>&1)"
    status=$?
    set -e
    [[ $status -ne 0 && "$output" == *"snapshot digest permissions or owner are unsafe"* ]]
    [[ -d "$session" ]]
}

run_owner_contract_case() {
    OWNER_SCRIPT="$SCRIPT" bash -c '
        source "$OWNER_SCRIPT"
        managed="$(declare -f assert_managed_surface_safe)"
        journal="$(declare -f validate_restore_transaction)"
        snapshot="$(declare -f assert_unchanged)"
        [[ "$managed" == *"-O \"\$HOME\""* ]]
        [[ "$managed" == *"-O \"\$current\""* ]]
        [[ "$journal" == *"-O \"\$RESTORE_TXN\""* ]]
        [[ "$journal" == *"-O \"\$entry\""* ]]
        [[ "$snapshot" == *"-O \"\$expected\""* ]]
    '
}

run_preferences_rollback_import_fault_case() {
    local name=preferences-rollback-import-fault case_root="$ROOT/preferences-rollback-import-fault"
    local home="$case_root/home" temp="$case_root/tmp" mock_bin="$case_root/bin"
    local prefs="$case_root/preferences.plist" fail_file="$case_root/fail-import-once"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences
    : > "$fail_file"
    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" MOCK_FAIL_ROLLBACK_IMPORT_ONCE="$fail_file" \
        SWIFTTUTOR_SMOKE_TESTING=1 SMOKE_STATE_TEST_FAIL_PHASE=verification \
        bash "$SCRIPT" restore "$session" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]]
    [[ ! -e "$fail_file" ]]
    assert_consistent_present_state "$app" "$workspace" "$prefs"
    [[ -d "$session" ]]
}

run_tamper_case() {
    local name="$1" mutation="$2"
    local case_root="$ROOT/$name" home="$ROOT/$name/home" temp="$ROOT/$name/tmp"
    local mock_bin="$ROOT/$name/bin" prefs="$ROOT/$name/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session status output quit_marker="$case_root/quit-called"
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -f -- "$quit_marker"
    SESSION_UNDER_TEST="$session" bash -c "$mutation"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences
    set +e
    output="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" MOCK_QUIT_MARKER="$quit_marker" \
        bash "$SCRIPT" restore "$session" 2>&1)"
    status=$?
    set -e
    [[ $status -ne 0 && "$output" == *"payload"* ]]
    [[ ! -e "$quit_marker" ]]
    assert_tree "$app" disposable-data
    assert_tree "$workspace" disposable-workspace
    grep -q disposable-preferences "$prefs"
    [[ -d "$session" ]]
}

run_hard_kill_retry_case() {
    local phase="$1" name="hard-kill-${1//[^A-Za-z0-9]/-}" case_root
    case_root="$ROOT/$name"
    local home="$case_root/home" temp="$case_root/tmp"
    local mock_bin="$case_root/bin" prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session status journal entry
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences

    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_KILL_PHASE="$phase" \
        SMOKE_STATE_TEST_FAIL_PHASE='' SMOKE_STATE_TEST_SIGNAL_PHASE='' \
        bash "$SCRIPT" restore "$session" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -eq 137 ]]
    journal="$session/restore-transaction"
    if [[ -d "$journal" ]]; then
        [[ ! -L "$journal" && "$(stat -f %Lp "$journal")" == 700 ]]
        for entry in "$journal"/*; do
            [[ -f "$entry" && ! -L "$entry" ]]
            [[ "$(stat -f %Lp "$entry")" == 600 ]]
        done
    fi

    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_KILL_PHASE='' SMOKE_STATE_TEST_FAIL_PHASE='' \
        SMOKE_STATE_TEST_SIGNAL_PHASE='' \
        bash "$SCRIPT" restore "$session" >/dev/null
    assert_tree "$app" original-data
    assert_tree "$workspace" original-workspace
    grep -q 'original-preferences' "$prefs"
    [[ ! -e "$session" ]]
}

assert_no_restore_auxiliary_paths() {
    local session="$1" app="$2" workspace="$3" token entry
    token="$(basename "$session")"
    for entry in "$(dirname "$app")/.$token."* "$(dirname "$workspace")/.$token."*; do
        [[ ! -e "$entry" && ! -L "$entry" ]] || return 1
    done
}

run_cleanup_boundary_case() {
    local name="$1" phase="$2" injection="$3"
    local case_root="$ROOT/$name" home="$ROOT/$name/home" temp="$ROOT/$name/tmp"
    local mock_bin="$ROOT/$name/bin" prefs="$ROOT/$name/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session journal status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences

    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_FAIL_PHASE="$([[ "$injection" == fail ]] && printf %s "$phase")" \
        SMOKE_STATE_TEST_KILL_PHASE="$([[ "$injection" == kill ]] && printf %s "$phase")" \
        SMOKE_STATE_TEST_HOOK_LOG="$case_root/hooks.log" \
        bash "$SCRIPT" restore "$session" >/dev/null 2>&1
    status=$?
    set -e
    if [[ "$injection" == kill ]]; then
        [[ $status -eq 137 ]]
    else
        [[ $status -ne 0 ]] || {
            echo "$name: cleanup failure was masked" >&2
            return 1
        }
    fi
    journal="$session/restore-transaction"
    [[ -d "$journal" && "$(<"$journal/phase")" == committed ]]
    assert_tree "$app" original-data
    assert_tree "$workspace" original-workspace
    grep -q original-preferences "$prefs"
    [[ -d "$session" ]]

    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        bash "$SCRIPT" restore "$session" >/dev/null
    assert_tree "$app" original-data
    assert_tree "$workspace" original-workspace
    grep -q original-preferences "$prefs"
    [[ ! -e "$session" ]]
    assert_no_restore_auxiliary_paths "$session" "$app" "$workspace"
}

run_rollback_cleanup_failure_case() {
    local name="$1" desired_data="$2" desired_workspace="$3" desired_preferences="$4"
    local phase="$5" injection="${6:-fail}"
    local case_root="$ROOT/$1" home="$ROOT/$1/home" temp="$ROOT/$1/tmp"
    local mock_bin="$ROOT/$1/bin" prefs="$ROOT/$1/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session journal status expected_phase=rollback-verified
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    [[ "$desired_data" == absent ]] || seed_tree "$app" original-data
    [[ "$desired_workspace" == absent ]] || seed_tree "$workspace" original-workspace
    [[ "$desired_preferences" == absent ]] || write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences

    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_FAIL_PHASE=verification \
        SMOKE_STATE_TEST_ALWAYS_FAIL_PHASE="$([[ "$injection" == fail ]] && printf %s "$phase")" \
        SMOKE_STATE_TEST_KILL_PHASE="$([[ "$injection" == kill ]] && printf %s "$phase")" \
        SMOKE_STATE_TEST_HOOK_LOG="$case_root/hooks.log" \
        bash "$SCRIPT" restore "$session" >/dev/null 2>&1
    status=$?
    set -e
    if [[ "$injection" == kill ]]; then
        [[ $status -eq 137 ]]
    else
        [[ $status -ne 0 ]]
    fi
    journal="$session/restore-transaction"
    [[ "$phase" != before-rollback-verified-marker ]] || expected_phase=verifying
    [[ -d "$journal" && "$(<"$journal/phase")" == "$expected_phase" ]]
    assert_tree "$app" disposable-data
    assert_tree "$workspace" disposable-workspace
    grep -q disposable-preferences "$prefs"

    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        bash "$SCRIPT" restore "$session" >/dev/null
    if [[ "$desired_data" == absent ]]; then
        [[ ! -e "$app" ]]
    else
        assert_tree "$app" original-data
    fi
    if [[ "$desired_workspace" == absent ]]; then
        [[ ! -e "$workspace" ]]
    else
        assert_tree "$workspace" original-workspace
    fi
    if [[ "$desired_preferences" == absent ]]; then
        [[ ! -e "$prefs" ]]
    else
        grep -q original-preferences "$prefs"
    fi
    [[ ! -e "$session" ]]
    assert_no_restore_auxiliary_paths "$session" "$app" "$workspace"
}

run_destructive_boundary_contract_case() {
    BOUNDARY_SCRIPT="$SCRIPT" bash -c '
        source "$BOUNDARY_SCRIPT"
        cleanup="$(declare -f cleanup_restore_auxiliary_path)"
        move="$(declare -f restore_move_with_retry)"
        partial="$(declare -f copy_tree_with_retry)"
        journal="$(declare -f remove_restore_journal)"
        orphan="$(declare -f remove_restore_journal_orphans)"
        exact="$(declare -f verify_exact_restored_tree)"
        restored="$(declare -f verify_restored_state)"
        manifest="$(declare -f write_tree_manifest)"
        [[ "$cleanup" == *"restore_test_hook \"before-cleanup-\$name\" || return 1"* ]]
        [[ "$cleanup" == *"validate_restore_auxiliary_path \"\$path\" \"\$target\" || return 1"* ]]
        [[ "$cleanup" == *"rm -rf -- \"\$path\" || return 1"* ]]
        [[ "$move" == *"validate_restore_move_boundary \"\$source\" \"\$destination\""* ]]
        [[ "$partial" == *"validate_restore_directory_identity \"\$destination\" || return 1"* ]]
        [[ "$journal" == *"assert_cleanup_phase || return 1"* ]]
        [[ "$orphan" == *"-O \"\$entry\""* ]]
        [[ "$exact" == *"write_tree_manifest \"\$expected_root\" \"\$expected\" || return 1"* ]]
        [[ "$exact" == *"write_tree_manifest \"\$live_root\" \"\$actual\" || return 1"* ]]
        [[ "$exact" == *"if ! diff -u \"\$expected\" \"\$actual\" > /dev/null"* ]]
        [[ "$restored" == *"verify_exact_restored_tree"*"|| return 1"* ]]
        [[ "$manifest" == *"find \"\$root\" -print0 > \"\$listing\" || return 1"* ]]
    '
}

run_cleanup_replacement_case() {
    local name="$1" action="$2" phase="$3" auxiliary_name="$4"
    local case_root="$ROOT/$name" home="$ROOT/$name/home" temp="$ROOT/$name/tmp"
    local mock_bin="$ROOT/$name/bin" prefs="$ROOT/$name/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session token auxiliary sentinel output status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    token="$(basename "$session")"
    auxiliary="$(dirname "$app")/.$token.$auxiliary_name"
    sentinel="$case_root/outside"
    mkdir "$sentinel"
    printf 'external-sentinel\n' > "$sentinel/value.txt"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences

    set +e
    output="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_MUTATE_PHASE="$phase" \
        SMOKE_STATE_TEST_MUTATE_PATH="$auxiliary" \
        SMOKE_STATE_TEST_MUTATE_ACTION="$action" \
        SMOKE_STATE_TEST_MUTATE_TARGET="$sentinel" \
        bash "$SCRIPT" restore "$session" 2>&1)"
    status=$?
    set -e
    [[ $status -ne 0 ]] || {
        echo "$name: cleanup replacement was not rejected" >&2
        return 1
    }
    [[ "$(cat "$sentinel/value.txt")" == external-sentinel ]]
    [[ -d "$session/restore-transaction" ]]
    return 0
}

run_live_move_replacement_case() {
    local name=live-move-mode-replacement case_root="$ROOT/live-move-mode-replacement"
    local home="$case_root/home" temp="$case_root/tmp" mock_bin="$case_root/bin"
    local prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session sentinel status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences
    sentinel="$case_root/external-sentinel"
    printf 'external-sentinel\n' > "$sentinel"
    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_MUTATE_PHASE=before-application-support-displace \
        SMOKE_STATE_TEST_MUTATE_PATH="$app" SMOKE_STATE_TEST_MUTATE_ACTION=mode \
        SMOKE_STATE_TEST_MUTATE_TARGET="$sentinel" \
        bash "$SCRIPT" restore "$session" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]]
    [[ "$(cat "$sentinel")" == external-sentinel ]]
    [[ -d "$session/restore-transaction" ]]
}

run_live_verification_tamper_case() {
    local name="$1" surface="$2" action="$3" relative="$4"
    local case_root="$ROOT/$name" home="$ROOT/$name/home" temp="$ROOT/$name/tmp"
    local mock_bin="$ROOT/$name/bin" prefs="$ROOT/$name/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session mutate_root mutate_path journal status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences
    if [[ "$surface" == application-support ]]; then
        mutate_root="$app"
    else
        mutate_root="$workspace"
    fi
    mutate_path="$mutate_root/$relative"

    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_MUTATE_PHASE=verification \
        SMOKE_STATE_TEST_MUTATE_PATH="$mutate_path" \
        SMOKE_STATE_TEST_MUTATE_ACTION="$action" \
        SMOKE_STATE_TEST_MUTATE_TARGET="$case_root/mutation-target" \
        bash "$SCRIPT" restore "$session" >"$case_root/restore.log" 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]] || {
        echo "$name: exact live metadata mismatch was accepted" >&2
        return 1
    }
    [[ -d "$session" ]]
    journal="$session/restore-transaction"
    if [[ -d "$journal" ]]; then
        [[ "$(<"$journal/phase")" != committed ]]
        [[ ! -L "$journal" && "$(stat -f %Lp "$journal")" == 700 ]]
    fi
    if ! assert_tree "$app" disposable-data \
        || ! assert_tree "$workspace" disposable-workspace
    then
        cat "$case_root/restore.log" >&2
        return 1
    fi
    grep -q disposable-preferences "$prefs"
}

run_persistent_rollforward_verification_tamper_case() {
    local case_root="$ROOT/persistent-rollforward-mode" home="$ROOT/persistent-rollforward-mode/home"
    local temp="$case_root/tmp" mock_bin="$case_root/bin" prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session journal status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences

    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_MUTATE_PHASE=verification \
        SMOKE_STATE_TEST_MUTATE_PATH="$app/root.txt" \
        SMOKE_STATE_TEST_MUTATE_ACTION=mode \
        SMOKE_STATE_TEST_FAIL_PHASE=verification \
        SMOKE_STATE_TEST_ALWAYS_FAIL_PHASE=rollback-application-support-copy \
        bash "$SCRIPT" restore "$session" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]]
    journal="$session/restore-transaction"
    [[ -d "$journal" && ! -L "$journal" ]]
    [[ "$(<"$journal/phase")" != rollback-failed-desired-restored ]]
    [[ "$(<"$journal/phase")" != committed ]]
    [[ "$(stat -f %Lp "$app/root.txt")" == 777 ]]
    [[ -d "$session" ]]
}

run_mutation_hook_confinement_cases() {
    local case_root="$ROOT/mutation-hook-confinement" home="$ROOT/mutation-hook-confinement/home"
    local temp="$case_root/tmp" outside="$case_root/outside" sibling="$home-sibling"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local candidate action target status
    mkdir -p "$home" "$temp" "$app" "$outside" "$sibling"

    for candidate in \
        "$home/../outside/value.txt" \
        "${temp%/}/../outside/value.txt" \
        "$sibling/value.txt"
    do
        mkdir -p "$(dirname "$candidate")"
        printf 'external-sentinel\n' > "$candidate"
        set +e
        HOME="$home" TMPDIR="$temp/" SWIFTTUTOR_SMOKE_TESTING=1 \
            SMOKE_STATE_TEST_MUTATE_PHASE=unsafe \
            SMOKE_STATE_TEST_MUTATE_PATH="$candidate" \
            SMOKE_STATE_TEST_MUTATE_ACTION=delete \
            bash -c 'source "$1"; restore_test_hook unsafe' _ "$SCRIPT" >/dev/null 2>&1
        status=$?
        set -e
        [[ $status -ne 0 && -f "$candidate" \
            && "$(cat "$candidate")" == external-sentinel ]] || {
            echo "mutation hook escaped through $candidate" >&2
            return 1
        }
    done

    printf 'external-sentinel\n' > "$outside/symlink-value.txt"
    ln -s "$outside" "$home/symlink-component"
    candidate="$home/symlink-component/symlink-value.txt"
    set +e
    HOME="$home" TMPDIR="$temp/" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_MUTATE_PHASE=unsafe SMOKE_STATE_TEST_MUTATE_PATH="$candidate" \
        SMOKE_STATE_TEST_MUTATE_ACTION=delete \
        bash -c 'source "$1"; restore_test_hook unsafe' _ "$SCRIPT" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 && "$(cat "$outside/symlink-value.txt")" == external-sentinel ]]

    target="$case_root/symlink-target"
    ln -s "$outside" "$target"
    candidate="$app/safe-auxiliary"
    mkdir "$candidate"
    set +e
    HOME="$home" TMPDIR="$temp/" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_MUTATE_PHASE=unsafe SMOKE_STATE_TEST_MUTATE_PATH="$candidate" \
        SMOKE_STATE_TEST_MUTATE_ACTION=symlink SMOKE_STATE_TEST_MUTATE_TARGET="$target" \
        bash -c 'source "$1"; APP_DATA="$2"; WORKSPACE="$3"; restore_test_hook unsafe' \
        _ "$SCRIPT" "$app" "$home/Developer/SwiftTutorApprentice/Workspace" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 && -d "$candidate" && ! -L "$candidate" ]]
}

run_manifest_find_failure_case() {
    local case_root="$ROOT/manifest-find-failure" bin="$ROOT/manifest-find-failure/bin"
    local source="$case_root/source" output="$case_root/output.manifest" status
    mkdir -p "$bin"
    seed_tree "$source" find-failure
    cat > "$bin/find" <<'MOCK'
#!/bin/bash
printf '%s\0' "$FAKE_FIND_ROOT"
exit 1
MOCK
    chmod 700 "$bin/find"
    set +e
    PATH="$bin:/usr/bin:/bin" FAKE_FIND_ROOT="$source" \
        TREE_SOURCE="$source" TREE_OUTPUT="$output" \
        bash -c 'source "$1"; set +e; status=0; write_tree_manifest "$TREE_SOURCE" "$TREE_OUTPUT" || status=$?; exit "$status"' \
        _ "$SCRIPT" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 && ! -e "$output" ]] || {
        echo "manifest writer accepted partial find output" >&2
        return 1
    }
}

make_partial_find() {
    local bin="$1"
    cat > "$bin/find" <<'MOCK'
#!/bin/bash
printf '%s\0' "$1"
exit "${FAKE_FIND_STATUS:-1}"
MOCK
    chmod 700 "$bin/find"
}

run_payload_find_backup_failure_case() {
    local case_root="$ROOT/payload-find-backup-failure" home="$ROOT/payload-find-backup-failure/home"
    local temp="$case_root/tmp" mock_bin="$case_root/bin" prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace" output status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    make_partial_find "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    set +e
    output="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" FAKE_FIND_STATUS=1 bash "$SCRIPT" backup 2>&1)"
    status=$?
    set -e
    [[ $status -ne 0 ]] || {
        echo "backup accepted partial payload traversal" >&2
        return 1
    }
    [[ -z "$(find "$temp" -maxdepth 1 -name 'SwiftTutorApprentice-smoke.*' -print)" ]]
}

run_payload_find_validation_failure_case() {
    local case_root="$ROOT/payload-find-validation-failure" home="$ROOT/payload-find-validation-failure/home"
    local temp="$case_root/tmp" mock_bin="$case_root/bin" prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace" session status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    make_partial_find "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" FAKE_FIND_STATUS=0 bash "$SCRIPT" backup)"
    printf 'unlisted-tamper\n' > "$session/application-support/unlisted.txt"
    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" FAKE_FIND_STATUS=1 \
        bash -c 'source "$1"; validate_session "$2"' _ "$SCRIPT" "$session" \
        >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]] || {
        echo "validation accepted repeated partial payload traversal" >&2
        return 1
    }
    [[ -d "$session" ]]
}

run_payload_validation_temp_alias_case() {
    local case_root="$ROOT/payload-validation-temp-alias"
    local home="$case_root/home" real_temp="$case_root/real-temp"
    local temp_alias="$case_root/temp-alias" mock_bin="$case_root/bin"
    local prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace" session
    mkdir -p "$home" "$real_temp"
    ln -s "$real_temp" "$temp_alias"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp_alias/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    HOME="$home" TMPDIR="$temp_alias/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" clean "$session"
    HOME="$home" TMPDIR="$temp_alias/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" restore "$session" >/dev/null
}

run_preferences_replace_requires_delete_case() {
    export MOCK_REQUIRE_DELETE_BEFORE_IMPORT=1
    export MOCK_DEFAULTS_DELETE_MARKER="$ROOT/preferences-replace-delete.marker"
    run_case preferences-replace-requires-delete present present present '' '' 0 original
    unset MOCK_REQUIRE_DELETE_BEFORE_IMPORT MOCK_DEFAULTS_DELETE_MARKER
}

run_rollforward_phase_publish_failure_case() {
    local case_root="$ROOT/rollforward-phase-failure" home="$ROOT/rollforward-phase-failure/home"
    local temp="$case_root/tmp" mock_bin="$case_root/bin" prefs="$case_root/preferences.plist"
    local app="$home/Library/Application Support/SwiftTutorApprentice"
    local workspace="$home/Developer/SwiftTutorApprentice/Workspace"
    local session journal status
    mkdir -p "$home" "$temp"
    make_mock_bin "$mock_bin"
    seed_tree "$app" original-data
    seed_tree "$workspace" original-workspace
    write_preferences "$prefs" original-preferences
    session="$(HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" backup)"
    rm -rf -- "$app" "$workspace"
    seed_tree "$app" disposable-data
    seed_tree "$workspace" disposable-workspace
    write_preferences "$prefs" disposable-preferences
    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_FAIL_PHASE=verification \
        SMOKE_STATE_TEST_ALWAYS_FAIL_PHASE=rollback-application-support-copy \
        SMOKE_STATE_TEST_FAIL_WRITE_PHASE=rollback-failed-desired-restored \
        bash "$SCRIPT" restore "$session" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]]
    journal="$session/restore-transaction"
    [[ -d "$journal" ]]
    if [[ "$(<"$journal/phase")" == rollback-failed-desired-restored ]]; then
        echo "failed terminal phase write was published" >&2
        return 1
    fi
    [[ -d "$session" ]]
    assert_tree "$app" original-data
    assert_tree "$workspace" original-workspace
    grep -q original-preferences "$prefs"

    set +e
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" SWIFTTUTOR_SMOKE_TESTING=1 \
        SMOKE_STATE_TEST_ALWAYS_FAIL_PHASE=rollback-application-support-copy \
        bash "$SCRIPT" restore "$session" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -ne 0 ]] || {
        echo "phase publish retry incorrectly completed cleanup" >&2
        return 1
    }
    [[ "$(<"$journal/phase")" == rollback-failed-desired-restored ]]
    HOME="$home" TMPDIR="$temp/" PATH="$mock_bin:/usr/bin:/bin" \
        MOCK_PREFERENCES="$prefs" bash "$SCRIPT" restore "$session" >/dev/null
    [[ ! -e "$session" ]]
}

if [[ "${SMOKE_RESTORE_TEST_FILTER:-}" == payload-validation-temp-alias ]]; then
    run_payload_validation_temp_alias_case
    exit 0
fi
if [[ "${SMOKE_RESTORE_TEST_FILTER:-}" == preferences-replace-requires-delete ]]; then
    run_preferences_replace_requires_delete_case
    exit 0
fi

run_mutation_hook_confinement_cases
run_manifest_find_failure_case
run_payload_find_backup_failure_case
run_payload_find_validation_failure_case
run_payload_validation_temp_alias_case
run_preferences_replace_requires_delete_case
run_rollforward_phase_publish_failure_case
run_live_verification_tamper_case live-app-mode-verification \
    application-support mode root.txt
run_live_verification_tamper_case live-workspace-mode-verification \
    workspace mode root.txt
run_live_verification_tamper_case live-app-added-entry-verification \
    application-support add-file added.txt
run_live_verification_tamper_case live-workspace-deleted-entry-verification \
    workspace delete nested/value.txt
run_live_verification_tamper_case live-app-type-verification \
    application-support replacement root.txt
run_persistent_rollforward_verification_tamper_case
run_cleanup_boundary_case cleanup-rm-failure \
    before-cleanup-application-support-rollback fail
run_cleanup_replacement_case cleanup-symlink-replacement symlink \
    before-cleanup-application-support-rollback application-support.rollback
run_cleanup_replacement_case cleanup-mode-replacement mode \
    before-cleanup-application-support-rollback application-support.rollback
run_live_move_replacement_case
for cleanup_name in \
    application-support-stage application-support-rollback \
    application-support-displaced application-support-rollback-install \
    application-support-installed workspace-stage workspace-rollback \
    workspace-displaced workspace-rollback-install workspace-installed
do
    run_cleanup_boundary_case "cleanup-failure-$cleanup_name" \
        "before-cleanup-$cleanup_name" fail
    run_cleanup_boundary_case "cleanup-kill-$cleanup_name" \
        "after-cleanup-$cleanup_name" kill
done
run_rollback_cleanup_failure_case rollback-cleanup-present present present present \
    before-cleanup-application-support-rollback fail
run_rollback_cleanup_failure_case rollback-cleanup-absent absent absent absent \
    after-cleanup-workspace-displaced kill
run_rollback_cleanup_failure_case rollback-before-verified-marker present present present \
    before-rollback-verified-marker kill
run_rollback_cleanup_failure_case rollback-after-verified-marker present present present \
    after-rollback-verified-marker kill
run_destructive_boundary_contract_case
run_copy_tree_boundary_cases
run_rollback_copy_fault_case rollback-app-copy-retry rollback-application-support-copy
run_rollback_copy_fault_case rollback-workspace-copy-retry rollback-workspace-copy
run_rollback_copy_fault_case rollback-app-copy-persistent \
    rollback-application-support-copy always
run_managed_mode_tamper_case managed-library-mode Library
run_managed_mode_tamper_case managed-developer-mode Developer
run_managed_mode_tamper_case managed-home-mode ''
run_journal_mode_tamper_case journal-directory-mode . 755
run_journal_mode_tamper_case journal-phase-mode phase 644
run_journal_mode_tamper_case journal-orphan-mode orphan 644
run_temp_journal_mode_tamper_case
run_snapshot_digest_mode_tamper_case
run_owner_contract_case

for phase in \
    stage-application-support \
    stage-workspace \
    after-application-support-swap \
    after-workspace-swap \
    preferences-apply \
    verification
do
    run_case "failure-$phase" present present present "$phase" '' 1 disposable
done

run_case failure-cleanup present present present cleanup '' 1 original
for phase in \
    stage-application-support \
    stage-workspace \
    after-application-support-swap \
    after-workspace-swap \
    preferences-apply \
    verification
do
    run_case "signal-$phase" present present present '' "$phase" 143 disposable
done
run_case signal-cleanup present present present '' cleanup 143 original
TEST_SIGNAL_NAME=INT run_case signal-int present present present '' after-application-support-swap 130 disposable
TEST_SIGNAL_NAME=HUP run_case signal-hup present present present '' after-application-support-swap 129 disposable
run_rollback_fault_case rollback-app-install rollback-application-support-install
run_rollback_fault_case rollback-workspace-install rollback-workspace-install
run_rollback_fault_case rollback-app-copy rollback-application-support-copy
run_rollback_fault_case rollback-workspace-copy rollback-workspace-copy
run_rollback_fault_case rollback-app-persistent-install rollback-application-support-install always
run_preferences_rollback_import_fault_case
for phase in \
    before-journal-publish after-journal-publish \
    before-application-support-marker after-application-support-marker \
    before-application-support-swap after-application-support-swap \
    before-workspace-marker after-workspace-marker \
    before-workspace-swap after-workspace-swap \
    before-preferences-marker after-preferences-marker \
    before-preferences-apply after-preferences-apply \
    before-committed-marker after-committed-marker \
    before-cleanup after-cleanup
do
    run_hard_kill_retry_case "$phase"
done
run_tamper_case tamper-bytes 'printf tampered >> "$SESSION_UNDER_TEST/application-support/root.txt"'
run_tamper_case tamper-added-file 'printf added > "$SESSION_UNDER_TEST/workspace/added.txt"'
run_tamper_case tamper-deleted-file 'rm "$SESSION_UNDER_TEST/application-support/nested/value.txt"'
run_tamper_case tamper-mode 'chmod 777 "$SESSION_UNDER_TEST/workspace/root.txt"'
run_tamper_case tamper-marker 'printf tampered >> "$SESSION_UNDER_TEST/application-support.present"'
run_tamper_case tamper-marker-mode 'chmod 666 "$SESSION_UNDER_TEST/workspace.present"'
run_tamper_case tamper-preferences 'printf tampered >> "$SESSION_UNDER_TEST/preferences.plist"'
run_case absent-all absent absent absent '' '' 0 original
run_case absent-data absent present present '' '' 0 original
run_case absent-workspace present absent present '' '' 0 original
run_case absent-preferences present present absent '' '' 0 original
run_case success-all-present present present present '' '' 0 original

echo "restore transaction safety tests passed"
