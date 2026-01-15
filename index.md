---
layout: default
title: Home
nav_order: 1
---

# fork-tools

<div class="fork-hero">
  <p class="fork-subtitle">Beautiful Git fork management for developers</p>
  <p class="fork-description">Generate elegant Markdown reports of your repositories, track upstream changes, and never miss an update.</p>
</div>

[Install](#installation){: .btn .btn-primary }[Quick Start](#quick-start){: .btn .btn-outline }[Examples](#examples){: .btn .btn-outline }

## Features

| Feature | Description |
|---------|-------------|
| **🔍 Auto-discovery** | Finds all your forks across common directories |
| **📊 Beautiful Reports** | Clean Markdown tables with status icons |
| **⚡ Real-time Status** | See ahead/behind counts, dirty state, branch info |
| **🔔 Watch Mode** | Get notified when upstream repos update |
| **🌐 Cross-platform** | macOS, Linux, Windows (Git Bash) |

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

## Quick Start

```bash
# Set your GitHub usernames
export GITHUB_USERNAMES="yourname orgname"

# Generate a report
fork-report > ~/fork-report.md

# View the report
cat ~/fork-report.md
```

## Examples

### Basic Report

```bash
fork-report
```

Output:

```markdown
# Repo Status Report

Generated: 2026-01-14 21:00:00

## Summary

| Metric | Count |
|--------|-------|
| Your Forks | 12 |
| With Upstream | 8 |
| Needs Update | 3 |
```

### Custom Directories

```bash
FORK_SEARCH_DIRS="~/projects:~/work:~/code" fork-report
```

### JSON Output

```bash
fork-report json | jq '.forks[] | select(.needs_update == true)'
```

### Watch Mode (fork-watcher)

```bash
# Check every 5 minutes
fork-watcher 300
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GITHUB_USERNAMES` | Your GitHub usernames (space-separated) | empty |
| `FORK_SEARCH_DIRS` | Directories to search (colon-separated) | `~:~/dev:~/projects:~/src` |
| `NO_COLOR` | Disable colored output | false |

## Tools

| Tool | Description |
|------|-------------|
| `fork-report` | Generate one-shot Markdown/JSON reports |
| `fork-check` | Quick check for upstream updates |
| `fork-watcher` | Auto-discover forks and watch for changes |

---
