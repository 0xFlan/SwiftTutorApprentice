#!/bin/bash
set -euo pipefail

umask 077

SCRIPT_PATH="${BASH_SOURCE[0]}"
cd "$(dirname "$SCRIPT_PATH")/.."
PROJECT_ROOT="$PWD"
APP_DATA="$HOME/Library/Application Support/SwiftTutorApprentice"
WORKSPACE="$HOME/Developer/SwiftTutorApprentice/Workspace"
PREFERENCES_DOMAIN="com.local.swifttutorapprentice"
TEMP_ROOT="$(cd "${TMPDIR%/}" && pwd -P)"
SESSION_PREFIX_INPUT="${TMPDIR%/}/SwiftTutorApprentice-smoke."
SESSION_PREFIX="$TEMP_ROOT/SwiftTutorApprentice-smoke."
BACKUP_SESSION=""
BACKUP_COMPLETE=0
RESTORE_ARMED=0
RESTORE_COMMITTED=0
RESTORE_TXN=""
RESTORE_TXN_TEMP=""
RESTORE_APP_STAGE=""
RESTORE_APP_ROLLBACK=""
RESTORE_APP_DISPLACED=""
RESTORE_APP_ROLLBACK_INSTALL=""
RESTORE_APP_INSTALLED=""
RESTORE_WORKSPACE_STAGE=""
RESTORE_WORKSPACE_ROLLBACK=""
RESTORE_WORKSPACE_DISPLACED=""
RESTORE_WORKSPACE_ROLLBACK_INSTALL=""
RESTORE_WORKSPACE_INSTALLED=""

fail() {
    echo "Smoke-state error: $*" >&2
    exit 1
}

usage() {
    fail "usage: $0 {backup|clean|legacy|future-progress|future-lessons|corrupt-progress|snapshot|assert-unchanged|restore} ..."
}

backup_transaction_cleanup() {
    if [[ "$BACKUP_COMPLETE" == "1" || -z "$BACKUP_SESSION" ]]; then
        return
    fi
    local parent base canonical
    parent="$(dirname "$BACKUP_SESSION")"
    base="$(basename "$BACKUP_SESSION")"
    [[ "$base" =~ ^SwiftTutorApprentice-smoke\.[[:alnum:]]+$ ]] || return
    [[ -d "$parent" ]] || return
    canonical="$(cd "$parent" && pwd -P)/$base"
    [[ "$canonical" == "$SESSION_PREFIX"* ]] || return
    [[ -d "$canonical" && ! -L "$canonical" ]] || return
    rm -rf -- "$canonical"
}

backup_transaction_signal() {
    local signal_status="$1"
    exit "$signal_status"
}

backup_transaction_begin() {
    BACKUP_SESSION="$1"
    BACKUP_COMPLETE=0
    trap backup_transaction_cleanup EXIT
    trap 'backup_transaction_signal 130' INT
    trap 'backup_transaction_signal 143' TERM
}

backup_transaction_complete() {
    BACKUP_COMPLETE=1
    trap - EXIT INT TERM
}

remove_chmod_failed_session() {
    local created="$1" base
    base="$(basename "$created")"
    [[ "$base" =~ ^SwiftTutorApprentice-smoke\.[[:alnum:]]+$ ]] || return 1
    [[ "$created" == "$SESSION_PREFIX_INPUT"* || "$created" == "$SESSION_PREFIX"* ]] \
        || return 1
    [[ -d "$created" && ! -L "$created" ]] || return 1
    rm -rf -- "$created"
}

create_backup_session() {
    local created canonical
    created="$(mktemp -d "${TMPDIR%/}/SwiftTutorApprentice-smoke.XXXXXX")"
    if ! chmod 700 "$created"; then
        remove_chmod_failed_session "$created"
        return 1
    fi
    backup_transaction_begin "$created"
    canonical="$(cd "$(dirname "$created")" && pwd -P)/$(basename "$created")"
    BACKUP_SESSION="$canonical"
}

binding_digest() {
    local session="$1"
    {
        cat "$session/.session-marker"
        cat "$session/metadata/home"
        cat "$session/metadata/application-support"
        cat "$session/metadata/workspace"
        cat "$session/metadata/preferences-domain"
        cat "$session/metadata/user-id"
        cat "$session/metadata/payload.sha256"
    } | shasum -a 256 | awk '{print $1}'
}

write_session_binding() {
    local session="$1" canonical_home
    canonical_home="$(cd "$HOME" && pwd -P)"
    mkdir "$session/metadata"
    chmod 700 "$session/metadata"
    printf '%s\n' "$canonical_home" > "$session/metadata/home"
    printf '%s\n' "$APP_DATA" > "$session/metadata/application-support"
    printf '%s\n' "$WORKSPACE" > "$session/metadata/workspace"
    printf '%s\n' "$PREFERENCES_DOMAIN" > "$session/metadata/preferences-domain"
    id -u > "$session/metadata/user-id"
    chmod 600 "$session/metadata/"{home,application-support,workspace,preferences-domain,user-id}
    write_payload_manifest "$session" "$session/metadata/payload.manifest" || return 1
    shasum -a 256 "$session/metadata/payload.manifest" | awk '{print $1}' \
        > "$session/metadata/payload.sha256"
    chmod 600 "$session/metadata/payload.manifest" "$session/metadata/payload.sha256"
    binding_digest "$session" > "$session/metadata/binding.sha256"
    chmod 600 "$session/metadata/binding.sha256"
}

