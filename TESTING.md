# Testing Shave

This is the current test suite. New work belongs here.

## How to run

From the repository root:

```bash
./tests/run-tests.sh
```

Useful variants:

```bash
./tests/run-tests.sh --list
./tests/run-tests.sh 0004
./tests/run-tests.sh 1,3,5
./tests/run-tests.sh 1-10
./tests/run-tests.sh --sequential
./tests/run-tests.sh --jobs 4
./tests/run-tests.sh --skip-0000 0001
```

A single selected suite such as `./tests/run-tests.sh 0004` runs that suite alone: no 0000 gate, no summary table, and no trailer tables. Only that suite's output is printed.

A multi-suite run prints only the `tables` summary, then the 9998 coverage table and the 9999 cloc table. Per-suite logs go in `tests/logs/NNNN/`. Running 0000 clears `tests/logs/` first. That directory is gitignored.

Exit 0 only when every assertion passed. Otherwise the exit code is Fail+Skip.

## Layout

```text
tests/
  run-tests.sh      Orchestrator
  lib/harness.sh    Pass/fail/skip helpers and Unity runner
  lib/lint.sh       Shared exclude-list and last-result cache helpers
  lib/cloc.sh       cloc-to-tables renderer
  lib/coverage.sh   gcov-to-tables renderer for shave-libs
  0000/test.sh      Sequential CMake build gate
  0001/test.sh      CLI missing-input contract
  0002/test.sh      Unity version parser
  0003/test.sh      Cppcheck
  0004/test.sh      Shellcheck
  0005/             Echo builtin vs Bash (test.sh plus echo-builtin.sh; shave/shave writes the binary)
  0006/             Printf builtin vs Bash (test.sh plus printf-builtin.sh; shave/shave writes the binary)
  0007/test.sh      CLI output defaults and unchanged skip
  0008/             Echo/printf for-loop vs Bash (test.sh plus echo-printf-loop.sh; shave/shave writes the binary)
  0009/             Wc vs GNU wc (test.sh plus wc.sh; shave/shave writes the binary)
  9998/test.sh      Sequential gcov coverage trailer
  9999/test.sh      Final cloc table
  NNNN/test.sh      Later suites
  fixtures/         Shared later-transpile samples such as hello-world.sh
  unity/            Project Unity tests
    framework/      Committed Unity 2.6.1 (ThrowTheSwitch)
shave/              Transpiler source (Bash and C)
shave-libs/         In-process replacements for frequent externals (shave_wc, shave_echo_builtin, ...)
VERSION             Project version used by CMake and the summary title
```

Each suite is a four-digit directory with an executable `test.sh`.

## Execution model

1. **0000 first.** Configures and builds the CMake project, including Unity binaries. If 0000 fails, remaining suites are skipped. `--skip-0000` is for debugging only.
2. **Parallel middle.** Every other `NNNN/test.sh` except 9998 and 9999 runs via `xargs -P "$(nproc)"`. Suites must be independent. Each suite writes gcov data under `tests/logs/NNNN/gcda`.
3. **9998 then 9999.** Always sequential trailers. 9998 merges gcov data from the prior suites and prints the coverage table after the summary. 9999 prints the cloc table after that.

The summary table has Test, Name, Time, Pass, Fail, Skip, and Status. Name comes from the `# Test NNNN:` header in that suite's `test.sh`. Status is PASS only when every assertion passed. Any fail or skip makes the suite FAIL. A hidden `group` column inserts a separator every ten test numbers.

The last row is totals: Test is the zero-padded suite count, Name is `Test Suite Totals`, Time is the summed run time, Pass/Fail/Skip are sums, and Status is PASS only when every suite passed. Totals-row values are bold.

The title is left-aligned as `Shave vX.Y.Z Results for YYYY-Mon-DD`, with `Shave` and `Results for` in the same color as the footer labels. Title and footer text are bold. The footer shows wall time, summed run time, and suites passed/failed with a percentage. Labels, values, and punctuation use different colors.

A suite is one of:

- **Bash comparison** — run Bash or the Shave CLI and assert exit status and output
- **Unity** — compile via CMake in 0000, then run the binary with `shave_run_unity`
- **Static analysis** — cppcheck, shellcheck, or similar project-wide checks
- **Report** — 9999-style end-of-run tables

## Current suites

| ID | Name | Role |
| -- | ---- | ---- |
| 0000 | CMake project build | Gate. Configure/build CMake, verify `shave-version`, libraries, and Unity binaries |
| 0001 | CLI missing input | `shave/shave` with no operand exits non-zero and names the missing input |
| 0002 | Unity version parser | Run `build/tests/test_version` |
| 0003 | Cppcheck C analysis | Lint project C/H files using `.lintignore` and `.lintignore-c`; last-result cache in `~/.cache/Shave/0003` |
| 0004 | Shellcheck analysis | Lint project `*.sh` files; fail on warning/error, not style notes; last-result cache in `~/.cache/Shave/0004` |
| 0005 | Echo builtin | Unity contract for `shave_echo_builtin`, then `shave/shave echo-builtin.sh` and byte-compare the generated binary to the script |
| 0006 | Printf builtin | Unity contract for `shave_printf_builtin`, then `shave/shave printf-builtin.sh` and byte-compare the generated binary to the script |
| 0007 | CLI output and skip | Default binary plus `.c`, `-o`/`-c`, and skip when bash/toolchain/outputs are unchanged |
| 0008 | Echo printf loop | `shave/shave` a 5-iteration `for` that calls echo and printf; byte-compare the generated binary to the script |
| 0009 | Wc | Unity contract for `shave_wc`, then `shave/shave wc.sh` and byte-compare the generated binary to the script |
| 9998 | Coverage | Sequential gcov report for instrumented `shave-libs` sources; PASS at >= 50% lines, FAIL below |
| 9999 | CLOC summary | Sequential end report via `tables` |

