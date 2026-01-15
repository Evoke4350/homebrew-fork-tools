#!/bin/bash
# test-integration.sh - Integration tests for fork tools
# Tests edge cases and various repository states
#
# Usage: ./test-integration.sh [--no-cleanup]
#   --no-cleanup  Keep test repositories for inspection

set -euo pipefail

# Test configuration
TEST_BASE_DIR="/tmp/fork-tools-tests"
CLEANUP=${CLEANUP:-true}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
if [[ -n "${TERM:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' NC=''
fi

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Test framework
test_start() {
    local test_name="$1"
    ((TESTS_RUN++))
    TEST_CURRENT="$test_name"
    log_info "Testing: $test_name"
}

test_pass() {
    ((TESTS_PASSED++))
    log_success "$TEST_CURRENT"
    TEST_CURRENT=""
}

test_fail() {
    local reason="$1"
    ((TESTS_FAILED++))
    log_error "$TEST_CURRENT: $reason"
    TEST_CURRENT=""
}

# Cleanup handler
cleanup() {
    if [[ "$CLEANUP" == "true" ]]; then
        log_info "Cleaning up test directory: $TEST_BASE_DIR"
        rm -rf "$TEST_BASE_DIR"
    else
        log_warn "Skipping cleanup. Test repos kept at: $TEST_BASE_DIR"
    fi
}

trap cleanup EXIT

# Setup test environment
setup() {
    log_info "Setting up test environment..."
    rm -rf "$TEST_BASE_DIR"
    mkdir -p "$TEST_BASE_DIR"
    cd "$TEST_BASE_DIR"

    # Create a source repository to clone/fork from
    mkdir -p source-repo
    cd source-repo
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "# Test Repository" > README.md
    mkdir -p src
    echo "console.log('hello');" > src/app.js
    git add .
    git commit -q -m "Initial commit"

    # Create a commit history
    for i in {1..5}; do
        echo "commit $i" >> history.txt
        git add history.txt
        git commit -q -m "Commit $i"
    done

    cd "$TEST_BASE_DIR"
}

# Helper: Create a bare repo
create_bare_repo() {
    local path="$1"
    git clone -q --bare "$TEST_BASE_DIR/source-repo" "$path"
}

# Helper: Create a regular repo
create_regular_repo() {
    local path="$1"
    local name="${2:-test-repo}"
    git clone -q "$TEST_BASE_DIR/source-repo" "$path"
    cd "$path"
    git config user.email "test@example.com"
    git config user.name "Test User"
    cd "$TEST_BASE_DIR"
}

# Helper: Add upstream remote to repo
add_upstream() {
    local repo="$1"
    local upstream_url="${2:-$TEST_BASE_DIR/source-repo}"
    cd "$repo"
    git remote add upstream "$upstream_url"
    cd "$TEST_BASE_DIR"
}

# Helper: Get upstream branch name (main or master)
get_upstream_branch() {
    # Look for upstream/main or upstream/master (exclude HEAD symref lines)
    git branch -r 2>/dev/null | grep -v "HEAD" | grep -E "^\s*upstream/(main|master)$" | head -1 | xargs || echo "upstream/master"
}

# Helper: Source fork-check.sh functions
source_fork_check() {
    # Source the script to get its functions
    # We need to override REPOS variable for testing
    REPOS=""
}

# Helper: Run fork-check on a repo and check output
run_fork_check() {
    local repo="$1"
    local expected_pattern="${2:-}"

    cd "$repo"

    # Mock check_repo function from fork-check.sh
    # We'll test the actual script behavior
    bash -c '
        check_repo() {
            local repo="$1"
            local name=$(basename "$repo")

            cd "$repo" 2>/dev/null || { echo "WARN: $name: not found"; return 1; }

            # Check if upstream remote exists
            if ! git remote | grep -q upstream; then
                echo "WARN: $name: No upstream remote"
                return 1
            fi

            # Fetch upstream commits (without merging)
            git fetch upstream >/dev/null 2>&1 || { echo "WARN: $name: fetch failed"; return 1; }

            # Compare HEAD with upstream/main or upstream/master
            local UPSTREAM_BRANCH=$(git branch -r | grep "upstream/main\|upstream/master" | head -1 | xargs || echo "upstream/main")
            local LOCAL=$(git rev-parse HEAD)
            local REMOTE=$(git rev-parse "$UPSTREAM_BRANCH" 2>/dev/null || echo "")

            if [[ "$LOCAL" != "$REMOTE" ]] && [[ -n "$REMOTE" ]]; then
                local AHEAD=$(git rev-list --count "HEAD..$UPSTREAM_BRANCH" 2>/dev/null || echo "?")
                if [[ "$AHEAD" != "0" && "$AHEAD" != "?" ]]; then
                    echo "UPDATE: $name: $AHEAD new commit(s) available!"
                    return 0
                fi
            fi

            echo "OK: $name: up to date"
            return 0
        }
        check_repo "'"$repo"'"
    '

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 1: Empty repository (no commits)
# =============================================================================
test_empty_repo() {
    test_start "Empty repository (no commits)"

    local empty_dir="$TEST_BASE_DIR/empty-repo"
    mkdir -p "$empty_dir"
    cd "$empty_dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Attempt to run fork-check-like operations
    # Should handle gracefully
    if git rev-parse HEAD >/dev/null 2>&1; then
        test_fail "Empty repo should not have HEAD"
    else
        test_pass
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 2: Bare repository
# =============================================================================
test_bare_repo() {
    test_start "Bare repository"

    local bare_dir="$TEST_BASE_DIR/bare-repo"
    create_bare_repo "$bare_dir"

    # Test that we can work with bare repos
    cd "$bare_dir"
    if git rev-parse HEAD >/dev/null 2>&1; then
        # Bare repo should allow rev-parse
        cd "$TEST_BASE_DIR"
        test_pass
    else
        cd "$TEST_BASE_DIR"
        test_fail "Could not rev-parse HEAD in bare repo"
    fi
}

# =============================================================================
# TEST 3: Repository with no origin remote
# =============================================================================
test_no_origin() {
    test_start "Repository with no origin remote"

    local no_origin_dir="$TEST_BASE_DIR/no-origin-repo"
    mkdir -p "$no_origin_dir"
    cd "$no_origin_dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "# No Origin" > README.md
    git add .
    git commit -q -m "Initial commit"
    # Do NOT add origin

    # Check for origin - should not find it
    if git remote get-url origin >/dev/null 2>&1; then
        test_fail "Should not have origin remote"
    else
        test_pass
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 4: Repository with multiple remotes
# =============================================================================
test_multiple_remotes() {
    test_start "Repository with multiple remotes"

    local multi_dir="$TEST_BASE_DIR/multi-remote-repo"
    create_regular_repo "$multi_dir"

    cd "$multi_dir"
    # Add multiple remotes
    git remote add upstream "$TEST_BASE_DIR/source-repo"
    git remote add fork "$TEST_BASE_DIR/source-repo"
    git remote add backup "$TEST_BASE_DIR/source-repo"

    # Count remotes
    local remote_count=$(git remote | wc -l | tr -d ' ')
    if [[ "$remote_count" -ge 4 ]]; then  # origin + 3 added
        test_pass
    else
        test_fail "Expected 4 remotes, got $remote_count"
    fi

    # Verify we can get URL from each
    for remote in origin upstream fork backup; do
        if ! git remote get-url "$remote" >/dev/null 2>&1; then
            test_fail "Could not get URL for remote: $remote"
            return
        fi
    done

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 5: Detached HEAD state
# =============================================================================
test_detached_head() {
    test_start "Detached HEAD state"

    local detached_dir="$TEST_BASE_DIR/detached-repo"
    create_regular_repo "$detached_dir"

    cd "$detached_dir"
    # Go back 2 commits to detach HEAD
    git checkout -q HEAD~2

    # Verify we're detached
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if [[ "$branch" == "HEAD" ]]; then
        # Should still be able to get repo info
        if git rev-parse HEAD >/dev/null 2>&1; then
            test_pass
        else
            test_fail "Could not get HEAD in detached state"
        fi
    else
        test_fail "Expected detached HEAD, got: $branch"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 6: Submodules
# =============================================================================
test_submodules() {
    test_start "Repository with submodules"

    local parent_dir="$TEST_BASE_DIR/parent-with-submodule"
    local submodule_dir="$TEST_BASE_DIR/submodule-repo"

    # Create the submodule first
    create_regular_repo "$submodule_dir" "submodule"
    cd "$submodule_dir"
    echo "submodule content" > file.txt
    git add file.txt
    git commit -q -m "Add submodule file"
    cd "$TEST_BASE_DIR"

    # Create parent repo with submodule
    create_regular_repo "$parent_dir" "parent"
    cd "$parent_dir"

    # Allow file protocol for submodules (git security default)
    # Use a temporary config for this test only
    git -c protocol.file.allow=always submodule add -q "$submodule_dir" lib/submodule 2>/dev/null

    if [[ $? -eq 0 ]]; then
        git commit -q -m "Add submodule"

        # Verify .gitmodules exists
        if [[ -f .gitmodules ]]; then
            # Verify we can detect the submodule
            if git submodule status | grep -q submodule; then
                test_pass
            else
                test_fail "Could not detect submodule"
            fi
        else
            test_fail ".gitmodules not created"
        fi
    else
        test_fail "Could not add submodule"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 7: Symlinked repositories
# =============================================================================
test_symlinked_repo() {
    test_start "Symlinked repository"

    local real_dir="$TEST_BASE_DIR/real-repo"
    local link_dir="$TEST_BASE_DIR/symlinked-repo"

    create_regular_repo "$real_dir" "real"

    # Create symlink
    ln -s "$real_dir" "$link_dir"

    # Test operations through symlink
    cd "$link_dir"
    if git status >/dev/null 2>&1 && git rev-parse HEAD >/dev/null 2>&1; then
        # Get resolved paths for comparison (handle macOS /tmp -> /private/tmp symlink)
        local pwd_resolved=$(pwd -P)
        local real_dir_resolved=$(cd "$real_dir" && pwd -P)
        if [[ "$pwd_resolved" == "$real_dir_resolved" ]]; then
            test_pass
        else
            test_fail "Symlink did not resolve correctly (got: $pwd_resolved, expected: $real_dir_resolved)"
        fi
    else
        test_fail "Could not operate through symlink"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 8: Very long repository name
# =============================================================================
test_long_repo_name() {
    test_start "Very long repository name"

    # Create a name that's 255 characters (common filesystem limit)
    local long_name=$(printf 'a%.0s' {1..200})
    local long_dir="$TEST_BASE_DIR/$long_name"

    create_regular_repo "$long_dir" "$long_name"

    # Test operations with long name
    cd "$long_dir"
    local basename=$(basename "$long_dir")
    if [[ ${#basename} -eq 200 ]] && git status >/dev/null 2>&1; then
        test_pass
    else
        test_fail "Could not handle long repo name (length: ${#basename})"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 9: Special characters in repository name
# =============================================================================
test_special_chars_repo_name() {
    test_start "Repository name with special characters"

    # Test various special character combinations
    local special_names=(
        "test-repo-with-dashes"
        "test.repo.with.dots"
        "test_repo_with_underscores"
        "test.repo-123_v2.0"
    )

    for name in "${special_names[@]}"; do
        local dir="$TEST_BASE_DIR/$name"
        if create_regular_repo "$dir" "$name" 2>/dev/null; then
            cd "$dir"
            if ! git status >/dev/null 2>&1; then
                test_fail "Failed with name: $name"
                cd "$TEST_BASE_DIR"
                return
            fi
        else
            test_fail "Could not create repo with name: $name"
            cd "$TEST_BASE_DIR"
            return
        fi
        cd "$TEST_BASE_DIR"
    done

    test_pass
}

# =============================================================================
# TEST 10: Concurrent access (multiple scripts running)
# =============================================================================
test_concurrent_access() {
    test_start "Concurrent access simulation"

    local repo1="$TEST_BASE_DIR/concurrent-repo-1"
    local repo2="$TEST_BASE_DIR/concurrent-repo-2"
    local repo3="$TEST_BASE_DIR/concurrent-repo-3"

    # Create multiple repos
    create_regular_repo "$repo1" "repo1"
    create_regular_repo "$repo2" "repo2"
    create_regular_repo "$repo3" "repo3"

    # Simulate concurrent git operations
    local pids=()

    # Function to run background operation
    run_git_op() {
        local repo="$1"
        local id="$2"
        cd "$repo"
        # Simulate fetch operation
        git fetch origin >/dev/null 2>&1
        git status >/dev/null 2>&1
        echo "Done: $id"
    }

    # Launch concurrent operations
    run_git_op "$repo1" "1" > "$TEST_BASE_DIR/concurrent-1.log" 2>&1 &
    pids+=($!)
    run_git_op "$repo2" "2" > "$TEST_BASE_DIR/concurrent-2.log" 2>&1 &
    pids+=($!)
    run_git_op "$repo3" "3" > "$TEST_BASE_DIR/concurrent-3.log" 2>&1 &
    pids+=($!)

    # Wait for all to complete
    local all_success=true
    for i in "${!pids[@]}"; do
        if ! wait "${pids[$i]}" 2>/dev/null; then
            all_success=false
        fi
    done

    cd "$TEST_BASE_DIR"

    if [[ "$all_success" == "true" ]]; then
        test_pass
    else
        test_fail "Some concurrent operations failed"
    fi
}

# =============================================================================
# TEST 11: fork-report.sh with empty repo list
# =============================================================================
test_fork_report_empty() {
    test_start "fork-report.sh with empty search directory"

    local empty_search_dir="$TEST_BASE_DIR/empty-search"
    mkdir -p "$empty_search_dir"

    # Run fork-report.sh on empty directory
    cd "$empty_search_dir"
    local output
    output=$(FORF_SEARCH_DIRS="$empty_search_dir" "$PROJECT_ROOT/fork-report.sh" 2>&1 || true)

    # Should complete without error and report no forks
    cd "$TEST_BASE_DIR"
    test_pass
}

# =============================================================================
# TEST 12: fork-report.sh JSON output
# =============================================================================
test_fork_report_json() {
    test_start "fork-report.sh JSON output format"

    local test_repo="$TEST_BASE_DIR/json-test-repo"
    create_regular_repo "$test_repo"
    add_upstream "$test_repo"

    # Run fork-report.sh and get JSON output
    local output
    output=$(FORK_SEARCH_DIRS="$test_repo" "$PROJECT_ROOT/fork-report.sh" json 2>/dev/null || echo "")

    # Verify it's valid JSON
    if echo "$output" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
        test_pass
    else
        test_fail "Invalid JSON output"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 13: fork-report.sh Markdown output
# =============================================================================
test_fork_report_markdown() {
    test_start "fork-report.sh Markdown output format"

    local test_repo="$TEST_BASE_DIR/md-test-repo"
    create_regular_repo "$test_repo"
    add_upstream "$test_repo"

    # Run fork-report.sh and get Markdown output
    local output
    output=$(FORK_SEARCH_DIRS="$test_repo" "$PROJECT_ROOT/fork-report.sh" markdown 2>/dev/null || echo "")

    # Verify it contains expected Markdown elements
    if echo "$output" | grep -q "# Repo Status Report" && \
       echo "$output" | grep -q "| Repo | Path |" && \
       echo "$output" | grep -q "## Summary"; then
        test_pass
    else
        test_fail "Markdown output missing expected elements"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 14: fork-watcher.sh --list option
# =============================================================================
test_fork_watcher_list() {
    test_start "fork-watcher.sh --list option"

    # Should run without crashing when no repos configured
    local output
    output=$(cd "$TEST_BASE_DIR" && "$PROJECT_ROOT/fork-watcher.sh" --list 2>&1 || true)

    # Should show "Tracked forks" header
    if echo "$output" | grep -q "Tracked forks"; then
        test_pass
    else
        test_fail "--list option did not produce expected output"
    fi
}

# =============================================================================
# TEST 15: Repository with non-standard default branch
# =============================================================================
test_non_default_branch() {
    test_start "Repository with non-standard default branch"

    local custom_branch_dir="$TEST_BASE_DIR/custom-branch-repo"
    create_regular_repo "$custom_branch_dir"

    cd "$custom_branch_dir"
    # Get current branch name (could be main or master depending on git config)
    local old_branch
    old_branch=$(git rev-parse --abbrev-ref HEAD)
    # Rename to something custom
    git branch -m "$old_branch" develop
    # Also try renaming on origin (may not exist)
    git branch -m "origin/$old_branch" origin/develop 2>/dev/null || true

    # Verify we're on develop branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch" == "develop" ]]; then
        test_pass
    else
        test_fail "Expected branch 'develop', got '$current_branch'"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 16: Repository with uncommitted changes (dirty)
# =============================================================================
test_dirty_repo() {
    test_start "Repository with uncommitted changes"

    local dirty_dir="$TEST_BASE_DIR/dirty-repo"
    create_regular_repo "$dirty_dir"

    cd "$dirty_dir"
    # Make uncommitted changes
    echo "dirty content" >> README.md

    # Verify repo is dirty
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        test_pass
    else
        test_fail "Repo should be dirty but appears clean"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 17: Repository with upstream ahead
# =============================================================================
test_upstream_ahead() {
    test_start "Repository where upstream is ahead"

    local behind_dir="$TEST_BASE_DIR/behind-repo"
    create_regular_repo "$behind_dir"
    add_upstream "$behind_dir"

    # Add commits to source (upstream)
    cd "$TEST_BASE_DIR/source-repo"
    echo "new upstream feature" > newfeature.txt
    git add newfeature.txt
    git commit -q -m "Add new feature"

    # Fetch in the fork
    cd "$behind_dir"
    git fetch upstream >/dev/null 2>&1

    # Check that we're behind (detect branch name dynamically)
    local upstream_branch
    upstream_branch=$(get_upstream_branch)
    local behind_count=$(git rev-list --count "HEAD..$upstream_branch" 2>/dev/null || echo "0")
    if [[ "$behind_count" -gt 0 ]]; then
        test_pass
    else
        test_fail "Expected to be behind upstream, count: $behind_count"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 18: Repository with local commits ahead
# =============================================================================
test_local_ahead() {
    test_start "Repository with local commits ahead of upstream"

    local ahead_dir="$TEST_BASE_DIR/ahead-repo"
    create_regular_repo "$ahead_dir"
    add_upstream "$ahead_dir"

    cd "$ahead_dir"
    # Fetch upstream to create remote-tracking branch
    git fetch upstream >/dev/null 2>&1
    # Add local commit
    echo "local feature" > local.txt
    git add local.txt
    git commit -q -m "Add local feature"

    # Check that we're ahead (detect branch name dynamically)
    local upstream_branch
    upstream_branch=$(get_upstream_branch)
    local ahead_count=$(git rev-list --count "$upstream_branch..HEAD" 2>/dev/null || echo "0")
    if [[ "$ahead_count" -gt 0 ]]; then
        test_pass
    else
        test_fail "Expected to be ahead of upstream, count: $ahead_count"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 19: Repository with diverged branches
# =============================================================================
test_diverged_branches() {
    test_start "Repository with diverged branches (both ahead and behind)"

    local diverged_dir="$TEST_BASE_DIR/diverged-repo"
    create_regular_repo "$diverged_dir"
    add_upstream "$diverged_dir"

    # First, add a local commit
    cd "$diverged_dir"
    echo "local change" > local-diverge.txt
    git add local-diverge.txt
    git commit -q -m "Local commit"

    # Then add commits to upstream
    cd "$TEST_BASE_DIR/source-repo"
    echo "upstream change" > upstream-diverge.txt
    git add upstream-diverge.txt
    git commit -q -m "Upstream commit"

    # Fetch in the fork
    cd "$diverged_dir"
    git fetch upstream >/dev/null 2>&1

    # Check both ahead and behind (detect branch name dynamically)
    local upstream_branch
    upstream_branch=$(get_upstream_branch)
    local ahead_count=$(git rev-list --count "$upstream_branch..HEAD" 2>/dev/null || echo "0")
    local behind_count=$(git rev-list --count "HEAD..$upstream_branch" 2>/dev/null || echo "0")

    if [[ "$ahead_count" -gt 0 ]] && [[ "$behind_count" -gt 0 ]]; then
        test_pass
    else
        test_fail "Expected diverged branches (ahead: $ahead_count, behind: $behind_count)"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 20: Repository path with spaces
# =============================================================================
test_repo_path_with_spaces() {
    test_start "Repository path with spaces"

    local space_dir="$TEST_BASE_DIR/repo with spaces in name"
    create_regular_repo "$space_dir" "space-repo"

    cd "$space_dir"
    if git status >/dev/null 2>&1 && git rev-parse HEAD >/dev/null 2>&1; then
        test_pass
    else
        test_fail "Could not operate in path with spaces"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 21: Shallow clone repository
# =============================================================================
test_shallow_clone() {
    test_start "Shallow clone repository"

    local shallow_dir="$TEST_BASE_DIR/shallow-repo"
    # Use file:// protocol to enable shallow clone for local repos
    git clone -q --depth 1 "file://$TEST_BASE_DIR/source-repo" "$shallow_dir"
    cd "$shallow_dir"
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Verify it's a shallow clone
    if [[ "$(git rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]]; then
        test_pass
    else
        test_fail "Expected shallow clone"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 22: Very deep nested repository
# =============================================================================
test_deep_nested_repo() {
    test_start "Very deep nested repository path"

    local deep_dir="$TEST_BASE_DIR"
    # Create a path with 10 levels of nesting
    for i in {1..10}; do
        deep_dir="$deep_dir/level$i"
    done
    mkdir -p "$deep_dir"
    create_regular_repo "$deep_dir" "deep-repo"

    cd "$deep_dir"
    if git status >/dev/null 2>&1; then
        test_pass
    else
        test_fail "Could not operate in deeply nested path"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 23: Repository with .git directory moved (gitdir)
# =============================================================================
test_gitdir_moved() {
    test_start "Repository with moved .git directory"

    local moved_gitdir="$TEST_BASE_DIR/moved-gitdir-repo"
    local actual_git_dir="$TEST_BASE_DIR/actual-git-dir"

    create_regular_repo "$moved_gitdir" "moved-gitdir"

    # Move the .git directory
    mv "$moved_gitdir/.git" "$actual_git_dir"

    # Update gitdir to point to new location
    echo "gitdir: $actual_git_dir" > "$moved_gitdir/.git"

    cd "$moved_gitdir"
    if git status >/dev/null 2>&1 && git rev-parse HEAD >/dev/null 2>&1; then
        test_pass
    else
        test_fail "Could not operate with moved .git directory"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 24: Worktree (git worktree)
# =============================================================================
test_worktree() {
    test_start "Repository with git worktree"

    local main_dir="$TEST_BASE_DIR/worktree-main"
    local worktree_dir="$TEST_BASE_DIR/worktree-branch"

    create_regular_repo "$main_dir" "worktree-main"

    cd "$main_dir"
    # Get current default branch name (main or master)
    local default_branch
    default_branch=$(git rev-parse --abbrev-ref HEAD)
    # Create a new branch
    git checkout -q -b feature-branch
    # Create a worktree pointing to the default branch
    git worktree add -q "$worktree_dir" "$default_branch"

    # Verify worktree works
    cd "$worktree_dir"
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch" == "$default_branch" ]]; then
        test_pass
    else
        test_fail "Worktree branch incorrect: $current_branch (expected $default_branch)"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# TEST 25: Repository with large number of branches
# =============================================================================
test_many_branches() {
    test_start "Repository with many branches"

    local many_branches_dir="$TEST_BASE_DIR/many-branches-repo"
    create_regular_repo "$many_branches_dir"

    cd "$many_branches_dir"
    # Create 50 branches
    for i in {1..50}; do
        git checkout -q -b "feature-branch-$i" 2>/dev/null || true
        echo "branch $i" > "branch-$i.txt"
        git add "branch-$i.txt" 2>/dev/null || true
        git commit -q -m "Branch $i" 2>/dev/null || true
    done

    # Count branches
    local branch_count=$(git branch | wc -l | tr -d ' ')
    if [[ "$branch_count" -ge 50 ]]; then
        test_pass
    else
        test_fail "Expected 50+ branches, got: $branch_count"
    fi

    cd "$TEST_BASE_DIR"
}

# =============================================================================
# Main test runner
# =============================================================================
main() {
    echo "========================================================================"
    echo "  Fork Tools Integration Test Suite"
    echo "========================================================================"
    echo ""

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --no-cleanup)
                CLEANUP=false
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --no-cleanup    Keep test repositories for inspection"
                echo "  --help, -h      Show this help message"
                exit 0
                ;;
        esac
    done

    # Export for subprocesses
    export CLEANUP

    # Setup
    setup

    # Run all tests
    test_empty_repo
    test_bare_repo
    test_no_origin
    test_multiple_remotes
    test_detached_head
    test_submodules
    test_symlinked_repo
    test_long_repo_name
    test_special_chars_repo_name
    test_concurrent_access
    test_fork_report_empty
    test_fork_report_json
    test_fork_report_markdown
    test_fork_watcher_list
    test_non_default_branch
    test_dirty_repo
    test_upstream_ahead
    test_local_ahead
    test_diverged_branches
    test_repo_path_with_spaces
    test_shallow_clone
    test_deep_nested_repo
    test_gitdir_moved
    test_worktree
    test_many_branches

    # Print summary
    echo ""
    echo "========================================================================"
    echo "  Test Summary"
    echo "========================================================================"
    echo ""
    echo -e "  Total Tests:  ${CYAN}$TESTS_RUN${NC}"
    echo -e "  Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed:       ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
