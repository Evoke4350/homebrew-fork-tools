#!/bin/bash
# fork-report.sh - Generate beautiful Markdown report of all repos, forks, and PRs
# Usage: fork-report.sh [--json] [--markdown]
#
# Author: Evoke4350
# Version: 1.0.0
# License: MIT
#
# Environment Variables:
#   GITHUB_USERNAMES  - Space-separated list of your GitHub usernames (default: empty)
#   FORK_SEARCH_DIRS  - Colon-separated list of directories to search (default: ~:~/dev:~/projects:~/src:~/github)
#   GITHUB_TOKEN      - Optional: GitHub token for PR info
#
# Examples:
#   GITHUB_USERNAMES="user1 user2" fork-report.sh
#   FORK_SEARCH_DIRS="~/code:~/work" fork-report.sh
#   fork-report.sh json > report.json

set -eo pipefail

# Version
VERSION="1.0.0"

# Default configuration (overridable via env vars)
if [[ -n "${GITHUB_USERNAMES:-}" ]]; then
    IFS=' ' read -ra GITHUB_USERNAMES <<< "$GITHUB_USERNAMES"
else
    GITHUB_USERNAMES=()
fi
IFS=':' read -ra SEARCH_DIRS <<< "${FORK_SEARCH_DIRS:-$HOME:$HOME/dev:$HOME/projects:$HOME/src:$HOME/github:$HOME/work}"
OUTPUT_FORMAT="${1:-markdown}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Auto-detect platform
detect_platform() {
    case "$(uname -s)" in
        Linux*)     PLATFORM="linux";;
        Darwin*)    PLATFORM="macos";;
        CYGWIN*)    PLATFORM="windows";;
        MINGW*|MSYS*) PLATFORM="windows";;
        *)          PLATFORM="unknown";;
    esac
}

# Colors (disable on Windows or if NO_COLOR set)
setup_colors() {
    if [[ -n "$NO_COLOR" ]] || [[ "$PLATFORM" == "windows" ]]; then
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
    else
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        NC='\033[0m'
    fi
}

# Check if repo is a fork
is_fork() {
    local origin_url="$1"
    local upstream_url="$2"

    # Has upstream remote
    [[ -n "$upstream_url" ]] && return 0

    # Origin belongs to user
    for username in "${GITHUB_USERNAMES[@]}"; do
        [[ "$origin_url" =~ $username ]] && return 0
    done

    return 1
}

# Store repo data globally
declare -a REPO_NAMES=()
declare -a REPO_PATHS=()
declare -a REPO_STATUS=()
declare -a REPO_BRANCHES=()
declare -a REPO_AHEAD=()
declare -a REPO_BEHIND=()
declare -a REPO_COMMITS=()
declare -a REPO_ORIGIN=()
declare -a REPO_UPSTREAM=()

# Get repo status and store in arrays
get_repo_status() {
    local repo_path="$1"
    local origin_url="$2"
    local upstream_url="$3"
    local repo_name=$(basename "$repo_path")

    cd "$repo_path" 2>/dev/null || return

    local status="clean"
    local ahead=0
    local behind=0
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n\r' || echo "unknown")
    local commit_hash=$(git log -1 --format="%h" 2>/dev/null | tr -d '\n\r' || echo "unknown")
    # Get commit subject, strip newlines and special chars
    local commit_subject=$(git log -1 --format="%s" 2>/dev/null | tr -d '\n\r\000-\037' | sed 's/|/\\|/g' || echo "unknown")

    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        status="dirty"
    fi

    if [[ -n "$upstream_url" ]] && [[ "$upstream_url" != "none" ]]; then
        git fetch upstream >/dev/null 2>&1 || true
        local upstream_branch=$(git rev-parse --abbrev-ref upstream/HEAD 2>/dev/null || echo "upstream/main")
        behind=$(git rev-list --count "$upstream_branch..HEAD" 2>/dev/null || echo 0)
        ahead=$(git rev-list --count "HEAD..$upstream_branch" 2>/dev/null || echo 0)
    else
        git fetch origin >/dev/null 2>&1 || true
        local origin_branch=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo "origin/main")
        behind=$(git rev-list --count "$origin_branch..HEAD" 2>/dev/null || echo 0)
        ahead=$(git rev-list --count "HEAD..$origin_branch" 2>/dev/null || echo 0)
    fi

    REPO_NAMES+=("$repo_name")
    REPO_PATHS+=("$(echo "$repo_path" | tr -d '\n')")
    REPO_STATUS+=("$status")
    REPO_BRANCHES+=("$branch")
    REPO_AHEAD+=("$ahead")
    REPO_BEHIND+=("$behind")
    REPO_COMMITS+=("$(echo "$commit_hash $commit_subject" | tr -d '\n\r')")
    REPO_ORIGIN+=("$(echo "$origin_url" | tr -d '\n\r')")
    REPO_UPSTREAM+=("$(echo "$upstream_url" | tr -d '\n\r')")
}

