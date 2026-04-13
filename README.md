# fork-tools

Keep your Git forks fresh and up-to-date. Generate beautiful status reports, track upstream changes, and never miss an update.

## Installation

### Homebrew (Recommended)

```bash
brew tap Evoke4350/fork-tools
brew install fork-report
```

### One-line Installer

```bash
curl -fsSL https://raw.githubusercontent.com/Evoke4350/homebrew-fork-tools/main/install.sh | sh
```

### Manual

```bash
curl -fsSL https://raw.githubusercontent.com/Evoke4350/homebrew-fork-tools/main/fork-report.sh -o fork-report
chmod +x fork-report
sudo mv fork-report /usr/local/bin/
```

## Quick Start

```bash
# Set your GitHub usernames
export GITHUB_USERNAMES="yourname orgname"

# Generate a report
fork-report > ~/fork-status.md

# View the report
cat ~/fork-status.md
```

## Tools

| Tool | Description |
|------|-------------|
| `fork-report` | Generate Markdown/JSON status reports |
| `fork-check` | Quick upstream check with watch mode |
| `fork-watcher` | Auto-discover forks and monitor changes |

### fork-report

```bash
# Show help and version
fork-report --help
fork-report --version

# Generate report
GITHUB_USERNAMES="yourname" fork-report

# Custom search directories
FORK_SEARCH_DIRS="~/projects:~/work" fork-report

# Save to file
fork-report > ~/fork-report.md

# JSON output for scripting
fork-report json | jq '.forks[] | select(.behind > 0)'
```

### fork-check

```bash
# Check once
fork-check

# Watch mode (every 5 minutes)
fork-check 300

# Check specific repos
REPOS="~/project1 ~/project2" fork-check
```

### fork-watcher

```bash
# List tracked forks
fork-watcher --list

# Watch mode
fork-watcher 300
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GITHUB_USERNAMES` | Space-separated GitHub usernames | empty |
| `FORK_SEARCH_DIRS` | Colon-separated directories to search | `~:~/dev:~/projects:~/src` |
| `GITHUB_TOKEN` | Optional GitHub token for API access | - |
| `NO_COLOR` | Disable colored output | false |
| `NO_TUI` | Disable [Gum](https://github.com/charmbracelet/gum) TUI styling even if installed | false |

## Optional: Glamorous TUI (Gum)

fork-tools auto-detects [Charmbracelet Gum](https://github.com/charmbracelet/gum)
and uses it for fancier banners, spinners, and styled progress messages if
present. It's completely optional — without Gum you get the same plain ANSI
output as before.

```bash
# macOS / Linuxbrew
brew install gum

# Debian / Ubuntu
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum
```

Gum is automatically disabled when:

- `stdout` / `stderr` is not a terminal (piped output, cron, CI)
- `NO_COLOR` or `NO_TUI` is set
- `TERM=dumb`

In `fork-report`, Gum output is strictly confined to `stderr`, so the Markdown
or JSON report on `stdout` is always byte-for-byte identical whether or not
Gum is installed — safe for piping into `jq`, `> file.md`, or `| glow`.

## Development

### Prerequisites

```bash
# Install dependencies
brew install bats shellcheck

# Or on Linux
sudo apt-get install bats shellcheck
```

### Testing

```bash
# Run all tests
make test

# Run specific test suites
make test-unit
make test-integration

# Run tests with verbose output
make test-verbose

# Run linting
make lint

# Syntax check
make syntax-check

# Full build pipeline
make build
```

### Docker Testing

```bash
# Run tests in Docker
make docker-test

# Run all Docker tests (multi-platform)
make docker-all

# Or use Docker Compose directly
docker compose -f docker-compose.test.yml up --build
```

### Makefile Commands

```bash
make help              # Show all available commands
make lint              # Run shellcheck
make test              # Run all tests
make docker-test       # Run tests in Docker
make ci                # Run full CI pipeline
make clean             # Remove build artifacts
```

## Output Formats

### Markdown

```markdown
# Repo Status Report

## Summary

| Metric | Count |
|--------|-------|
| Your Forks | 12 |
| With Upstream | 8 |
| Needs Update | 3 |

## Your Forks

| Repo | Path | Branch | Status | Behind | Ahead |
|------|------|--------|--------|--------|-------|
| my-project | ~/projects/my-project | main | ⬇️ | 5 | 0 |
```

### JSON

```json
{
  "version": "1.0.0",
  "generated_at": "2026-01-14T12:00:00Z",
  "forks": [
    {
      "name": "my-project",
      "path": "/Users/you/projects/my-project",
      "status": "clean",
      "branch": "main",
      "ahead": 0,
      "behind": 5
    }
  ]
}
```

## Status Icons

| Icon | Meaning |
|------|---------|
| ✅ | Clean, up to date |
| 🔴 | Dirty working copy |
| ⬆️ | Ahead of upstream |
| ⬇️ | Behind upstream |

## Examples

### Find repos needing updates

```bash
fork-report json | jq '.forks[] | select(.behind > 0)'
```

### Count dirty repos

```bash
fork-report json | jq '[.forks[] | select(.status == "dirty")] | length'
```

### Sync all forks with upstream

```bash
fork-report json | jq -r '.forks[].path' | while read repo; do
  echo "Updating $repo..."
  cd "$repo" && git fetch upstream && git rebase upstream/main
done
```

### Daily cron job

```bash
# Add to crontab: crontab -e
0 9 * * * fork-report > ~/fork-reports/$(date +%Y%m%d).md
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Check fork status
  run: |
    GITHUB_USERNAMES="${{ github.repository_owner }}" fork-report json
```

### Git Hook

```bash
# .git/hooks/post-merge
fork-report | grep "⬇️" && echo "⚠️  Upstream updates available!"
```

## Troubleshooting

**No forks found?**
- Set `GITHUB_USERNAMES` environment variable
- Check `FORK_SEARCH_DIRS` includes your repo locations

**Permission denied?**
- Make scripts executable: `chmod +x *.sh`

**Git commands failing?**
- Verify repos are valid Git repositories
- Check network connectivity for `git fetch`

## Changelog

### v1.0.0 (2026-01-14)

- Initial stable release
- 163 bats unit tests for `fork-report` and `fork-watcher`, plus 8 behavior
  tests for `fork-check` and 25 integration tests
- JSON output with full escaping for control characters
- Cross-platform support (macOS, Linux, Windows Git Bash)
- Docker test infrastructure
- CI/CD pipeline with GitHub Actions

## License

MIT License - Copyright (c) 2026 Evoke4350

## Links

- [GitHub](https://github.com/Evoke4350/homebrew-fork-tools)
- [Documentation](https://evoke4350.github.io/homebrew-fork-tools)
- [Report Issues](https://github.com/Evoke4350/homebrew-fork-tools/issues)
