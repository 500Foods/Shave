#!/usr/bin/env bash
# Test 0004: Shellcheck analysis
#
# CHANGELOG
# 1.2.0 - 2026-08-18 - Per-file last-result cache under ~/.cache/Shave/0004
# 1.1.0 - 2026-08-18 - Fail on warning/error only, not style notes
# 1.0.0 - 2026-08-18 - Initial shellcheck suite

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"

# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/harness.sh"
# shellcheck source=../lib/lint.sh
# shellcheck disable=SC1091
# Justification: lint helper path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/lint.sh"

shave_shellcheck_one() {
    local file="$1"
    local content_hash="$2"
    local cache_file
    cache_file="$(shave_lint_cache_file "${SHAVE_SHELLCHECK_CACHE_DIR}" "${file}" "${content_hash}")"
    shave_lint_prune_old_cache "${cache_file}"
    shellcheck -e SC1091 -f gcc "${file}" > "${cache_file}" 2>&1 || true
    cat "${cache_file}"
}

shave_test_init "0004" "shellcheck"

cd "${REPO_ROOT}" || exit 1

if ! command -v shellcheck >/dev/null 2>&1; then
    shave_skip "shellcheck is not installed"
    shave_test_finish
    exit $?
fi
shave_pass "shellcheck is available"

mapfile -t SHELL_FILES < <(shave_list_files ".lintignore" -name '*.sh')
if [[ ${#SHELL_FILES[@]} -eq 0 ]]; then
    shave_pass "no shell files to check"
    shave_test_finish
    exit $?
fi
shave_pass "discovered ${#SHELL_FILES[@]} shell files"

cores="$(nproc 2>/dev/null || echo 1)"
CACHE_DIR=""
CACHE_DIR="$(shave_lint_cache_dir "0004")"
cache_key=""
cache_key="$( {
    shellcheck --version 2>/dev/null || true
    printf 'flags:-e SC1091 -f gcc\n'
} | md5sum | awk '{print $1}')"
shave_lint_cache_reset_if_stale "${CACHE_DIR}" "${cache_key}"

declare -A file_hashes=()
while read -r hash file; do
    file_hashes["${file}"]="${hash}"
done < <(shave_lint_hash_files "${SHELL_FILES[@]}")

cached_files=0
to_process=()
temp_output=""
temp_output="$(mktemp)"
for file in "${SHELL_FILES[@]}"; do
    content_hash="${file_hashes[${file}]}"
    cache_file=""
    cache_file="$(shave_lint_cache_file "${CACHE_DIR}" "${file}" "${content_hash}")"
    if [[ -f "${cache_file}" ]]; then
        cached_files=$((cached_files + 1))
        cat "${cache_file}" >> "${temp_output}"
    else
        to_process+=("${file}")
    fi
done

printf 'using cached results for %s of %s files\n' "${cached_files}" "${#SHELL_FILES[@]}"
printf 'running shellcheck on %s / %s files\n' "${#to_process[@]}" "${#SHELL_FILES[@]}"

export -f shave_shellcheck_one
export -f shave_lint_cache_file
export -f shave_lint_prune_old_cache
export SHAVE_SHELLCHECK_CACHE_DIR="${CACHE_DIR}"

if [[ ${#to_process[@]} -gt 0 ]]; then
    for file in "${to_process[@]}"; do
        printf '%s %s\n' "${file}" "${file_hashes[${file}]}"
    done | xargs -n 2 -P "${cores}" bash -c 'shave_shellcheck_one "$0" "$1"' >> "${temp_output}" 2>&1
fi

issue_count=0
if [[ -s "${temp_output}" ]]; then
    grep -E ': (error|warning):' "${temp_output}" > "${temp_output}.issues" || true
    if [[ -s "${temp_output}.issues" ]]; then
        issue_count="$(wc -l < "${temp_output}.issues")"
        issue_count="${issue_count// /}"
        cat "${temp_output}.issues"
    fi
    rm -f "${temp_output}.issues"
fi
rm -f "${temp_output}"

if [[ ! "${issue_count}" =~ ^[0-9]+$ ]]; then
    issue_count=0
fi

if [[ "${issue_count}" -eq 0 ]]; then
    shave_pass "shellcheck found no issues in ${#SHELL_FILES[@]} files"
else
    shave_fail "shellcheck found ${issue_count} issue(s) in ${#SHELL_FILES[@]} files"
fi

shave_test_finish
exit $?
