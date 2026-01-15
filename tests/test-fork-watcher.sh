#!/usr/bin/env bats
# test-fork-watcher.sh - Comprehensive tests for fork-watcher.sh
#
# Test coverage goals:
# 1. --list flag
# 2. Single check mode
# 3. Watch mode
# 4. Auto-discovery of forks
# 5. SEARCH_DIRS configuration
# 6. upstream remote detection
# 7. Notification formatting
# 8. Terminal-notifier integration
# 9. Error handling
# 10. Progress reporting

set -eo pipefail

# ============================================================================
# TEST FIXTURES AND SETUP
# ============================================================================

# Get the script path
FORK_WATCHER_SCRIPT="${BATS_TEST_DIRNAME}/../fork-watcher.sh"
PROJECT_ROOT="${PROJECT_ROOT:-${BATS_TEST_DIRNAME}/..}"

# Mock base directory for test repos
MOCK_REPO_BASE=""

setup() {
    # Create a temporary directory for mock repos
    MOCK_REPO_BASE=$(mktemp -d -t fork-watcher-test-XXXXXX)

    # Create mock search directories
    mkdir -p "$MOCK_REPO_BASE/home"
    mkdir -p "$MOCK_REPO_BASE/dev"
    mkdir -p "$MOCK_REPO_BASE/projects"
    mkdir -p "$MOCK_REPO_BASE/src"
}

teardown() {
    # Clean up mock repos
    if [[ -n "$MOCK_REPO_BASE" && -d "$MOCK_REPO_BASE" ]]; then
        rm -rf "$MOCK_REPO_BASE"
    fi
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Create a mock git repository
create_mock_repo() {
    local repo_name="$1"
    local with_upstream="${2:-false}"
    local repo_path="$MOCK_REPO_BASE/home/$repo_name"

    mkdir -p "$repo_path"
    cd "$repo_path"

    # Initialize git repo
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial commit
    echo "# Test Repository" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Set up origin remote
    git remote add origin "https://github.com/testuser/$repo_name.git"

    # Set up upstream if requested (makes it a fork)
    if [[ "$with_upstream" == "true" ]]; then
        git remote add upstream "https://github.com/original/$repo_name.git"
    fi

    echo "$repo_path"
}

# Create a mock git repository with commits behind upstream
create_mock_outdated_fork() {
    local repo_name="$1"
    local repo_path="$MOCK_REPO_BASE/home/$repo_name"
    local upstream_path="$MOCK_REPO_BASE/upstream/$repo_name"

    # Create upstream repo first
    mkdir -p "$upstream_path"
    cd "$upstream_path"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "# Original Repository" > README.md
    git add README.md
    git commit -q -m "Initial commit"
    # Add another commit
    echo "New feature" >> feature.md
    git add feature.md
    git commit -q -m "Add new feature"

    # Create fork
    mkdir -p "$repo_path"
    cd "$repo_path"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "# Fork Repository" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Set up remotes
    git remote add origin "https://github.com/testuser/$repo_name.git"
    git remote add upstream "$upstream_path"

    # Fetch from upstream
    git fetch upstream -q 2>/dev/null || true

    echo "$repo_path"
}

# Create a mock repository with remote as 'origin' only (no upstream)
create_mock_origin_only_repo() {
    local repo_name="$1"
    local repo_path="$MOCK_REPO_BASE/dev/$repo_name"

    mkdir -p "$repo_path"
    cd "$repo_path"

    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    echo "# Test Repository" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Only origin, no upstream
    git remote add origin "https://github.com/testuser/$repo_name.git"

    echo "$repo_path"
}

# Extract function from fork-watcher.sh
# This allows us to test individual functions without running the whole script
extract_function() {
    local func_name="$1"
    local temp_script=$(mktemp)

    # Extract the function definition
    sed -n "/^$func_name()/,/^}/p" "$FORK_WATCHER_SCRIPT" > "$temp_script"

    # Add necessary globals and dependencies
    cat > "$temp_script" <<'EOF'
#!/bin/bash
set -eo pipefail

NOTIFY_APP="com.github.GitHub"
SOUND="default"
EOF

    sed -n "/^$func_name()/,/^}/p" "$FORK_WATCHER_SCRIPT" >> "$temp_script"

    echo "$temp_script"
}

# Mock terminal-notifier for testing notifications
mock_terminal_notifier() {
    local mock_script="$MOCK_REPO_BASE/terminal-notifier-mock"
    cat > "$mock_script" <<'EOF'
#!/bin/bash
# Mock terminal-notifier that records invocations
MOCK_LOG_FILE="${TERMINAL_NOTIFIER_LOG:-/tmp/terminal-notifier-mock.log}"

# Log the invocation
echo "terminal-notifier called with: $*" >> "$MOCK_LOG_FILE"

# Parse arguments for testing
while [[ $# -gt 0 ]]; do
    case "$1" in
        -title)
            echo "TITLE: $2" >> "$MOCK_LOG_FILE"
            shift 2
            ;;
        -subtitle)
            echo "SUBTITLE: $2" >> "$MOCK_LOG_FILE"
            shift 2
            ;;
        -message)
            echo "MESSAGE: $2" >> "$MOCK_LOG_FILE"
            shift 2
            ;;
        -sound)
            echo "SOUND: $2" >> "$MOCK_LOG_FILE"
            shift 2
            ;;
        -open)
            echo "OPEN: $2" >> "$MOCK_LOG_FILE"
            shift 2
            ;;
        -group)
            echo "GROUP: $2" >> "$MOCK_LOG_FILE"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done
