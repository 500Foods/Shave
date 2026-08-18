# Shave

This is the very start of a Bash-to-C transpiler. Why? Well, lots of bash scripts in the world could do with a bit of a boost, and nearly everything that a bash script is doing is often based on underlying C apps. So, having something that converts a Bash script into its native C environment would likely be a huge improvement performance-wise, and also introduces opportunities for obfuscation and other security aspects that can't be achieved easily through Bash alone.

## Table of Contents

- [Agents](./AGENTS.md) - Binding project opinions and contributor rules.
- [Requirements](./docs/REQUIREMENTS.md) - Details the tools and environment needed to run Shave.
- [Releases](./releases/RELEASES.md) - Chronological summary of all Shave releases.
- [Sitemap](./SITEMAP.md) - Directory of all Markdown files within the Shave project.
- [Testing](./TESTING.md) - Current suite, how to add tests, and the plan for growing coverage.

## Layout

- `shave/` is the transpiler itself: Bash scripts plus C sources.
- `shave-libs/` is for in-process replacements of frequent externals (`wc`, `cat`, and the like) so generated C does not fork the way Bash does.
- `tests/fixtures/` holds stable bash samples for later transpile comparison. Do not put those in `shave/`.
- `tests/unity/framework/` is the committed Unity 2.6.1 copy. Build trees stay local and gitignored.

## Testing

```bash
./tests/run-tests.sh
```

`0000` builds the CMake project, remaining suites run in parallel, and `9999` prints a cloc table at the end. A single id such as `./tests/run-tests.sh 0004` runs that suite alone. See [TESTING.md](./TESTING.md).

## Additional Notes

While this project is currently under active development, feel free to give it a try and post any issues you encounter. Or start a discussion if you would like to help steer the project in a particular direction. Early days yet, so a good time to have your voice heard. As the project unfolds, additional resources will be made available, including platform binaries, more documentation, demos, and so on.

## Sponsor / Donate / Support

If you find this work interesting, helpful, or valuable, or that it has saved you time, money, or both, please consider directly supporting these efforts financially via [GitHub Sponsors](https://github.com/sponsors/500Foods) or donating via [Buy Me a Pizza](https://www.buymeacoffee.com/andrewsimard500). Also, check out these other [GitHub Repositories](https://github.com/500Foods?tab=repositories&q=&sort=stargazers) that may interest you.

## Latest Test Results

Run `./tests/run-tests.sh` for the current summary table and cloc report. The July 2025 figures below are from the retired `oldtests/` suite and are no longer generated automatically.

### Last archived oldtests run

Generated on: Mon Jul  7 02:47:52 PDT 2025

| Status | Time | Test | Tests | Pass | Fail |
| ------ | ---- | ---- | ----- | ---- | ---- |
| ✅ | 00:00:03.370 | 90_markdown_links_check | 4 | 4 | 0 |
| ✅ | 00:00:06.457 | 99_static_codebase_analysis | 11 | 11 | 0 |
