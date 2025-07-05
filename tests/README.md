# Shave Tests

This document provides an overview of the testing framework for Shave, a Bash-to-C transpiler. It includes instructions on how to run the tests and a summary of the available test scripts and resources within the tests folder.

## Running Tests

To run the tests for Shave, follow these steps:

1. **Ensure Dependencies**: Make sure all necessary dependencies are installed. Refer to the main project documentation for setup instructions.
2. **Navigate to Project Root**: Open a terminal and navigate to the root directory of the Shave project.
3. **Execute Test Command**: Run the test suite using the command:

   ```bash
   ./tests/test_00_all.sh
   ```

   This script will execute a comprehensive set of tests and output the results to the terminal. Results are also saved in the `results` directory for later review.

**Note**: If the test script or setup process changes, this document will be updated accordingly. Check the main project repository for the latest instructions if you encounter issues.

## Available Test Scripts

Below is a list of the primary test scripts available in the Shave project. Each script focuses on specific aspects of the project or its documentation.

- **test_00_all.sh**: A master test script that likely runs a full suite of tests across the Shave project. This is the primary entry point for running all tests.
- **test_90_check_links.sh**: A specialized test script focused on validating links within the project's Markdown files, ensuring documentation integrity.
- **test_99_codebase.sh**: A test script that appears to analyze or validate the codebase, potentially checking for coding standards or other metrics.

## Table Tests

Within the `lib/tables-tests/` directory, there is a detailed set of test scripts specifically for testing table formatting and rendering, which may be used in documentation or output generation:

- **tables_test_01_basic.sh** to **tables_test_09_showcase.sh**: A series of test scripts that cover various aspects of table handling, from basic formatting to complex layouts, titles, footers, and showcasing capabilities. These scripts test the functionality of the `tables.sh` library script.
- **tables_tests.sh**: Likely a wrapper script to run all table-related tests collectively.

## Supporting Libraries

The `lib/` directory contains utility scripts that support the testing framework:

- **cloc.sh**: Counts lines of code, possibly used for codebase analysis in tests.
- **env_utils.sh**: Provides environment-related utility functions for test scripts.
- **file_utils.sh**: Offers file manipulation utilities used by test scripts.
- **framework.sh**: Core testing framework functions that other test scripts rely on.
- **github-sitemap.sh**: May generate or validate sitemaps for GitHub documentation.
- **lifecycle.sh**: Manages test lifecycle events or phases.
- **log_output.sh**: Handles logging and output formatting for test results.
- **network_utils.sh**: Provides network-related utilities for tests that may require connectivity.
- **tables.sh**: A library for generating and formatting tables, extensively tested by the scripts in `lib/tables-tests/`.

## Test Results

The `results/` directory stores output files from test runs, which can be reviewed for detailed analysis:

- **latest_test_results.md**: Contains the most recent test results in Markdown format for easy reading.
- **repository_info.md**: Provides information about the repository, possibly generated during codebase tests.
- **large_files_*.txt** and **source_line_counts_*.txt**: Text files with metrics about large files and line counts in the source code.
- **markdown_links_check_*.log**: Logs from the link checking test, detailing any issues found with documentation links.
- **subtest_*.txt**: Individual subtest results for specific test scripts like link checking and codebase analysis.

## Adding New Tests

If you are contributing to Shave and wish to add new tests:

1. Create test files in the appropriate subdirectory within the `tests` folder, such as `lib/tables-tests/` for table-related tests.
2. Update the relevant wrapper script (e.g., `test_00_all.sh` or `tables_tests.sh`) to include your new test cases.
3. Document the purpose of the new tests in this README if they introduce a new test category or significant functionality.

## Reporting Issues

If you encounter failures or unexpected behavior while running tests, please report them by opening an issue on the [Shave GitHub repository](https://github.com/500Foods/Shave/issues). Include details about the test failure, environment, and steps to reproduce the issue.
