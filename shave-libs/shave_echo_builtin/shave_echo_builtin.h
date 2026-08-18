#ifndef SHAVE_ECHO_BUILTIN_H
#define SHAVE_ECHO_BUILTIN_H

/*
 * shave_echo_builtin.h - In-process Bash builtin echo
 *
 * CHANGELOG
 * 1.0.1 - 2026-08-18 - Add version macros for downstream consumers
 * 1.0.0 - 2026-08-18 - Initial public API
 */

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SHAVE_ECHO_BUILTIN_VERSION_MAJOR 1
#define SHAVE_ECHO_BUILTIN_VERSION_MINOR 0
#define SHAVE_ECHO_BUILTIN_VERSION_PATCH 1

/*
 * In-process Bash builtin echo.
 *
 * Calling convention matches a command-line echo:
 *   argv[0] is the command name and is ignored
 *   argv[1..] are the operands and -n/-e/-E flags
 *
 *   int main(int argc, char **argv) {
 *       return shave_echo_builtin(argc, argv);
 *   }
 *
 * Reentrant and thread-safe when each call uses its own FILE.
 * No global state. Caller owns every FILE. No heap allocation.
 *
 * Returns 0 on success, 1 on write error or invalid arguments.
 */

int shave_echo_builtin(int argc, char *const argv[]);
int shave_echo_builtin_fp(FILE *out, int argc, char *const argv[]);
int shave_echo_builtin_xpg(int argc, char *const argv[]);
int shave_echo_builtin_xpg_fp(FILE *out, int argc, char *const argv[]);

#ifdef __cplusplus
}
#endif

#endif
