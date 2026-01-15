---
layout: default
title: Documentation
nav_order: 2
has_children: true
---

# Documentation

Complete documentation for fork-tools.

## Quick Links

- [Installation Guide](#installation) - Get started with fork-tools
- [Usage Guide](usage.html) - Learn how to use the tools
- [API Reference](api.html) - Command-line interface reference

## Installation

### Homebrew

```bash
brew tap Evoke4350/fork-tools
brew install fork-report
```

### Manual Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Evoke4350/homebrew-fork-tools/main/fork-report.sh -o fork-report
chmod +x fork-report
sudo mv fork-report /usr/local/bin/
```

## Quick Start

```bash
# Set your GitHub username
export GITHUB_USERNAMES="yourname"

# Generate a report
fork-report > ~/fork-report.md
```

## Examples

### Daily Fork Check

Create a cron job to check your forks daily:

```bash
# Add to crontab: crontab -e
0 9 * * * fork-report > ~/fork-reports/$(date +%Y%m%d).md
```

### CI/CD Integration

Use in GitHub Actions to check fork status:

```yaml
- name: Check fork status
  run: |
    GITHUB_USERNAMES="$GITHUB_REPOSITORY_OWNER" fork-report json > fork-status.json
```

### Git Hook Integration

Add to `.git/hooks/post-merge`:

```bash
#!/bin/bash
fork-report | grep "⬇️" && echo "Upstream updates available!"
```

## Features

- 🔍 **Auto-discovery** - Finds forks automatically
- 📊 **Beautiful Reports** - Markdown or JSON output
- ⚡ **Fast** - Scans hundreds of repos in seconds
- 🌐 **Cross-platform** - macOS, Linux, Windows

## Changelog

See [CHANGELOG.md](https://github.com/Evoke4350/homebrew-fork-tools/blob/main/CHANGELOG.md) for version history.

## Support

- Issues: [GitHub Issues](https://github.com/Evoke4350/homebrew-fork-tools/issues)
- Documentation: [Project Docs](https://evoke4350.github.io/homebrew-fork-tools)
- Version: 1.0.0
