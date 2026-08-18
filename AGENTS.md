# AGENTS

These instructions bind anyone working on Shave, especially agents that arrive with their own habits.

## Opinions

These are not suggestions. Do not debate them. Do not "just this once."

- **NO PYTHON IN THE PROJECT.** No Python scripts, no `python`/`python3` calls, no Python helpers, no Python in generated output. Use Bash, C, `jq`, or `tables`.
- **Default `shave-libs/` are GNU coreutils.** In-process replacements start with `wc`, `cat`, `echo`, and the rest of that set so generated C does not fork the way Bash does.
- **Tests for everything.** New behavior gets a `tests/NNNN/test.sh` in the same change. No coverage, no merge.
- **shellcheck clean.** No warnings, no errors. Exceptions only when critically necessary, with a justification on the line above. Prefer none.
- **cppcheck clean.** No warnings, no errors. Same exception rule as shellcheck. Prefer none.

## Tests

The live suite is `./tests/run-tests.sh`. See TESTING.md before adding or changing tests.

- Run `./tests/run-tests.sh` after any major update.
- Run `./tests/run-tests.sh NNNN` to iterate on one suite. That path does not run 0000 and does not print the summary table.
- Add new coverage as `tests/NNNN/test.sh`.
- 0000 is the CMake build gate. 9999 is the sequential cloc trailer. Everything else must be safe to run in parallel.
- 0001 is the durable CLI missing-input contract. Transpile samples live in `tests/fixtures/`, not `shave/`.
- `shave/` is the transpiler (Bash and C). `shave-libs/` is for in-process replacements of frequent externals so generated C does not fork.
- Unity lives in `tests/unity/framework/`. Build trees stay local and gitignored.
- Do not create a second orchestrator.

## Coding Habits

- Whenever updating a source code file (bash script, C source, etc.) be sure to update the CHANGELOG at the top each time.
- When adding log output messages, avoid using a trailing period at the end of the message. The period is unnecessary and can be distracting in log outputs.
- Generated C executables must be compressed with `upx -9`.

## Shellcheck

If you're presented with, or otherwise encounter, shellcheck issues, please follow these instructions

Please try to correct shellcheck issues by addressing the coding style rather than just adding exceptions.
Do not add cppcheck or shellcheck exceptions unless they are critically necessary. Those tools default to reasonable rules, so assume an exception is not needed and write code that passes the linters.
Try to address one at a time in order.
If you do add an exception, please also include an additional justification comment as to why you feel it is necessary.
Note that exceptions need to be placed on the line immediately prior to the line being excepted.

```bash
# shellcheck source=./shave-output.sh  # Essential for logging and output handling
# shellcheck disable=SC1091  # File path is dynamically determined at runtime
```

Often we find ourselves running through the list fixing them, only to find out after that none of them have actually been fixed.
Run the shellcheck command again after each to confirm that the number of outstanding issues is indeed shrinking.
Sometimes the shellcheck output doesn't match your version of the file, or what you think is the current version of the file.
After making a change and running shellcheck, be sure to reload the file in its current state so that you are properly in sync.
Suite 0004 fails on shellcheck warnings and errors, not style notes. Fix warnings in the same change that introduced them.

### Handling SC2155 Warnings

When addressing SC2155 warnings ("Declare and assign separately to avoid masking return values"), ensure that you declare the variable with `local` on one line, and then assign the value on a separate line without using `local` again. For example:

```bash
local my_variable
my_variable=$(some_command)
```

This separation prevents the assignment from masking the return value of the command, which is what shellcheck flags.

### Handling SC2004 Warnings

When addressing SC2004 warnings ("$/${} is unnecessary on arithmetic variables"), check for unnecessary use of `$` in arithmetic contexts, including array indices. Shellcheck flags `$` usage in places where the variable is treated as a number, such as inside `(( ))` or in array indices. For example, change:

```bash
array[$index]="value"
```

to:

```bash
array[index]="value"
```

This removes the unnecessary `$` prefix, resolving the warning. Ensure you address the actual line flagged by shellcheck rather than assuming it's related to nearby arithmetic operations.

### Handling SC2034 Warnings for Namerefs

When addressing SC2034 warnings ("variable appears unused"), particularly for nameref variables used to return arrays, ensure that the shellcheck disable directive is placed immediately before the line where the variable is assigned, not just where it is declared. Shellcheck may flag the assignment as the point of non-usage. For example:

```bash
local -n my_ref="$1"  # Declaration may not trigger warning
# ... other code ...
# shellcheck disable=SC2034
# Justification: Nameref used to return array to caller
my_ref=("some" "values")  # Assignment may trigger warning
```

This placement ensures that shellcheck recognizes the exception at the point where it reports the issue.