# Escape string for JSON - removes ALL control chars and escapes special chars
json_escape() {
    local input="$1"
    # Remove ALL control characters (U+0000-U+001F)
    # Escape backslashes FIRST, then double quotes
    # Convert newlines to spaces and trim trailing space
    printf '%s' "$input" | tr -d '\000-\037' | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/ $//'
}

# Generate Markdown report
generate_markdown() {
    local total_repos="$1"
    local count=${#REPO_NAMES[@]}
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Count stats
    local forks=0
    local dirty=0
    local needs_update=0
    local has_upstream=0

    for ((i=0; i<count; i++)); do
        [[ "${REPO_UPSTREAM[$i]}" != "none" ]] && ((has_upstream++))
        [[ "${REPO_STATUS[$i]}" == "dirty" ]] && ((dirty++))
        [[ "${REPO_AHEAD[$i]}" -gt 0 ]] && ((needs_update++))
        ((forks++))
    done

    cat <<EOF
# Repo Status Report

**Generated:** $timestamp  |  **fork-report.sh v$VERSION**

---

## Summary

| Metric | Count |
|--------|-------|
| Total Repos Scanned | $total_repos |
| Your Forks | $forks |
| With Upstream | $has_upstream |
| Dirty Working Copy | $dirty |
| Needs Update | $needs_update |

---

## Your Forks

| Repo | Path | Branch | Status | Behind | Ahead | Latest Commit |
|------|------|--------|--------|--------|-------|---------------|
EOF

    for ((i=0; i<count; i++)); do
        local name="${REPO_NAMES[$i]}"
        local path="${REPO_PATHS[$i]}"
        local status="${REPO_STATUS[$i]}"
        local branch="${REPO_BRANCHES[$i]}"
        local ahead="${REPO_AHEAD[$i]}"
        local behind="${REPO_BEHIND[$i]}"
        local commit="${REPO_COMMITS[$i]}"

        local status_icon="✅"
        [[ "$status" == "dirty" ]] && status_icon="🔴"
        [[ "$ahead" -gt 0 ]] && status_icon="⬆️"
        [[ "$behind" -gt 0 ]] && status_icon="⬇️"

        # Sanitize for markdown output (escape special chars)
        local path_display=$(echo "$path" | sed "s|$HOME|~|" | sed 's/|[`\\]/\\&/g')
        local clean_commit=$(echo "$commit" | sed 's/|/\\|/g' | sed 's/`/\\`/g' | head -c 60)

        echo "| $name | \`$path_display\` | \`$branch\` | $status_icon | $behind | $ahead | \`$clean_commit\` |"
    done

    echo ""
    echo "---"
    echo ""
    echo "## Legend"
    echo ""
    echo "| Icon | Meaning |"
    echo "|------|---------|"
    echo "| ✅ | Clean, up to date |"
    echo "| 🔴 | Dirty working copy (uncommitted changes) |"
    echo "| ⬆️ | Ahead of upstream (commits to push) |"
    echo "| ⬇️ | Behind upstream (new commits available) |"
    echo ""
    echo "<!-- END OF REPORT -->"
}

# Generate JSON report
generate_json() {
    local count=${#REPO_NAMES[@]}
    local timestamp=$(date +"%Y-%m-%dT%H:%M:%S%:z")

    echo "{"
    echo "  \"version\": \"$VERSION\","
    echo "  \"generated_at\": \"$timestamp\","
    echo "  \"forks\": ["

    for ((i=0; i<count; i++)); do
        [[ $i -gt 0 ]] && echo ","
        echo "    {"
        echo "      \"name\": \"$(json_escape "${REPO_NAMES[$i]}")\","
        echo "      \"path\": \"$(json_escape "${REPO_PATHS[$i]}")\","
        echo "      \"status\": \"$(json_escape "${REPO_STATUS[$i]}")\","
        echo "      \"branch\": \"$(json_escape "${REPO_BRANCHES[$i]}")\","
        echo "      \"ahead\": ${REPO_AHEAD[$i]},"
        echo "      \"behind\": ${REPO_BEHIND[$i]},"
        echo "      \"latest_commit\": \"$(json_escape "${REPO_COMMITS[$i]}")\","
        echo "      \"origin\": \"$(json_escape "${REPO_ORIGIN[$i]}")\","
        echo "      \"upstream\": \"$(json_escape "${REPO_UPSTREAM[$i]}")\""
        echo -n "    }"
    done

    echo ""
    echo "  ]"
    echo "}"
}

# Show usage
show_help() {
    cat <<HELP
fork-report.sh v${VERSION} - Generate beautiful Markdown report of repos and forks

USAGE:
    fork-report.sh [OPTIONS] [FORMAT]

FORMAT:
    markdown    Generate Markdown report (default)
    json        Generate JSON report

OPTIONS:
    -h, --help      Show this help message
    -v, --version   Show version information
    --config        Show current configuration

ENVIRONMENT VARIABLES:
    GITHUB_USERNAMES   Space-separated list of your GitHub usernames
                       Example: export GITHUB_USERNAMES="user1 user2"

    FORK_SEARCH_DIRS   Colon-separated list of directories to search
                       Example: export FORK_SEARCH_DIRS="~/code:~/work"

    GITHUB_TOKEN       Optional: GitHub token for PR info
    NO_COLOR           Disable colored output

EXAMPLES:
    # Basic usage (scans common directories)
    fork-report.sh

    # Specify your GitHub usernames
    GITHUB_USERNAMES="myuser orgname" fork-report.sh

    # Custom search directories
    FORK_SEARCH_DIRS="~/projects:~/work" fork-report.sh

    # Save to file
    fork-report.sh > ~/fork-report.md

    # JSON output
    fork-report.sh json > report.json

    # Windows Git Bash
    fork-report.sh markdown > report.md

LICENSE:
    MIT License - Copyright (c) 2026

HELP
}

# Show configuration
show_config() {
    echo "fork-report.sh v${VERSION} Configuration"
    echo "======================================="
    echo ""
    echo "Platform: $PLATFORM"
    echo "Output Format: $OUTPUT_FORMAT"
    echo ""
    echo "GitHub Usernames: ${GITHUB_USERNAMES[*]:-(none set)}"
    echo "Search Directories:"
    for dir in "${SEARCH_DIRS[@]}"; do
        echo "  - $dir"
    done
    echo ""
    echo "Environment:"
    echo "  GITHUB_USERNAMES=${GITHUB_USERNAMES[*]:-(empty)}"
    echo "  FORK_SEARCH_DIRS=${FORK_SEARCH_DIRS:-default}"
    echo "  GITHUB_TOKEN=${GITHUB_TOKEN:+(set)}"
    echo "  NO_COLOR=${NO_COLOR:-false}"
}

# Main
_main() {
    detect_platform
    setup_colors

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "fork-report.sh v${VERSION}"
                exit 0
                ;;
            --config)
                show_config
                exit 0
                ;;
            json|markdown)
                OUTPUT_FORMAT="$1"
                shift
                ;;
            *)
                if [[ "$1" =~ ^- ]]; then
                    echo "Unknown option: $1" >&2
                    echo "Use --help for usage information" >&2
                    exit 1
                fi
                OUTPUT_FORMAT="$1"
                shift
                ;;
        esac
    done

    # Check if GITHUB_USERNAMES is set
    if [[ ${#GITHUB_USERNAMES[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Warning:${NC} GITHUB_USERNAMES not set" >&2
        echo "  Set it to detect your forks:" >&2
        echo "  ${CYAN}GITHUB_USERNAMES=\"yourname\" fork-report.sh${NC}" >&2
        echo "" >&2
        echo "  Scanning ALL repos instead..." >&2
        echo ""
    fi

    local total_scanned=0

    echo -e "${BLUE}🔍 Scanning for repos...${NC}" >&2

    for base_dir in "${SEARCH_DIRS[@]}"; do
        [[ ! -d "$base_dir" ]] && continue

        while IFS= read -r gitdir; do
            ((total_scanned++))
            [[ $((total_scanned % 10)) -eq 0 ]] && echo -ne "\r${CYAN}Scanning${NC}: $total_scanned repos checked..." >&2

            local repo_path=$(dirname "$gitdir")
            cd "$repo_path" 2>/dev/null || continue

            local origin_url=$(git remote get-url origin 2>/dev/null || echo "none")
            local upstream_url=$(git remote get-url upstream 2>/dev/null || echo "none")

            [[ "$origin_url" == "none" ]] && continue

            # If no usernames set, scan all repos
            if [[ ${#GITHUB_USERNAMES[@]} -eq 0 ]] || is_fork "$origin_url" "$upstream_url"; then
                get_repo_status "$repo_path" "$origin_url" "$upstream_url"
            fi
        done < <(find "$base_dir" -maxdepth 3 -mount -name ".git" -type d 2>/dev/null | \
                grep -v -e "node_modules" -e "\.cursor" -e "\.venv" -e "/venv/" -e "site-packages" -e "\.nvm")
    done

    local fork_count=${#REPO_NAMES[@]}
    echo -e "\r${GREEN}✓${NC} Scanned $total_scanned repos, found $fork_count forks" >&2
    echo "" >&2

    if [[ $fork_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No forks found!${NC}" >&2
        return 1
    fi

    case "$OUTPUT_FORMAT" in
        json)
            generate_json
            ;;
        markdown|*)
            generate_markdown "$total_scanned"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _main "$@"
fi
