#ifndef SHAVE_WC_H
#define SHAVE_WC_H

/*
 * shave_wc.h - In-process GNU wc
 *
 * CHANGELOG
 * 1.0.3 - 2026-08-18 - Initial public API
 */

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SHAVE_WC_VERSION_MAJOR 1
#define SHAVE_WC_VERSION_MINOR 0
#define SHAVE_WC_VERSION_PATCH 3

/*
 * In-process GNU wc.
 *
 * Calling convention matches a command-line wc:
 *   argv[0] is the command name and is ignored
 *   argv[1..] are options and file operands
 *
 *   int main(int argc, char **argv) {
 *       return shave_wc(argc, argv);
 *   }
 *
 * Reentrant and thread-safe when each call uses its own FILE objects.
 * Caller owns every FILE.
 *
 * Returns 0 on success, 1 on write, file, or usage error.
 */

int shave_wc(int argc, char *const argv[]);
int shave_wc_fp(FILE *out, FILE *err, int argc, char *const argv[]);

#ifdef __cplusplus
}
#endif

#endif
