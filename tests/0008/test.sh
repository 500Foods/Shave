#!/usr/bin/env bash
# Test 0008: Echo printf loop
#
# CHANGELOG
# 1.0.0 - 2026-08-18 - shave/shave a 5-iteration echo/printf loop and compare to Bash
#
# Runs shave/shave on tests/0008/echo-printf-loop.sh. That writes
# echo-printf-loop.c and the UPX-compressed echo-printf-loop binary beside
# the script. Compare the binary stdout to the script stdout. Generated C
# must walk the CST into a for-loop that calls both builtins.

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"

# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/harness.sh"

SHAVE_0008_WORK=""
shave_0008_cleanup() {
    if [[ -n "${SHAVE_0008_WORK}" && -d "${SHAVE_0008_WORK}" ]]; then
        rm -rf "${SHAVE_0008_WORK}"
    fi
}
trap shave_0008_cleanup EXIT

shave_test_init "0008" "echo_printf_loop"

SHAVE_BIN="${REPO_ROOT}/shave/shave"
FIXTURE_SH="${TEST_DIR}/echo-printf-loop.sh"
FIXTURE_C="${TEST_DIR}/echo-printf-loop.c"
FIXTURE_BIN="${TEST_DIR}/echo-printf-loop"

shave_assert_file "${SHAVE_BIN}" "shave/shave exists"
shave_assert_exec "${SHAVE_BIN}" "shave/shave is executable"
shave_assert_file "${FIXTURE_SH}" "echo-printf-loop.sh exists"
shave_assert_cmd tree-sitter "tree-sitter is available"

if [[ ! -x "${SHAVE_BIN}" || ! -f "${FIXTURE_SH}" ]]; then
    shave_test_finish
    exit $?
fi

export SHAVE_ROOT="${REPO_ROOT}"
export SHAVE_LIBDIR="${REPO_ROOT}/build"
export SHAVE_FORCE=1

shave_status=0
"${SHAVE_BIN}" "${FIXTURE_SH}" >/dev/null || shave_status=$?
shave_assert_status 0 "${shave_status}" "shave/shave echo-printf-loop.sh exits 0"
shave_assert_file "${FIXTURE_C}" "shave writes echo-printf-loop.c beside the script"
shave_assert_exec "${FIXTURE_BIN}" "shave writes echo-printf-loop beside the script"
if grep -q 'for (' "${FIXTURE_C}" 2>/dev/null; then
    shave_pass "generated C contains a for-loop"
else
    shave_fail "generated C does not contain a for-loop"
fi
if grep -q 'shave_echo_builtin(' "${FIXTURE_C}" 2>/dev/null; then
    shave_pass "generated C calls shave_echo_builtin"
else
    shave_fail "generated C does not call shave_echo_builtin"
fi
if grep -q 'shave_printf_builtin(' "${FIXTURE_C}" 2>/dev/null; then
    shave_pass "generated C calls shave_printf_builtin"
else
    shave_fail "generated C does not call shave_printf_builtin"
fi
if grep -q 'shave_set_var(' "${FIXTURE_C}" 2>/dev/null; then
    shave_pass "generated C sets the loop variable"
else
    shave_fail "generated C does not set the loop variable"
fi

if [[ ! -x "${FIXTURE_BIN}" ]]; then
    shave_test_finish
    exit $?
fi

SHAVE_0008_WORK="$(mktemp -d "${TMPDIR:-/tmp}/shave-0008.XXXXXX")"
if [[ ! -d "${SHAVE_0008_WORK}" ]]; then
    shave_fail "could not create 0008 work directory"
    shave_test_finish
    exit $?
fi
bash_out="${SHAVE_0008_WORK}/bash.out"
c_out="${SHAVE_0008_WORK}/c.out"
bash_err="${SHAVE_0008_WORK}/bash.err"
c_err="${SHAVE_0008_WORK}/c.err"

bash_status=0
bash "${FIXTURE_SH}" >"${bash_out}" 2>"${bash_err}" || bash_status=$?
shave_assert_status 0 "${bash_status}" "echo-printf-loop.sh exits 0"

c_status=0
"${FIXTURE_BIN}" >"${c_out}" 2>"${c_err}" || c_status=$?
shave_assert_status 0 "${c_status}" "echo-printf-loop exits 0"

bash_err_size=0
c_err_size=0
bash_err_size="$(wc -c < "${bash_err}")"
c_err_size="$(wc -c < "${c_err}")"
bash_err_size="${bash_err_size// /}"
c_err_size="${c_err_size// /}"
shave_assert_eq "0" "${bash_err_size}" "echo-printf-loop.sh writes no stderr"
shave_assert_eq "0" "${c_err_size}" "echo-printf-loop writes no stderr"

bash_size=0
c_size=0
bash_size="$(wc -c < "${bash_out}")"
c_size="$(wc -c < "${c_out}")"
bash_size="${bash_size// /}"
c_size="${c_size// /}"
shave_assert_eq "${bash_size}" "${c_size}" "echo-printf-loop and echo-printf-loop.sh stdout sizes match"

if cmp -s "${bash_out}" "${c_out}"; then
    shave_pass "echo-printf-loop stdout matches echo-printf-loop.sh"
else
    shave_fail "echo-printf-loop stdout differs from echo-printf-loop.sh"
    cmp -l "${bash_out}" "${c_out}" | head -n 20
fi

shave_test_finish
exit $?
