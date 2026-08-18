#!/usr/bin/env bash
# Test 0000: CMake project build
# Runs first and sequentially. Remaining suites assume this passed
#
# CHANGELOG
# 1.0.3 - 2026-08-18 - Build shave_wc archive and Unity binary
# 1.7.0 - 2026-08-18 - CMake no longer builds echo/printf comparison binaries
# 1.6.2 - 2026-08-18 - Echo fixture binary lives beside tests/0005/echo-builtin.sh
# 1.6.1 - 2026-08-18 - cmake --build stays incremental; do not wipe the tree
# 1.6.0 - 2026-08-18 - Build suite-local echo/printf comparison samples
# 1.5.0 - 2026-08-18 - Build shave_printf_builtin archive, Unity, and C fixture
# 1.4.0 - 2026-08-18 - Build shave_echo_builtin archive, Unity, and C fixture
# 1.3.0 - 2026-08-18 - C sources live in shave/; Unity lives in tests/unity/framework
# 1.2.0 - 2026-08-18 - Also build Unity test binaries
# 1.1.0 - 2026-08-18 - Replace ad-hoc toolchain probe with CMake configure and build
# 1.0.0 - 2026-08-18 - Initial environment and toolchain gate

set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"

# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/harness.sh"

shave_test_init "0000" "cmake_build"

VERSION_FILE="${REPO_ROOT}/VERSION"
BUILD_DIR="${REPO_ROOT}/build"
VERSION_BIN="${BUILD_DIR}/shave-version"
UNITY_BIN="${BUILD_DIR}/tests/test_version"
ECHO_LIB="${BUILD_DIR}/libshave_echo_builtin.a"
ECHO_UNITY_BIN="${BUILD_DIR}/tests/test_echo_builtin"
PRINTF_LIB="${BUILD_DIR}/libshave_printf_builtin.a"
PRINTF_UNITY_BIN="${BUILD_DIR}/tests/test_printf_builtin"
WC_LIB="${BUILD_DIR}/libshave_wc.a"
WC_UNITY_BIN="${BUILD_DIR}/tests/test_wc"

shave_assert_cmd cmake "cmake is available"
shave_assert_cmd gcc "gcc is available"
shave_assert_file "${REPO_ROOT}/CMakeLists.txt" "CMakeLists.txt exists"
shave_assert_file "${VERSION_FILE}" "VERSION file exists"
shave_assert_file "${REPO_ROOT}/shave/version.c" "C sources live in shave/"
shave_assert_file "${REPO_ROOT}/tests/unity/framework/unity.c" "Unity framework is vendored in-tree"

expected_version=""
expected_version="$(tr -d '[:space:]' < "${VERSION_FILE}")"
if [[ -n "${expected_version}" ]]; then
    shave_pass "VERSION file is readable"
else
    shave_fail "VERSION file is empty"
fi

mkdir -p "${BUILD_DIR}"

configure_status=0
cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" || configure_status=$?
shave_assert_status 0 "${configure_status}" "cmake configure succeeds"

build_status=0
cmake --build "${BUILD_DIR}" || build_status=$?
shave_assert_status 0 "${build_status}" "cmake build succeeds"

shave_assert_exec "${VERSION_BIN}" "shave-version was built"

if [[ -x "${VERSION_BIN}" ]]; then
    built_version=""
    built_version="$("${VERSION_BIN}" 2>/dev/null || true)"
    shave_assert_eq "${expected_version}" "${built_version}" "built version matches VERSION file"
fi

shave_assert_exec "${UNITY_BIN}" "Unity test_version was built"
shave_assert_file "${ECHO_LIB}" "shave_echo_builtin archive was built"
shave_assert_exec "${ECHO_UNITY_BIN}" "Unity test_echo_builtin was built"
shave_assert_file "${PRINTF_LIB}" "shave_printf_builtin archive was built"
shave_assert_exec "${PRINTF_UNITY_BIN}" "Unity test_printf_builtin was built"
shave_assert_file "${WC_LIB}" "shave_wc archive was built"
shave_assert_exec "${WC_UNITY_BIN}" "Unity test_wc was built"

shave_test_finish
exit $?
