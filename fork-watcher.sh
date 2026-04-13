#!/bin/bash
# fork-watcher.sh - Check for updates on forked repositories and notify
# Usage: fork-watcher.sh [check_interval_seconds]
#   Without args: runs once and exits
#   With interval: runs continuously, checking every N seconds

set -eo pipefail

# Configuration
WATCH_INTERVAL="${1:-}"  # If provided, run in watch mode
NOTIFY_APP="com.github.GitHub"  # Opens GitHub when notification clicked
SOUND="default"

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

# Array of your forks: "local_path upstream_url"
# Add your forks here in format: "/path/to/repo|https://github.com/original/repo"
REPOS=()
# Examples:
# REPOS+=("$HOME/dev/my-fork|https://github.com/original/original-repo")
# REPOS+=("$HOME/projects/oh-my-claude-sisyphus|https://github.com/someuser/oh-my-claude-sisyphus")

# Auto-discover forks in common directories if no repos specified
if [[ ${#REPOS[@]} -eq 0 ]]; then
    SEARCH_DIRS=(
        "$HOME"
        "$HOME/dev"
        "$HOME/projects"
        "$HOME/src"
        "$HOME/github"
        "$HOME/Development"
        "$HOME/work"
    )

    # Find repos with "upstream" remote (indicates a fork)
    for dir in "${SEARCH_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            while IFS= read -r repo; do
                UPSTREAM=$(cd "$repo" 2>/dev/null && git remote get-url upstream 2>/dev/null || echo "")
                if [[ -n "$UPSTREAM" ]]; then
                    REPOS+=("$repo|$UPSTREAM")
                fi
            done < <(find "$dir" -maxdepth 2 -name ".git" -type d 2>/dev/null | head -20)
        fi
    done
fi

# Function to check a single fork
check_fork() {
    local repo_path="$1"
    local upstream_url="$2"
    local repo_name=$(basename "$repo_path")

    cd "$repo_path" 2>/dev/null || return

    # Fetch upstream without merging
    # Prefer upstream remote, fall back to origin
    UPSTREAM_NAME=$(git remote get-name upstream 2>/dev/null || git remote get-name origin 2>/dev/null || echo "origin")

    # Get local and remote refs
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git ls-remote "$UPSTREAM_NAME" HEAD 2>/dev/null | awk '{print $1}')

    if [[ "$LOCAL" != "$REMOTE" ]]; then
        # Get commit count difference
        AHEAD=$(git rev-list --count "HEAD..$UPSTREAM_NAME/HEAD" 2>/dev/null || echo "?")

        if [[ "$AHEAD" != "0" && "$AHEAD" != "?" ]]; then
            local message="$repo_name: $AHEAD new commit(s) available"

            # Send notification
            terminal-notifier \
                -title "🍴 Fork Update" \
                -subtitle "$repo_name" \
                -message "$AHEAD new commit(s) in upstream" \
                -sound "$SOUND" \
                -open "https://github.com/$(echo "$upstream_url" | sed 's|https://github.com/||' | sed 's|\.git$||')" \
                -group "fork-watcher-$repo_name" 2>/dev/null || \
            echo "📦 $message"

            # Also print to terminal
            echo "🍴 $message"
            echo "   $upstream_url"
        fi
    fi
}

# Function to show all tracked forks
list_forks() {
    if (( HAS_GUM )); then
        gum style --foreground 39 --bold '📋 Tracked forks:'
    else
        echo "📋 Tracked forks:"
    fi
    echo ""
    for repo in "${REPOS[@]}"; do
        IFS='|' read -r path upstream <<< "$repo"
        if [[ -d "$path" ]]; then
            if (( HAS_GUM )); then
                gum style --foreground 42 "  ✓ $(basename "$path")"
            else
                echo "  ✓ $(basename "$path")"
            fi
            echo "    → $upstream"
        else
            if (( HAS_GUM )); then
                gum style --foreground 196 "  ✗ $(basename "$path") (not found)"
            else
                echo "  ✗ $(basename "$path") (not found)"
            fi
        fi
    done
}

# Main loop
main() {
    if [[ "$1" == "--list" ]]; then
        list_forks
        return
    fi

    if (( HAS_GUM )); then
        gum style \
            --border rounded \
            --border-foreground 212 \
            --padding "0 2" \
            --bold \
            "🍴 Fork Watcher - Checking ${#REPOS[@]} fork(s)..."
    else
        echo "🍴 Fork Watcher - Checking ${#REPOS[@]} fork(s)..."
    fi

    if [[ -n "$WATCH_INTERVAL" ]]; then
        if (( HAS_GUM )); then
            gum style --foreground 39 "🔄 Watch mode: checking every $WATCH_INTERVAL seconds"
            gum style --foreground 244 "Press Ctrl+C to stop"
        else
            echo "🔄 Watch mode: checking every $WATCH_INTERVAL seconds"
            echo "Press Ctrl+C to stop"
        fi
        echo ""

        while true; do
            for repo in "${REPOS[@]}"; do
                IFS='|' read -r path upstream <<< "$repo"
                check_fork "$path" "$upstream"
            done

            if [[ ${#REPOS[@]} -eq 0 ]]; then
                echo "⚠️  No forks found! Add them manually:"
                echo '   REPOS+=("$HOME/dev/myproject|https://github.com/original/project")'
            fi

            sleep "$WATCH_INTERVAL"
        done
    else
        # Single check
        for repo in "${REPOS[@]}"; do
            IFS='|' read -r path upstream <<< "$repo"
            check_fork "$path" "$upstream"
        done

        if [[ ${#REPOS[@]} -eq 0 ]]; then
            echo "⚠️  No forks found! Add them manually:"
            echo '   REPOS+=("$HOME/dev/myproject|https://github.com/original/project")'
        fi
    fi
}

main "$@"
