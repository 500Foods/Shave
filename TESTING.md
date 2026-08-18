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

A single selected suite such as `./tests/run-tests.sh 0004` runs that suite alone: no 0000 gate, no summary table, and no cloc table. Only that suite's output is printed.

A multi-suite run prints only the `tables` summary, then the 9999 cloc table. Per-suite logs go in `tests/logs/NNNN/`. Running 0000 clears `tests/logs/` first. That directory is gitignored.

Exit 0 only when every assertion passed. Otherwise the exit code is Fail+Skip.

## Layout

```text
tests/
  run-tests.sh      Orchestrator
  lib/harness.sh    Pass/fail/skip helpers and Unity runner
  lib/lint.sh       Shared exclude-list and last-result cache helpers
  lib/cloc.sh       cloc-to-tables renderer
  0000/test.sh      Sequential CMake build gate
  0001/test.sh      CLI missing-input contract
  0002/test.sh      Unity version parser
  0003/test.sh      Cppcheck
  0004/test.sh      Shellcheck
  9999/test.sh      Final cloc table
  NNNN/test.sh      Later suites
  fixtures/         Stable bash samples for later transpile comparison
  unity/            Project Unity tests
    framework/      Committed Unity 2.6.1 (ThrowTheSwitch)
shave/              Transpiler source (Bash and C)
shave-libs/         In-process replacements for frequent externals (wc, cat, ...)
VERSION             Project version used by CMake and the summary title
```

Each suite is a four-digit directory with an executable `test.sh`.

## Execution model

1. **0000 first.** Configures and builds the CMake project, including Unity binaries. If 0000 fails, remaining suites are skipped. `--skip-0000` is for debugging only.
2. **Parallel middle.** Every other `NNNN/test.sh` except 9999 runs via `xargs -P "$(nproc)"`. Suites must be independent.
3. **9999 last.** Always sequential. Generates the cloc table and prints it after the summary.

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
| 0000 | CMake project build | Gate. Configure/build CMake, verify `shave-version` and Unity binaries |
| 0001 | CLI missing input | `shave.sh` with no operand exits non-zero and names the missing input |
| 0002 | Unity version parser | Run `build/tests/test_version` |
| 0003 | Cppcheck C analysis | Lint project C/H files using `.lintignore` and `.lintignore-c`; last-result cache in `~/.cache/Shave/0003` |
| 0004 | Shellcheck analysis | Lint project `*.sh` files; fail on warning/error, not style notes; last-result cache in `~/.cache/Shave/0004` |
| 9999 | CLOC summary | Sequential end report via `tables` |

## Adding a suite

1. Create `tests/NNNN/` with the next free number below 9999.
2. Add an executable `test.sh` whose first comment is `# Test NNNN: Short name`.
3. Source `tests/lib/harness.sh`.
4. Call `shave_test_init`, assertions, then `shave_test_finish`.
5. Keep the suite independent of siblings. Shared helpers go in `tests/lib/`.
6. If it needs a compiled binary, add that target to CMake and assert it in 0000.
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

## Plan

Use this suite as the product grows. Do not wait until the transpiler is "done."

### Near term

- Keep 0000 as the only build gate. New compiled artifacts must appear there.
- Grow Unity coverage in `tests/unity/` for C helpers such as version parsing, later CST/combiner logic, and generated-code contracts.
- Keep 0001 as the missing-input CLI contract. It does not transpile and should stay green while the app grows. Add sibling CLI suites for help, version, debug/keep flags, and sourced-file discovery.
- Put transpile fixtures under `tests/fixtures/`, not in `shave/`. `hello-world.sh` is the first sample.
- Treat 0003 and 0004 as merge gates. Fix new warnings in the same change that introduced them.
- Leave 9999 last. If another end-of-run report is needed, add it to 9999 or add 9998 as another sequential trailer. Do not put reports in the parallel band.

### As codegen becomes real

The current pipeline still emits `printf` wrappers. When real C generation starts, add suites in this order:

1. **Fixture bash scripts** under `tests/fixtures/` with expected stdout/stderr/exit status.
2. **Transpile comparison suites** that run the Bash original and the Shave-built binary against the same fixture.
3. **Unity tests** against generated C helpers once those helpers exist as libraries rather than one-off mains.
4. **Self-hosting later**, not first. Do not make 0000 depend on Shave compiling itself until fixture comparisons are green.

Number those suites in the 0010–0899 range. Keep 09xx for project-wide quality if needed. Keep 9999 as the trailer.

### What not to do

- Do not make suites share writable files. Parallel runs will collide.
- Do not skip 0000 in CI or after CMake/source changes.
- Do not treat SKIP as a soft pass. SKIP fails the suite and counts in the exit code.
- Do not use Python. Escape JSON and render tables in Bash or with `jq`/`tables`.

### Working agreement

After any change that can affect behavior, run `./tests/run-tests.sh`. After a focused test change, `./tests/run-tests.sh NNNN` is enough while iterating, then run the full suite before stopping. AGENTS.md repeats this for agent sessions.