append_payload_manifest_path() {
    local session="$1" requested="$2" unsorted="$3" listing="$4"
    local entry relative type mode owner digest listing_directory
    listing_directory="${listing%/*}"
    [[ ( -d "$requested" || -f "$requested" ) && ! -L "$requested" && -O "$requested" ]] \
        || return 1
    [[ -d "$listing_directory" && ! -L "$listing_directory" \
        && -O "$listing_directory" ]] || return 1
    if [[ -d "$requested" ]]; then
        [[ "$listing_directory" != "$requested" \
            && "$listing_directory" != "$requested/"* ]] || return 1
    fi
    [[ ! -e "$listing" && ! -L "$listing" ]] || return 1
    : > "$listing" || return 1
    chmod 600 "$listing" || return 1
    find "$requested" -print0 > "$listing" || return 1
    [[ -f "$listing" && ! -L "$listing" && -O "$listing" \
        && "$(stat -f %Lp "$listing")" == 600 ]] || return 1
    while IFS= read -r -d '' entry; do
        if [[ -d "$requested" ]]; then
            [[ "$entry" == "$requested" || "$entry" == "$requested/"* ]] || return 1
        else
            [[ "$entry" == "$requested" ]] || return 1
        fi
        [[ "$entry" == "$session/"* && ! -L "$entry" && -O "$entry" ]] \
            || return 1
        relative="${entry#"$session"/}"
        mode="$(stat -f %Lp "$entry")" || return 1
        owner="$(stat -f %u "$entry")" || return 1
        [[ "$mode" =~ ^[0-7]{3,4}$ && "$owner" == "$(id -u)" ]] || return 1
        if [[ -d "$entry" ]]; then
            type=D
            digest=-
        elif [[ -f "$entry" ]]; then
            type=F
            digest="$(shasum -a 256 "$entry" | awk '{print $1}')" || return 1
            [[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] || return 1
        else
            return 1
        fi
        printf '%q\t%s\t%s\t%s\t%s\n' "$relative" "$type" "$mode" "$owner" "$digest" \
            >> "$unsorted" || return 1
    done < "$listing"
    remove_payload_manifest_work_file "$listing" "$listing_directory" || return 1
}

write_payload_manifest() {
    local session="$1" output="$2" marker requested
    local directory="${output%/*}" base="${output##*/}" index=0
    local unsorted complete listing directory_mode
    [[ -d "$directory" && ! -L "$directory" && -O "$directory" ]] || return 1
    directory_mode="$(stat -f %Lp "$directory")" || return 1
    (( (8#$directory_mode & 022) == 0 )) || return 1
    [[ ! -e "$output" && ! -L "$output" ]] || return 1
    unsorted="$directory/.$base.unsorted.new.$$"
    complete="$directory/.$base.complete.new.$$"
    [[ ! -e "$unsorted" && ! -L "$unsorted" \
        && ! -e "$complete" && ! -L "$complete" ]] || return 1
    : > "$unsorted" || return 1
    chmod 600 "$unsorted" || return 1
    for marker in \
        application-support.present application-support.absent \
        workspace.present workspace.absent preferences.present preferences.absent
    do
        if [[ -e "$session/$marker" || -L "$session/$marker" ]]; then
            index=$((index + 1))
            listing="$directory/.$base.$index.listing.new.$$"
            append_payload_manifest_path "$session" "$session/$marker" "$unsorted" "$listing" \
                || return 1
        fi
    done
    for requested in application-support workspace preferences.plist preferences.normalized.plist; do
        [[ ! -e "$session/$requested" && ! -L "$session/$requested" ]] || {
            index=$((index + 1))
            listing="$directory/.$base.$index.listing.new.$$"
            append_payload_manifest_path "$session" "$session/$requested" "$unsorted" "$listing" \
                || return 1
        }
    done
    LC_ALL=C sort "$unsorted" > "$complete" || return 1
    chmod 600 "$complete" || return 1
    [[ -f "$complete" && ! -L "$complete" && -O "$complete" \
        && "$(stat -f %Lp "$complete")" == 600 ]] || return 1
    mv -- "$complete" "$output" || return 1
    remove_payload_manifest_work_file "$unsorted" "$directory" || return 1
}

remove_payload_manifest_work_file() {
    local path="$1" expected_directory="$2"
    [[ "${path%/*}" == "$expected_directory" \
        && "${path##*/}" == .*.new.* \
        && -f "$path" && ! -L "$path" && -O "$path" \
        && "$(stat -f %Lp "$path")" == 600 ]] || return 1
    rm -f -- "$path" || return 1
}

write_tree_manifest() {
    local root="$1" output="$2" entry relative type mode owner digest
    local directory base listing unsorted complete directory_mode
    [[ -d "$root" && ! -L "$root" && -O "$root" ]] || return 1
    directory="${output%/*}"
    base="${output##*/}"
    [[ -n "$directory" && -n "$base" && -d "$directory" && ! -L "$directory" \
        && -O "$directory" ]] || return 1
    directory_mode="$(stat -f %Lp "$directory")" || return 1
    (( (8#$directory_mode & 022) == 0 )) || return 1
    [[ "$directory" != "$root" && "$directory" != "$root/"* ]] || return 1
    [[ ! -e "$output" && ! -L "$output" ]] || return 1
    listing="$directory/.$base.listing.new.$$"
    unsorted="$directory/.$base.unsorted.new.$$"
    complete="$directory/.$base.complete.new.$$"
    [[ ! -e "$listing" && ! -L "$listing" \
        && ! -e "$unsorted" && ! -L "$unsorted" \
        && ! -e "$complete" && ! -L "$complete" ]] || return 1
    : > "$listing" || return 1
    chmod 600 "$listing" || return 1
    find "$root" -print0 > "$listing" || return 1
    [[ -f "$listing" && ! -L "$listing" && -O "$listing" \
        && "$(stat -f %Lp "$listing")" == 600 ]] || return 1
    : > "$unsorted" || return 1
    chmod 600 "$unsorted" || return 1
    while IFS= read -r -d '' entry; do
        [[ "$entry" == "$root" || "$entry" == "$root/"* ]] || return 1
        [[ ! -L "$entry" && -O "$entry" ]] || return 1
        relative="${entry#"$root"}"
        [[ -n "$relative" ]] || relative=.
        mode="$(stat -f %Lp "$entry")" || return 1
        owner="$(stat -f %u "$entry")" || return 1
        [[ "$mode" =~ ^[0-7]{3,4}$ && "$owner" =~ ^[0-9]+$ ]] || return 1
        if [[ -d "$entry" ]]; then
            type=D
            digest=-
        elif [[ -f "$entry" ]]; then
            type=F
            digest="$(shasum -a 256 "$entry" | awk '{print $1}')" || return 1
            [[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] || return 1
        else
            return 1
        fi
        printf '%q\t%s\t%s\t%s\t%s\n' "$relative" "$type" "$mode" "$owner" "$digest" \
            >> "$unsorted" || return 1
    done < "$listing"
    LC_ALL=C sort "$unsorted" > "$complete" || return 1
    chmod 600 "$complete" || return 1
    [[ -f "$complete" && ! -L "$complete" && -O "$complete" \
        && "$(stat -f %Lp "$complete")" == 600 ]] || return 1
    mv -- "$complete" "$output" || return 1
    remove_manifest_work_file "$listing" "$directory" || return 1
    remove_manifest_work_file "$unsorted" "$directory" || return 1
}

remove_manifest_work_file() {
    local path="$1" expected_directory="$2"
    [[ "${path%/*}" == "$expected_directory" \
        && "${path##*/}" == .*.new.* \
        && -f "$path" && ! -L "$path" && -O "$path" \
        && "$(stat -f %Lp "$path")" == 600 ]] || return 1
    rm -f -- "$path" || return 1
}

verify_tree_manifest() {
    local root="$1" expected="$2" name="$3"
    local temporary="$RESTORE_TXN/.$name.live.manifest.new.$$"
    [[ -f "$expected" && ! -L "$expected" && -O "$expected" \
        && "$(stat -f %Lp "$expected")" == 600 ]] || return 1
    write_tree_manifest "$root" "$temporary" || return 1
    chmod 600 "$temporary" || return 1
    if ! diff -u "$expected" "$temporary" >/dev/null; then
        remove_tree_verification_manifest "$temporary" || return 1
        return 1
    fi
    [[ -f "$temporary" && ! -L "$temporary" && -O "$temporary" \
        && "$(stat -f %Lp "$temporary")" == 600 ]] || return 1
    rm -f -- "$temporary" || return 1
}

remove_tree_verification_manifest() {
    local path="$1"
    [[ -d "$RESTORE_TXN" && ! -L "$RESTORE_TXN" && -O "$RESTORE_TXN" \
        && "$(stat -f %Lp "$RESTORE_TXN")" == 700 ]] || return 1
    [[ "$(dirname "$path")" == "$RESTORE_TXN" \
        && "$(basename "$path")" == .*\.manifest.new.* \
        && -f "$path" && ! -L "$path" && -O "$path" \
        && "$(stat -f %Lp "$path")" == 600 ]] || return 1
    rm -f -- "$path" || return 1
}

verify_exact_restored_tree() {
    local expected_root="$1" live_root="$2" name="$3"
    local expected="$RESTORE_TXN/.$name.expected.manifest.new.$$"
    local actual="$RESTORE_TXN/.$name.live.manifest.new.$$"
    write_tree_manifest "$expected_root" "$expected" || return 1
    chmod 600 "$expected" || return 1
    write_tree_manifest "$live_root" "$actual" || return 1
    chmod 600 "$actual" || return 1
    if ! diff -u "$expected" "$actual" >/dev/null; then
        remove_tree_verification_manifest "$expected" || return 1
        remove_tree_verification_manifest "$actual" || return 1
        return 1
    fi
    remove_tree_verification_manifest "$expected" || return 1
    remove_tree_verification_manifest "$actual" || return 1
}

validate_payload_manifest() {
    local session="$1" expected_digest actual_digest temporary temporary_directory
    [[ -f "$session/metadata/payload.manifest" \
        && ! -L "$session/metadata/payload.manifest" \
        && -O "$session/metadata/payload.manifest" ]] \
        || fail "backup payload manifest is missing or unsafe"
    [[ -f "$session/metadata/payload.sha256" \
        && ! -L "$session/metadata/payload.sha256" \
        && -O "$session/metadata/payload.sha256" ]] \
        || fail "backup payload checksum is missing or unsafe"
    [[ "$(stat -f %Lp "$session/metadata/payload.manifest")" == 600 \
        && "$(stat -f %Lp "$session/metadata/payload.sha256")" == 600 ]] \
        || fail "backup payload metadata permissions must be 600"
    expected_digest="$(read_binding_value "$session/metadata/payload.sha256")"
    actual_digest="$(shasum -a 256 "$session/metadata/payload.manifest" | awk '{print $1}')"
    [[ "$expected_digest" =~ ^[[:xdigit:]]{64}$ && "$actual_digest" == "$expected_digest" ]] \
        || fail "backup payload checksum does not match"
    temporary_directory="$(mktemp -d "${TMPDIR%/}/SwiftTutorApprentice-payload-manifest.XXXXXX")" \
        || fail "backup payload traversal workspace could not be created"
    temporary_directory="$(cd "${temporary_directory%/*}" && pwd -P)/${temporary_directory##*/}"
    chmod 700 "$temporary_directory" \
        || fail "backup payload traversal workspace could not be protected"
    temporary="$temporary_directory/payload.manifest"
    if ! write_payload_manifest "$session" "$temporary"; then
        remove_payload_validation_directory "$temporary_directory" || true
        fail "backup payload traversal could not be completed"
    fi
    if ! diff -u "$session/metadata/payload.manifest" "$temporary" >/dev/null; then
        remove_payload_validation_directory "$temporary_directory" || true
        fail "backup payload content or mode does not match its manifest"
    fi
    remove_payload_validation_directory "$temporary_directory" \
        || fail "backup payload traversal workspace could not be removed"
}

remove_payload_validation_directory() {
    local path="$1" parent base
    parent="${path%/*}"
    base="${path##*/}"
    [[ "$parent" == "$TEMP_ROOT" \
        && "$base" == SwiftTutorApprentice-payload-manifest.* \
        && -d "$path" && ! -L "$path" && -O "$path" \
        && "$(stat -f %Lp "$path")" == 700 ]] || return 1
    rm -rf -- "$path" || return 1
}

read_binding_value() {
    local path="$1" value
    [[ -f "$path" && ! -L "$path" && -O "$path" ]] \
        || fail "session binding metadata is missing or unsafe, or has the wrong owner"
    [[ "$(stat -f %Lp "$path")" == "600" ]] || fail "session binding metadata permissions must be 600"
    [[ "$(wc -l < "$path" | tr -d ' ')" == "1" ]] || fail "session binding metadata must contain exactly one line"
    IFS= read -r value < "$path" || fail "session binding metadata could not be read"
    printf '%s' "$value"
}

validate_session_binding() {
    local session="$1" canonical_home expected_digest stored_digest
    [[ -d "$session/metadata" && ! -L "$session/metadata" ]] \
        || fail "session binding metadata directory is missing or unsafe"
    [[ "$(stat -f %Lp "$session/metadata")" == "700" ]] \
        || fail "session binding metadata directory permissions must be 700"
    [[ -O "$session/metadata" ]] || fail "session binding metadata has the wrong owner"

    canonical_home="$(cd "$HOME" && pwd -P)"
    [[ "$(read_binding_value "$session/metadata/home")" == "$canonical_home" ]] \
        || fail "session HOME does not match current HOME"
    [[ "$(read_binding_value "$session/metadata/application-support")" == "$APP_DATA" ]] \
        || fail "session Application Support path does not match"
    [[ "$(read_binding_value "$session/metadata/workspace")" == "$WORKSPACE" ]] \
        || fail "session Workspace path does not match"
    [[ "$(read_binding_value "$session/metadata/preferences-domain")" == "$PREFERENCES_DOMAIN" ]] \
        || fail "session preferences domain does not match"
    [[ "$(read_binding_value "$session/metadata/user-id")" == "$(id -u)" ]] \
        || fail "session user context does not match"

    stored_digest="$(read_binding_value "$session/metadata/binding.sha256")"
    expected_digest="$(binding_digest "$session")"
    [[ "$stored_digest" =~ ^[[:xdigit:]]{64}$ && "$stored_digest" == "$expected_digest" ]] \
        || fail "session binding metadata checksum does not match"
    validate_payload_manifest "$session"
    assert_managed_surface_safe "$APP_DATA"
    assert_managed_surface_safe "$WORKSPACE"
}

validate_backup_state() {
    local session="$1" surface="$2"
    local present="$session/$surface.present"
    local absent="$session/$surface.absent"
    if [[ -f "$present" && ! -L "$present" ]]; then
        [[ -O "$present" && "$(stat -f %Lp "$present")" == 600 ]] \
            || fail "$surface backup marker permissions or owner are unsafe"
        [[ ! -e "$absent" && ! -L "$absent" ]] \
            || fail "$surface backup has conflicting presence markers"
        case "$surface" in
            application-support|workspace)
                [[ -d "$session/$surface" && ! -L "$session/$surface" ]] \
                    || fail "$surface backup directory is missing or unsafe"
                [[ -O "$session/$surface" ]] || fail "$surface backup directory has the wrong owner"
                local payload_mode
                payload_mode="$(stat -f %Lp "$session/$surface")"
                (( (8#$payload_mode & 022) == 0 )) \
                    || fail "$surface backup directory is group/world writable"
                ;;
            preferences)
                [[ -f "$session/preferences.plist" && ! -L "$session/preferences.plist" ]] \
                    || fail "preferences backup is missing or unsafe"
                [[ -f "$session/preferences.normalized.plist" && ! -L "$session/preferences.normalized.plist" ]] \
                    || fail "normalized preferences backup is missing or unsafe"
                [[ -O "$session/preferences.plist" && -O "$session/preferences.normalized.plist" \
                    && "$(stat -f %Lp "$session/preferences.plist")" == 600 \
                    && "$(stat -f %Lp "$session/preferences.normalized.plist")" == 600 ]] \
                    || fail "preferences backup permissions or owner are unsafe"
                ;;
        esac
    elif [[ -f "$absent" && ! -L "$absent" ]]; then
        [[ -O "$absent" && "$(stat -f %Lp "$absent")" == 600 ]] \
            || fail "$surface backup marker permissions or owner are unsafe"
        [[ ! -e "$present" && ! -L "$present" ]] \
            || fail "$surface backup has conflicting absence markers"
    else
        fail "$surface backup presence marker is missing or unsafe"
    fi
}

quit_app() {
    osascript -e 'tell application id "com.local.swifttutorapprentice" to quit' \
        >/dev/null 2>&1 || true
    local attempt
    for attempt in {1..50}; do
        if ! pgrep -x SwiftTutorApprentice >/dev/null 2>&1; then
            return
        fi
        sleep 0.1
    done
    fail "SwiftTutorApprentice is still running"
}

validate_session() {
    local requested="$1"
    [[ "$requested" == /* ]] || fail "session path must be absolute"
    [[ "$requested" == "$SESSION_PREFIX_INPUT"* || "$requested" == "$SESSION_PREFIX"* ]] \
        || fail "session path is outside the system temporary directory"
    [[ -d "$requested" && ! -L "$requested" ]] || fail "session directory is missing or is a symlink"

    local parent base canonical
    parent="$(dirname "$requested")"
    base="$(basename "$requested")"
    [[ "$base" =~ ^SwiftTutorApprentice-smoke\.[[:alnum:]]+$ ]] \
        || fail "session directory name is unsafe"
    canonical="$(cd "$parent" && pwd -P)/$base"
    [[ "$canonical" == "$SESSION_PREFIX"* ]] || fail "canonical session path is outside the system temporary directory"
    [[ -f "$canonical/.session-marker" && ! -L "$canonical/.session-marker" ]] \
        || fail "session marker is missing or unsafe"
    [[ -O "$canonical" && "$(stat -f %Lp "$canonical")" == "700" ]] \
        || fail "session directory permissions or owner are unsafe"
    [[ -O "$canonical/.session-marker" \
        && "$(stat -f %Lp "$canonical/.session-marker")" == "600" ]] \
        || fail "session marker permissions or owner are unsafe"
    grep -Eq '^[[:xdigit:]-]{32,}$' "$canonical/.session-marker" \
        || fail "session marker is invalid"
    validate_snapshot_directory "$canonical"
    validate_session_binding "$canonical"
    validate_backup_state "$canonical" application-support
    validate_backup_state "$canonical" workspace
    validate_backup_state "$canonical" preferences
    SESSION="$canonical"
}

copy_tree() {
    local source="$1" destination="$2" test_phase="${3:-}"
    [[ -d "$source" && ! -L "$source" ]] || fail "$source must be a real directory"
    [[ ! -e "$destination" && ! -L "$destination" ]] || fail "$destination already exists"
    /usr/bin/ditto --noqtn "$source" "$destination" || return 1
    if [[ -n "$test_phase" ]]; then
        restore_test_hook "$test_phase" || return 1
    fi
    diff -qr "$source" "$destination" >/dev/null || return 1
}

normalize_preferences() {
    local source="$1" destination="$2"
    plutil -convert xml1 -o "$destination" "$source"
}

replace_preferences_from() {
    local source="$1"
    defaults delete "$PREFERENCES_DOMAIN" >/dev/null 2>&1 || true
    defaults import "$PREFERENCES_DOMAIN" "$source" >/dev/null
}

assert_managed_surface_safe() {
    local target="$1"
    local home_real relative component current mode
    [[ "$HOME" == /* && -d "$HOME" && ! -L "$HOME" && -O "$HOME" ]] \
        || fail "HOME is missing or unsafe"
    mode="$(stat -f %Lp "$HOME")"
    (( (8#$mode & 022) == 0 )) || fail "HOME permissions or owner are unsafe"
    home_real="$(cd "$HOME" && pwd -P)"
    [[ "$home_real" == "$HOME" ]] || fail "HOME is not canonical"
    [[ "$target" == "$HOME/"* ]] || fail "managed surface is outside HOME"
    relative="${target#"$HOME"/}"
    current="$HOME"
    IFS='/' read -r -a components <<< "$relative"
    for component in "${components[@]}"; do
        [[ -n "$component" && "$component" != "." && "$component" != ".." ]] \
            || fail "managed surface path contains traversal"
        current="$current/$component"
        [[ ! -L "$current" ]] || fail "$current is a symlink"
        if [[ -e "$current" ]]; then
            [[ -d "$current" && -O "$current" ]] \
                || fail "$current permissions or owner are unsafe"
            mode="$(stat -f %Lp "$current")"
            (( (8#$mode & 022) == 0 )) \
                || fail "$current permissions or owner are unsafe"
        fi
    done
}

path_is_within_root() {
    local candidate="$1" root="$2"
    [[ -n "$root" && ( "$candidate" == "$root" || "$candidate" == "$root/"* ) ]]
}

canonicalize_test_path() {
    local requested="$1" require_existing="$2" parent base parent_real
    TEST_CANONICAL_PATH=""
    [[ "$requested" == /* && "$requested" != *//* \
        && "$requested" != */../* && "$requested" != */.. \
        && "$requested" != */./* && "$requested" != */. ]] || return 1
    parent="${requested%/*}"
    base="${requested##*/}"
    [[ -n "$parent" && -n "$base" && "$base" != . && "$base" != .. ]] || return 1
    [[ "$base" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
    [[ -d "$parent" && ! -L "$parent" ]] || return 1
    parent_real="$(cd "$parent" && pwd -P)" || return 1
    [[ "$parent_real" == "$parent" ]] || return 1
    if [[ "$require_existing" == 1 ]]; then
        [[ -e "$requested" && ! -L "$requested" ]] || return 1
    else
        [[ ! -e "$requested" && ! -L "$requested" ]] || return 1
    fi
    TEST_CANONICAL_PATH="$parent_real/$base"
}

test_mutation_path_allowed() {
    local candidate="$1" root
    for root in \
        "$APP_DATA" "$WORKSPACE" \
        "$RESTORE_APP_STAGE" "$RESTORE_APP_ROLLBACK" "$RESTORE_APP_DISPLACED" \
        "$RESTORE_APP_ROLLBACK_INSTALL" "$RESTORE_APP_INSTALLED" \
        "$RESTORE_WORKSPACE_STAGE" "$RESTORE_WORKSPACE_ROLLBACK" \
        "$RESTORE_WORKSPACE_DISPLACED" "$RESTORE_WORKSPACE_ROLLBACK_INSTALL" \
        "$RESTORE_WORKSPACE_INSTALLED" "$RESTORE_TXN"
    do
        path_is_within_root "$candidate" "$root" && return 0
    done
    return 1
}

restore_test_hook() {
    local phase="$1"
    [[ "${SWIFTTUTOR_SMOKE_TESTING:-0}" == "1" ]] || return 0
    if [[ -n "${SMOKE_STATE_TEST_HOOK_LOG:-}" ]]; then
        printf '%s\n' "$phase" >> "$SMOKE_STATE_TEST_HOOK_LOG"
    fi
    if [[ "${SMOKE_STATE_TEST_MUTATE_PHASE:-}" == "$phase" ]]; then
        local mutate_path="${SMOKE_STATE_TEST_MUTATE_PATH:-}"
        local mutate_action="${SMOKE_STATE_TEST_MUTATE_ACTION:-}"
        local mutate_target="${SMOKE_STATE_TEST_MUTATE_TARGET:-}"
        local require_existing=1 canonical_mutate canonical_target
        [[ "$mutate_action" != add-file ]] || require_existing=0
        canonicalize_test_path "$mutate_path" "$require_existing" || return 65
        canonical_mutate="$TEST_CANONICAL_PATH"
        test_mutation_path_allowed "$canonical_mutate" || return 65
        case "$mutate_action" in
            symlink)
                canonicalize_test_path "$mutate_target" 1 || return 65
                canonical_target="$TEST_CANONICAL_PATH"
                path_is_within_root "$canonical_target" "$TEMP_ROOT" || return 65
                rm -rf -- "$canonical_mutate" || return 1
                ln -s "$canonical_target" "$canonical_mutate" || return 1
                ;;
            mode)
                chmod 777 "$canonical_mutate" || return 1
                ;;
            replacement)
                rm -rf -- "$canonical_mutate" || return 1
                mkdir "$canonical_mutate" || return 1
                chmod 700 "$canonical_mutate" || return 1
                ;;
            add-file)
                printf 'synthetic-added-entry\n' > "$canonical_mutate" || return 1
                chmod 600 "$canonical_mutate" || return 1
                ;;
            delete)
                rm -rf -- "$canonical_mutate" || return 1
                ;;
            *) return 64 ;;
        esac
    fi
    if [[ "${SMOKE_STATE_TEST_KILL_PHASE:-}" == "$phase" ]]; then
        kill -KILL "$$"
    fi
    if [[ "${SMOKE_STATE_TEST_SIGNAL_PHASE:-}" == "$phase" ]]; then
        case "${SMOKE_STATE_TEST_SIGNAL_NAME:-TERM}" in
            INT) kill -INT "$$" ;;
            TERM) kill -TERM "$$" ;;
            HUP) kill -HUP "$$" ;;
            *) return 64 ;;
        esac
    fi
    if [[ "${SMOKE_STATE_TEST_FAIL_PHASE:-}" == "$phase" ]]; then
        return 1
    fi
    if [[ "${SMOKE_STATE_TEST_ALWAYS_FAIL_PHASE:-}" == "$phase" ]]; then
        return 1
    fi
    if [[ "${SMOKE_STATE_TEST_FAIL_ONCE_PHASE:-}" == "$phase" ]]; then
        local once_marker="${SMOKE_STATE_TEST_HOOK_LOG:-${TMPDIR%/}/restore-hook}.$phase.once"
        if [[ ! -e "$once_marker" ]]; then
            : > "$once_marker"
            return 1
        fi
    fi
}

restore_auxiliary_paths() {
    local token parent
    token="$(basename "$SESSION")"
    parent="$(dirname "$APP_DATA")"
    RESTORE_APP_STAGE="$parent/.$token.application-support.stage"
    RESTORE_APP_ROLLBACK="$parent/.$token.application-support.rollback"
    RESTORE_APP_DISPLACED="$parent/.$token.application-support.displaced"
    RESTORE_APP_ROLLBACK_INSTALL="$parent/.$token.application-support.rollback-install"
    RESTORE_APP_INSTALLED="$parent/.$token.application-support.installed"
    parent="$(dirname "$WORKSPACE")"
    RESTORE_WORKSPACE_STAGE="$parent/.$token.workspace.stage"
    RESTORE_WORKSPACE_ROLLBACK="$parent/.$token.workspace.rollback"
    RESTORE_WORKSPACE_DISPLACED="$parent/.$token.workspace.displaced"
    RESTORE_WORKSPACE_ROLLBACK_INSTALL="$parent/.$token.workspace.rollback-install"
    RESTORE_WORKSPACE_INSTALLED="$parent/.$token.workspace.installed"
}

validate_restore_auxiliary_path() {
    local path="$1" target="$2" expected_parent expected_prefix
    expected_parent="$(dirname "$target")"
    expected_prefix=".$(basename "$SESSION")."
    [[ "$(dirname "$path")" == "$expected_parent" ]] \
        || fail "restore transaction path escaped its managed parent"
    [[ "$(basename "$path")" == "$expected_prefix"* ]] \
        || fail "restore transaction path has an unsafe name"
    assert_managed_surface_safe "$path"
}

validate_restore_paths() {
    restore_auxiliary_paths
    validate_restore_auxiliary_path "$RESTORE_APP_STAGE" "$APP_DATA"
    validate_restore_auxiliary_path "$RESTORE_APP_ROLLBACK" "$APP_DATA"
    validate_restore_auxiliary_path "$RESTORE_APP_DISPLACED" "$APP_DATA"
    validate_restore_auxiliary_path "$RESTORE_APP_ROLLBACK_INSTALL" "$APP_DATA"
    validate_restore_auxiliary_path "$RESTORE_APP_INSTALLED" "$APP_DATA"
    validate_restore_auxiliary_path "$RESTORE_WORKSPACE_STAGE" "$WORKSPACE"
    validate_restore_auxiliary_path "$RESTORE_WORKSPACE_ROLLBACK" "$WORKSPACE"
    validate_restore_auxiliary_path "$RESTORE_WORKSPACE_DISPLACED" "$WORKSPACE"
    validate_restore_auxiliary_path "$RESTORE_WORKSPACE_ROLLBACK_INSTALL" "$WORKSPACE"
    validate_restore_auxiliary_path "$RESTORE_WORKSPACE_INSTALLED" "$WORKSPACE"
}

validate_owned_safe_directory() {
    local path="$1" mode
    [[ -d "$path" && ! -L "$path" && -O "$path" ]] || return 1
    mode="$(stat -f %Lp "$path")" || return 1
    (( (8#$mode & 022) == 0 ))
}

validate_restore_directory_identity() {
    local path="$1"
    case "$path" in
        "$APP_DATA"|"$WORKSPACE")
            assert_managed_surface_safe "$path" || return 1
            ;;
        "$RESTORE_APP_STAGE"|"$RESTORE_APP_ROLLBACK"|"$RESTORE_APP_DISPLACED"|\
        "$RESTORE_APP_ROLLBACK_INSTALL"|"$RESTORE_APP_INSTALLED")
            validate_restore_auxiliary_path "$path" "$APP_DATA" || return 1
            ;;
        "$RESTORE_WORKSPACE_STAGE"|"$RESTORE_WORKSPACE_ROLLBACK"|\
        "$RESTORE_WORKSPACE_DISPLACED"|"$RESTORE_WORKSPACE_ROLLBACK_INSTALL"|\
        "$RESTORE_WORKSPACE_INSTALLED")
            validate_restore_auxiliary_path "$path" "$WORKSPACE" || return 1
            ;;
        *) return 1 ;;
    esac
}

