#!/usr/bin/env bash
# Test 0001: CLI missing input
#
# CHANGELOG
# 1.1.0 - 2026-08-18 - Drop hello-world bash run; keep durable CLI contract
# 1.0.0 - 2026-08-18 - Initial bash comparison and CLI smoke test

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$TEST_DIR/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "$TESTS_DIR/lib/harness.sh"

shave_test_init "0001" "cli_missing_input"

SHAVE_SH="$REPO_ROOT/shave/shave.sh"
shave_assert_file "$SHAVE_SH" "shave.sh exists"
shave_assert_exec "$SHAVE_SH" "shave.sh is executable"

missing_out=""
missing_status=0
missing_out="$("$SHAVE_SH" 2>&1)" || missing_status=$?
if [[ "$missing_status" -ne 0 ]]; then
    shave_pass "shave.sh with no input exits non-zero"
else
    shave_fail "shave.sh with no input should fail"
fi
shave_assert_contains "$missing_out" "No input Bash script provided" "missing input reports a clear error"

shave_test_finish
exit $?
