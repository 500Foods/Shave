#ifndef SHAVE_PRINTF_BUILTIN_H
#define SHAVE_PRINTF_BUILTIN_H

/*
 * shave_printf_builtin.h - In-process Bash builtin printf
 *
 * CHANGELOG
 * 1.0.0 - 2026-08-18 - Initial public API
 */

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SHAVE_PRINTF_BUILTIN_VERSION_MAJOR 1
#define SHAVE_PRINTF_BUILTIN_VERSION_MINOR 0
#define SHAVE_PRINTF_BUILTIN_VERSION_PATCH 0

/*
 * In-process Bash builtin printf.
 *
 * Calling convention matches a command-line printf:
 *   argv[0] is the command name and is ignored
 *   argv[1..] are options, the format, and arguments
 *
 *   int main(int argc, char **argv) {
 *       return shave_printf_builtin(argc, argv);
 *   }
 *
 * Reentrant and thread-safe when each call uses its own FILE.
 * No global state. Caller owns every FILE.
 * Numeric conversion uses a fixed stack buffer. Padding is streamed.
 *
 * Returns 0 on success, 1 on write/format/number error, 2 on usage error.
 * -v is accepted and ignored: capture output with _fp instead.
 */

int shave_printf_builtin(int argc, char *const argv[]);
int shave_printf_builtin_fp(FILE *out, int argc, char *const argv[]);

#ifdef __cplusplus
}
#endif

#endif
