# fork-tools - Git Fork Management Skill

Comprehensive skill for managing Git forks, tracking upstream changes, and keeping repositories synchronized.

## Overview

**fork-tools** provides three utilities for managing forked Git repositories:

| Tool | Purpose | Usage |
|------|---------|-------|
| `fork-report` | Generate Markdown/JSON reports of fork status | One-shot status reports |
| `fork-check` | Quick check for upstream updates | Fast status checks |
| `fork-watcher` | Auto-discover forks and monitor changes | Continuous monitoring |

## Environment Setup

```bash
# Required environment variables
export GITHUB_USERNAMES="yourusername orgname"  # Your GitHub usernames
export FORK_SEARCH_DIRS="~/projects:~/work:~/src"  # Directories to search

# Optional
export GITHUB_TOKEN="ghp_xxx"  # For GitHub API access
export NO_COLOR=1                # Disable colored output
```

## Tool Reference

### fork-report

Generate beautiful status reports of all forks.

**Synopsis:**
```bash
fork-report [OPTIONS] [FORMAT]
```

**Options:**
- `-h, --help` - Show help
- `-v, --version` - Show version
- `--config` - Show current configuration

**Formats:**
- `markdown` (default) - Markdown table report
- `json` - JSON structured output

**Examples:**
```bash
# Basic report
fork-report

# Save to file
fork-report > status.md

# JSON output
fork-report json | jq '.forks[] | select(.behind > 0)'

# With custom directories
FORK_SEARCH_DIRS="~/projects:~/work" fork-report
```

**Output Schema (JSON):**
```json
{
  "version": "1.0.0",
  "forks": [
    {
      "name": "repo-name",
      "path": "/full/path/to/repo",
      "status": "clean|dirty",
      "branch": "main",
      "ahead": 0,
      "behind": 5,
      "latest_commit": "abc123 message",
      "origin": "https://github.com/user/repo.git",
      "upstream": "https://github.com/original/repo.git"
    }
  ]
}
```

### fork-check

Quick check for upstream updates.

**Synopsis:**
```bash
fork-check [watch_interval]
```

**Usage:**
```bash
# Single check
fork-check

# Watch mode (check every 5 minutes)
fork-check 300
```

### fork-watcher

Auto-discover forks and monitor for changes.

**Synopsis:**
```bash
fork-watcher [watch_interval]
```

**Options:**
- `--list` - List all tracked forks

**Usage:**
```bash
# List forks
fork-watcher --list

# Watch mode
fork-watcher 300
```

## Common Workflows

### Check All Forks for Updates

```bash
# Generate report
GITHUB_USERNAMES="myuser" fork-report > status.md

# View repos needing updates
fork-report json | jq '.forks[] | select(.behind > 0) | {name, behind}'
```

### Sync All Forks with Upstream

```bash
# Get list of forks behind upstream
fork-report json | jq -r '.forks[] | select(.behind > 0) | .path' | while read repo; do
  echo "Updating $repo..."
  cd "$repo" && git fetch upstream && git rebase upstream/main
done
```

### Find Dirty Working Copies

```bash
fork-report json | jq '.forks[] | select(.status == "dirty") | {name, path}'
```

### Count Repos Ahead of Upstream

```bash
fork-report json | jq '[.forks[] | select(.ahead > 0)] | length'
```

### Monitor Forks Continuously

```bash
# Check every 10 minutes, notify on changes
fork-watcher 600
```

## Status Indicators

| Icon | Meaning | Action |
|------|---------|--------|
| ✅ | Clean, up to date | None needed |
| 🔴 | Dirty working copy | Commit or stash changes |
| ⬆️ | Ahead of upstream | Push commits |
| ⬇️ | Behind upstream | Pull/rebase with upstream |

## Fork Detection

A repository is considered a fork if:
1. It has an `upstream` remote configured, OR
2. Its `origin` URL contains one of your `GITHUB_USERNAMES`

**Adding upstream remote:**
```bash
cd your-fork
git remote add upstream https://github.com/original/repo.git
git fetch upstream
```

## Installation

### Homebrew (Recommended)
```bash
brew tap Evoke4350/fork-tools
brew install fork-report
```

### Manual
```bash
curl -fsSL https://raw.githubusercontent.com/Evoke4350/homebrew-fork-tools/main/fork-report.sh -o fork-report
chmod +x fork-report
sudo mv fork-report /usr/local/bin/
```

## Platform Support

- **macOS** - Full support, native notifications
- **Linux** - Full support
- **Windows (Git Bash)** - Full support, no notifications

## Troubleshooting

### No forks found
- Set `GITHUB_USERNAMES` environment variable
- Ensure `FORK_SEARCH_DIRS` includes your repo locations
- Check that repos have `origin` remote configured

### Permission denied
- Ensure scripts are executable: `chmod +x fork-report.sh`

### Git commands failing
- Verify repos are valid Git repositories
- Check network connectivity for `git fetch`

## Advanced Usage

### Daily Cron Job
```bash
# Add to crontab
0 9 * * * fork-report > ~/fork-reports/$(date +\%Y\%m\%d).md
```

### CI/CD Integration
```yaml
- name: Check fork status
  run: |
    GITHUB_USERNAMES="$GITHUB_REPOSITORY_OWNER" fork-report json
```

### Git Hook Integration
```bash
# .git/hooks/post-merge
fork-report | grep "⬇️" && echo "Upstream updates available!"
```

## Best Practices

1. **Always set `GITHUB_USERNAMES`** - prevents scanning non-fork repos
2. **Use JSON output for scripts** - easier to parse with `jq`
3. **Run `fork-report` before pushing** - ensure you're not behind upstream
4. **Set up `upstream` remote** on all forks for accurate tracking
5. **Use watch mode sparingly** - respect GitHub API rate limits

## Output Formats

### Markdown Example
```markdown
# Repo Status Report

| Repo | Branch | Status | Behind | Ahead |
|------|--------|--------|--------|-------|
| my-project | main | ⬇️ | 5 | 0 |
```

### JSON Example
```json
{"name":"my-project","status":"clean","behind":5,"ahead":0}
```

## Exit Codes

- `0` - Success
- `1` - Error (no repos found, invalid options, etc.)

## Version

Current version: `1.0.0`

Check with: `fork-report --version`
