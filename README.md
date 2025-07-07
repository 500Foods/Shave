# Shave

This is the very start of a Bash-to-C transpiler. Why? Well, lots of bash scripts in the world could do with a bit of a boost, and nearly everything that a bash script is doing is often based on underlying C apps. So, having something that converts a Bash script into its native C environment would likely be a huge improvement performance-wise, and also introduces opportunities for obfuscation and other security aspects that can't be achieved easily through Bash alone.

## Table of Contents

- [Recipe for Success](./RECIPE.md) - Guidelines for working on the Shave project, including shellcheck issue handling.
- [Requirements](./docs/REQUIREMENTS.md) - Details the tools and environment needed to run Shave.
- [Releases](./releases/RELEASES.md) - Chronological summary of all Shave releases.
- [Sitemap](./SITEMAP.md) - Directory of all Markdown files within the Shave project.
- [Tests](./tests/README.md) - Instructions on running tests and overview of test suites.

## Additional Notes

While this project is currently under active development, feel free to give it a try and post any issues you encounter. Or start a discussion if you would like to help steer the project in a particular direction. Early days yet, so a good time to have your voice heard. As the project unfolds, additional resources will be made available, including platform binaries, more documentation, demos, and so on.

## Sponsor / Donate / Support

If you find this work interesting, helpful, or valuable, or that it has saved you time, money, or both, please consider directly supporting these efforts financially via [GitHub Sponsors](https://github.com/sponsors/500Foods) or donating via [Buy Me a Pizza](https://www.buymeacoffee.com/andrewsimard500). Also, check out these other [GitHub Repositories](https://github.com/500Foods?tab=repositories&q=&sort=stargazers) that may interest you.

## Latest Test Results

Generated on: Mon Jul  7 02:47:52 PDT 2025

### Summary

| Metric | Value |
| ------ | ----- |
| Total Tests | 2 |
| Passed | 2 |
| Failed | 0 |
| Skipped | 0 |
| Total Subtests | 15 |
| Passed Subtests | 15 |
| Failed Subtests | 0 |
| Elapsed Time | 00:00:06.766 |
| Running Time | 00:00:09.827 |

### Individual Test Results

| Status | Time | Test | Tests | Pass | Fail |
| ------ | ---- | ---- | ----- | ---- | ---- |
| ✅ | 00:00:03.370 | 90_markdown_links_check | 4 | 4 | 0 |
| ✅ | 00:00:06.457 | 99_static_codebase_analysis | 11 | 11 | 0 |

## Repository Information

Generated via cloc: Mon Jul  7 02:47:52 PDT 2025

```cloc
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
Bourne Shell                    33           1027           1179           8884
Markdown                        23           1702             45           4228
YAML                             1              0              0              2
-------------------------------------------------------------------------------
SUM:                            57           2729           1224          13114
-------------------------------------------------------------------------------

CodeDoc: 2.1    CodeComment: 7.5
```
