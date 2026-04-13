---
layout: default
title: API Reference
nav_order: 3
parent: Documentation
---

# API Reference

Command-line interface reference for fork-tools.

## fork-report

Generate beautiful Markdown reports of Git repositories and forks.

### Synopsis

```bash
fork-report [OPTIONS] [FORMAT]
```

### Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-v, --version` | Show version information |
| `--config` | Show current configuration |

### Formats

| Format | Description |
|--------|-------------|
| `markdown` | Generate Markdown report (default) |
| `json` | Generate JSON report |

### Environment Variables

| Variable | Type | Description |
|----------|------|-------------|
| `GITHUB_USERNAMES` | string[] | Space-separated list of GitHub usernames |
| `FORK_SEARCH_DIRS` | string | Colon-separated list of directories to search |
| `GITHUB_TOKEN` | string | Optional GitHub token for API access |
| `NO_COLOR` | boolean | Disable colored output |

### Exit Codes

| Code | Description |
|------|-------------|
| `0` | Success |
| `1` | Error (no forks found, invalid options, etc.) |

### Examples

```bash
# Basic usage
fork-report

# With configuration
GITHUB_USERNAMES="user1 user2" fork-report

# JSON output
fork-report json | jq '.'

# Save to file
fork-report > report.md

# Custom directories
FORK_SEARCH_DIRS="~/projects:~/work" fork-report
```

---

## fork-check

Quick check for upstream updates on your forks. If `REPOS` is not set,
fork-check auto-discovers forks by scanning `FORK_SEARCH_DIRS` for git
repositories that have an `upstream` remote configured.

### Synopsis

```bash
fork-check [watch_interval]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `watch_interval` | Optional: check interval in seconds (enables watch mode) |

### Environment Variables

| Variable | Type | Description |
|----------|------|-------------|
| `REPOS` | string | Space- or newline-separated list of repo paths to check. If unset, fork-check auto-discovers. |
| `FORK_SEARCH_DIRS` | string | Colon-separated directories to scan when auto-discovering. Default: `$HOME:$HOME/dev:$HOME/projects:$HOME/src:$HOME/github:$HOME/work` |
| `SOUND` | string | Notification sound (default: `default`) |

### Exit Codes

| Code | Description |
|------|-------------|
| `0`  | Success (checks ran, regardless of how many forks were behind) |
| `1`  | No forks to check — `REPOS` is empty and auto-discovery found nothing |

### Examples

```bash
# One-time check (auto-discovers forks)
fork-check

# Explicit repo list
REPOS="$HOME/projects/my-fork $HOME/dev/other-fork" fork-check

# Watch mode (every 5 minutes)
fork-check 300
```

---

## fork-watcher

Auto-discover forks and watch for updates. Scans a built-in list of
common directories for repos with an `upstream` remote, then compares
the local HEAD against the upstream HEAD after fetching.

### Synopsis

```bash
fork-watcher [watch_interval]
fork-watcher --list
```

### Options

| Option | Description |
|--------|-------------|
| `--list` | List all discovered forks and exit |

### Arguments

| Argument | Description |
|----------|-------------|
| `watch_interval` | Optional: poll interval in seconds (enables watch mode) |

### Environment Variables

| Variable | Type | Description |
|----------|------|-------------|
| `SOUND` | string | Notification sound passed to `terminal-notifier` (default: `default`) |

> **Note:** fork-watcher's search directories are currently hardcoded
> inside the script. Configurable search paths and notification app
> selection are planned; open an issue if you need them.

### Examples

```bash
# List tracked forks
fork-watcher --list

# Watch mode
fork-watcher 300
```

---

## JSON Output Schema

```json
{
  "version": "string",
  "generated_at": "ISO 8601 timestamp",
  "forks": [
    {
      "name": "string",
      "path": "string",
      "status": "clean|dirty",
      "branch": "string",
      "ahead": "number",
      "behind": "number",
      "latest_commit": "string",
      "origin": "string",
      "upstream": "string"
    }
  ]
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Repository name |
| `path` | string | Absolute path to repository |
| `status` | string | `clean` or `dirty` |
| `branch` | string | Current branch name |
| `ahead` | number | Commits ahead of upstream |
| `behind` | number | Commits behind upstream |
| `latest_commit` | string | Latest commit hash and message |
| `origin` | string | Origin remote URL |
| `upstream` | string | Upstream remote URL |
