#include "shave_version.h"
#include "version_info.h"

#include <stdio.h>

int main(void) {
    int major = 0;
    int minor = 0;
    int patch = 0;

    if (!shave_parse_version(SHAVE_VERSION, &major, &minor, &patch)) {
        return 1;
    }
    printf("%d.%d.%d\n", major, minor, patch);
    return 0;
}