## Adding a suite

1. Create `tests/NNNN/` with the next free number below 9999.
2. Add an executable `test.sh` whose first comment is `# Test NNNN: Short name`.
3. Source `tests/lib/harness.sh`.
4. Call `shave_test_init`, assertions, then `shave_test_finish`.
5. Keep the suite independent of siblings. Shared helpers go in `tests/lib/`.
6. Unity and shared libraries belong in CMake/0000. Suite comparison binaries come from `shave/shave`, not CMake.
7. Run `./tests/run-tests.sh NNNN` while writing it, then `./tests/run-tests.sh` before finishing.

```bash
#!/usr/bin/env bash
# Test 0010: Example
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "${TEST_DIR}/.." && pwd)"
# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "${TESTS_DIR}/lib/harness.sh"

shave_test_init "0010" "example"
shave_assert_eq "expected" "expected" "values match"
shave_test_finish
exit $?
```

Do not invent a second orchestrator.

## Result contract

Each `test.sh` must print:

```text
TEST NNNN short_name
  PASS message
  FAIL message
  SKIP message
RESULT NNNN name=short_name passed=N failed=N skipped=N
```

The display name comes from the `# Test NNNN:` header. Exit 0 when `failed=0`. The orchestrator still marks the suite FAIL if any assertion failed or was skipped.

## Conventions

- Update the CHANGELOG at the top of a script when you change it
- Do not put a trailing period on log or assertion messages
- Do not add cppcheck or shellcheck exceptions unless they are critically necessary
- Those tools default to reasonable rules. Write code that passes them. Assume an exception is not needed
- If a disable is still required, put it on the line above the finding and add a justification comment
- Shellcheck suite 0004 fails on `warning` and `error` only
- 0003 and 0004 cache last per-file results under `~/.cache/Shave/0003` and `~/.cache/Shave/0004`. Unchanged files replay the last output so a prior fail still counts as a fail. The cache is keyed by tool version and options; a key change wipes that suite's cache
- Generated C executables are compressed with `upx -9`
- 9998 fails any instrumented `shave-libs` source under 50% gcov line coverage. The Pass column is assertion count, not file count. The coverage table lists one row per instrumented source.

## Plan

Use this suite as the product grows. Do not wait until the transpiler is "done."

### Near term

- Keep 0000 as the only build gate. New compiled artifacts must appear there.
- Grow Unity coverage in `tests/unity/` for C helpers such as version parsing, later CST/combiner logic, and generated-code contracts.
- Keep 0001 as the missing-input CLI contract. It does not transpile and should stay green while the app grows. 0007 covers default output paths and skip. Add sibling CLI suites for version, debug/keep flags, and sourced-file discovery.
- Put shared later-transpile samples under `tests/fixtures/`, not in `shave/`. `hello-world.sh` is the first shared sample. Suite-specific comparison scripts live in that suite folder beside `test.sh`.
- 0000 must not wipe the CMake tree. `cmake --build` is incremental and should skip unchanged targets.
- Treat 0003 and 0004 as merge gates. Fix new warnings in the same change that introduced them.
- Leave 9998 and 9999 as sequential trailers. 9998 is coverage and is a merge gate at 50% per instrumented `shave-libs` file. 9999 is cloc. Do not put reports in the parallel band.

### As codegen becomes real

Echo, printf, and wc generation are live from the tree-sitter CST: `shave/shave script.sh` writes `script.c` plus a UPX-compressed `script` beside the input. 0005 and 0006 are the builtin transpile comparisons. 0008 is the first loop comparison. 0009 is the first coreutils comparison. Remaining work:

1. **Suite comparison samples** beside `tests/NNNN/test.sh` with expected stdout/stderr/exit status. `0005/echo-builtin.sh`, `0006/printf-builtin.sh`, `0008/echo-printf-loop.sh`, and `0009/wc.sh` are the first feature samples.
2. **Transpile comparison suites** that run the Bash original and the `shave/shave` binary against the same sample. 0005, 0006, 0008, and 0009 are the first of these.
3. **Unity tests** against generated C helpers once those helpers exist as libraries rather than one-off mains.
4. **Self-hosting later**, not first. Do not make 0000 depend on Shave compiling itself until fixture comparisons are green.

Number those suites in the 0010–0899 range. Keep 09xx for project-wide quality if needed. Keep 9998 and 9999 as the trailers.

### What not to do

- Do not make suites share writable files. Parallel runs will collide.
- Do not skip 0000 in CI or after CMake/source changes.
- Do not treat SKIP as a soft pass. SKIP fails the suite and counts in the exit code.
- Do not use Python. Escape JSON and render tables in Bash or with `jq`/`tables`.

### Working agreement

After any change that can affect behavior, run `./tests/run-tests.sh`. After a focused test change, `./tests/run-tests.sh NNNN` is enough while iterating, then run the full suite before stopping. AGENTS.md repeats this for agent sessions.
