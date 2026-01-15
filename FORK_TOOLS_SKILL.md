# fork-tools - Universal Skill File

Compatible with: Claude Code, Cursor, oh-my-opencode, opencode

---

## Description (oh-my-opencode)

description: Manage Git forks - check status, sync with upstream, generate reports
model: anthropic/claude-sonnet-4-5

---

## Quick Reference (All Platforms)

**Activation keywords:** `fork-tools`, `fork status`, `check forks`, `sync forks`

**What it does:**
- Scans all Git repositories in configured directories
- Identifies forks by `upstream` remote or username matching
- Generates Markdown/JSON reports of fork status
- Shows ahead/behind counts, dirty state, branch info
- Provides sync commands for updating forks

---

## Core Concepts

### What is a Fork?

A fork is a copy of a repository that allows you to make changes without affecting the original. The original is called "upstream".

### Fork States

| Icon | State | Meaning | Action |
|------|-------|---------|--------|
| ✅ | Clean | Up to date with upstream | None |
| 🔴 | Dirty | Uncommitted changes | Commit/stash changes |
| ⬆️ | Ahead | Local commits not upstream | Push to origin |
| ⬇️ | Behind | Upstream has new commits | Pull/rebase from upstream |

### Environment Variables

```bash
# REQUIRED - Your GitHub usernames (space-separated)
export GITHUB_USERNAMES="yourusername orgname"

# OPTIONAL - Directories to search (colon-separated)
export FORK_SEARCH_DIRS="~/projects:~/work:~/src"

# OPTIONAL - GitHub token for API access
export GITHUB_TOKEN="ghp_xxx"
```

---

## Tool Reference

### fork-report

Generate beautiful status reports.

```bash
# Basic usage
fork-report

# Save to file
fork-report > status.md

# JSON output
fork-report json

# Show configuration
fork-report --config
```

**JSON Schema:**
```json
{
  "forks": [{
    "name": "repo-name",
    "path": "/full/path",
    "status": "clean|dirty",
    "branch": "main",
    "ahead": 0,
    "behind": 5
  }]
}
```

### fork-check

Quick upstream check.

```bash
# Single check
fork-check

# Watch mode (5 min intervals)
fork-check 300
```

### fork-watcher

Auto-discover and monitor.

```bash
# List all tracked forks
fork-watcher --list

# Watch mode
fork-watcher 300
```

---

## Common Workflows

### Check All Forks Status

```bash
GITHUB_USERNAMES="myuser" fork-report
```

### Find Forks Needing Updates

```bash
fork-report json | jq '.forks[] | select(.behind > 0)'
```

### Sync All Forks with Upstream

```bash
fork-report json | jq -r '.forks[] | select(.behind > 0) | .path' | while read repo; do
  echo "Updating $repo..."
  cd "$repo" && git fetch upstream && git rebase upstream/main
done
```

### Find Dirty Working Copies

```bash
fork-report json | jq '.forks[] | select(.status == "dirty")'
```

### Count Unpushed Commits

```bash
fork-report json | jq '[.forks[] | select(.ahead > 0)] | length'
```

---

## Adding Upstream Remote

```bash
cd your-fork
git remote add upstream https://github.com/original/repo.git
git fetch upstream
```

Verify:
```bash
git remote -v
```

Should show both `origin` and `upstream`.

---

## Sync Workflow

After checking forks and finding ones behind upstream:

```bash
# 1. Fetch upstream
git fetch upstream

# 2. Ensure clean state
git status

# 3. Rebase onto upstream/main (or upstream/master)
git rebase upstream/main

# 4. Push to origin
git push origin main
```

For conflicts:
```bash
# Resolve conflicts, then:
git rebase --continue
```

---

## Fork Detection Rules

A repository is a fork if:
1. Has an `upstream` remote configured, OR
2. `origin` URL contains a username from `GITHUB_USERNAMES`

