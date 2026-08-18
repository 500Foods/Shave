#!/usr/bin/env bash
# Shave Test Harness: Shared helpers for numbered test.sh scripts
#
# CHANGELOG
# 1.1.0 - 2026-08-18 - RESULT line remains the suite contract for run-tests.sh
# 1.0.1 - 2026-08-18 - Drop unused repo-root helper
# 1.0.0 - 2026-08-18 - Initial harness for pass/fail/skip reporting

if [[ -n "${SHAVE_HARNESS_GUARD:-}" ]]; then
    return 0
fi
SHAVE_HARNESS_GUARD=1

SHAVE_TEST_PASS=0
SHAVE_TEST_FAIL=0
SHAVE_TEST_SKIP=0
SHAVE_TEST_ID=""
SHAVE_TEST_NAME=""

shave_color() {
    local code="$1"
    shift
    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        printf '\033[%sm%s\033[0m' "$code" "$*"
    else
        printf '%s' "$*"
    fi
}

shave_test_init() {
    SHAVE_TEST_ID="$1"
    SHAVE_TEST_NAME="$2"
    SHAVE_TEST_PASS=0
    SHAVE_TEST_FAIL=0
    SHAVE_TEST_SKIP=0
    printf 'TEST %s %s\n' "$SHAVE_TEST_ID" "$SHAVE_TEST_NAME"
}

shave_pass() {
    SHAVE_TEST_PASS=$((SHAVE_TEST_PASS + 1))
    printf '  %s %s\n' "$(shave_color 32 PASS)" "$*"
}

shave_fail() {
    SHAVE_TEST_FAIL=$((SHAVE_TEST_FAIL + 1))
    printf '  %s %s\n' "$(shave_color 31 FAIL)" "$*"
}

shave_skip() {
    SHAVE_TEST_SKIP=$((SHAVE_TEST_SKIP + 1))
    printf '  %s %s\n' "$(shave_color 33 SKIP)" "$*"
}

shave_assert_file() {
    local path="$1"
    local msg="${2:-file exists: $path}"
    if [[ -f "$path" ]]; then
        shave_pass "$msg"
        return 0
    fi
    shave_fail "$msg"
    return 1
}

shave_assert_exec() {
    local path="$1"
    local msg="${2:-executable: $path}"
    if [[ -x "$path" ]]; then
        shave_pass "$msg"
        return 0
    fi
    shave_fail "$msg"
    return 1
}

shave_assert_cmd() {
    local name="$1"
    local msg="${2:-command available: $name}"
    if command -v "$name" >/dev/null 2>&1; then
        shave_pass "$msg"
        return 0
    fi
    shave_fail "$msg"
    return 1
}

shave_assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-values match}"
    if [[ "$expected" == "$actual" ]]; then
        shave_pass "$msg"
        return 0
    fi
    shave_fail "$msg (expected '$expected', got '$actual')"
    return 1
}

shave_assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-output contains expected text}"
    if [[ "$haystack" == *"$needle"* ]]; then
        shave_pass "$msg"
        return 0
    fi
    shave_fail "$msg (missing '$needle')"
    return 1
}

shave_assert_status() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-exit status $expected}"
    shave_assert_eq "$expected" "$actual" "$msg"
}

shave_test_finish() {
    printf 'RESULT %s name=%s passed=%s failed=%s skipped=%s\n' \
        "$SHAVE_TEST_ID" "$SHAVE_TEST_NAME" "$SHAVE_TEST_PASS" "$SHAVE_TEST_FAIL" "$SHAVE_TEST_SKIP"
    if (( SHAVE_TEST_FAIL > 0 )); then
        return 1
    fi
    return 0
}
