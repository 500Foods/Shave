#include "shave_printf_builtin.h"
#include "unity.h"

#include <stdio.h>
#include <string.h>

static void assert_printf_bytes(int argc, char *argv[], const void *expected, size_t expected_len)
{
    FILE *out;
    char buffer[256];
    size_t got;

    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(0, shave_printf_builtin_fp(out, argc, argv));
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
    TEST_ASSERT_EQUAL_INT(1, SHAVE_PRINTF_BUILTIN_VERSION_MAJOR);
    TEST_ASSERT_GREATER_OR_EQUAL_INT(0, SHAVE_PRINTF_BUILTIN_VERSION_MINOR);
}

void test_null_file_is_error(void)
{
    char *argv[] = {"printf", "x"};

    TEST_ASSERT_EQUAL_INT(1, shave_printf_builtin_fp(NULL, 2, argv));
}

void test_null_argv_with_argc_is_error(void)
{
    FILE *out;

    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(1, shave_printf_builtin_fp(out, 2, NULL));
    fclose(out);
}

void test_missing_format_is_usage(void)
{
    char *argv[] = {"printf"};

    TEST_ASSERT_EQUAL_INT(2, shave_printf_builtin(1, argv));
}

void test_invalid_option_is_usage(void)
{
    char *argv[] = {"printf", "-z", "%s", "x"};

    TEST_ASSERT_EQUAL_INT(2, shave_printf_builtin(4, argv));
}

void test_plain_text_no_newline(void)
{
    char *argv[] = {"printf", "hello"};

    assert_printf_bytes(2, argv, "hello", 5);
}

void test_percent_s(void)
{
    char *argv[] = {"printf", "%s\n", "hello"};

    assert_printf_bytes(3, argv, "hello\n", 6);
}

void test_reuses_format(void)
{
    char *argv[] = {"printf", "%s ", "a", "b", "c"};

    assert_printf_bytes(5, argv, "a b c ", 6);
}

void test_missing_string_is_empty(void)
{
    char *argv[] = {"printf", "%s-%s\n", "only"};

    assert_printf_bytes(3, argv, "only-\n", 6);
}

void test_missing_int_is_zero(void)
{
    char *argv[] = {"printf", "%d %d\n", "5"};

    assert_printf_bytes(3, argv, "5 0\n", 4);
}

void test_percent_b_interprets(void)
{
    char *argv[] = {"printf", "%b\n", "a\\tb"};

    assert_printf_bytes(3, argv, "a\tb\n", 4);
}

void test_percent_s_does_not_interpret(void)
{
    char *argv[] = {"printf", "%s\n", "a\\tb"};

    assert_printf_bytes(3, argv, "a\\tb\n", 5);
}

void test_percent_q_spaces(void)
{
    char *argv[] = {"printf", "%q\n", "hello world"};

    assert_printf_bytes(3, argv, "hello\\ world\n", 13);
}

void test_percent_q_empty(void)
{
    char *argv[] = {"printf", "%q\n", ""};

    assert_printf_bytes(3, argv, "''\n", 3);
}

void test_percent_b_c_stops(void)
{
    char *argv[] = {"printf", "%bEND\n", "hi\\cXX"};

    assert_printf_bytes(3, argv, "hi", 2);
}

void test_hex_null_then_letter(void)
{
    char *argv[] = {"printf", "%bX\n", "\\x00"};

    assert_printf_bytes(3, argv, "\0X\n", 3);
}

void test_double_dash_ends_options(void)
{
    char *argv[] = {"printf", "--", "-%s-\n", "x"};

    assert_printf_bytes(4, argv, "-x-\n", 4);
}

void test_width_and_left(void)
{
    char *argv[] = {"printf", "%-5s|\n", "hi"};

    assert_printf_bytes(3, argv, "hi   |\n", 7);
}

void test_successive_calls_do_not_share_state(void)
{
    FILE *out;
    char buffer[32];
    size_t got;
    char *first[] = {"printf", "%b", "foo\\cbar"};
    char *second[] = {"printf", "%s\n", "next"};

    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(0, shave_printf_builtin_fp(out, 3, first));
    TEST_ASSERT_EQUAL_INT(0, shave_printf_builtin_fp(out, 3, second));
    rewind(out);
    got = fread(buffer, 1, sizeof(buffer), out);
    fclose(out);
    TEST_ASSERT_EQUAL_UINT(8, got);
    TEST_ASSERT_EQUAL_MEMORY("foonext\n", buffer, 8);
}

void test_write_error_returns_one(void)
{
    FILE *out;
    char *argv[] = {"printf", "blocked"};

    out = fopen("/dev/full", "w");
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(1, shave_printf_builtin_fp(out, 2, argv));
    fclose(out);
}

void test_invalid_number_returns_one(void)
{
    FILE *out;
    char buffer[8];
    size_t got;
    char *argv[] = {"printf", "%d\n", "abc"};

    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(1, shave_printf_builtin_fp(out, 3, argv));
    rewind(out);
    got = fread(buffer, 1, sizeof(buffer), out);
    fclose(out);
    TEST_ASSERT_EQUAL_UINT(2, got);
    TEST_ASSERT_EQUAL_MEMORY("0\n", buffer, 2);
}

int main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_version_macros);
    RUN_TEST(test_null_file_is_error);
    RUN_TEST(test_null_argv_with_argc_is_error);
    RUN_TEST(test_missing_format_is_usage);
    RUN_TEST(test_invalid_option_is_usage);
    RUN_TEST(test_plain_text_no_newline);
    RUN_TEST(test_percent_s);
    RUN_TEST(test_reuses_format);
    RUN_TEST(test_missing_string_is_empty);
    RUN_TEST(test_missing_int_is_zero);
    RUN_TEST(test_percent_b_interprets);
    RUN_TEST(test_percent_s_does_not_interpret);
    RUN_TEST(test_percent_q_spaces);
    RUN_TEST(test_percent_q_empty);
    RUN_TEST(test_percent_b_c_stops);
    RUN_TEST(test_hex_null_then_letter);
    RUN_TEST(test_double_dash_ends_options);
    RUN_TEST(test_width_and_left);
    RUN_TEST(test_successive_calls_do_not_share_state);
    RUN_TEST(test_write_error_returns_one);
    RUN_TEST(test_invalid_number_returns_one);
    return UNITY_END();
}
