---
layout: default
title: Usage Guide
nav_order: 2
parent: Documentation
---

# Usage Guide

Complete guide for using fork-tools.

## Table of Contents

- [Configuration](#configuration)
- [Generating Reports](#generating-reports)
- [Watch Mode](#watch-mode)
- [Output Formats](#output-formats)
- [Advanced Examples](#advanced-examples)

## Configuration

### Environment Variables

Set these in your `~/.zshrc` or `~/.bashrc`:

```bash
# Your GitHub usernames
export GITHUB_USERNAMES="yourname orgname"

# Directories to search
export FORK_SEARCH_DIRS="~/projects:~/work:~/src"

# Optional: GitHub token for PR info
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
```

### Verify Configuration

```bash
fork-report --config
```

Output:

```
fork-report.sh v1.0.0 Configuration
=======================================

Platform: macos
Output Format: markdown

GitHub Usernames: yourname orgname
Search Directories:
  - /Users/you
  - /Users/you/dev
  - /Users/you/projects
  - /Users/you/src
```

## Generating Reports

### Basic Report

```bash
fork-report > report.md
```

### JSON Report

```bash
fork-report json > report.json
```

### With Custom Directories

```bash
FORK_SEARCH_DIRS="~/code:~/work" fork-report
```

## Watch Mode

### fork-watcher

Continuously monitor your forks for updates:

```bash
# Check every 5 minutes (300 seconds)
fork-watcher 300
```

You'll get a desktop notification when upstream has new commits.

### fork-check

Quick one-time check:

```bash
fork-check
```

## Output Formats

### Markdown Output

```markdown
# Repo Status Report

## Summary

| Metric | Count |
|--------|-------|
| Your Forks | 12 |
| Needs Update | 3 |

## Your Forks

| Repo | Branch | Status | Behind | Ahead |
|------|--------|--------|--------|-------|
| my-project | main | ⬇️ | 5 | 0 |
```

### JSON Output

```json
{
  "version": "1.0.0",
  "generated_at": "2026-01-14T21:00:00-08:00",
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

## Advanced Examples

### Find All Dirty Repos

```bash
fork-report json | jq '.forks[] | select(.status == "dirty") | .name'
```

### Count Repos Needing Updates

```bash
fork-report json | jq '[.forks[] | select(.behind > 0)] | length'
```

### Generate HTML Report

```bash
fork-report | glow - > report.html
```

### Sync All Forks

```bash
fork-report json | jq -r '.forks[].path' | while read repo; do
  echo "Updating $repo..."
  cd "$repo" && git fetch upstream && git rebase upstream/main
done
```

## Status Icons

| Icon | Meaning |
|------|---------|
| ✅ | Clean, up to date |
| 🔴 | Dirty working copy |
| ⬆️ | Ahead of upstream (unpushed commits) |
| ⬇️ | Behind upstream (new commits available) |

## Troubleshooting

### No forks found

Make sure `GITHUB_USERNAMES` is set:

```bash
export GITHUB_USERNAMES="yourname"
```

### Permission denied

Make the script executable:

```bash
chmod +x fork-report.sh
```

### Git commands failing

Ensure you're in a Git repository or that the search directories are correct.