validate_restore_move_boundary() {
    local source="$1" destination="$2"
    validate_restore_directory_identity "$source" || return 1
    validate_restore_directory_identity "$destination" || return 1
    validate_owned_safe_directory "$source" || return 1
    [[ ! -e "$destination" && ! -L "$destination" ]] || return 1
}

write_restore_phase() {
    local phase="$1" temporary="$RESTORE_TXN/.phase.new.$$"
    printf '%s\n' "$phase" > "$temporary" || return 1
    chmod 600 "$temporary" || return 1
    if [[ "${SWIFTTUTOR_SMOKE_TESTING:-0}" == 1 \
        && "${SMOKE_STATE_TEST_FAIL_WRITE_PHASE:-}" == "$phase" ]]
    then
        return 1
    fi
    restore_test_hook before-phase-publish || return 1
    [[ -d "$RESTORE_TXN" && ! -L "$RESTORE_TXN" && -O "$RESTORE_TXN" \
        && "$(stat -f %Lp "$RESTORE_TXN")" == 700 ]] || return 1
    [[ -f "$temporary" && ! -L "$temporary" && -O "$temporary" \
        && "$(stat -f %Lp "$temporary")" == 600 ]] || return 1
    [[ -f "$RESTORE_TXN/phase" && ! -L "$RESTORE_TXN/phase" \
        && -O "$RESTORE_TXN/phase" \
        && "$(stat -f %Lp "$RESTORE_TXN/phase")" == 600 ]] || return 1
    mv -f -- "$temporary" "$RESTORE_TXN/phase" || return 1
    restore_test_hook after-phase-publish || return 1
}

