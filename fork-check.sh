#!/bin/bash
# fork-check.sh - Quick check for fork updates
# Usage: fork-check.sh [watch_interval_seconds]
#
# Examples:
#   fork-check.sh              # Check once
#   fork-check.sh 300           # Watch mode, check every 5 minutes
#   fork-check.sh 60           # Watch mode, check every minute

set -eo pipefail

SOUND="${SOUND:-default}"

# List of repos to check (space-separated)
# Override with REPOS environment variable
REPOS="${REPOS:-}"

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
    echo "🔄 Watching ${REPOS//$'\n'/ } for updates every ${INTERVAL}s..."
    echo "Press Ctrl+C to stop"
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
