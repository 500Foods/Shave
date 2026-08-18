#!/usr/bin/env bash
# Test 0005: Echo builtin
#
# CHANGELOG
# 1.4.0 - 2026-08-18 - shave/shave echo-builtin.sh, then compare binary to script
# 1.3.0 - 2026-08-18 - Shave compiler builds tests/0005/echo-builtin from echo-builtin.c
# 1.2.0 - 2026-08-18 - Compare tests/0005/echo-builtin binary to echo-builtin.sh
# 1.1.0 - 2026-08-18 - Comparison samples live beside this harness
# 1.0.0 - 2026-08-18 - Compare shave_echo_builtin C output to Bash echo
#
# Runs the Unity contract for the reusable echo library, then runs
# shave/shave on tests/0005/echo-builtin.sh. That writes echo-builtin.c
# and the UPX-compressed echo-builtin binary beside the script. Compare
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

SHAVE_0005_WORK=""
shave_0005_cleanup() {
    if [[ -n "${SHAVE_0005_WORK}" && -d "${SHAVE_0005_WORK}" ]]; then
        rm -rf "${SHAVE_0005_WORK}"
    fi
}
trap shave_0005_cleanup EXIT

shave_test_init "0005" "echo_builtin"

SHAVE_BIN="${REPO_ROOT}/shave/shave"
UNITY_BIN="${REPO_ROOT}/build/tests/test_echo_builtin"
FIXTURE_SH="${TEST_DIR}/echo-builtin.sh"
FIXTURE_C="${TEST_DIR}/echo-builtin.c"
FIXTURE_BIN="${TEST_DIR}/echo-builtin"
LIB_A="${REPO_ROOT}/build/libshave_echo_builtin.a"

shave_assert_file "${LIB_A}" "shave_echo_builtin archive exists"
shave_assert_file "${SHAVE_BIN}" "shave/shave exists"
shave_assert_exec "${SHAVE_BIN}" "shave/shave is executable"
shave_assert_file "${UNITY_BIN}" "Unity echo binary exists"
shave_assert_exec "${UNITY_BIN}" "Unity echo binary is executable"
shave_assert_file "${FIXTURE_SH}" "echo-builtin.sh exists"

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
shave_assert_status 0 "${shave_status}" "shave/shave echo-builtin.sh exits 0"
shave_assert_file "${FIXTURE_C}" "shave writes echo-builtin.c beside the script"
shave_assert_exec "${FIXTURE_BIN}" "shave writes echo-builtin beside the script"
if grep -q 'shave_echo_builtin(' "${FIXTURE_C}" 2>/dev/null; then
    shave_pass "generated C calls shave_echo_builtin"
else
    shave_fail "generated C does not call shave_echo_builtin"
fi

if [[ ! -x "${FIXTURE_BIN}" ]]; then
    shave_test_finish
    exit $?
fi

SHAVE_0005_WORK="$(mktemp -d "${TMPDIR:-/tmp}/shave-0005.XXXXXX")"
if [[ ! -d "${SHAVE_0005_WORK}" ]]; then
    shave_fail "could not create 0005 work directory"
    shave_test_finish
    exit $?
fi
bash_out="${SHAVE_0005_WORK}/bash.out"
c_out="${SHAVE_0005_WORK}/c.out"
bash_err="${SHAVE_0005_WORK}/bash.err"
c_err="${SHAVE_0005_WORK}/c.err"

bash_status=0
bash "${FIXTURE_SH}" >"${bash_out}" 2>"${bash_err}" || bash_status=$?
shave_assert_status 0 "${bash_status}" "echo-builtin.sh exits 0"

c_status=0
"${FIXTURE_BIN}" >"${c_out}" 2>"${c_err}" || c_status=$?
shave_assert_status 0 "${c_status}" "echo-builtin exits 0"

bash_err_size=0
c_err_size=0
bash_err_size="$(wc -c < "${bash_err}")"
c_err_size="$(wc -c < "${c_err}")"
bash_err_size="${bash_err_size// /}"
c_err_size="${c_err_size// /}"
shave_assert_eq "0" "${bash_err_size}" "echo-builtin.sh writes no stderr"
shave_assert_eq "0" "${c_err_size}" "echo-builtin writes no stderr"

bash_size=0
c_size=0
bash_size="$(wc -c < "${bash_out}")"
c_size="$(wc -c < "${c_out}")"
bash_size="${bash_size// /}"
c_size="${c_size// /}"
shave_assert_eq "${bash_size}" "${c_size}" "echo-builtin and echo-builtin.sh stdout sizes match"

if cmp -s "${bash_out}" "${c_out}"; then
    shave_pass "echo-builtin stdout matches echo-builtin.sh"
else
    shave_fail "echo-builtin stdout differs from echo-builtin.sh"
    cmp -l "${bash_out}" "${c_out}" | head -n 20
fi

shave_test_finish
exit $?
