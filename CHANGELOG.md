# Changelog

All notable changes to fork-tools will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **`fork-watcher`: critical bug.** The script called `git remote get-name`,
  which is not a real git subcommand. Every invocation silently fell through
  to the hardcoded `"origin"` string, so fork-watcher never actually watched
  the `upstream` remote. Replaced with `git remote get-url upstream` detection.
- **`fork-watcher`: missing fetch.** The script claimed to "fetch upstream
  without merging" but never actually ran `git fetch`, so `rev-list --count`
  operated on stale local tracking refs. Added the missing fetch.
- **`fork-check`: silent no-op by default.** Running `fork-check` with no
  `REPOS` env var would iterate an empty loop and exit 0, doing nothing.
  The script now auto-discovers forks by scanning `FORK_SEARCH_DIRS` for
  repos with an `upstream` remote, and exits with a clear error message
  when nothing can be found.
- **`tests/test-integration.sh`: typo.** `test_fork_report_empty` passed
  `FORF_SEARCH_DIRS` (typo) instead of `FORK_SEARCH_DIRS`, invalidating the
  assertion. Also strengthened the test to actually check the output.
- **`docs/api.md`: documented non-existent env vars.** `SEARCH_DIRS` and
  `NOTIFY_APP` for fork-watcher are hardcoded in the script and were never
  read from the environment. Removed from the documentation.
- **CI security-scan theater.** The `security` job used
  `git log … -- "*sh" | grep -i password … || true`, which is a pathspec
  filter, not a content filter, and would pass even with hard-coded secrets.
  Replaced with a real pattern-based scan that flags likely secrets and
  fails the build when found.
- **`fork-report.rb`: pinned `sha256`.** The Homebrew formula used
  `sha256 :no_check`, disabling tarball integrity verification. Pinned the
  real digest for the v1.0.0 GitHub release tarball.
- **README / CHANGELOG: test-count and coverage claims.** Previous releases
  claimed "176 tests passing (100% coverage)" — the real bats `@test` count
  was 163, coverage was never measured, and "`fork-check` tests" were
  grep-the-source substring checks that could not actually fail. Corrected
  to reflect the real honest counts after the rewrite.

### Added
- Optional [Charmbracelet Gum](https://github.com/charmbracelet/gum) integration
  for glamorous TUI output. Auto-detected at runtime; falls back to the existing
  plain ANSI output when unavailable.
  - `install.sh`: bordered banner, spinners during downloads, styled summary
  - `fork-report.sh`: styled scan progress header and summary (stderr only —
    stdout report is never touched)
  - `fork-watcher.sh`: styled fork list and watch-mode header
  - `fork-check.sh`: styled watch-mode header
- `NO_TUI` environment variable to opt out of Gum styling even when installed.
- `FORK_SEARCH_DIRS` environment variable support in `fork-check.sh` for
  customizing where auto-discovery scans.
- **Real behavior tests for `fork-check.sh`.** Replaced 38 grep-the-source
  theater tests (each of the form `grep -q "pattern" fork-check.sh`) with
  8 real tests that execute the script against temporary git fixtures and
  assert on its output and exit codes.

## [1.0.0] - 2026-01-14

### Platform Support
- macOS (Darwin)
- Linux (Debian, Ubuntu, Alpine, Arch)
- Windows (Git Bash, WSL)

### Dependencies
- Bash 4.0+
- Git 2.0+
- (Optional) jq for JSON processing
- (Optional) terminal-notifier for macOS notifications
- (Optional) [gum](https://github.com/charmbracelet/gum) for glamorous TUI styling

### Tests
- 31 bats unit tests for fork-report.sh
- 132 bats unit tests for fork-watcher.sh
- 25 integration test functions in test-integration.sh
- (Note: earlier versions claimed "176 tests passing (100% coverage)" —
  neither figure was accurate. See the [Unreleased] `Fixed` section.)

[1.0.0]: https://github.com/Evoke4350/homebrew-fork-tools/releases/tag/v1.0.0
