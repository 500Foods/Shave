#!/usr/bin/env bash
# Test 0006: Printf builtin
#
# CHANGELOG
# 1.4.0 - 2026-08-18 - Assert the shared printf library
# 1.3.0 - 2026-08-18 - shave/shave printf-builtin.sh, then compare binary to script
# 1.2.0 - 2026-08-18 - Shave compiler builds tests/0006/printf-builtin from printf-builtin.c
# 1.1.0 - 2026-08-18 - Comparison samples live beside this harness
# 1.0.0 - 2026-08-18 - Compare shave_printf_builtin C output to Bash printf
#
# Runs the Unity contract for the reusable printf library, then runs
# shave/shave on tests/0006/printf-builtin.sh. That writes printf-builtin.c
# and the UPX-compressed printf-builtin binary beside the script. Compare
# the binary stdout to the script stdout. Do not compile a hand-written C
# twin. Bash and C must match byte-for-byte, including NULs.

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"

# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/harness.sh"

SHAVE_0006_WORK=""
shave_0006_cleanup() {
    if [[ -n "${SHAVE_0006_WORK}" && -d "${SHAVE_0006_WORK}" ]]; then
        rm -rf "${SHAVE_0006_WORK}"
    fi
}
trap shave_0006_cleanup EXIT

shave_test_init "0006" "printf_builtin"

SHAVE_BIN="${REPO_ROOT}/shave/shave"
UNITY_BIN="${REPO_ROOT}/build/tests/test_printf_builtin"
FIXTURE_SH="${TEST_DIR}/printf-builtin.sh"
FIXTURE_C="${TEST_DIR}/printf-builtin.c"
FIXTURE_BIN="${TEST_DIR}/printf-builtin"
LIB_SO="${REPO_ROOT}/build/libshave_printf_builtin.so"

shave_assert_file "${LIB_SO}" "shave_printf_builtin shared library exists"
shave_assert_file "${SHAVE_BIN}" "shave/shave exists"
shave_assert_exec "${SHAVE_BIN}" "shave/shave is executable"
shave_assert_file "${UNITY_BIN}" "Unity printf binary exists"
shave_assert_exec "${UNITY_BIN}" "Unity printf binary is executable"
shave_assert_file "${FIXTURE_SH}" "printf-builtin.sh exists"

if [[ -x "${UNITY_BIN}" ]]; then
    shave_run_unity "${UNITY_BIN}"
fi

if [[ ! -x "${SHAVE_BIN}" || ! -f "${FIXTURE_SH}" ]]; then
    shave_test_finish
    exit $?
fi

export SHAVE_ROOT="${REPO_ROOT}"
export SHAVE_LIBDIR="${REPO_ROOT}/build"
export SHAVE_FORCE=1

shave_status=0
"${SHAVE_BIN}" "${FIXTURE_SH}" >/dev/null || shave_status=$?
shave_assert_status 0 "${shave_status}" "shave/shave printf-builtin.sh exits 0"
shave_assert_file "${FIXTURE_C}" "shave writes printf-builtin.c beside the script"
shave_assert_exec "${FIXTURE_BIN}" "shave writes printf-builtin beside the script"
if grep -q 'shave_printf_builtin(' "${FIXTURE_C}" 2>/dev/null; then
    shave_pass "generated C calls shave_printf_builtin"
else
    shave_fail "generated C does not call shave_printf_builtin"
fi

if [[ ! -x "${FIXTURE_BIN}" ]]; then
    shave_test_finish
    exit $?
fi

SHAVE_0006_WORK="$(mktemp -d "${TMPDIR:-/tmp}/shave-0006.XXXXXX")"
if [[ ! -d "${SHAVE_0006_WORK}" ]]; then
    shave_fail "could not create 0006 work directory"
    shave_test_finish
    exit $?
fi
bash_out="${SHAVE_0006_WORK}/bash.out"
c_out="${SHAVE_0006_WORK}/c.out"
bash_err="${SHAVE_0006_WORK}/bash.err"
c_err="${SHAVE_0006_WORK}/c.err"

export LC_ALL=en_US.utf8
export LANG=en_US.utf8

bash_status=0
bash "${FIXTURE_SH}" >"${bash_out}" 2>"${bash_err}" || bash_status=$?
shave_assert_status 0 "${bash_status}" "printf-builtin.sh exits 0"

c_status=0
"${FIXTURE_BIN}" >"${c_out}" 2>"${c_err}" || c_status=$?
shave_assert_status 0 "${c_status}" "printf-builtin exits 0"

bash_err_size=0
c_err_size=0
bash_err_size="$(wc -c < "${bash_err}")"
c_err_size="$(wc -c < "${c_err}")"
bash_err_size="${bash_err_size// /}"
c_err_size="${c_err_size// /}"
shave_assert_eq "0" "${bash_err_size}" "printf-builtin.sh writes no stderr"
shave_assert_eq "0" "${c_err_size}" "printf-builtin writes no stderr"

bash_size=0
c_size=0
bash_size="$(wc -c < "${bash_out}")"
c_size="$(wc -c < "${c_out}")"
bash_size="${bash_size// /}"
c_size="${c_size// /}"
shave_assert_eq "${bash_size}" "${c_size}" "printf-builtin and printf-builtin.sh stdout sizes match"

if cmp -s "${bash_out}" "${c_out}"; then
    shave_pass "printf-builtin stdout matches printf-builtin.sh"
else
    shave_fail "printf-builtin stdout differs from printf-builtin.sh"
    cmp -l "${bash_out}" "${c_out}" | head -n 20
fi

shave_test_finish
exit $?
