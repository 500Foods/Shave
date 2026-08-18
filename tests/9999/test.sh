#!/usr/bin/env bash
# Test 9999: CLOC summary
# Runs last and prints a tables-formatted cloc report
#
# CHANGELOG
# 1.0.0 - 2026-08-18 - Initial end-of-suite cloc table

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
LOG_DIR="${TESTS_DIR}/logs/9999"

# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/harness.sh"
# shellcheck source=../lib/cloc.sh
# shellcheck disable=SC1091
# Justification: cloc helper path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/cloc.sh"

shave_test_init "9999" "cloc"

cd "${REPO_ROOT}" || exit 1

if ! command -v cloc >/dev/null 2>&1; then
    shave_skip "cloc is not installed"
    shave_test_finish
    exit $?
fi
shave_pass "cloc is available"
shave_assert_cmd tables "tables is available"
shave_assert_cmd jq "jq is available"

mkdir -p "${LOG_DIR}"
table_file="${LOG_DIR}/cloc.table"
if shave_cloc_render "${REPO_ROOT}" "${table_file}" "${REPO_ROOT}/.lintignore"; then
    shave_assert_file "${table_file}" "cloc table was written"
    if [[ -s "${table_file}" ]]; then
        shave_pass "cloc table is non-empty"
        cat "${table_file}"
    else
        shave_fail "cloc table is empty"
    fi
else
    shave_fail "cloc table generation failed"
fi

shave_test_finish
exit $?
