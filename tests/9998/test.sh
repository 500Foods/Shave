#!/usr/bin/env bash
# Test 9998: Coverage
# Runs after the parallel suites and prints a tables-formatted gcov report
#
# CHANGELOG
# 1.0.1 - 2026-08-18 - Drop gcov-tool; union per-suite gcov JSON
# 1.0.0 - 2026-08-18 - Initial end-of-suite shave-libs gcov table

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
LOG_DIR="${TESTS_DIR}/logs/9998"

# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/harness.sh"
# shellcheck source=../lib/coverage.sh
# shellcheck disable=SC1091
# Justification: coverage helper path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/coverage.sh"

shave_test_init "9998" "coverage"

cd "${REPO_ROOT}" || exit 1

if ! command -v gcov >/dev/null 2>&1; then
    shave_skip "gcov is not installed"
    shave_test_finish
    exit $?
fi
shave_pass "gcov is available"
shave_assert_cmd tables "tables is available"
shave_assert_cmd jq "jq is available"

mkdir -p "${LOG_DIR}"
table_file="${LOG_DIR}/coverage.table"
results_file="${LOG_DIR}/coverage.results"
render_status=0
shave_coverage_render "${REPO_ROOT}" "${table_file}" "${TESTS_DIR}/logs" "${REPO_ROOT}/build" || render_status=$?

if [[ "${render_status}" -eq 1 ]]; then
    shave_fail "coverage table generation failed"
    shave_test_finish
    exit $?
fi

shave_assert_file "${table_file}" "coverage table was written"
if [[ -s "${table_file}" ]]; then
    shave_pass "coverage table is non-empty"
    cat "${table_file}"
else
    shave_fail "coverage table is empty"
fi

if [[ ! -s "${results_file}" ]]; then
    shave_fail "coverage results are missing"
    shave_test_finish
    exit $?
fi

while IFS='|' read -r file total hit pct status; do
    [[ -n "${file}" ]] || continue
    if [[ "${status}" == "PASS" ]]; then
        shave_pass "${file} coverage ${pct}% (${hit}/${total})"
    else
        shave_fail "${file} coverage ${pct}% (${hit}/${total}) is below ${SHAVE_COVERAGE_MIN:-50}%"
    fi
done < "${results_file}"

shave_test_finish
exit $?
