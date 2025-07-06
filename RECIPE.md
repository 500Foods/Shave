# RECIPE FOR SUCCESS

These instructions should form a guide to others working on this project, particularly AI models that have their own opinions
on how things should be done. These could be loaded up initially as part of the initial prompt in such scenarios, particularly
in agentic workflows where the AI is just as likely to run off and burn things down to the ground as it is to make useful changes.

## Tests

A comprehensive test suite is available in the tests folder. test_00_all.sh should be run after any major updates to ensure
that everything is still in good working order.

## Releases

In release/RELEASES.md you will find comprehensive instructions on how to update and otherwise manage release notes.
Please try not to deviate from the instructions in that file.

## Coding Habits

- Whenever updating a source code file (bash script, C source, etc.) be sure to update the CHANGELOG at the top each time.
- When adding log output messages, avoid using a trailing period at the end of the message. The period is unnecessary and can be distracting in log outputs.

## Shellcheck

If you're presented with, or otherwise encounter, shellcheck issues, please follow these instructions

Please try to correct shellcheck issues by addressing the coding style rather than just adding exceptions.
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
