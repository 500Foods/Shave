#!/usr/bin/env bash
# Test 0002: Unity version parser
#
# CHANGELOG
# 1.0.0 - 2026-08-18 - Initial Unity test for version parsing

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"

# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/harness.sh"

shave_test_init "0002" "unity_version"

UNITY_BIN="${REPO_ROOT}/build/tests/test_version"
shave_assert_file "${UNITY_BIN}" "Unity test binary exists"
shave_assert_exec "${UNITY_BIN}" "Unity test binary is executable"

if [[ -x "${UNITY_BIN}" ]]; then
    shave_run_unity "${UNITY_BIN}"
fi

shave_test_finish
exit $?