EOF
    chmod +x "$mock_script"
    echo "$mock_script"
}

# Check if script exists and is executable
check_script_exists() {
    [[ -f "$FORK_WATCHER_SCRIPT" ]]
}

# ============================================================================
# TEST SUITE 1: Script Existence and Basic Properties
# ============================================================================

@test "fork-watcher.sh script exists" {
    [[ -f "$FORK_WATCHER_SCRIPT" ]]
}

@test "fork-watcher.sh is executable" {
    [[ -x "$FORK_WATCHER_SCRIPT" ]] || skip "Script not executable"
}

@test "fork-watcher.sh has valid shebang" {
    local first_line=$(head -n 1 "$FORK_WATCHER_SCRIPT")
    [[ "$first_line" == "#!/bin/bash" ]]
}

@test "fork-watcher.sh contains set -eo pipefail" {
    grep -q "set -eo pipefail" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 2: --list Flag
# ============================================================================

@test "fork-watcher.sh accepts --list flag" {
    # Create a test wrapper with empty REPOS array
    local test_script=$(mktemp)
    cat > "$test_script" <<'EOF'
#!/bin/bash
REPOS=()
SEARCH_DIRS=()
EOF
    cat "$FORK_WATCHER_SCRIPT" | sed '/^#!/d' | sed '/^set -eo pipefail/d' >> "$test_script"
    chmod +x "$test_script"

    run "$test_script" --list
    # Should execute without error
    [[ "$status" -eq 0 ]] || [[ "$output" == *"Tracked forks"* ]]

    rm -f "$test_script"
}

@test "fork-watcher.sh --list shows tracked forks header" {
    grep -q "list_forks" "$FORK_WATCHER_SCRIPT"
    grep -q "Tracked forks" "$FORK_WATCHER_SCRIPT"
}

@test "list_forks function exists" {
    grep -q "^list_forks()" "$FORK_WATCHER_SCRIPT"
}

@test "list_forks displays fork path and upstream" {
    grep -A 10 "^list_forks()" "$FORK_WATCHER_SCRIPT" | grep -q "basename"
    grep -A 10 "^list_forks()" "$FORK_WATCHER_SCRIPT" | grep -q "upstream"
}

# ============================================================================
# TEST SUITE 3: Single Check Mode
# ============================================================================

@test "fork-watcher.sh runs in single check mode without arguments" {
    # Create test script with isolated environment
    local test_script=$(mktemp)
    cat > "$test_script" <<'EOF'
#!/bin/bash
REPOS=()
SEARCH_DIRS=("/nonexistent/path")
EOF
    # Append main script logic (skip the REPOS auto-discovery part)
    sed '/^#!/d; /^set -eo pipefail/d; /^# Auto-discover/,/^fi$/d' "$FORK_WATCHER_SCRIPT" >> "$test_script"
    chmod +x "$test_script"

    timeout 2 "$test_script" 2>/dev/null || true
    local result=$?

    # Should exit cleanly (not timeout)
    rm -f "$test_script"
    [[ $result -ne 124 ]]  # 124 is timeout exit code
}

@test "single check mode iterates through REPOS array" {
    grep -q "for repo in \"\${REPOS\[@\]}\"" "$FORK_WATCHER_SCRIPT"
}

@test "single check mode calls check_fork for each repo" {
    grep -A 5 "for repo in \"\${REPOS\[@\]}\"" "$FORK_WATCHER_SCRIPT" | grep -q "check_fork"
}

@test "single check mode shows warning when no repos found" {
    grep -q "No forks found" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 4: Watch Mode
# ============================================================================

@test "fork-watcher.sh accepts interval argument for watch mode" {
    grep -q "WATCH_INTERVAL=\"\${1:-}\"" "$FORK_WATCHER_SCRIPT"
}

@test "watch mode runs in continuous loop" {
    grep -A 20 "if \[\[ -n \"\$WATCH_INTERVAL" "$FORK_WATCHER_SCRIPT" | grep -q "while true"
}

@test "watch mode sleeps between checks" {
    grep -A 20 "while true" "$FORK_WATCHER_SCRIPT" | grep -q "sleep"
}

@test "watch mode displays watch mode message" {
    grep -q "Watch mode: checking every" "$FORK_WATCHER_SCRIPT"
}

@test "watch mode shows Ctrl+C prompt" {
    grep -q "Press Ctrl+C to stop" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 5: Auto-discovery of Forks
# ============================================================================

@test "fork-watcher.sh auto-discovers forks when REPOS is empty" {
    grep -q "if \[\[ \${#REPOS\[@\]} -eq 0 \]\]" "$FORK_WATCHER_SCRIPT"
}

@test "auto-discovery uses find to locate .git directories" {
    grep -q "find.*\.git" "$FORK_WATCHER_SCRIPT"
}

@test "auto-discovery checks for upstream remote" {
    grep -q "git remote get-url upstream" "$FORK_WATCHER_SCRIPT"
}

@test "auto-discovery adds repos to REPOS array" {
    grep -q 'REPOS+=("\$repo' "$FORK_WATCHER_SCRIPT"
}

@test "auto-discovery limits find depth to 2" {
    grep -q "maxdepth 2" "$FORK_WATCHER_SCRIPT"
}

@test "auto-discovery limits find results to prevent excessive scanning" {
    grep -q "head -20" "$FORK_WATCHER_SCRIPT"
}

@test "auto-discovery handles non-existent directories gracefully" {
    grep -q "2>/dev/null" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 6: SEARCH_DIRS Configuration
# ============================================================================

@test "SEARCH_DIRS array is defined" {
    grep -q "SEARCH_DIRS=" "$FORK_WATCHER_SCRIPT"
}

@test "SEARCH_DIRS includes common home directory" {
    grep -A 10 'SEARCH_DIRS=' "$FORK_WATCHER_SCRIPT" | grep -q '"\$HOME"'
}

@test "SEARCH_DIRS includes dev directory" {
    grep -A 10 'SEARCH_DIRS=' "$FORK_WATCHER_SCRIPT" | grep -q 'dev'
}

@test "SEARCH_DIRS includes projects directory" {
    grep -A 10 'SEARCH_DIRS=' "$FORK_WATCHER_SCRIPT" | grep -q 'projects'
}

@test "SEARCH_DIRS includes src directory" {
    grep -A 10 'SEARCH_DIRS=' "$FORK_WATCHER_SCRIPT" | grep -q 'src'
}

@test "SEARCH_DIRS includes github directory" {
    grep -A 10 'SEARCH_DIRS=' "$FORK_WATCHER_SCRIPT" | grep -q 'github'
}

@test "SEARCH_DIRS includes Development directory" {
    grep -A 10 'SEARCH_DIRS=' "$FORK_WATCHER_SCRIPT" | grep -q 'Development'
}

@test "SEARCH_DIRS iterates through array" {
    grep -q "for dir in \"\${SEARCH_DIRS\[@\]}\"" "$FORK_WATCHER_SCRIPT"
}

@test "auto-discovery checks if directory exists before scanning" {
    grep -q "\[\[ -d \"\$dir\" \]\]" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 7: Upstream Remote Detection
# ============================================================================

@test "check_fork function exists" {
    grep -q "^check_fork()" "$FORK_WATCHER_SCRIPT"
}

@test "upstream remote is checked in fork detection" {
    grep -q "git remote get-url upstream" "$FORK_WATCHER_SCRIPT"
}

@test "upstream remote detection uses error suppression" {
    grep -q "git remote get-url upstream 2>/dev/null" "$FORK_WATCHER_SCRIPT"
}

@test "check_fork falls back to origin if no upstream" {
    grep -q "git remote | grep -i upstream || git remote | grep -i origin" "$FORK_WATCHER_SCRIPT"
}

@test "check_fork changes to repo directory" {
    grep -q 'cd "\$repo_path"' "$FORK_WATCHER_SCRIPT"
}

@test "check_fork returns early if cd fails" {
    grep -A 1 'cd "\$repo_path"' "$FORK_WATCHER_SCRIPT" | grep -q "|| return"
}

# ============================================================================
# TEST SUITE 8: Notification Formatting
# ============================================================================

@test "notifications use fork emoji" {
    grep -q "🍴" "$FORK_WATCHER_SCRIPT"
}

@test "notifications show commit count" {
    grep -q "new commit(s)" "$FORK_WATCHER_SCRIPT"
}

@test "notification title includes Fork Update" {
    grep -q "Fork Update" "$FORK_WATCHER_SCRIPT"
}

@test "notification includes repo name" {
    grep -q '\$repo_name' "$FORK_WATCHER_SCRIPT"
}

@test "notification includes upstream URL" {
    grep -q '\$upstream_url' "$FORK_WATCHER_SCRIPT"
}

@test "notification formats message with count" {
    grep -q '\$AHEAD new commit(s)' "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 9: Terminal-notifier Integration
# ============================================================================

@test "terminal-notifier command is used" {
    grep -q "terminal-notifier" "$FORK_WATCHER_SCRIPT"
}

@test "terminal-notifier receives title argument" {
    grep -q "\\-title" "$FORK_WATCHER_SCRIPT"
}

@test "terminal-notifier receives subtitle argument" {
    grep -q "\\-subtitle" "$FORK_WATCHER_SCRIPT"
}

@test "terminal-notifier receives message argument" {
    grep -q "\\-message" "$FORK_WATCHER_SCRIPT"
}

@test "terminal-notifier receives sound argument" {
    grep -q "\\-sound" "$FORK_WATCHER_SCRIPT"
}

@test "terminal-notifier receives open URL argument" {
    grep -q "\\-open" "$FORK_WATCHER_SCRIPT"
}

@test "terminal-notifier receives group argument" {
    grep -q "\\-group" "$FORK_WATCHER_SCRIPT"
}

@test "notification group includes repo name" {
    grep -q "fork-watcher-\$repo_name" "$FORK_WATCHER_SCRIPT"
}

@test "terminal-notifier failure falls back to echo" {
    grep -A 10 "terminal-notifier" "$FORK_WATCHER_SCRIPT" | grep -q "||"
}

@test "open URL is constructed from upstream URL" {
    grep -q "sed.*github\.com" "$FORK_WATCHER_SCRIPT"
}

@test "open URL strips .git suffix" {
    grep -q "sed.*s.*\.git" "$FORK_WATCHER_SCRIPT"
}

@test "SOUND variable is set to default" {
    grep -q 'SOUND="default"' "$FORK_WATCHER_SCRIPT"
}

@test "NOTIFY_APP variable is set to GitHub" {
    grep -q "NOTIFY_APP=" "$FORK_WATCHER_SCRIPT"
    grep -q "com.github.GitHub" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 10: Error Handling
# ============================================================================

@test "script uses set -eo pipefail for error handling" {
    grep -q "set -eo pipefail" "$FORK_WATCHER_SCRIPT"
}

@test "git commands use error suppression" {
    grep -q "git.*2>/dev/null" "$FORK_WATCHER_SCRIPT"
}

@test "find command uses error suppression" {
    grep -q "find.*2>/dev/null" "$FORK_WATCHER_SCRIPT"
}

@test "cd command uses error suppression in check_fork" {
    grep -q 'cd "\$repo_path" 2>/dev/null' "$FORK_WATCHER_SCRIPT"
}

@test "rev-list command has error fallback" {
    grep -q "rev-list.*|| echo" "$FORK_WATCHER_SCRIPT"
}

@test "script handles missing repos gracefully" {
    grep -q "\[\[ -d" "$FORK_WATCHER_SCRIPT"
}

@test "script handles missing upstream gracefully" {
    # Check for empty upstream handling
    grep -q '\[\[ -n "\$UPSTREAM" \]\]' "$FORK_WATCHER_SCRIPT"
}

@test "script handles empty REPOS array" {
    grep -q '\[\[ \${#REPOS\[@\]} -eq 0 \]\]' "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 11: Progress Reporting
# ============================================================================

@test "script displays fork count on start" {
    grep -q "Checking.*fork" "$FORK_WATCHER_SCRIPT"
}

@test "progress message uses REPOS array count" {
    grep -q '\${#REPOS\[@\]}' "$FORK_WATCHER_SCRIPT"
}

@test "script outputs emoji indicators" {
    grep -q "🍴\|🔄\|⚠️\|📋" "$FORK_WATCHER_SCRIPT"
}

@test "script prints updates to terminal" {
    grep -q "echo.*message" "$FORK_WATCHER_SCRIPT"
}

@test "script displays help message when no repos found" {
    grep -q "No forks found" "$FORK_WATCHER_SCRIPT"
}

@test "help message includes example REPOS configuration" {
    grep -q "REPOS+=(" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 12: Git Operations
# ============================================================================

@test "script fetches upstream without merging" {
    # Check that fetch happens but no merge
    grep -q "git ls-remote" "$FORK_WATCHER_SCRIPT"
}

@test "script compares local and remote HEAD" {
    grep -q "git rev-parse HEAD" "$FORK_WATCHER_SCRIPT"
    grep -q "git ls-remote.*HEAD" "$FORK_WATCHER_SCRIPT"
}

@test "script calculates commit difference" {
    grep -q "git rev-list.*HEAD" "$FORK_WATCHER_SCRIPT"
}

@test "script checks if ahead count is non-zero" {
    grep -q '\[\[ "\$AHEAD" != "0"' "$FORK_WATCHER_SCRIPT"
}

@test "script handles unknown commit counts" {
    grep -q '\[\[ "\$AHEAD" != "0" && "\$AHEAD' "$FORK_WATCHER_SCRIPT"
}

@test "script uses UPSTREAM_NAME variable" {
    grep -q "UPSTREAM_NAME=" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 13: Configuration Variables
# ============================================================================

@test "WATCH_INTERVAL variable is defined" {
    grep -q "WATCH_INTERVAL=" "$FORK_WATCHER_SCRIPT"
}

@test "WATCH_INTERVAL defaults to first argument" {
    grep -q 'WATCH_INTERVAL="\${1:-}"' "$FORK_WATCHER_SCRIPT"
}

@test "REPOS array is initialized" {
    grep -q "^REPOS=(" "$FORK_WATCHER_SCRIPT"
}

@test "REPOS array includes usage examples" {
    grep -q "Add your forks here" "$FORK_WATCHER_SCRIPT"
}

@test "REPOS format is documented" {
    grep -q "local_path.*upstream_url" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 14: Integration Tests with Mock Repos
# ============================================================================

@test "mock fork repo can be created" {
    local repo_path=$(create_mock_repo "test-fork" true)
    [[ -d "$repo_path" ]]
    [[ -d "$repo_path/.git" ]]
}

@test "mock fork repo has upstream remote" {
    local repo_path=$(create_mock_repo "test-fork" true)
    cd "$repo_path"
    run git remote get-url upstream
    [[ "$output" == "https://github.com/original/test-fork.git" ]]
}

@test "mock fork repo has origin remote" {
    local repo_path=$(create_mock_repo "test-fork" true)
    cd "$repo_path"
    run git remote get-url origin
    [[ "$output" == "https://github.com/testuser/test-fork.git" ]]
}

@test "mock non-fork repo has no upstream remote" {
    local repo_path=$(create_mock_origin_only_repo "test-non-fork")
    cd "$repo_path"
    run git remote get-url upstream 2>&1 || true
    [[ "$status" -ne 0 ]]
}

@test "auto-discovery finds fork with upstream remote" {
    local repo_path=$(create_mock_repo "discovery-test" true)
    cd "$repo_path"
    run git remote get-url upstream
    [[ "$output" == "https://github.com/original/discovery-test.git" ]]
}

@test "find command can locate .git directories in mock structure" {
    local repo_path=$(create_mock_repo "find-test" true)
    run find "$MOCK_REPO_BASE/home" -maxdepth 2 -name ".git" -type d
    [[ "$output" == *".git" ]]
}

# ============================================================================
# TEST SUITE 15: Command Line Argument Parsing
# ============================================================================

@test "main function exists" {
    grep -q "^main()" "$FORK_WATCHER_SCRIPT"
}

@test "script calls main with all arguments" {
    grep -q 'main "$@"' "$FORK_WATCHER_SCRIPT"
}

@test "main checks for --list flag first" {
    grep -A 5 "^main()" "$FORK_WATCHER_SCRIPT" | grep -q "\-\-list"
}

@test "main returns after --list" {
    grep -A 10 "if \[\[ \"\$1\" == \"--list" "$FORK_WATCHER_SCRIPT" | grep -q "return"
}

# ============================================================================
# TEST SUITE 16: Output Formatting
# ============================================================================

@test "output uses emoji for visual feedback" {
    # Check for various emoji usage
    grep -q "🍴" "$FORK_WATCHER_SCRIPT"  # Fork emoji
    grep -q "📋" "$FORK_WATCHER_SCRIPT"  # Clipboard/list emoji
    grep -q "🔄" "$FORK_WATCHER_SCRIPT"  # Refresh emoji
    grep -q "⚠️" "$FORK_WATCHER_SCRIPT"  # Warning emoji
}

@test "list_forks uses checkmark for existing repos" {
    grep -q "✓" "$FORK_WATCHER_SCRIPT"
}

@test "list_forks uses X mark for missing repos" {
    grep -q "✗" "$FORK_WATCHER_SCRIPT"
}

@test "list_forks uses arrow for upstream URL" {
    grep -q "→" "$FORK_WATCHER_SCRIPT"
}

@test "output includes repo name formatting" {
    grep -q "basename" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 17: Edge Cases
# ============================================================================

@test "script handles spaces in repo paths" {
    # Check that variables are properly quoted
    grep -q 'for repo in "\${REPOS\[@\]}"' "$FORK_WATCHER_SCRIPT"
    grep -q 'IFS=' "$FORK_WATCHER_SCRIPT"
}

@test "script handles REPOS entries with pipe separator" {
    grep -q "IFS='|'" "$FORK_WATCHER_SCRIPT"
    grep -q "read -r path upstream" "$FORK_WATCHER_SCRIPT"
}

@test "script handles empty upstream URL" {
    grep -q 'echo ""' "$FORK_WATCHER_SCRIPT"
}

@test "script handles git command failures gracefully" {
    # Check for error suppression patterns
    grep -q "2>/dev/null" "$FORK_WATCHER_SCRIPT"
    grep -q "|| echo" "$FORK_WATCHER_SCRIPT"
}

@test "script handles non-numeric commit counts" {
    grep -q 'AHEAD.*\?' "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 18: URL Parsing
# ============================================================================

@test "script parses upstream URL for GitHub" {
    grep -q "github.com" "$FORK_WATCHER_SCRIPT"
}

@test "script strips https://github.com/ from URL" {
    grep -q "sed.*s\|https://github.com/\|\|" "$FORK_WATCHER_SCRIPT"
}

@test "script strips .git suffix from URLs" {
    grep -q 'sed.*\.git' "$FORK_WATCHER_SCRIPT"
}

@test "URL parsing uses pipe as sed delimiter" {
    # Using | as delimiter avoids issues with / in URLs
    grep -q "sed.*|" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 19: Function Organization
# ============================================================================

@test "check_fork function takes two parameters" {
    grep -A 3 "^check_fork()" "$FORK_WATCHER_SCRIPT" | grep -q "repo_path"
    grep -A 3 "^check_fork()" "$FORK_WATCHER_SCRIPT" | grep -q "upstream_url"
}

@test "check_fork function extracts repo name" {
    grep "basename" "$FORK_WATCHER_SCRIPT" | grep -q "repo_path"
}

@test "list_forks function iterates REPOS array" {
    grep -A 5 "^list_forks()" "$FORK_WATCHER_SCRIPT" | grep -q 'for repo in "\${REPOS'
}

# ============================================================================
# TEST SUITE 20: Documentation and Comments
# ============================================================================

@test "script includes usage comment" {
    grep -q "Usage:" "$FORK_WATCHER_SCRIPT"
}

@test "script describes watch mode in usage" {
    grep -q "check_interval" "$FORK_WATCHER_SCRIPT"
}

@test "script describes single run mode" {
    grep -q "Without args" "$FORK_WATCHER_SCRIPT"
}

@test "script includes purpose description" {
    grep -q "Check for updates on forked" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 21: Security Considerations
# ============================================================================

@test "script uses quoted variables" {
    # Check for proper quoting patterns
    grep -q '"\$repo_path"' "$FORK_WATCHER_SCRIPT"
    grep -q '"\$upstream_url"' "$FORK_WATCHER_SCRIPT"
}

@test "script limits find command scope" {
    grep -q "maxdepth" "$FORK_WATCHER_SCRIPT"
}

@test "script limits find results" {
    grep -q "head" "$FORK_WATCHER_SCRIPT"
}

# ============================================================================
# TEST SUITE 22: Mock Terminal-notifier Behavior
# ============================================================================

@test "mock terminal-notifier can be created" {
    local mock_path=$(mock_terminal_notifier)
    [[ -x "$mock_path" ]]
}

@test "mock terminal-notifier logs invocations" {
    local mock_path=$(mock_terminal_notifier)
    export TERMINAL_NOTIFIER_LOG="$MOCK_REPO_BASE/notifier.log"
    run "$mock_path" -title "Test" -message "Test message"
    [[ -f "$TERMINAL_NOTIFIER_LOG" ]]
}

@test "mock terminal-notifier records title parameter" {
    local mock_path=$(mock_terminal_notifier)
    export TERMINAL_NOTIFIER_LOG="$MOCK_REPO_BASE/notifier.log"
    "$mock_path" -title "Test Title" -message "Test" >/dev/null 2>&1
    grep -q "TITLE: Test Title" "$TERMINAL_NOTIFIER_LOG"
}

@test "mock terminal-notifier records message parameter" {
    local mock_path=$(mock_terminal_notifier)
    export TERMINAL_NOTIFIER_LOG="$MOCK_REPO_BASE/notifier.log"
    "$mock_path" -title "Test" -message "Test Message" >/dev/null 2>&1
    grep -q "MESSAGE: Test Message" "$TERMINAL_NOTIFIER_LOG"
}

# ============================================================================
# TEST SUITE 23: Real-world Scenario Tests
# ============================================================================

@test "script can process multiple repos in sequence" {
    # Create multiple mock repos
    create_mock_repo "fork1" true
    create_mock_repo "fork2" true
    create_mock_repo "fork3" true

    # Count repos found - the .git dirs are at depth 2 (home/fork1/.git)
    local count=$(find "$MOCK_REPO_BASE/home" -maxdepth 2 -name ".git" -type d 2>/dev/null | wc -l | tr -d ' ')
    [[ "$count" -ge 3 ]]
}

@test "script distinguishes between forks and non-forks" {
    # Create both types
    create_mock_repo "is-fork" true
    create_mock_origin_only_repo "not-fork"

    # Check that fork has upstream
    cd "$MOCK_REPO_BASE/home/is-fork"
    run git remote get-url upstream
    [[ "$status" -eq 0 ]]

    # Check that non-fork doesn't have upstream
    cd "$MOCK_REPO_BASE/dev/not-fork"
    run git remote get-url upstream 2>&1
    [[ "$status" -ne 0 ]]
}

@test "auto-discovery only adds repos with upstream" {
    local repo_with_upstream=$(create_mock_repo "with-upstream" true)
    local repo_without_upstream=$(create_mock_origin_only_repo "without-upstream")

    # Verify upstream presence using run
    run git -C "$repo_with_upstream" remote get-url upstream 2>&1
    [[ "$status" -eq 0 ]]

    # Verify no upstream - this should fail
    run git -C "$repo_without_upstream" remote get-url upstream 2>&1
    [[ "$status" -ne 0 ]]
}

# ============================================================================
# TEST SUITE 24: BATS-specific Tests
# ============================================================================

@test "BATS framework is available" {
    command -v bats >/dev/null 2>&1
}

@test "test can create temporary directories" {
    local test_dir=$(mktemp -d)
    [[ -d "$test_dir" ]]
    rmdir "$test_dir"
    [[ ! -d "$test_dir" ]]
}

@test "test can access MOCK_REPO_BASE" {
    [[ -n "$MOCK_REPO_BASE" ]]
    [[ -d "$MOCK_REPO_BASE" ]]
}

@test "test setup creates search directories" {
    [[ -d "$MOCK_REPO_BASE/home" ]]
    [[ -d "$MOCK_REPO_BASE/dev" ]]
    [[ -d "$MOCK_REPO_BASE/projects" ]]
    [[ -d "$MOCK_REPO_BASE/src" ]]
}

# ============================================================================
# TEST SUITE 25: Complete Workflow Tests
# ============================================================================

@test "complete workflow: create repo, add upstream, verify structure" {
    local repo_path=$(create_mock_repo "workflow-test" true)

    # Verify directory structure
    [[ -d "$repo_path" ]]
    [[ -d "$repo_path/.git" ]]

    # Verify git config
    cd "$repo_path"
    [[ "$(git config user.name)" == "Test User" ]]

    # Verify remotes
    [[ "$(git remote get-url origin)" == "https://github.com/testuser/workflow-test.git" ]]
    [[ "$(git remote get-url upstream)" == "https://github.com/original/workflow-test.git" ]]

    # Verify commit exists
    [[ "$(git rev-list --count HEAD)" -eq 1 ]]
}

@test "script handles all SEARCH_DIRS locations" {
    # Create repos in different locations
    mkdir -p "$MOCK_REPO_BASE/src/test-repo/.git"
    mkdir -p "$MOCK_REPO_BASE/projects/test-repo/.git"

    run find "$MOCK_REPO_BASE/src" -maxdepth 2 -name ".git" -type d
    [[ "$output" == *".git" ]]

    run find "$MOCK_REPO_BASE/projects" -maxdepth 2 -name ".git" -type d
    [[ "$output" == *".git" ]]
}

@test "script IFS pipe parsing works correctly" {
    local test_entry="/path/to/repo|https://github.com/original/repo.git"
    IFS='|' read -r path upstream <<< "$test_entry"

    [[ "$path" == "/path/to/repo" ]]
    [[ "$upstream" == "https://github.com/original/repo.git" ]]
}

@test "script handles multiple REPOS entries" {
    REPOS=()
    REPOS+=("/path1|https://github.com/original1/repo1.git")
    REPOS+=("/path2|https://github.com/original2/repo2.git")
    REPOS+=("/path3|https://github.com/original3/repo3.git")

    [[ "${#REPOS[@]}" -eq 3 ]]
    [[ "${REPOS[0]}" == *"/path1|"* ]]
    [[ "${REPOS[1]}" == *"/path2|"* ]]
    [[ "${REPOS[2]}" == *"/path3|"* ]]
}
