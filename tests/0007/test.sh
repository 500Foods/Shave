#!/usr/bin/env bash
# Test 0007: CLI output and skip
#
# CHANGELOG
# 1.1.0 - 2026-08-18 - Product CLI is shave/shave
# 1.0.0 - 2026-08-18 - Default binary/.c output, -c override, unchanged skip
#
# Harness only. Comparison samples stay out of this folder. Uses the shared
# hello-world.sh fixture to assert the product CLI: write binary + .c, honor
# -o/-c, and skip generate/compile when bash, toolchain, and outputs match.

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"

# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/harness.sh"

SHAVE_0007_WORK=""
shave_0007_cleanup() {
    if [[ -n "${SHAVE_0007_WORK}" && -d "${SHAVE_0007_WORK}" ]]; then
        rm -rf "${SHAVE_0007_WORK}"
    fi
}
trap shave_0007_cleanup EXIT

shave_test_init "0007" "cli_output_skip"

SHAVE_BIN="${REPO_ROOT}/shave/shave"
FIXTURE_SH="${REPO_ROOT}/tests/fixtures/hello-world.sh"

shave_assert_file "${SHAVE_BIN}" "shave/shave exists"
shave_assert_exec "${SHAVE_BIN}" "shave/shave is executable"
shave_assert_file "${FIXTURE_SH}" "hello-world fixture exists"

SHAVE_0007_WORK="$(mktemp -d "${TMPDIR:-/tmp}/shave-0007.XXXXXX")"
if [[ ! -d "${SHAVE_0007_WORK}" ]]; then
    shave_fail "could not create 0007 work directory"
    shave_test_finish
    exit $?
fi

cp "${FIXTURE_SH}" "${SHAVE_0007_WORK}/hello.sh"
input_sh="${SHAVE_0007_WORK}/hello.sh"

help_out=""
help_out="$("${SHAVE_BIN}" -h 2>&1)" || true
shave_assert_contains "${help_out}" "-c, --c-source" "help documents -c"
shave_assert_contains "${help_out}" "SHAVE_GCC" "help documents SHAVE_GCC"
shave_assert_contains "${help_out}" "SHAVE_FORCE" "help documents SHAVE_FORCE"

first_status=0
SHAVE_UPX=0 SHAVE_FORCE=1 "${SHAVE_BIN}" "${input_sh}" >/dev/null || first_status=$?
shave_assert_status 0 "${first_status}" "default shave of hello.sh exits 0"
shave_assert_file "${SHAVE_0007_WORK}/hello.c" "default writes hello.c beside the binary"
shave_assert_exec "${SHAVE_0007_WORK}/hello" "default writes hello executable"
shave_assert_file "${SHAVE_0007_WORK}/hello.shave" "default writes incremental stamp"

second_status=0
second_out=""
second_out="$(SHAVE_UPX=0 "${SHAVE_BIN}" "${input_sh}" 2>&1)" || second_status=$?
shave_assert_status 0 "${second_status}" "repeat shave of unchanged hello.sh exits 0"
shave_assert_contains "${second_out}" "skipping generate and compile" "unchanged inputs skip generate and compile"

named_bin="${SHAVE_0007_WORK}/named"
named_c="${SHAVE_0007_WORK}/named-src.c"
named_status=0
SHAVE_UPX=0 SHAVE_FORCE=1 "${SHAVE_BIN}" -o "${named_bin}" -c "${named_c}" "${input_sh}" >/dev/null || named_status=$?
shave_assert_status 0 "${named_status}" "shave -o/-c exits 0"
shave_assert_file "${named_c}" "-c writes the requested C source"
shave_assert_exec "${named_bin}" "-o writes the requested executable"
if [[ ! -f "${SHAVE_0007_WORK}/named.c" ]]; then
    shave_pass "-c does not also write output.c"
else
    shave_fail "-c should not also write named.c"
fi

shave_test_finish
exit $?
