#include "shave_echo_builtin.h"
#include "unity.h"

#include <stdio.h>
#include <string.h>

static void assert_echo_bytes(int argc, char *argv[], const void *expected, size_t expected_len)
{
    FILE *out;
    char buffer[256];
    size_t got;

    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(0, shave_echo_builtin_fp(out, argc, argv));
    rewind(out);
    got = fread(buffer, 1, sizeof(buffer), out);
    fclose(out);
    TEST_ASSERT_EQUAL_UINT(expected_len, got);
    TEST_ASSERT_EQUAL_MEMORY(expected, buffer, expected_len);
}

void setUp(void)
{
}

void tearDown(void)
{
}

void test_version_macros(void)
{
    TEST_ASSERT_EQUAL_INT(1, SHAVE_ECHO_BUILTIN_VERSION_MAJOR);
    TEST_ASSERT_GREATER_OR_EQUAL_INT(0, SHAVE_ECHO_BUILTIN_VERSION_MINOR);
}

void test_null_file_is_error(void)
{
    char *argv[] = {"echo", "x"};

    TEST_ASSERT_EQUAL_INT(1, shave_echo_builtin_fp(NULL, 2, argv));
}

void test_null_argv_with_argc_is_error(void)
{
    FILE *out;

    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(1, shave_echo_builtin_fp(out, 2, NULL));
    fclose(out);
}

void test_plain_words_and_newline(void)
{
    char *argv[] = {"echo", "hello", "world"};

    assert_echo_bytes(3, argv, "hello world\n", 12);
}

void test_n_suppresses_newline(void)
{
    char *argv[] = {"echo", "-n", "partial"};

    assert_echo_bytes(3, argv, "partial", 7);
}

void test_e_interprets_tab_and_newline(void)
{
    char *argv[] = {"echo", "-e", "a\\tb\\nc"};

    assert_echo_bytes(3, argv, "a\tb\nc\n", 6);
}

void test_E_leaves_escapes(void)
{
    char *argv[] = {"echo", "-E", "a\\tb"};

    assert_echo_bytes(3, argv, "a\\tb\n", 5);
}

void test_c_stops_output(void)
{
    char *argv[] = {"echo", "-e", "foo\\cbar"};

    assert_echo_bytes(3, argv, "foo", 3);
}

void test_double_dash_is_operand(void)
{
    char *argv[] = {"echo", "--", "-n"};

    assert_echo_bytes(3, argv, "-- -n\n", 6);
}

void test_unknown_dash_is_operand(void)
{
    char *argv[] = {"echo", "-x", "no"};

    assert_echo_bytes(3, argv, "-x no\n", 6);
}

void test_hex_null_then_letter(void)
{
    char *argv[] = {"echo", "-e", "\\x00X"};

    assert_echo_bytes(3, argv, "\0X\n", 3);
}

void test_xpg_interprets_without_e(void)
{
    FILE *out;
    char buffer[16];
    size_t got;
    char *argv[] = {"echo", "a\\tb"};

    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(0, shave_echo_builtin_xpg_fp(out, 2, argv));
    rewind(out);
    got = fread(buffer, 1, sizeof(buffer), out);
    fclose(out);
    TEST_ASSERT_EQUAL_UINT(4, got);
    TEST_ASSERT_EQUAL_MEMORY("a\tb\n", buffer, 4);
}

void test_successive_calls_do_not_share_state(void)
{
    FILE *out;
    char buffer[32];
    size_t got;
    char *first[] = {"echo", "-e", "foo\\cbar"};
    char *second[] = {"echo", "next"};

    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(0, shave_echo_builtin_fp(out, 3, first));
    TEST_ASSERT_EQUAL_INT(0, shave_echo_builtin_fp(out, 2, second));
    rewind(out);
    got = fread(buffer, 1, sizeof(buffer), out);
    fclose(out);
    TEST_ASSERT_EQUAL_UINT(8, got);
    TEST_ASSERT_EQUAL_MEMORY("foonext\n", buffer, 8);
}

void test_write_error_returns_one(void)
{
    FILE *out;
    char *argv[] = {"echo", "blocked"};

    out = fopen("/dev/full", "w");
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(1, shave_echo_builtin_fp(out, 2, argv));
    fclose(out);
}

int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_version_macros);
    RUN_TEST(test_null_file_is_error);
    RUN_TEST(test_null_argv_with_argc_is_error);
    RUN_TEST(test_plain_words_and_newline);
    RUN_TEST(test_n_suppresses_newline);
    RUN_TEST(test_e_interprets_tab_and_newline);
    RUN_TEST(test_E_leaves_escapes);
    RUN_TEST(test_c_stops_output);
    RUN_TEST(test_double_dash_is_operand);
    RUN_TEST(test_unknown_dash_is_operand);
    RUN_TEST(test_hex_null_then_letter);
    RUN_TEST(test_xpg_interprets_without_e);
    RUN_TEST(test_successive_calls_do_not_share_state);
    RUN_TEST(test_write_error_returns_one);
    return UNITY_END();
}
