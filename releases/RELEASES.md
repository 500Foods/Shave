# Releases

This document provides a chronological overview of all Shave releases. Each entry includes a brief summary with links to detailed release notes.

<!--
CRITICAL INSTRUCTIONS

Step 1: Gather Changes
- Use git log to list ALL changed files for the day with the numbers representing the number of lines added or removed:
  ```
  git log --since="2025-04-04 00:00" --until="2025-04-04 23:59" --numstat --pretty=format: | awk '{add[$3]+=$1; del[$3]+=$2} END {for (f in add) printf "%d\t%d\t%s\n", add[f], del[f], f}' | sort -rn
  ```
- Group files by subsystem/component
- For each significant component, examine detailed changes. Please request one file at a time as these can be quite large.
- Any file with more than 25 lines changed should guarantee an entry in the release notes, though lesser changes could qualify
  ```
  git log --since="YYYY-MM-DD 00:00" --until="YYYY-MM-DD 23:59" -p -- path/to/component
  ```

Step 2: Document Changes
- Keep entries concise and factual
- Focus on WHAT changed, not WHY
- Avoid marketing language ("comprehensive", "robust", etc.)
- Include links to key source files (2-3 per major change)
- Group related changes under clear topic headings

Step 3: Structure Format
- Start with topic heading (e.g., "Parsing", "Testing")
- List specific changes as bullet points
- Include links to significant files in bullet points
- Example:
  ```
  1. Parser
  - Added handler for echo (shave/shave-parser.sh)
  - Added handler for ls (shave/shave-parser.sh)
  ```

Step 4: Quality Checks
- Verify all major changes are documented
- Ensure links point to actual changed files
- Confirm grouping is logical
- Remove any speculation or marketing language
- Keep focus on technical changes

Remember:
- This is a technical record, not marketing
- Every statement should be backed by commit evidence
- Include links to 2-3 key files per major change
- Group by topic to maintain clarity
- Release notes are organized by year and month in the `releases/` directory:
- `releases/YYYY-MM/YYYY-MM-DD.md` - Detailed release notes for each day
- Each monthly folder contains individual markdown files for each release day
- This file serves as the master index with one-line summaries and links to full details
-->

## 2025

### July 2025

- **2025-07-05** - [Version 0.1.0: Initial Shave transpiler setup](2025-07/2025-07-05.md) - First release with basic Bash-to-C transpiler structure and command-line parsing
