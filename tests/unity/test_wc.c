#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include "shave_wc.h"
#include "unity.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char shave_wc_dir[256];

static void shave_wc_write_file(const char *name, const void *data, size_t length)
{
    char path[300];
    FILE *out;
    int n;

    n = snprintf(path, sizeof(path), "%s/%s", shave_wc_dir, name);
    TEST_ASSERT_TRUE(n > 0 && (size_t)n < sizeof(path));
    out = fopen(path, "wb");
    TEST_ASSERT_NOT_NULL(out);
    if (length > 0) {
        TEST_ASSERT_EQUAL_UINT(length, fwrite(data, 1, length, out));
    }
    fclose(out);
}

static void assert_wc_bytes(int argc, char *argv[], const void *expected, size_t expected_len)
{
    FILE *out;
    char buffer[256];
    size_t got;

    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(0, shave_wc_fp(out, stderr, argc, argv));
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
    TEST_ASSERT_EQUAL_INT(1, SHAVE_WC_VERSION_MAJOR);
    TEST_ASSERT_EQUAL_INT(0, SHAVE_WC_VERSION_MINOR);
    TEST_ASSERT_EQUAL_INT(3, SHAVE_WC_VERSION_PATCH);
}

void test_null_file_is_error(void)
{
    char *argv[] = {"wc"};

    TEST_ASSERT_EQUAL_INT(1, shave_wc_fp(NULL, stderr, 1, argv));
}

void test_null_argv_with_argc_is_error(void)
{
    FILE *out;

    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(1, shave_wc_fp(out, stderr, 2, NULL));
    fclose(out);
}

void test_invalid_option_is_error(void)
{
    char *argv[] = {"wc", "-z", "x"};

    TEST_ASSERT_EQUAL_INT(1, shave_wc(3, argv));
}

void test_lines_one_file(void)
{
    FILE *out;
    char path[300];
    char buffer[256];
    char expected[300];
    char *argv[3];
    size_t got;
    int n;

    shave_wc_write_file("a.txt", "hello world\nsecond line\n", 24);
    (void)snprintf(path, sizeof(path), "%s/a.txt", shave_wc_dir);
    argv[0] = "wc";
    argv[1] = "-l";
    argv[2] = path;
    n = snprintf(expected, sizeof(expected), "2 %s\n", path);
    TEST_ASSERT_TRUE(n > 0);
    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(0, shave_wc_fp(out, stderr, 3, argv));
    rewind(out);
    got = fread(buffer, 1, sizeof(buffer), out);
    fclose(out);
    TEST_ASSERT_EQUAL_UINT((size_t)n, got);
    TEST_ASSERT_EQUAL_MEMORY(expected, buffer, (size_t)n);
}

void test_bytes_one_file(void)
{
    FILE *out;
    char path[300];
    char buffer[256];
    char expected[300];
    char *argv[3];
    size_t got;
    int n;

    shave_wc_write_file("b.txt", "one\n", 4);
    (void)snprintf(path, sizeof(path), "%s/b.txt", shave_wc_dir);
    argv[0] = "wc";
    argv[1] = "-c";
    argv[2] = path;
    n = snprintf(expected, sizeof(expected), "4 %s\n", path);
    TEST_ASSERT_TRUE(n > 0);
    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(0, shave_wc_fp(out, stderr, 3, argv));
    rewind(out);
    got = fread(buffer, 1, sizeof(buffer), out);
    fclose(out);
    TEST_ASSERT_EQUAL_UINT((size_t)n, got);
    TEST_ASSERT_EQUAL_MEMORY(expected, buffer, (size_t)n);
}