mark_restore_state() {
    local destination="$RESTORE_TXN/$1" temporary="$RESTORE_TXN/.$1.new.$$"
    : > "$temporary" || return 1
    chmod 600 "$temporary" || return 1
    restore_test_hook before-state-marker-publish || return 1
    [[ -d "$RESTORE_TXN" && ! -L "$RESTORE_TXN" && -O "$RESTORE_TXN" \
        && "$(stat -f %Lp "$RESTORE_TXN")" == 700 ]] || return 1
    [[ -f "$temporary" && ! -L "$temporary" && -O "$temporary" \
        && "$(stat -f %Lp "$temporary")" == 600 ]] || return 1
    [[ "$(dirname "$destination")" == "$RESTORE_TXN" ]] || return 1
    [[ ! -e "$destination" && ! -L "$destination" ]] || return 1
    mv -- "$temporary" "$destination" || return 1
    restore_test_hook after-state-marker-publish || return 1
}

remove_restore_journal_orphans() {
    local entry
    [[ -d "$RESTORE_TXN" && ! -L "$RESTORE_TXN" ]] || return 0
    for entry in "$RESTORE_TXN"/.*.new.*; do
        [[ -e "$entry" || -L "$entry" ]] || continue
        [[ -f "$entry" && ! -L "$entry" && -O "$entry" \
            && "$(stat -f %Lp "$entry")" == 600 ]] \
            || fail "restore transaction has an unsafe orphan journal file"
        restore_test_hook before-orphan-delete || return 1
        [[ -d "$RESTORE_TXN" && ! -L "$RESTORE_TXN" && -O "$RESTORE_TXN" \
            && "$(stat -f %Lp "$RESTORE_TXN")" == 700 ]] || return 1
        [[ "$(dirname "$entry")" == "$RESTORE_TXN" \
            && "$(basename "$entry")" == .*\.new.* \
            && -f "$entry" && ! -L "$entry" && -O "$entry" \
            && "$(stat -f %Lp "$entry")" == 600 ]] || return 1
        rm -f -- "$entry" || return 1
        restore_test_hook after-orphan-delete || return 1
    done
}

