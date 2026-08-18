#!/usr/bin/env bash
# Test 0009: Wc
#
# CHANGELOG
# 1.0.3 - 2026-08-18 - shave/shave wc.sh, then compare binary to script
#
# Runs the Unity contract for the reusable wc library, then runs
# shave/shave on tests/0009/wc.sh. That writes wc.c and the
# UPX-compressed wc binary beside the script. Compare the binary
# stdout to the script stdout. Do not compile a hand-written C twin.
# Bash and C must match byte-for-byte, including NULs.

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"

# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/harness.sh"

SHAVE_0009_WORK=""
shave_0009_cleanup() {
    if [[ -n "${SHAVE_0009_WORK}" && -d "${SHAVE_0009_WORK}" ]]; then
        rm -rf "${SHAVE_0009_WORK}"
    fi
}
trap shave_0009_cleanup EXIT

shave_test_init "0009" "wc"

SHAVE_BIN="${REPO_ROOT}/shave/shave"
UNITY_BIN="${REPO_ROOT}/build/tests/test_wc"
FIXTURE_SH="${TEST_DIR}/wc.sh"
FIXTURE_C="${TEST_DIR}/wc.c"
FIXTURE_BIN="${TEST_DIR}/wc"
LIB_A="${REPO_ROOT}/build/libshave_wc.a"

shave_assert_file "${LIB_A}" "shave_wc archive exists"
shave_assert_file "${SHAVE_BIN}" "shave/shave exists"
shave_assert_exec "${SHAVE_BIN}" "shave/shave is executable"
shave_assert_file "${UNITY_BIN}" "Unity wc binary exists"
shave_assert_exec "${UNITY_BIN}" "Unity wc binary is executable"
shave_assert_file "${FIXTURE_SH}" "wc.sh exists"

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
shave_assert_status 0 "${shave_status}" "shave/shave wc.sh exits 0"
shave_assert_file "${FIXTURE_C}" "shave writes wc.c beside the script"
shave_assert_exec "${FIXTURE_BIN}" "shave writes wc beside the script"
if grep -q 'shave_wc(' "${FIXTURE_C}" 2>/dev/null; then
    shave_pass "generated C calls shave_wc"
else
    shave_fail "generated C does not call shave_wc"
fi

if [[ ! -x "${FIXTURE_BIN}" ]]; then
    shave_test_finish
    exit $?
fi

SHAVE_0009_WORK="$(mktemp -d "${TMPDIR:-/tmp}/shave-0009.XXXXXX")"
if [[ ! -d "${SHAVE_0009_WORK}" ]]; then
    shave_fail "could not create 0009 work directory"
    shave_test_finish
    exit $?
fi
bash_out="${SHAVE_0009_WORK}/bash.out"
c_out="${SHAVE_0009_WORK}/c.out"
bash_err="${SHAVE_0009_WORK}/bash.err"
c_err="${SHAVE_0009_WORK}/c.err"

bash_status=0
(
    cd "${TEST_DIR}" || exit 1
    bash "${FIXTURE_SH}" >"${bash_out}" 2>"${bash_err}"
) || bash_status=$?
shave_assert_status 0 "${bash_status}" "wc.sh exits 0"

c_status=0
(
    cd "${TEST_DIR}" || exit 1
    "${FIXTURE_BIN}" >"${c_out}" 2>"${c_err}"
) || c_status=$?
shave_assert_status 0 "${c_status}" "wc exits 0"

bash_err_size=0
c_err_size=0
bash_err_size="$(wc -c < "${bash_err}")"
c_err_size="$(wc -c < "${c_err}")"
bash_err_size="${bash_err_size// /}"
c_err_size="${c_err_size// /}"
shave_assert_eq "0" "${bash_err_size}" "wc.sh writes no stderr"
shave_assert_eq "0" "${c_err_size}" "wc writes no stderr"

bash_size=0
c_size=0
bash_size="$(wc -c < "${bash_out}")"
c_size="$(wc -c < "${c_out}")"
bash_size="${bash_size// /}"
c_size="${c_size// /}"
shave_assert_eq "${bash_size}" "${c_size}" "wc and wc.sh stdout sizes match"

if cmp -s "${bash_out}" "${c_out}"; then
    shave_pass "wc stdout matches wc.sh"
else
    shave_fail "wc stdout differs from wc.sh"
    cmp -l "${bash_out}" "${c_out}" | head -n 20
fi

shave_test_finish
exit $?