void test_default_counts_two_files(void)
{
    FILE *out;
    char path_a[300];
    char path_b[300];
    char buffer[512];
    char expected[512];
    char *argv[3];
    size_t got;
    int n;

    shave_wc_write_file("c.txt", "hello world\nsecond line\n", 24);
    shave_wc_write_file("d.txt", "one\n", 4);
    (void)snprintf(path_a, sizeof(path_a), "%s/c.txt", shave_wc_dir);
    (void)snprintf(path_b, sizeof(path_b), "%s/d.txt", shave_wc_dir);
    argv[0] = "wc";
    argv[1] = path_a;
    argv[2] = path_b;
    n = snprintf(expected, sizeof(expected),
                 " 2  4 24 %s\n 1  1  4 %s\n 3  5 28 total\n", path_a, path_b);
    TEST_ASSERT_TRUE(n > 0);
    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(0, shave_wc_fp(out, stderr, 3, argv));
    rewind(out);
    got = fread(buffer, 1, sizeof(buffer), out);
    fclose(out);
    TEST_ASSERT_EQUAL_UINT((size_t)n, got);
    TEST_ASSERT_EQUAL_MEMORY(expected, buffer, (size_t)n);
}

void test_missing_file_is_error(void)
{
    char path[300];
    char *argv[2];

    (void)snprintf(path, sizeof(path), "%s/missing.txt", shave_wc_dir);
    argv[0] = "wc";
    argv[1] = path;
    TEST_ASSERT_EQUAL_INT(1, shave_wc(2, argv));
}

void test_total_only(void)
{
    char path_a[300];
    char path_b[300];
    char *argv[5];

    shave_wc_write_file("e.txt", "hello world\nsecond line\n", 24);
    shave_wc_write_file("f.txt", "one\n", 4);
    (void)snprintf(path_a, sizeof(path_a), "%s/e.txt", shave_wc_dir);
    (void)snprintf(path_b, sizeof(path_b), "%s/f.txt", shave_wc_dir);
    argv[0] = "wc";
    argv[1] = "--total=only";
    argv[2] = "-l";
    argv[3] = path_a;
    argv[4] = path_b;
    assert_wc_bytes(5, argv, "3\n", 2);
}

void test_max_line_tab(void)
{
    FILE *out;
    char path[300];
    char buffer[256];
    char expected[300];
    char *argv[3];
    size_t got;
    int n;

    shave_wc_write_file("tab.txt", "a\tb\n", 4);
    (void)snprintf(path, sizeof(path), "%s/tab.txt", shave_wc_dir);
    argv[0] = "wc";
    argv[1] = "-L";
    argv[2] = path;
    n = snprintf(expected, sizeof(expected), "9 %s\n", path);
    TEST_ASSERT_TRUE(n > 0);
    out = tmpfile();
    TEST_ASSERT_NOT_NULL(out);
    TEST_ASSERT_EQUAL_INT(0, shave_wc_fp(out, stderr, 3, argv));
    rewind(out);
    got = fread(buffer, 1, sizeof(buffer), out);
    fclose(out);
    TEST_ASSERT_EQUAL_UINT((size_t)n, got);
    TEST_ASSERT_EQUAL_MEMORY(expected, buffer, (size_t)n);
}

int main(void)
{
    char template[] = "/tmp/shave-wc-unity.XXXXXX";
    char *dir;

    dir = mkdtemp(template);
    if (dir == NULL) {
        return 1;
    }
    (void)snprintf(shave_wc_dir, sizeof(shave_wc_dir), "%s", dir);

    UNITY_BEGIN();
    RUN_TEST(test_version_macros);
    RUN_TEST(test_null_file_is_error);
    RUN_TEST(test_null_argv_with_argc_is_error);
    RUN_TEST(test_invalid_option_is_error);
    RUN_TEST(test_lines_one_file);
    RUN_TEST(test_bytes_one_file);
    RUN_TEST(test_default_counts_two_files);
    RUN_TEST(test_missing_file_is_error);
    RUN_TEST(test_total_only);
    RUN_TEST(test_max_line_tab);
    {
        int status = UNITY_END();
        char path[300];
        const char *names[] = {
            "a.txt", "b.txt", "c.txt", "d.txt", "e.txt", "f.txt", "tab.txt"
        };
        size_t idx;
        for (idx = 0; idx < sizeof(names) / sizeof(names[0]); idx++) {
            (void)snprintf(path, sizeof(path), "%s/%s", dir, names[idx]);
            (void)unlink(path);
        }
        (void)rmdir(dir);
        return status;
    }
}