**Examples:**
- `origin: https://github.com/myuser/project.git` + `GITHUB_USERNAMES="myuser"` = fork
- `origin: https://github.com/myuser/project.git` + `upstream: https://github.com/original/project.git` = fork

---

## Installation

### One-line install (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/Evoke4350/homebrew-fork-tools/main/install.sh | sh
```

### Homebrew

```bash
brew tap Evoke4350/fork-tools
brew install fork-report
```

### Manual

```bash
curl -O https://raw.githubusercontent.com/Evoke4350/homebrew-fork-tools/main/fork-report.sh
chmod +x fork-report.sh
sudo mv fork-report.sh /usr/local/bin/
```

---

## Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| macOS | ✅ Full | Native notifications via terminal-notifier |
| Linux | ✅ Full | libnotify support |
| Windows (Git Bash) | ✅ Full | No notifications |
| Windows (PowerShell) | ⚠️ Partial | Use WSL or Git Bash |

---

## Troubleshooting

### "No forks found"

1. Set `GITHUB_USERNAMES`
2. Check `FORK_SEARCH_DIRS` includes your repo locations
3. Verify repos have `origin` remote

### "Permission denied"

```bash
chmod +x fork-report.sh
```

### Git commands failing

- Verify repo is valid Git directory
- Check network connectivity for `git fetch`

### Fork not detected

- Add `upstream` remote
- Ensure username in `GITHUB_USERNAMES`
- Check `origin` URL format

---

## Git Hook Integration

Add to `.git/hooks/post-merge`:

```bash
#!/bin/bash
fork-report | grep "⬇️" && echo "⚠️  Upstream updates available!"
```

Add to `.git/hooks/pre-push`:

```bash
#!/bin/bash
BEHIND=$(fork-report json | jq '[.forks[] | select(.behind > 0)] | length')
if [[ "$BEHIND" -gt 0 ]]; then
  echo "⚠️  You are behind upstream on $BEHIND fork(s)"
fi
```

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Check fork status
  run: |
    GITHUB_USERNAMES="${{ github.repository_owner }}" fork-report json > fork-status.json

- name: Upload status
  uses: actions/upload-artifact@v4
  with:
    name: fork-status
    path: fork-status.json
```

---

## Best Practices

1. **Always set `GITHUB_USERNAMES`** - prevents scanning unrelated repos
2. **Run `fork-report` before pushing** - ensure you're not behind
3. **Use JSON for scripts** - easier to parse with `jq`
4. **Add `upstream` remote** to all forks - accurate tracking
5. **Rebase don't merge** - keeps history clean
6. **Watch mode sparingly** - respect rate limits

---

## Advanced Patterns

### Daily Status Report

```bash
# Cron job: 0 9 * * * fork-report > ~/fork-reports/$(date +%Y%m%d).md
```

### Bulk Sync

```bash
for repo in $(fork-report json | jq -r '.forks[] | .path'); do
  (cd "$repo" && git fetch upstream -q && git rebase upstream/main -q)
done
```

### Find Stale Forks

```bash
fork-report json | jq '.forks[] | select(.behind > 50)'
```

### Generate HTML Report

```bash
fork-report | glow - > report.html
```

---

## Command Reference Card

```bash
# Essential commands
fork-report --help              # Show help
fork-report --config            # Show current config
fork-report json                # JSON output
fork-report > status.md          # Save markdown

# Quick checks
fork-check                      # One-time check
fork-watcher --list             # List tracked forks
fork-watcher 300                # Watch every 5 min

# Common jq queries
fork-report json | jq '.forks[] | .name'
fork-report json | jq '.forks[] | select(.status == "dirty")'
fork-report json | jq '[.forks[] | select(.behind > 0)] | length'
```

---

## Version: 1.0.0
## Docs: https://evoke4350.github.io/homebrew-fork-tools
## Repo: https://github.com/Evoke4350/homebrew-fork-tools
