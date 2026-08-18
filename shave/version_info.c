#include "version_info.h"

#include <stdio.h>

int shave_parse_version(const char *text, int *major, int *minor, int *patch) {
    int parsed_major = 0;
    int parsed_minor = 0;
    int parsed_patch = 0;
    char extra = '\0';

    if (text == NULL || major == NULL || minor == NULL || patch == NULL) {
        return 0;
    }

    if (sscanf(text, "%d.%d.%d%c", &parsed_major, &parsed_minor, &parsed_patch, &extra) != 3) {
        return 0;
    }
    if (parsed_major < 0 || parsed_minor < 0 || parsed_patch < 0) {
        return 0;
    }

    *major = parsed_major;
    *minor = parsed_minor;
    *patch = parsed_patch;
    return 1;
}
