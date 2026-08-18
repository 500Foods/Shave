#!/usr/bin/env bash
# Shared lint helpers for numbered test suites
#
# CHANGELOG
# 1.1.0 - 2026-08-18 - Per-file last-result cache helpers for 0003/0004
# 1.0.0 - 2026-08-18 - Initial exclude-list and file discovery helpers

if [[ -n "${SHAVE_LINT_GUARD:-}" ]]; then
    return 0
fi
SHAVE_LINT_GUARD=1

shave_lint_patterns() {
    local ignore_file="${1:-.lintignore}"
    local pattern
    if [[ -f "${ignore_file}" ]]; then
        while IFS= read -r pattern; do
            pattern="${pattern%%#*}"
            pattern="${pattern#"${pattern%%[![:space:]]*}"}"
            pattern="${pattern%"${pattern##*[![:space:]]}"}"
            [[ -z "${pattern}" ]] && continue
            printf '%s\n' "${pattern%/\*}"
        done < "${ignore_file}"
    fi
}

shave_should_exclude() {
    local rel_file="${1#./}"
    local ignore_file="${2:-.lintignore}"
    local pattern
    while IFS= read -r pattern; do
        [[ -z "${pattern}" ]] && continue
        if [[ "${rel_file}" == "${pattern}" || "${rel_file}" == "${pattern}"/* ]]; then
            return 0
        fi
    done < <(shave_lint_patterns "${ignore_file}")
    return 1
}

shave_list_files() {
    local ignore_file="${1:-.lintignore}"
    shift
    local file
    while IFS= read -r file; do
        if ! shave_should_exclude "${file}" "${ignore_file}"; then
            printf '%s\n' "${file}"
        fi
    done < <(find . -type f "$@" | sort)
}

shave_lint_cache_dir() {
    local suite="$1"
    local root="${XDG_CACHE_HOME:-${HOME}/.cache}/Shave"
    local dir="${root}/${suite}"
    mkdir -p "${dir}"
    printf '%s\n' "${dir}"
}

shave_lint_cache_reset_if_stale() {
    local cache_dir="$1"
    local key="$2"
    local key_file="${cache_dir}/cache.key"
    if [[ -f "${key_file}" ]]; then
        if [[ "$(cat "${key_file}")" != "${key}" ]]; then
            find "${cache_dir}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
        fi
    fi
    printf '%s\n' "${key}" > "${key_file}"
}

shave_lint_cache_file() {
    local cache_dir="$1"
    local file="$2"
    local content_hash="$3"
    local flat_path
    flat_path="$(printf 'cache%s' "${file}" | tr '/' '_')"
    printf '%s/%s_%s\n' "${cache_dir}" "${flat_path}" "${content_hash}"
}

shave_lint_hash_files() {
    if [[ $# -eq 0 ]]; then
        return 0
    fi
    md5sum "$@"
}

shave_lint_prune_old_cache() {
    local cache_file="$1"
    local prefix="${cache_file%_*}_"
    local old
    for old in "${prefix}"*; do
        if [[ -f "${old}" && "${old}" != "${cache_file}" ]]; then
            rm -f "${old}"
        fi
    done
}
