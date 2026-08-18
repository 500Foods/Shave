# Testing Shave

This is the current test suite. `oldtests/` is the previous framework, kept only as reference.

## How to run

From the repository root:

```bash
./tests/run-tests.sh
```

Useful variants:

```bash
./tests/run-tests.sh --list
./tests/run-tests.sh 0001
./tests/run-tests.sh 1,3,5
./tests/run-tests.sh 1-10
./tests/run-tests.sh --sequential
./tests/run-tests.sh --jobs 4
./tests/run-tests.sh --skip-0000 0001
```

`run-tests.sh` prints only a `tables` summary. Per-suite output is written to `tests/logs/NNNN/`. Running `0000` clears `tests/logs/` first. That directory is gitignored.

## Layout

```text
tests/
  run-tests.sh      Orchestrator
  lib/harness.sh    Shared pass/fail/skip helpers
  0000/test.sh      Sequential CMake project build gate
  0001/test.sh      First parallel suite
  NNNN/test.sh      Later suites
```

Each suite is a four-digit directory with a `test.sh` entry point.

## Execution model

`run-tests.sh` always runs `0000` first, unless `--skip-0000` is passed. `0000` configures and builds the CMake project. If `0000` fails, remaining suites are skipped.

After `0000` passes, every other discovered `NNNN/test.sh` runs in parallel via `xargs -P "$(nproc)"`. Suites must be independent. Use `--sequential` or `--jobs 1` when debugging.

The summary table has Test, Name, Time, Pass, Fail, Skip, and Status. Name comes from the `# Test NNNN:` header in that suite's `test.sh`. Status is PASS only when every assertion passed. Any fail or skip makes the suite FAIL. The title is left-aligned as `Shave vX.Y.Z Results for YYYY-Mon-DD`. The footer shows wall time, summed run time, and suites passed/failed with a percentage. The process exits 0 when every assertion passed; otherwise the exit code is Fail+Skip.

A suite can be a:

- **Bash comparison test** — run a Bash script (or Shave CLI) and assert exit status and output
- **Unity test** — compile and run a C unit test once generated C exists

`0001` is a bash comparison smoke test: it runs `shave/shave-test.sh` and checks that `shave.sh` rejects a missing input file.

## Adding a suite

1. Create `tests/NNNN/` with the next free number.
2. Add an executable `test.sh`.
3. Source `tests/lib/harness.sh`.
4. Call `shave_test_init`, assertions, then `shave_test_finish`.

```bash
#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$TEST_DIR/.." && pwd)"
# shellcheck source=../lib/harness.sh
# shellcheck disable=SC1091
# Justification: harness path is derived from this suite directory at runtime
source "$TESTS_DIR/lib/harness.sh"

shave_test_init "0010" "example"

shave_assert_eq "expected" "expected" "values match"
# or compile/run a Unity binary and assert its output

shave_test_finish
exit $?
```

Keep suites focused. Put shared helpers in `tests/lib/`, not in `0000`.

## Result contract

Each `test.sh` should print:

```text
TEST NNNN short_name
  PASS message
  FAIL message
  SKIP message
RESULT NNNN name=short_name passed=N failed=N skipped=N
```

The suite display name comes from the `# Test NNNN:` header in that `test.sh`. Exit `0` when `failed=0`. The orchestrator still marks a suite FAIL if any assertion failed or was skipped.

## Conventions

- Update the CHANGELOG at the top of a test script when you change it
- Do not put a trailing period on log or assertion messages
- Prefer fixing shellcheck findings over adding exceptions
- If a `shellcheck disable` is required, put it on the line above the finding and add a justification comment
