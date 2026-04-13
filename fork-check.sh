#!/bin/bash
# fork-check.sh - Quick check for fork updates
# Usage: fork-check.sh [watch_interval_seconds]
#
# Examples:
#   fork-check.sh              # Check once (auto-discovers forks)
#   fork-check.sh 300          # Watch mode, check every 5 minutes
#   fork-check.sh 60           # Watch mode, check every minute
#
# Environment variables:
#   REPOS            Space- or newline-separated list of repo paths to check.
#                    If unset, fork-check auto-discovers forks by scanning
#                    FORK_SEARCH_DIRS for repos with an 'upstream' remote.
#   FORK_SEARCH_DIRS Colon-separated directories to scan for auto-discovery.
#                    Defaults to common locations under $HOME.
#   SOUND            Notification sound name (default: "default").

set -eo pipefail

SOUND="${SOUND:-default}"

# List of repos to check (space- or newline-separated).
# Override with REPOS environment variable; otherwise auto-discover below.
REPOS="${REPOS:-}"

# Auto-discover forks when REPOS is not provided.
# A fork is any git repo with an 'upstream' remote configured.
if [[ -z "$REPOS" ]]; then
    IFS=':' read -ra _fc_search_dirs <<< "${FORK_SEARCH_DIRS:-$HOME:$HOME/dev:$HOME/projects:$HOME/src:$HOME/github:$HOME/work}"
    _fc_discovered=()
    for _fc_base in "${_fc_search_dirs[@]}"; do
        [[ -d "$_fc_base" ]] || continue
        while IFS= read -r _fc_gitdir; do
            _fc_repo=$(dirname "$_fc_gitdir")
            if git -C "$_fc_repo" remote get-url upstream >/dev/null 2>&1; then
                _fc_discovered+=("$_fc_repo")
            fi
        done < <(find "$_fc_base" -maxdepth 3 -mount -name ".git" -type d 2>/dev/null \
                    | grep -v -e "node_modules" -e "\.cursor" -e "\.venv" -e "/venv/" -e "site-packages" -e "\.nvm")
    done
    REPOS="${_fc_discovered[*]}"
    unset _fc_search_dirs _fc_discovered _fc_base _fc_gitdir _fc_repo
fi

# If still nothing to check, fail loudly instead of silently no-op'ing.
if [[ -z "$REPOS" ]]; then
    {
        echo "⚠️  fork-check: no forks to check."
        echo ""
        echo "  Either:"
        echo "    1. Set REPOS to a space-separated list of repo paths, e.g.:"
        echo "         REPOS=\"\$HOME/projects/my-fork \$HOME/dev/other-fork\" fork-check"
        echo ""
        echo "    2. Or configure an 'upstream' remote on your forks so fork-check"
        echo "       can auto-discover them under FORK_SEARCH_DIRS (default: \$HOME,"
        echo "       \$HOME/dev, \$HOME/projects, \$HOME/src, \$HOME/github, \$HOME/work)."
        echo ""
        echo "       cd your-fork && git remote add upstream <original-repo-url>"
    } >&2
    exit 1
fi

# Gum integration (optional) - glamorous TUI output when gum is installed.
# Falls back to plain text for non-interactive/NO_COLOR/NO_TUI environments.
HAS_GUM=0
if command -v gum >/dev/null 2>&1 \
   && [[ -t 1 ]] \
   && [[ -z "${NO_TUI:-}" ]] \
   && [[ -z "${NO_COLOR:-}" ]] \
   && [[ "${TERM:-dumb}" != "dumb" ]]; then
    HAS_GUM=1
fi

check_repo() {
    local repo="$1"
    local name=$(basename "$repo")

    cd "$repo" 2>/dev/null || {
        echo "⚠️  $name: not found"
        return
    }

    # Check if upstream remote exists
    if ! git remote | grep -q upstream; then
        echo "⚠️  $name: No upstream remote (add with: git remote add upstream <original-repo>)"
        return
    fi

    # Fetch upstream commits (without merging)
    git fetch upstream >/dev/null 2>&1 || return

    # Compare HEAD with upstream/main or upstream/master
    UPSTREAM_BRANCH=$(git branch -r | grep "upstream/main\|upstream/master" | head -1 | xargs || echo "upstream/main")

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse "$UPSTREAM_BRANCH" 2>/dev/null || return)

    if [[ "$LOCAL" != "$REMOTE" ]]; then
        AHEAD=$(git rev-list --count "HEAD..$UPSTREAM_BRANCH" 2>/dev/null || echo "?")
        if [[ "$AHEAD" != "0" && "$AHEAD" != "?" ]]; then
            local message="🍴 $name: $AHEAD new commit(s) available!"
            echo "$message"

            # Desktop notification
            if command -v terminal-notifier >/dev/null 2>&1; then
                terminal-notifier \
                    -title "🍴 Fork Update" \
                    -subtitle "$name" \
                    -message "$AHEAD new commit(s) in upstream" \
                    -sound "$SOUND" \
                    -execute "open -a Terminal" \
                    -group "fork-check-$name" 2>/dev/null &
            fi
        fi
    fi
}

# Watch mode
if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
    INTERVAL="$1"
    if (( HAS_GUM )); then
        gum style \
            --border rounded \
            --border-foreground 212 \
            --padding "0 2" \
            "🔄 Watching ${REPOS//$'\n'/ } for updates every ${INTERVAL}s..." \
            "Press Ctrl+C to stop"
    else
        echo "🔄 Watching ${REPOS//$'\n'/ } for updates every ${INTERVAL}s..."
        echo "Press Ctrl+C to stop"
    fi
    echo ""

    while true; do
        for repo in $REPOS; do
            check_repo "$repo"
        done
        sleep "$INTERVAL"
    done
else
    # Single check
    for repo in $REPOS; do
        check_repo "$repo"
    done
fi
