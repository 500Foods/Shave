#!/usr/bin/env bash
# Test 0003: Cppcheck C analysis
#
# CHANGELOG
# 1.1.0 - 2026-08-18 - Per-file last-result cache under ~/.cache/Shave/0003
# 1.0.0 - 2026-08-18 - Initial cppcheck suite

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

shave_test_init "0003" "cppcheck"

cd "${REPO_ROOT}" || exit 1

if ! command -v cppcheck >/dev/null 2>&1; then
    shave_skip "cppcheck is not installed"
    shave_test_finish
    exit $?
fi
shave_pass "cppcheck is available"
shave_assert_file ".lintignore-c" ".lintignore-c exists"

mapfile -t C_FILES < <(shave_list_files ".lintignore" \( -name '*.c' -o -name '*.h' -o -name '*.inc' \))
if [[ ${#C_FILES[@]} -eq 0 ]]; then
    shave_pass "no C files to check"
    shave_test_finish
    exit $?
fi
shave_pass "discovered ${#C_FILES[@]} C/H files"

cppcheck_args=()
while IFS='=' read -r key value; do
    case "${key}" in
        enable) cppcheck_args+=("--enable=${value}") ;;
        include)
            if [[ -e "${value}" ]]; then
                cppcheck_args+=("--include=${value}")
            fi
            ;;
        check-level) cppcheck_args+=("--check-level=${value}") ;;
        template) cppcheck_args+=("--template=${value}") ;;
        option) cppcheck_args+=("${value}") ;;
        suppress) cppcheck_args+=("--suppress=${value}") ;;
        define) cppcheck_args+=("-D${value}") ;;
    esac
done < <(grep -v '^#' ".lintignore-c" | grep '=' || true)

cores="$(nproc 2>/dev/null || echo 1)"
CACHE_DIR=""
CACHE_DIR="$(shave_lint_cache_dir "0003")"
cache_key=""
cache_key="$( {
    cppcheck --version 2>/dev/null || true
    printf 'args:%s\n' "${cppcheck_args[*]}"
    cat ".lintignore-c"
} | md5sum | awk '{print $1}')"
shave_lint_cache_reset_if_stale "${CACHE_DIR}" "${cache_key}"
BUILD_DIR="${CACHE_DIR}/build"
mkdir -p "${BUILD_DIR}"

declare -A file_hashes=()
while read -r hash file; do
    file_hashes["${file}"]="${hash}"
done < <(shave_lint_hash_files "${C_FILES[@]}")

cached_files=0
to_process=()
header_changed=0
for file in "${C_FILES[@]}"; do
    content_hash="${file_hashes[${file}]}"
    cache_file=""
    cache_file="$(shave_lint_cache_file "${CACHE_DIR}" "${file}" "${content_hash}")"
    if [[ -f "${cache_file}" ]]; then
        cached_files=$((cached_files + 1))
    else
        to_process+=("${file}")
        case "${file}" in
            *.h|*.inc) header_changed=1 ;;
        esac
    fi
done

if [[ "${header_changed}" -eq 1 && ${#to_process[@]} -lt ${#C_FILES[@]} ]]; then
    to_process=("${C_FILES[@]}")
    cached_files=0
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
fi

printf 'using cached results for %s of %s files\n' "${cached_files}" "${#C_FILES[@]}"
printf 'running cppcheck on %s / %s files\n' "${#to_process[@]}" "${#C_FILES[@]}"

if [[ ${#to_process[@]} -gt 0 ]]; then
    fresh_output=""
    fresh_output="$(cppcheck -j"${cores}" --cppcheck-build-dir="${BUILD_DIR}" "${cppcheck_args[@]}" "${to_process[@]}" 2>&1 || true)"
    fresh_output="$(printf '%s\n' "${fresh_output}" | grep -v '^cppcheck: info:' || true)"

    for file in "${to_process[@]}"; do
        content_hash="${file_hashes[${file}]}"
        cache_file=""
        cache_file="$(shave_lint_cache_file "${CACHE_DIR}" "${file}" "${content_hash}")"
        shave_lint_prune_old_cache "${cache_file}"
        rel_file="${file#./}"
        : > "${cache_file}"
        if [[ -n "${fresh_output}" ]]; then
            while IFS= read -r line; do
                if [[ "${line}" == "${file}:"* || "${line}" == "${rel_file}:"* ]]; then
                    printf '%s\n' "${line}" >> "${cache_file}"
                fi
            done <<< "${fresh_output}"
        fi
    done
fi

combined_output=""
for file in "${C_FILES[@]}"; do
    content_hash="${file_hashes[${file}]}"
    cache_file=""
    cache_file="$(shave_lint_cache_file "${CACHE_DIR}" "${file}" "${content_hash}")"
    if [[ -s "${cache_file}" ]]; then
        combined_output+="$(cat "${cache_file}")"$'\n'
    fi
done

if [[ -n "${combined_output}" ]]; then
    printf '%s' "${combined_output}"
fi

issue_count=0
if [[ -n "${combined_output}" ]]; then
    issue_count="$(printf '%s' "${combined_output}" | grep -cE ':[0-9]+:' || true)"
fi
if [[ ! "${issue_count}" =~ ^[0-9]+$ ]]; then
    issue_count=0
fi

if [[ "${issue_count}" -eq 0 ]]; then
    shave_pass "cppcheck found no issues in ${#C_FILES[@]} files"
else
    shave_fail "cppcheck found ${issue_count} issue(s) in ${#C_FILES[@]} files"
fi

shave_test_finish
exit $?