initialize_restore_transaction() {
    RESTORE_TXN_TEMP="$SESSION/.restore-transaction.new"
    if [[ -e "$RESTORE_TXN_TEMP" || -L "$RESTORE_TXN_TEMP" ]]; then
        [[ -d "$RESTORE_TXN_TEMP" && ! -L "$RESTORE_TXN_TEMP" \
            && -O "$RESTORE_TXN_TEMP" \
            && "$(stat -f %Lp "$RESTORE_TXN_TEMP")" == 700 ]] \
            || fail "restore transaction temporary journal is unsafe"
        restore_test_hook before-temporary-journal-delete || return 1
        [[ -d "$RESTORE_TXN_TEMP" && ! -L "$RESTORE_TXN_TEMP" \
            && -O "$RESTORE_TXN_TEMP" \
            && "$(stat -f %Lp "$RESTORE_TXN_TEMP")" == 700 ]] || return 1
        rm -rf -- "$RESTORE_TXN_TEMP" || return 1
        restore_test_hook after-temporary-journal-delete || return 1
    fi
    mkdir "$RESTORE_TXN_TEMP"
    chmod 700 "$RESTORE_TXN_TEMP"
    printf 'staging\n' > "$RESTORE_TXN_TEMP/phase"
    chmod 600 "$RESTORE_TXN_TEMP/phase"
    restore_test_hook before-journal-publish
    [[ -d "$RESTORE_TXN_TEMP" && ! -L "$RESTORE_TXN_TEMP" \
        && -O "$RESTORE_TXN_TEMP" \
        && "$(stat -f %Lp "$RESTORE_TXN_TEMP")" == 700 ]] || return 1
    [[ ! -e "$RESTORE_TXN" && ! -L "$RESTORE_TXN" ]] || return 1
    mv -- "$RESTORE_TXN_TEMP" "$RESTORE_TXN" || return 1
    RESTORE_TXN_TEMP=""
    restore_test_hook after-journal-publish
}

