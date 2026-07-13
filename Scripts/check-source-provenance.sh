#!/bin/bash

provenance_fail() {
    echo "Source provenance check failed: $*" >&2
    return 1
}

assert_clean_source_provenance() {
    local repo_root="$1"
    local staged_paths
    local unstaged_paths
    local untracked_inputs
    local failed=0

    if ! git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        provenance_fail "$repo_root is not a Git working tree"
        return 1
    fi

    if ! staged_paths="$(git -C "$repo_root" diff --cached --name-only --diff-filter=ACDMRTUXB --)"; then
        provenance_fail "could not inspect tracked staged changes in $repo_root"
        return 1
    fi
    if ! unstaged_paths="$(git -C "$repo_root" diff --name-only --diff-filter=ACDMRTUXB --)"; then
        provenance_fail "could not inspect tracked unstaged changes in $repo_root"
        return 1
    fi
    # Deliberately do not apply ignore rules here. A compiler-visible input is
    # provenance-relevant even when a local or global ignore pattern hides it.
    if ! untracked_inputs="$(git -C "$repo_root" ls-files --others -- \
        Package.swift Package.resolved Sources Resources/AppIcon.icns)"; then
        provenance_fail "could not inspect untracked build inputs in $repo_root"
        return 1
    fi

    if [[ -n "$staged_paths" ]]; then
        printf 'Source provenance check failed: tracked staged changes:\n%s\n' "$staged_paths" >&2
        failed=1
    fi
    if [[ -n "$unstaged_paths" ]]; then
        printf 'Source provenance check failed: tracked unstaged changes:\n%s\n' "$unstaged_paths" >&2
        failed=1
    fi
    if [[ -n "$untracked_inputs" ]]; then
        printf 'Source provenance check failed: untracked build inputs:\n%s\n' "$untracked_inputs" >&2
        failed=1
    fi

    (( failed == 0 )) || return 1
}

require_clean_manifest_provenance() {
    local manifest="$1"
    local source_working_tree_state

    source_working_tree_state="$(/usr/libexec/PlistBuddy \
        -c 'Print :SourceWorkingTreeState' "$manifest" 2>/dev/null)" \
        || provenance_fail "SourceWorkingTreeState is missing from $manifest"
    [[ "$source_working_tree_state" == "clean" ]] \
        || provenance_fail "SourceWorkingTreeState must be exactly clean, found $source_working_tree_state"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    if (( $# > 1 )); then
        echo "Usage: $0 [repo-root]" >&2
        exit 2
    fi
    if (( $# == 1 )); then
        repo_root="$1"
    else
        repo_root="$(cd "$(dirname "$0")/.." && pwd)"
    fi
    assert_clean_source_provenance "$repo_root"
fi
