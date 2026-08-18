#include "unity.h"
#include "version_info.h"

void setUp(void) {
}

void tearDown(void) {
}

void test_parse_current_version(void) {
    int major = 0;
    int minor = 0;
    int patch = 0;

    TEST_ASSERT_TRUE(shave_parse_version("1.0.3", &major, &minor, &patch));
    TEST_ASSERT_EQUAL_INT(1, major);
    TEST_ASSERT_EQUAL_INT(0, minor);
    TEST_ASSERT_EQUAL_INT(3, patch);
}

void test_parse_rejects_null_text(void) {
    int major = 0;
    int minor = 0;
    int patch = 0;

    TEST_ASSERT_FALSE(shave_parse_version(NULL, &major, &minor, &patch));
}

void test_parse_rejects_incomplete_version(void) {
    int major = 0;
    int minor = 0;
    int patch = 0;

    TEST_ASSERT_FALSE(shave_parse_version("1.2", &major, &minor, &patch));
}

void test_parse_rejects_trailing_text(void) {
    int major = 0;
    int minor = 0;
    int patch = 0;

    TEST_ASSERT_FALSE(shave_parse_version("1.2.3-beta", &major, &minor, &patch));
}

int main(void) {
    UNITY_BEGIN();
    RUN_TEST(test_parse_current_version);
    RUN_TEST(test_parse_rejects_null_text);
    RUN_TEST(test_parse_rejects_incomplete_version);
    RUN_TEST(test_parse_rejects_trailing_text);
    return UNITY_END();
}