validate_restore_transaction() {
    local entry phase
    [[ -d "$RESTORE_TXN" && ! -L "$RESTORE_TXN" && -O "$RESTORE_TXN" ]] \
        || fail "restore transaction journal is missing or unsafe"
    [[ "$(stat -f %Lp "$RESTORE_TXN")" == "700" ]] \
        || fail "restore transaction journal permissions must be 700"
    remove_restore_journal_orphans
    [[ -f "$RESTORE_TXN/phase" && ! -L "$RESTORE_TXN/phase" \
        && -O "$RESTORE_TXN/phase" ]] \
        || fail "restore transaction phase is missing or unsafe"
    [[ "$(stat -f %Lp "$RESTORE_TXN/phase")" == "600" ]] \
        || fail "restore transaction phase permissions must be 600"
    phase="$(<"$RESTORE_TXN/phase")"
    case "$phase" in
        staging|installing-application-support|installing-workspace|installing-preferences|verifying|committed|rollback-verified|rollback-failed-desired-restored) ;;
        *) fail "restore transaction phase is invalid" ;;
    esac
    for entry in "$RESTORE_TXN"/*; do
        [[ -f "$entry" && ! -L "$entry" && -O "$entry" ]] \
            || fail "restore transaction journal contains an unsafe entry"
        [[ "$(stat -f %Lp "$entry")" == "600" ]] \
            || fail "restore transaction journal files must be 600"
    done
}

capture_directory_rollback() {
    local target="$1" rollback="$2" name="$3"
    if [[ -e "$target" || -L "$target" ]]; then
        [[ -d "$target" && ! -L "$target" ]] \
            || fail "$name live state is not a real directory"
        copy_tree "$target" "$rollback"
        write_tree_manifest "$rollback" "$RESTORE_TXN/$name.pre-restore.manifest"
        chmod 600 "$RESTORE_TXN/$name.pre-restore.manifest"
        mark_restore_state "$name.pre-present"
    else
        mark_restore_state "$name.pre-absent"
    fi
}

capture_preferences_rollback() {
    if defaults export "$PREFERENCES_DOMAIN" "$RESTORE_TXN/preferences.rollback.plist" \
        >/dev/null 2>&1
    then
        normalize_preferences \
            "$RESTORE_TXN/preferences.rollback.plist" \
            "$RESTORE_TXN/preferences.rollback.normalized.plist"
        chmod 600 "$RESTORE_TXN/preferences.rollback.plist" \
            "$RESTORE_TXN/preferences.rollback.normalized.plist"
        mark_restore_state preferences.pre-present
    else
        rm -f -- "$RESTORE_TXN/preferences.rollback.plist"
        mark_restore_state preferences.pre-absent
    fi
}

stage_restore_directory() {
    local source="$1" stage="$2" marker="$3" phase="$4"
    if [[ -f "$SESSION/$marker.present" ]]; then
        copy_tree "$source" "$stage" "$phase"
    else
        [[ -f "$SESSION/$marker.absent" ]] || fail "$marker backup state is missing"
    fi
}

install_restore_directory() {
    local target="$1" stage="$2" displaced="$3" marker="$4" phase="$5"
    restore_test_hook "before-$marker-marker"
    mark_restore_state "$marker.changed"
    restore_test_hook "after-$marker-marker"
    write_restore_phase "installing-$marker" || return 1
    restore_test_hook "before-$marker-swap" || return 1
    if [[ -e "$target" || -L "$target" ]]; then
        restore_test_hook "before-$marker-displace" || return 1
        validate_restore_move_boundary "$target" "$displaced" \
            || fail "$marker live state became unsafe before displacement"
        mv -- "$target" "$displaced" || return 1
        restore_test_hook "after-$marker-displace" || return 1
    fi
    if [[ -f "$SESSION/$marker.present" ]]; then
        restore_test_hook "before-$marker-install" || return 1
        validate_restore_move_boundary "$stage" "$target" \
            || fail "$marker staged state became unsafe before install"
        mv -- "$stage" "$target" || return 1
        restore_test_hook "after-$marker-install" || return 1
    fi
    restore_test_hook "after-$marker-swap" || return 1
    restore_test_hook "$phase" || return 1
}

restore_move_with_retry() {
    local phase="$1" source="$2" destination="$3" attempt
    for attempt in 1 2; do
        if restore_test_hook "$phase" \
            && validate_restore_move_boundary "$source" "$destination" \
            && mv -- "$source" "$destination"
        then
            return 0
        fi
    done
    return 1
}

copy_tree_with_retry() {
    local source="$1" destination="$2" phase="$3" attempt
    for attempt in 1 2; do
        if copy_tree "$source" "$destination" "$phase"; then
            return 0
        fi
        if [[ -e "$destination" || -L "$destination" ]]; then
            restore_test_hook "before-$phase-partial-delete" || return 1
            validate_restore_directory_identity "$destination" || return 1
            validate_owned_safe_directory "$destination" || return 1
            rm -rf -- "$destination" || return 1
            restore_test_hook "after-$phase-partial-delete" || return 1
        fi
    done
    return 1
}

install_directory_rollback() {
    local target="$1" rollback="$2" rollback_install="$3" installed="$4" marker="$5"
    [[ -f "$RESTORE_TXN/$marker.changed" ]] || return 0
    if [[ -f "$RESTORE_TXN/$marker.pre-present" ]]; then
        [[ -d "$rollback" && ! -L "$rollback" ]] || return 1
        [[ ! -e "$rollback_install" && ! -L "$rollback_install" ]] || return 1
        copy_tree_with_retry "$rollback" "$rollback_install" \
            "rollback-$marker-copy" || return 1
    else
        [[ -f "$RESTORE_TXN/$marker.pre-absent" ]] || return 1
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        restore_test_hook "before-rollback-$marker-displace" || return 1
        validate_restore_move_boundary "$target" "$installed" || return 1
        mv -- "$target" "$installed" || return 1
        restore_test_hook "after-rollback-$marker-displace" || return 1
    fi
    if [[ -f "$RESTORE_TXN/$marker.pre-present" ]]; then
        if ! restore_move_with_retry "rollback-$marker-install" "$rollback_install" "$target"; then
            if [[ -d "$installed" && ! -L "$installed" ]]; then
                restore_move_with_retry "rollback-$marker-fallback" "$installed" "$target" || true
            fi
            return 1
        fi
    fi
}

verify_preferences_against() {
    local expected="$1" normalized="$2" prefix="$3"
    defaults export "$PREFERENCES_DOMAIN" "$RESTORE_TXN/$prefix.live.plist" >/dev/null \
        || return 1
    normalize_preferences "$RESTORE_TXN/$prefix.live.plist" \
        "$RESTORE_TXN/$prefix.live.normalized.plist" || return 1
    diff -u "$normalized" "$RESTORE_TXN/$prefix.live.normalized.plist" >/dev/null
}

rollback_restore_preferences() {
    [[ -f "$RESTORE_TXN/preferences.changed" ]] || return 0
    if [[ -f "$RESTORE_TXN/preferences.pre-present" ]]; then
        replace_preferences_from "$RESTORE_TXN/preferences.rollback.plist" \
            || replace_preferences_from "$RESTORE_TXN/preferences.rollback.plist" \
            || return 1
        verify_preferences_against "$RESTORE_TXN/preferences.rollback.plist" \
            "$RESTORE_TXN/preferences.rollback.normalized.plist" preferences.rollback.verify
    else
        [[ -f "$RESTORE_TXN/preferences.pre-absent" ]] || return 1
        defaults delete "$PREFERENCES_DOMAIN" >/dev/null 2>&1 || true
        if defaults export "$PREFERENCES_DOMAIN" \
            "$RESTORE_TXN/preferences.rollback.unexpected.plist" >/dev/null 2>&1
        then
            return 1
        fi
    fi
}

verify_directory_rollback() {
    local target="$1" rollback="$2" marker="$3"
    [[ -f "$RESTORE_TXN/$marker.changed" ]] || return 0
    if [[ -f "$RESTORE_TXN/$marker.pre-present" ]]; then
        [[ -d "$target" && ! -L "$target" ]] || return 1
        verify_tree_manifest "$target" "$RESTORE_TXN/$marker.pre-restore.manifest" \
            "$marker.pre-restore"
    else
        [[ ! -e "$target" && ! -L "$target" ]]
    fi
}

verify_preferences_rollback() {
    [[ -f "$RESTORE_TXN/preferences.changed" ]] || return 0
    if [[ -f "$RESTORE_TXN/preferences.pre-present" ]]; then
        verify_preferences_against "$RESTORE_TXN/preferences.rollback.plist" \
            "$RESTORE_TXN/preferences.rollback.normalized.plist" preferences.rollback.verify
    else
        [[ -f "$RESTORE_TXN/preferences.pre-absent" ]] || return 1
        if defaults export "$PREFERENCES_DOMAIN" \
            "$RESTORE_TXN/preferences.rollback.unexpected.plist" >/dev/null 2>&1
        then
            return 1
        fi
        rm -f -- "$RESTORE_TXN/preferences.rollback.unexpected.plist" || return 1
    fi
}

verify_pre_restore_state() {
    verify_directory_rollback "$APP_DATA" "$RESTORE_APP_ROLLBACK" \
        application-support || return 1
    verify_directory_rollback "$WORKSPACE" "$RESTORE_WORKSPACE_ROLLBACK" \
        workspace || return 1
    verify_preferences_rollback || return 1
}

restore_desired_after_failed_rollback_directory() {
    local target="$1" installed="$2" parking="$3" marker="$4"
    [[ -f "$RESTORE_TXN/$marker.changed" ]] || return 0
    [[ -d "$installed" && ! -L "$installed" ]] || return 0
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -e "$parking" || -L "$parking" ]]; then
            restore_test_hook "before-rollforward-$marker-parking-delete" || return 1
            validate_restore_directory_identity "$parking" || return 1
            validate_owned_safe_directory "$parking" || return 1
            rm -rf -- "$parking" || return 1
            restore_test_hook "after-rollforward-$marker-parking-delete" || return 1
        fi
        restore_move_with_retry "rollforward-$marker-park" "$target" "$parking" \
            || return 1
    fi
    restore_move_with_retry "rollforward-$marker-install" "$installed" "$target"
}

restore_desired_after_failed_rollback() {
    restore_desired_after_failed_rollback_directory "$APP_DATA" "$RESTORE_APP_INSTALLED" \
        "$RESTORE_APP_ROLLBACK_INSTALL" application-support || return 1
    restore_desired_after_failed_rollback_directory "$WORKSPACE" "$RESTORE_WORKSPACE_INSTALLED" \
        "$RESTORE_WORKSPACE_ROLLBACK_INSTALL" workspace || return 1
    if [[ -f "$RESTORE_TXN/preferences.changed" ]]; then
        if [[ -f "$SESSION/preferences.present" ]]; then
            replace_preferences_from "$SESSION/preferences.plist" \
                || return 1
        else
            defaults delete "$PREFERENCES_DOMAIN" >/dev/null 2>&1 || true
        fi
    fi
    verify_restored_state || return 1
    write_restore_phase rollback-failed-desired-restored || return 1
    RESTORE_COMMITTED=1
}

cleanup_restore_auxiliary_state() {
    cleanup_restore_auxiliary_path "$RESTORE_APP_STAGE" "$APP_DATA" \
        application-support-stage || return 1
    cleanup_restore_auxiliary_path "$RESTORE_APP_ROLLBACK" "$APP_DATA" \
        application-support-rollback || return 1
    cleanup_restore_auxiliary_path "$RESTORE_APP_DISPLACED" "$APP_DATA" \
        application-support-displaced || return 1
    cleanup_restore_auxiliary_path "$RESTORE_APP_ROLLBACK_INSTALL" "$APP_DATA" \
        application-support-rollback-install || return 1
    cleanup_restore_auxiliary_path "$RESTORE_APP_INSTALLED" "$APP_DATA" \
        application-support-installed || return 1
    cleanup_restore_auxiliary_path "$RESTORE_WORKSPACE_STAGE" "$WORKSPACE" \
        workspace-stage || return 1
    cleanup_restore_auxiliary_path "$RESTORE_WORKSPACE_ROLLBACK" "$WORKSPACE" \
        workspace-rollback || return 1
    cleanup_restore_auxiliary_path "$RESTORE_WORKSPACE_DISPLACED" "$WORKSPACE" \
        workspace-displaced || return 1
    cleanup_restore_auxiliary_path "$RESTORE_WORKSPACE_ROLLBACK_INSTALL" "$WORKSPACE" \
        workspace-rollback-install || return 1
    cleanup_restore_auxiliary_path "$RESTORE_WORKSPACE_INSTALLED" "$WORKSPACE" \
        workspace-installed || return 1
}

assert_cleanup_phase() {
    local phase
    [[ -d "$RESTORE_TXN" && ! -L "$RESTORE_TXN" && -O "$RESTORE_TXN" \
        && "$(stat -f %Lp "$RESTORE_TXN")" == 700 ]] || return 1
    [[ -f "$RESTORE_TXN/phase" && ! -L "$RESTORE_TXN/phase" \
        && -O "$RESTORE_TXN/phase" \
        && "$(stat -f %Lp "$RESTORE_TXN/phase")" == 600 ]] || return 1
    phase="$(<"$RESTORE_TXN/phase")"
    case "$phase" in
        committed|rollback-verified|rollback-failed-desired-restored) return 0 ;;
        *) return 1 ;;
    esac
}

cleanup_restore_auxiliary_path() {
    local path="$1" target="$2" name="$3" mode
    restore_test_hook "before-cleanup-$name" || return 1
    assert_cleanup_phase || return 1
    validate_restore_auxiliary_path "$path" "$target" || return 1
    if [[ -e "$path" || -L "$path" ]]; then
        [[ -d "$path" && ! -L "$path" && -O "$path" ]] || return 1
        mode="$(stat -f %Lp "$path")" || return 1
        (( (8#$mode & 022) == 0 )) || return 1
        rm -rf -- "$path" || return 1
    fi
    restore_test_hook "after-cleanup-$name" || return 1
}

remove_restore_journal() {
    restore_test_hook before-restore-journal-delete || return 1
    assert_cleanup_phase || return 1
    validate_restore_transaction || return 1
    rm -rf -- "$RESTORE_TXN" || return 1
    restore_test_hook after-restore-journal-delete || return 1
}

rollback_restore_transaction() {
    local rollback_status=0
    validate_restore_paths
    if [[ ! -d "$RESTORE_TXN" ]]; then
        if [[ -n "$RESTORE_TXN_TEMP" \
            && ( -e "$RESTORE_TXN_TEMP" || -L "$RESTORE_TXN_TEMP" ) ]]
        then
            [[ -d "$RESTORE_TXN_TEMP" && ! -L "$RESTORE_TXN_TEMP" \
                && -O "$RESTORE_TXN_TEMP" \
                && "$(stat -f %Lp "$RESTORE_TXN_TEMP")" == 700 ]] \
                || return 1
            restore_test_hook before-temporary-journal-delete || return 1
            [[ -d "$RESTORE_TXN_TEMP" && ! -L "$RESTORE_TXN_TEMP" \
                && -O "$RESTORE_TXN_TEMP" \
                && "$(stat -f %Lp "$RESTORE_TXN_TEMP")" == 700 ]] || return 1
            rm -rf -- "$RESTORE_TXN_TEMP" || return 1
            restore_test_hook after-temporary-journal-delete || return 1
        fi
        return 0
    fi
    remove_restore_journal_orphans
    if verify_pre_restore_state; then
        restore_test_hook before-rollback-verified-marker || return 1
        write_restore_phase rollback-verified || return 1
        restore_test_hook after-rollback-verified-marker || return 1
        cleanup_restore_auxiliary_state || return 1
        remove_restore_journal || return 1
        return 0
    fi
    install_directory_rollback "$APP_DATA" "$RESTORE_APP_ROLLBACK" \
        "$RESTORE_APP_ROLLBACK_INSTALL" "$RESTORE_APP_INSTALLED" application-support \
        || rollback_status=1
    install_directory_rollback "$WORKSPACE" "$RESTORE_WORKSPACE_ROLLBACK" \
        "$RESTORE_WORKSPACE_ROLLBACK_INSTALL" "$RESTORE_WORKSPACE_INSTALLED" workspace \
        || rollback_status=1
    rollback_restore_preferences || rollback_status=1
    verify_pre_restore_state || rollback_status=1
    if [[ $rollback_status -eq 0 ]]; then
        restore_test_hook before-rollback-verified-marker || return 1
        write_restore_phase rollback-verified || return 1
        restore_test_hook after-rollback-verified-marker || return 1
        cleanup_restore_auxiliary_state || return 1
        remove_restore_journal || return 1
    elif restore_desired_after_failed_rollback; then
        echo "Smoke-state error: rollback failed; verified restored backup remains live and journaled" >&2
    else
        echo "Smoke-state error: rollback and verified roll-forward both failed; journal retained" >&2
    fi
    return "$rollback_status"
}

restore_transaction_exit() {
    local status="$?"
    trap - EXIT INT TERM HUP
    if [[ "$RESTORE_ARMED" == "1" && "$RESTORE_COMMITTED" != "1" ]]; then
        if ! rollback_restore_transaction; then
            echo "Smoke-state error: restore transaction rollback did not complete" >&2
        fi
    fi
    exit "$status"
}

restore_transaction_signal() {
    exit "$1"
}

arm_restore_transaction() {
    RESTORE_ARMED=1
    RESTORE_COMMITTED=0
    trap restore_transaction_exit EXIT
    trap 'restore_transaction_signal 130' INT
    trap 'restore_transaction_signal 143' TERM
    trap 'restore_transaction_signal 129' HUP
}

disarm_restore_transaction() {
    RESTORE_ARMED=0
    trap - EXIT INT TERM HUP
}

verify_restored_state() {
    if [[ -f "$SESSION/application-support.present" ]]; then
        verify_exact_restored_tree "$SESSION/application-support" "$APP_DATA" \
            application-support || return 1
    else
        [[ ! -e "$APP_DATA" && ! -L "$APP_DATA" ]] \
            || return 1
    fi
    if [[ -f "$SESSION/workspace.present" ]]; then
        verify_exact_restored_tree "$SESSION/workspace" "$WORKSPACE" workspace \
            || return 1
    else
        [[ ! -e "$WORKSPACE" && ! -L "$WORKSPACE" ]] || return 1
    fi
    if [[ -f "$SESSION/preferences.present" ]]; then
        defaults export "$PREFERENCES_DOMAIN" "$RESTORE_TXN/preferences.live.plist" >/dev/null \
            || return 1
        chmod 600 "$RESTORE_TXN/preferences.live.plist" || return 1
        [[ -f "$RESTORE_TXN/preferences.live.plist" \
            && ! -L "$RESTORE_TXN/preferences.live.plist" \
            && -O "$RESTORE_TXN/preferences.live.plist" ]] || return 1
        normalize_preferences \
            "$RESTORE_TXN/preferences.live.plist" \
            "$RESTORE_TXN/preferences.live.normalized.plist" || return 1
        chmod 600 "$RESTORE_TXN/preferences.live.normalized.plist" || return 1
        [[ -f "$RESTORE_TXN/preferences.live.normalized.plist" \
            && ! -L "$RESTORE_TXN/preferences.live.normalized.plist" \
            && -O "$RESTORE_TXN/preferences.live.normalized.plist" ]] || return 1
        diff -u "$SESSION/preferences.normalized.plist" \
            "$RESTORE_TXN/preferences.live.normalized.plist" >/dev/null || return 1
    else
        if defaults export "$PREFERENCES_DOMAIN" "$RESTORE_TXN/preferences.unexpected.plist" \
            >/dev/null 2>&1
        then
            return 1
        fi
        if [[ -e "$RESTORE_TXN/preferences.unexpected.plist" \
            || -L "$RESTORE_TXN/preferences.unexpected.plist" ]]
        then
            [[ -f "$RESTORE_TXN/preferences.unexpected.plist" \
                && ! -L "$RESTORE_TXN/preferences.unexpected.plist" \
                && -O "$RESTORE_TXN/preferences.unexpected.plist" \
                && "$(stat -f %Lp "$RESTORE_TXN/preferences.unexpected.plist")" == 600 ]] \
                || return 1
            rm -f -- "$RESTORE_TXN/preferences.unexpected.plist" || return 1
        fi
    fi
}

backup() {
    quit_app
    assert_managed_surface_safe "$APP_DATA"
    assert_managed_surface_safe "$WORKSPACE"
    create_backup_session
    local session="$BACKUP_SESSION"
    uuidgen > "$session/.session-marker"
    chmod 600 "$session/.session-marker"
    mkdir "$session/snapshots"
    chmod 700 "$session/snapshots"

    if [[ -e "$APP_DATA" || -L "$APP_DATA" ]]; then
        copy_tree "$APP_DATA" "$session/application-support"
        : > "$session/application-support.present"
        chmod 600 "$session/application-support.present"
    else
        : > "$session/application-support.absent"
        chmod 600 "$session/application-support.absent"
    fi

    if [[ -e "$WORKSPACE" || -L "$WORKSPACE" ]]; then
        copy_tree "$WORKSPACE" "$session/workspace"
        : > "$session/workspace.present"
        chmod 600 "$session/workspace.present"
    else
        : > "$session/workspace.absent"
        chmod 600 "$session/workspace.absent"
    fi

    if defaults export "$PREFERENCES_DOMAIN" "$session/preferences.plist" \
        >/dev/null 2>&1
    then
        normalize_preferences \
            "$session/preferences.plist" \
            "$session/preferences.normalized.plist"
        : > "$session/preferences.present"
        chmod 600 "$session/preferences.plist" "$session/preferences.normalized.plist" \
            "$session/preferences.present"
    else
        rm -f -- "$session/preferences.plist"
        : > "$session/preferences.absent"
        chmod 600 "$session/preferences.absent"
    fi

    write_session_binding "$session"

    backup_transaction_complete
    printf '%s\n' "$session"
}

remove_live_state() {
    assert_managed_surface_safe "$APP_DATA"
    assert_managed_surface_safe "$WORKSPACE"
    rm -rf -- "$APP_DATA"
    rm -rf -- "$WORKSPACE"
    defaults delete "$PREFERENCES_DOMAIN" >/dev/null 2>&1 || true
}

install_workspace_and_preferences() {
    mkdir -p "$WORKSPACE"
    cat > "$WORKSPACE/main.swift" <<'SWIFT'
import Foundation

print("SwiftTutor Apprentice deterministic smoke workspace")
SWIFT

    defaults delete "$PREFERENCES_DOMAIN" >/dev/null 2>&1 || true
    defaults write "$PREFERENCES_DOMAIN" aiEnabled -bool false
    defaults write "$PREFERENCES_DOMAIN" aiCommand -string "claude"
    defaults write "$PREFERENCES_DOMAIN" aiProvider -string "cli"
    defaults write "$PREFERENCES_DOMAIN" apiKey -string ""
    defaults write "$PREFERENCES_DOMAIN" apiModel -string "claude-opus-4-8"
    defaults write "$PREFERENCES_DOMAIN" hasSeenWelcome -bool true
}

install_fixture_state() {
    local mode="$1"
    quit_app
    remove_live_state
    install_workspace_and_preferences
    mkdir -p "$APP_DATA"

    case "$mode" in
        legacy)
            cp "$PROJECT_ROOT/Tests/SwiftTutorApprenticeTests/Fixtures/legacy-progress.json" \
                "$APP_DATA/progress.json"
            cp "$PROJECT_ROOT/Tests/SwiftTutorApprenticeTests/Fixtures/legacy-lessons.json" \
                "$APP_DATA/lessons.json"
            ;;
        future-progress)
            cp "$PROJECT_ROOT/Tests/SwiftTutorApprenticeTests/Fixtures/future-progress.json" \
                "$APP_DATA/progress.json"
            ;;
        future-lessons)
            cp "$PROJECT_ROOT/Tests/SwiftTutorApprenticeTests/Fixtures/future-presentation-lessons.json" \
                "$APP_DATA/lessons.json"
            ;;
        corrupt-progress)
            cp "$PROJECT_ROOT/Tests/SwiftTutorApprenticeTests/Fixtures/corrupt-version-3-progress.json" \
                "$APP_DATA/progress.json"
            ;;
        *)
            fail "unknown fixture mode $mode"
            ;;
    esac
}

validate_label() {
    local label="$1"
    [[ ${#label} -ge 1 && ${#label} -le 64 ]] \
        || fail "snapshot label must be 1-64 characters"
    [[ "$label" =~ ^[A-Za-z0-9]([A-Za-z0-9_-]*[A-Za-z0-9])?$ ]] \
        || fail "snapshot label must use ASCII alphanumerics with internal hyphens or underscores"
}

validate_snapshot_directory() {
    local session="$1" requested session_real snapshot_real
    requested="$session/snapshots"
    [[ "$session" == /* && -d "$session" && ! -L "$session" ]] \
        || fail "snapshot directory session is missing or unsafe"
    session_real="$(cd "$session" && pwd -P)"
    [[ -d "$requested" && ! -L "$requested" ]] \
        || fail "snapshot directory is missing or unsafe"
    snapshot_real="$(cd "$requested" && pwd -P)"
    [[ "$snapshot_real" == "$session_real/snapshots" ]] \
        || fail "snapshot directory is outside the session"
    [[ -O "$snapshot_real" && -r "$snapshot_real" && -w "$snapshot_real" && -x "$snapshot_real" ]] \
        || fail "snapshot directory must be owned and accessible by the current user"
    [[ "$(stat -f %Lp "$snapshot_real")" == "700" ]] \
        || fail "snapshot directory permissions must be 700"
    SNAPSHOT_DIRECTORY="$snapshot_real"
}

validate_app_state_file() {
    local requested="$1"
    [[ "$requested" == /* ]] || fail "app-state file path must be absolute"
    [[ -d "$APP_DATA" && ! -L "$APP_DATA" ]] || fail "Application Support directory is missing or unsafe"
    [[ -f "$requested" && ! -L "$requested" ]] || fail "app-state target must be a regular non-symlink file"

    local data_real file_real relative component current
    data_real="$(cd "$APP_DATA" && pwd -P)"
    file_real="$(cd "$(dirname "$requested")" && pwd -P)/$(basename "$requested")"
    [[ "$file_real" == "$data_real/"* ]] || fail "app-state file is outside Application Support"

    relative="${requested#"$APP_DATA"/}"
    [[ "$relative" != "$requested" && "$relative" != *".."* ]] \
        || fail "app-state file path contains traversal"
    current="$APP_DATA"
    IFS='/' read -r -a components <<< "$relative"
    for component in "${components[@]}"; do
        [[ -n "$component" && "$component" != "." && "$component" != ".." ]] \
            || fail "app-state file path contains an unsafe component"
        current="$current/$component"
        [[ ! -L "$current" ]] || fail "app-state file path contains a symlink"
    done
    APP_STATE_FILE="$file_real"
}

snapshot() {
    local label="$1" requested="$2"
    validate_label "$label"
    validate_snapshot_directory "$SESSION"
    quit_app
    validate_app_state_file "$requested"
    local destination="$SNAPSHOT_DIRECTORY/$label.sha256"
    [[ ! -e "$destination" && ! -L "$destination" ]] \
        || fail "snapshot label already exists"
    shasum -a 256 "$APP_STATE_FILE" | awk '{print $1}' > "$destination"
    chmod 600 "$destination"
}

assert_unchanged() {
    local label="$1" requested="$2"
    validate_label "$label"
    validate_snapshot_directory "$SESSION"
    quit_app
    validate_app_state_file "$requested"
    local expected="$SNAPSHOT_DIRECTORY/$label.sha256"
    [[ -f "$expected" && ! -L "$expected" && -O "$expected" ]] \
        || fail "snapshot is missing or unsafe"
    [[ "$(stat -f %Lp "$expected")" == 600 ]] \
        || fail "snapshot digest permissions or owner are unsafe"
    local actual
    actual="$(shasum -a 256 "$APP_STATE_FILE" | awk '{print $1}')"
    [[ "$actual" == "$(<"$expected")" ]] || fail "$APP_STATE_FILE changed"
}

restore() {
    quit_app
    assert_managed_surface_safe "$APP_DATA"
    assert_managed_surface_safe "$WORKSPACE"
    mkdir -p "$(dirname "$APP_DATA")" "$(dirname "$WORKSPACE")"
    assert_managed_surface_safe "$APP_DATA"
    assert_managed_surface_safe "$WORKSPACE"
    RESTORE_TXN="$SESSION/restore-transaction"
    validate_restore_paths

    if [[ -e "$RESTORE_TXN" || -L "$RESTORE_TXN" ]]; then
        validate_restore_transaction
        if [[ "$(<"$RESTORE_TXN/phase")" == committed \
            || "$(<"$RESTORE_TXN/phase")" == rollback-failed-desired-restored ]]
        then
            RESTORE_COMMITTED=1
            verify_restored_state
            restore_test_hook cleanup || fail "restore cleanup hook failed"
            cleanup_restore_auxiliary_state || fail "restore auxiliary cleanup failed"
            remove_restore_journal || fail "restore journal cleanup failed"
            restore_test_hook before-session-delete || fail "restore session cleanup hook failed"
            validate_session "$SESSION"
            rm -rf -- "$SESSION" || fail "restore session cleanup failed"
            restore_test_hook after-session-delete || fail "restore session cleanup hook failed"
            return
        fi
        if [[ "$(<"$RESTORE_TXN/phase")" == rollback-verified ]]; then
            verify_pre_restore_state \
                || fail "verified rollback state no longer matches its journal"
            cleanup_restore_auxiliary_state || fail "rollback auxiliary cleanup failed"
            remove_restore_journal || fail "rollback journal cleanup failed"
        else
        rollback_restore_transaction \
            || fail "could not recover the interrupted restore transaction"
        fi
    fi

    [[ ! -e "$RESTORE_APP_STAGE" && ! -L "$RESTORE_APP_STAGE" ]] \
        || fail "stale Application Support restore staging path exists"
    [[ ! -e "$RESTORE_APP_ROLLBACK" && ! -L "$RESTORE_APP_ROLLBACK" ]] \
        || fail "stale Application Support rollback path exists"
    [[ ! -e "$RESTORE_APP_DISPLACED" && ! -L "$RESTORE_APP_DISPLACED" ]] \
        || fail "stale Application Support displaced path exists"
    [[ ! -e "$RESTORE_APP_ROLLBACK_INSTALL" && ! -L "$RESTORE_APP_ROLLBACK_INSTALL" ]] \
        || fail "stale Application Support rollback install path exists"
    [[ ! -e "$RESTORE_APP_INSTALLED" && ! -L "$RESTORE_APP_INSTALLED" ]] \
        || fail "stale Application Support installed path exists"
    [[ ! -e "$RESTORE_WORKSPACE_STAGE" && ! -L "$RESTORE_WORKSPACE_STAGE" ]] \
        || fail "stale workspace restore staging path exists"
    [[ ! -e "$RESTORE_WORKSPACE_ROLLBACK" && ! -L "$RESTORE_WORKSPACE_ROLLBACK" ]] \
        || fail "stale workspace rollback path exists"
    [[ ! -e "$RESTORE_WORKSPACE_DISPLACED" && ! -L "$RESTORE_WORKSPACE_DISPLACED" ]] \
        || fail "stale workspace displaced path exists"
    [[ ! -e "$RESTORE_WORKSPACE_ROLLBACK_INSTALL" \
        && ! -L "$RESTORE_WORKSPACE_ROLLBACK_INSTALL" ]] \
        || fail "stale workspace rollback install path exists"
    [[ ! -e "$RESTORE_WORKSPACE_INSTALLED" && ! -L "$RESTORE_WORKSPACE_INSTALLED" ]] \
        || fail "stale workspace installed path exists"

    arm_restore_transaction
    initialize_restore_transaction

    stage_restore_directory "$SESSION/application-support" "$RESTORE_APP_STAGE" \
        application-support stage-application-support
    stage_restore_directory "$SESSION/workspace" "$RESTORE_WORKSPACE_STAGE" \
        workspace stage-workspace
    capture_directory_rollback "$APP_DATA" "$RESTORE_APP_ROLLBACK" application-support
    capture_directory_rollback "$WORKSPACE" "$RESTORE_WORKSPACE_ROLLBACK" workspace
    capture_preferences_rollback

    install_restore_directory "$APP_DATA" "$RESTORE_APP_STAGE" \
        "$RESTORE_APP_DISPLACED" application-support after-application-support-swap
    install_restore_directory "$WORKSPACE" "$RESTORE_WORKSPACE_STAGE" \
        "$RESTORE_WORKSPACE_DISPLACED" workspace after-workspace-swap

    restore_test_hook before-preferences-marker
    mark_restore_state preferences.changed
    restore_test_hook after-preferences-marker
    write_restore_phase installing-preferences || return 1
    restore_test_hook before-preferences-apply
    if [[ -f "$SESSION/preferences.present" ]]; then
        replace_preferences_from "$SESSION/preferences.plist"
    else
        [[ -f "$SESSION/preferences.absent" ]] || fail "preferences backup state is missing"
        defaults delete "$PREFERENCES_DOMAIN" >/dev/null 2>&1 || true
    fi
    restore_test_hook after-preferences-apply
    restore_test_hook preferences-apply

    write_restore_phase verifying || return 1
    restore_test_hook verification
    verify_restored_state
    restore_test_hook before-committed-marker
    write_restore_phase committed || return 1
    RESTORE_COMMITTED=1
    restore_test_hook after-committed-marker

    restore_test_hook before-cleanup
    restore_test_hook cleanup || fail "restore cleanup hook failed"
    cleanup_restore_auxiliary_state || fail "restore auxiliary cleanup failed"
    restore_test_hook after-cleanup
    remove_restore_journal || fail "restore journal cleanup failed"
    disarm_restore_transaction
    restore_test_hook before-session-delete || fail "restore session cleanup hook failed"
    validate_session "$SESSION"
    rm -rf -- "$SESSION" || fail "restore session cleanup failed"
    restore_test_hook after-session-delete || fail "restore session cleanup hook failed"
}

main() {
    local command_name="${1:-}"
    case "$command_name" in
        backup)
            [[ $# -eq 1 ]] || usage
            backup
            ;;
        clean|legacy|future-progress|future-lessons|corrupt-progress)
            [[ $# -eq 2 ]] || usage
            validate_session "$2"
            if [[ "$command_name" == "clean" ]]; then
                quit_app
                remove_live_state
            else
                install_fixture_state "$command_name"
            fi
            ;;
        snapshot|assert-unchanged)
            [[ $# -eq 4 ]] || usage
            validate_session "$2"
            if [[ "$command_name" == "snapshot" ]]; then
                snapshot "$4" "$3"
            else
                assert_unchanged "$4" "$3"
            fi
            ;;
        restore)
            [[ $# -eq 2 ]] || usage
            validate_session "$2"
            restore
            ;;
        *)
            usage
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
