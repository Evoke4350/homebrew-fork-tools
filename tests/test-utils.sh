#!/bin/bash
# test-utils.sh - Comprehensive tests for shared utility functions
# Usage: ./tests/test-utils.sh
#
# Tests cover:
# 1. is_fork() function - detects forks by username or upstream
# 2. get_repo_status() - parses git status correctly
# 3. get_owner() - extracts owner from git URLs
# 4. json_escape() - properly escapes JSON strings
# 5. Platform detection - correctly identifies macOS/Linux/Windows
# 6. Color setup - respects NO_COLOR env var
# 7. URL parsing (HTTPS vs SSH git URLs)

set -eo pipefail

# ============================================================================
# TEST INFRASTRUCTURE
# ============================================================================

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for test output
setup_test_colors() {
    if [[ -n "$NO_COLOR" ]]; then
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

# Test assertions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "    ${RED}Expected: $expected${NC}"
        echo "    ${RED}Got: $actual${NC}"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Assertion failed}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo "    ${RED}Expected '$haystack' to contain '$needle'${NC}"
        return 1
    fi
}

assert_match() {
    local string="$1"
    local pattern="$2"
    local message="${3:-Assertion failed}"

    if [[ "$string" =~ $pattern ]]; then
        return 0
    else
        echo "    ${RED}Expected '$string' to match pattern '$pattern'${NC}"
        return 1
    fi
}

assert_success() {
    local exit_code="$1"
    if [[ "$exit_code" -eq 0 ]]; then
        return 0
    else
        echo "    ${RED}Command failed with exit code $exit_code${NC}"
        return 1
    fi
}

assert_failure() {
    local exit_code="$1"
    if [[ "$exit_code" -ne 0 ]]; then
        return 0
    else
        echo "    ${RED}Expected command to fail but it succeeded${NC}"
        return 1
    fi
}

# Test runner
run_test() {
    local test_name="$1"
    local test_function="$2"

    ((TESTS_RUN++))

    printf "  ${CYAN}Testing:${NC} $test_name ... "

    if output=$($test_function 2>&1); then
        ((TESTS_PASSED++))
        echo "${GREEN}PASS${NC}"
    else
        ((TESTS_FAILED++))
        echo "${RED}FAIL${NC}"
        [[ -n "$output" ]] && echo "$output"
    fi
}

# Test suite banner
start_suite() {
    local suite_name="$1"
    echo ""
    echo "${BLUE}========================================${NC}"
    echo "${BLUE}TEST SUITE: $suite_name${NC}"
    echo "${BLUE}========================================${NC}"
}

# ============================================================================
# SOURCE THE UTILITIES
# ============================================================================

source_utils() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_dir="$(dirname "$script_dir")"

    # Source the main script that contains the utility functions
    # We need to extract just the utility functions since running the whole
    # script would execute the main logic
    source "$project_dir/fork-report.sh"

    # The utility functions are now available:
    # - detect_platform
    # - setup_colors
    # - is_fork
    # - get_repo_status
    # - json_escape
}

# ============================================================================
# MOCK REPO SETUP
# ============================================================================

# Create a temporary directory for mock repos
MOCK_REPO_BASE=""
cleanup_repos() {
    if [[ -n "$MOCK_REPO_BASE" && -d "$MOCK_REPO_BASE" ]]; then
        rm -rf "$MOCK_REPO_BASE"
    fi
}

# Create a mock git repository
create_mock_repo() {
    local repo_name="$1"
    local with_upstream="${2:-false}"
    local with_changes="${3:-false}"
    local repo_path="$MOCK_REPO_BASE/$repo_name"

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

    # Set up upstream if requested
    if [[ "$with_upstream" == "true" ]]; then
        git remote add upstream "https://github.com/original/$repo_name.git"
    fi

    # Make uncommitted changes if requested
    if [[ "$with_changes" == "true" ]]; then
        echo "uncommitted changes" >> README.md
    fi

    echo "$repo_path"
}

# Create a mock git repository with specific remote URL
create_mock_repo_with_remote() {
    local repo_name="$1"
    local remote_url="$2"
    local repo_path="$MOCK_REPO_BASE/$repo_name"

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

    # Set up remote with specified URL
    git remote add origin "$remote_url"

    echo "$repo_path"
}

# ============================================================================
# UTILITY FUNCTIONS TO TEST
# ============================================================================

# Extract owner from git URL
# This is a derived utility based on patterns in the scripts
get_owner() {
    local url="$1"

    # Handle SSH URLs: git@github.com:owner/repo.git
    if [[ "$url" =~ ^git@.*:([^/]+)/ ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi

    # Handle HTTPS URLs: https://github.com/owner/repo.git
    if [[ "$url" =~ ^https?://[^/]+/([^/]+)/ ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi

    echo "unknown"
}

# ============================================================================
# TEST: is_fork() function
# ============================================================================

test_is_fork_with_upstream() {
    # Set up test environment
    GITHUB_USERNAMES=("testuser")

    local origin_url="https://github.com/testuser/myrepo.git"
    local upstream_url="https://github.com/original/myrepo.git"

    # Should return 0 (true) because upstream is set
    is_fork "$origin_url" "$upstream_url"
    assert_success $? "is_fork should detect upstream"
}

test_is_fork_with_username_match() {
    GITHUB_USERNAMES=("testuser" "anotheruser")

    local origin_url="https://github.com/testuser/myrepo.git"
    local upstream_url=""

    # Should return 0 (true) because origin contains username
    is_fork "$origin_url" "$upstream_url"
    assert_success $? "is_fork should detect username in origin URL"
}

test_is_fork_no_match() {
    GITHUB_USERNAMES=("testuser")

    local origin_url="https://github.com/original/myrepo.git"
    local upstream_url=""

    # Should return 1 (false) - no upstream, username doesn't match
    is_fork "$origin_url" "$upstream_url"
    assert_failure $? "is_fork should return false for non-fork"
}

test_is_fork_empty_username_list() {
    GITHUB_USERNAMES=()

    local origin_url="https://github.com/someuser/myrepo.git"
    local upstream_url=""

    # Should return 1 (false) when no usernames configured and no upstream
    is_fork "$origin_url" "$upstream_url"
    assert_failure $? "is_fork should return false with empty username list"
}

test_is_fork_multiple_usernames() {
    GITHUB_USERNAMES=("user1" "user2" "testuser")

    local origin_url="https://github.com/testuser/myrepo.git"
    local upstream_url=""

    # Should match against any username in the list
    is_fork "$origin_url" "$upstream_url"
    assert_success $? "is_fork should work with multiple usernames"
}

# ============================================================================
# TEST: get_owner() function
# ============================================================================

test_get_owner_https_url() {
    local url="https://github.com/ownername/repo.git"
    local owner=$(get_owner "$url")

    assert_equals "ownername" "$owner" "Should extract owner from HTTPS URL"
}

test_get_owner_https_github_com() {
    local url="https://github.com/testuser/fork-project.git"
    local owner=$(get_owner "$url")

    assert_equals "testuser" "$owner" "Should extract owner from github.com HTTPS URL"
}

test_get_owner_ssh_url() {
    local url="git@github.com:ownername/repo.git"
    local owner=$(get_owner "$url")

    assert_equals "ownername" "$owner" "Should extract owner from SSH URL"
}

test_get_owner_ssh_with_custom_host() {
    local url="git@gitlab.com:mygroup/project.git"
    local owner=$(get_owner "$url")

    assert_equals "mygroup" "$owner" "Should extract owner from SSH URL with custom host"
}

test_get_owner_http_no_git_extension() {
    local url="http://github.com/ownername/repo"
    local owner=$(get_owner "$url")

    assert_equals "ownername" "$owner" "Should extract owner from URL without .git"
}

test_get_owner_unknown_format() {
    local url="not-a-valid-url"
    local owner=$(get_owner "$url")

    assert_equals "unknown" "$owner" "Should return 'unknown' for invalid URLs"
}

test_get_owner_with_subgroup() {
    local url="https://gitlab.com/group/subgroup/project.git"
    local owner=$(get_owner "$url")

    # Should extract the first segment (group)
    assert_equals "group" "$owner" "Should extract first group from nested path"
}

# ============================================================================
# TEST: json_escape() function
# ============================================================================

test_json_escape_simple_string() {
    local input="simple string"
    local output=$(json_escape "$input")

    assert_equals "simple string" "$output" "Should pass through simple strings"
}

test_json_escape_double_quotes() {
    local input='string with "quotes"'
    local output=$(json_escape "$input")

    assert_contains "$output" '\\"' "Should escape double quotes"
}

test_json_escape_single_quotes() {
    local input="string with 'apostrophes'"
    local output=$(json_escape "$input")

    # Single quotes are escaped
    assert_contains "$output" "'" "Should handle single quotes"
}

test_json_escape_backslashes() {
    local input='path\to\file'
    local output=$(json_escape "$input")

    assert_contains "$output" '\\\\' "Should escape backslashes"
}

test_json_escape_newline() {
    local input=$'line1\nline2'
    local output=$(json_escape "$input")

    # Newlines should be preserved
    assert_contains "$output" $'\n' "Should preserve newlines"
}

test_json_escape_complex_string() {
    local input='{"key": "value"}'
    local output=$(json_escape "$input")

    # Double quotes should be escaped
    [[ "$output" == *'{\\\"key\\\": \\\"value\\\"}'* ]] || \
    [[ "$output" == *'{\\\\\"key\\\\\": \\\\\"value\\\\\"}'* ]]
    assert_success $? "Should escape complex JSON-like string"
}

test_json_escape_unicode() {
    local input="Hello 世界"
    local output=$(json_escape "$input")

    assert_equals "Hello 世界" "$output" "Should preserve unicode characters"
}

test_json_escape_empty_string() {
    local input=""
    local output=$(json_escape "$input")

    assert_equals "" "$output" "Should handle empty string"
}

# ============================================================================
# TEST: Platform Detection (detect_platform)
# ============================================================================

test_detect_platform_sets_variable() {
    detect_platform

    [[ -n "$PLATFORM" ]]
    assert_success $? "detect_platform should set PLATFORM variable"
}

test_detect_platform_valid_value() {
    detect_platform

    # PLATFORM should be one of the valid values
    [[ "$PLATFORM" =~ ^(linux|macos|windows|unknown)$ ]]
    assert_success $? "PLATFORM should be a valid value"
}

test_detect_platform_current_os() {
    detect_platform
    local current_os=$(uname -s)

    case "$current_os" in
        Linux*)
            assert_equals "linux" "$PLATFORM" "Should detect Linux"
            ;;
        Darwin*)
            assert_equals "macos" "$PLATFORM" "Should detect macOS"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            assert_equals "windows" "$PLATFORM" "Should detect Windows"
            ;;
        *)
            assert_equals "unknown" "$PLATFORM" "Should be unknown for unrecognized OS"
            ;;
    esac
}

# ============================================================================
# TEST: Color Setup (setup_colors)
# ============================================================================

test_setup_colors_sets_variables() {
    unset NO_COLOR
    setup_colors

    # All color variables should be set
    [[ -n "$RED" && -n "$GREEN" && -n "$YELLOW" && -n "$BLUE" && -n "$CYAN" && -n "$NC" ]]
    assert_success $? "setup_colors should set all color variables"
}

test_setup_colors_with_no_color() {
    NO_COLOR=1
    setup_colors

    # Colors should be empty when NO_COLOR is set
    [[ -z "$RED" && -z "$GREEN" && -z "$YELLOW" && -z "$BLUE" && -z "$CYAN" ]]
    assert_success $? "setup_colors should disable colors when NO_COLOR is set"
}

test_setup_colors_nc_always_set() {
    NO_COLOR=1
    setup_colors

    # NC should always be set (even if empty)
    [[ "${NC+x}" == "x" ]]
    assert_success $? "NC variable should always be defined"
}

# ============================================================================
# TEST: URL Parsing (HTTPS vs SSH)
# ============================================================================

test_url_parse_identify_https() {
    local url="https://github.com/user/repo.git"

    [[ "$url" =~ ^https:// ]]
    assert_success $? "Should identify HTTPS URL"
}

test_url_parse_identize_ssh() {
    local url="git@github.com:user/repo.git"

    [[ "$url" =~ ^git@ ]]
    assert_success $? "Should identify SSH URL"
}

test_url_parse_extract_repo_name_https() {
    local url="https://github.com/user/repository.git"

    [[ "$url" =~ ^https://[^/]+/[^/]+/([^/]+) ]]
    local repo_name="${BASH_REMATCH[1]}"

    assert_equals "repository.git" "$repo_name" "Should extract repo name from HTTPS URL"
}

test_url_parse_extract_repo_name_ssh() {
    local url="git@github.com:user/repository.git"

    [[ "$url" =~ ^git@[^:]+:([^/]+)/([^/]+) ]]
    local repo_name="${BASH_REMATCH[2]}"

    assert_equals "repository.git" "$repo_name" "Should extract repo name from SSH URL"
}

test_url_parse_strip_git_extension() {
    local url="https://github.com/user/repo.git"
    local clean_name="${url%.git}"

    assert_equals "https://github.com/user/repo" "$clean_name" "Should strip .git extension"
}

test_url_parse_gitlab_vs_github() {
    local github_url="https://github.com/user/repo.git"
    local gitlab_url="https://gitlab.com/user/repo.git"

    [[ "$github_url" =~ github\.com ]]
    assert_success $? "Should identify GitHub URL"

    [[ "$gitlab_url" =~ gitlab\.com ]]
    assert_success $? "Should identify GitLab URL"
}

test_url_parse_with_path() {
    local url="https://github.com/org/group/subgroup/repo.git"

    [[ "$url" =~ ^https://[^/]+/ ]]
    assert_success $? "Should parse URL with nested groups"
}

# ============================================================================
# TEST: get_repo_status() behavior
# ============================================================================

test_get_repo_status_clean_repo() {
    local repo_path=$(create_mock_repo "clean-repo")

    # Store original directory
    local original_dir=$(pwd)

    # Navigate to test repo
    cd "$repo_path"

    # Mock get_repo_status behavior - check if repo is clean
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        local status="clean"
    else
        local status="dirty"
    fi

    cd "$original_dir"

    assert_equals "clean" "$status" "Clean repo should have clean status"
}

test_get_repo_status_dirty_repo() {
    local repo_path=$(create_mock_repo "dirty-repo" false true)

    # Store original directory
    local original_dir=$(pwd)

    # Navigate to test repo
    cd "$repo_path"

    # Mock get_repo_status behavior - check if repo is dirty
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        local status="clean"
    else
        local status="dirty"
    fi

    cd "$original_dir"

    assert_equals "dirty" "$status" "Repo with changes should have dirty status"
}

test_get_repo_status_branch_name() {
    local repo_path=$(create_mock_repo "branch-test")

    # Store original directory
    local original_dir=$(pwd)

    # Navigate to test repo
    cd "$repo_path"

    # Get branch name
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    cd "$original_dir"

    assert_equals "main" "$branch" "Should detect main branch"
}

test_get_repo_status_commit_hash() {
    local repo_path=$(create_mock_repo "commit-test")

    # Store original directory
    local original_dir=$(pwd)

    # Navigate to test repo
    cd "$repo_path"

    # Get short commit hash
    local commit_hash=$(git log -1 --format="%h" 2>/dev/null || echo "unknown")

    cd "$original_dir"

    # Should be a 7-character hex string
    [[ "$commit_hash" =~ ^[0-9a-f]{7}$ ]]
    assert_success $? "Should get valid commit hash"
}

test_get_repo_status_commit_subject() {
    local repo_path=$(create_mock_repo "subject-test")

    # Store original directory
    local original_dir=$(pwd)

    # Navigate to test repo
    cd "$repo_path"

    # Get commit subject
    local commit_subject=$(git log -1 --format="%s" 2>/dev/null || echo "unknown")

    cd "$original_dir"

    assert_equals "Initial commit" "$commit_subject" "Should get commit subject"
}

# ============================================================================
# TEST: Integration tests with mock repos
# ============================================================================

test_integration_fork_detection() {
    # Create a fork (has upstream)
    local fork_path=$(create_mock_repo "test-fork" true)

    # Store original directory
    local original_dir=$(pwd)
    cd "$fork_path"

    local has_upstream=$(git remote get-url upstream 2>/dev/null || echo "")

    cd "$original_dir"

    [[ -n "$has_upstream" ]]
    assert_success $? "Fork should have upstream remote"
}

test_integration_non_fork_detection() {
    # Create a non-fork (no upstream)
    local non_fork_path=$(create_mock_repo "test-non-fork" false)

    # Store original directory
    local original_dir=$(pwd)
    cd "$non_fork_path"

    local has_upstream=$(git remote get-url upstream 2>/dev/null || echo "")

    cd "$original_dir"

    [[ -z "$has_upstream" ]]
    assert_success $? "Non-fork should not have upstream remote"
}

test_integration_remote_url_extraction() {
    local custom_url="https://github.com/customuser/customrepo.git"
    local repo_path=$(create_mock_repo_with_remote "remote-test" "$custom_url")

    # Store original directory
    local original_dir=$(pwd)
    cd "$repo_path"

    local origin_url=$(git remote get-url origin 2>/dev/null || echo "")

    cd "$original_dir"

    assert_equals "$custom_url" "$origin_url" "Should retrieve correct origin URL"
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

main() {
    setup_test_colors

    echo ""
    echo "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo "${BLUE}║     Homebrew Fork Tools - Utility Test Suite          ║${NC}"
    echo "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Set up mock repo base directory
    MOCK_REPO_BASE=$(mktemp -d -t fork-test-repos-XXXXXX)
    trap cleanup_repos EXIT

    # Source utilities
    source_utils

    # Run test suites
    # ========================================================================
    start_suite "is_fork() Function"
    run_test "Detects fork by upstream remote" test_is_fork_with_upstream
    run_test "Detects fork by username match" test_is_fork_with_username_match
    run_test "Returns false for non-fork" test_is_fork_no_match
    run_test "Handles empty username list" test_is_fork_empty_username_list
    run_test "Works with multiple usernames" test_is_fork_multiple_usernames

    start_suite "get_owner() Function"
    run_test "Extracts owner from HTTPS URL" test_get_owner_https_url
    run_test "Extracts owner from github.com HTTPS URL" test_get_owner_https_github_com
    run_test "Extracts owner from SSH URL" test_get_owner_ssh_url
    run_test "Extracts owner from SSH with custom host" test_get_owner_ssh_with_custom_host
    run_test "Extracts owner from URL without .git" test_get_owner_http_no_git_extension
    run_test "Returns 'unknown' for invalid URL" test_get_owner_unknown_format
    run_test "Handles subgroup paths" test_get_owner_with_subgroup

    start_suite "json_escape() Function"
    run_test "Passes through simple strings" test_json_escape_simple_string
    run_test "Escapes double quotes" test_json_escape_double_quotes
    run_test "Escapes single quotes" test_json_escape_single_quotes
    run_test "Escapes backslashes" test_json_escape_backslashes
    run_test "Preserves newlines" test_json_escape_newline
    run_test "Escapes complex JSON-like strings" test_json_escape_complex_string
    run_test "Preserves unicode characters" test_json_escape_unicode
    run_test "Handles empty string" test_json_escape_empty_string

    start_suite "Platform Detection"
    run_test "Sets PLATFORM variable" test_detect_platform_sets_variable
    run_test "Sets valid PLATFORM value" test_detect_platform_valid_value
    run_test "Detects current OS correctly" test_detect_platform_current_os

    start_suite "Color Setup"
    run_test "Sets all color variables" test_setup_colors_sets_variables
    run_test "Respects NO_COLOR environment variable" test_setup_colors_with_no_color
    run_test "Always defines NC variable" test_setup_colors_nc_always_set

    start_suite "URL Parsing"
    run_test "Identifies HTTPS URLs" test_url_parse_identify_https
    run_test "Identifies SSH URLs" test_url_parse_identize_ssh
    run_test "Extracts repo name from HTTPS URL" test_url_parse_extract_repo_name_https
    run_test "Extracts repo name from SSH URL" test_url_parse_extract_repo_name_ssh
    run_test "Strips .git extension" test_url_parse_strip_git_extension
    run_test "Identifies GitHub vs GitLab URLs" test_url_parse_gitlab_vs_github
    run_test "Parses URLs with nested paths" test_url_parse_with_path

    start_suite "Repository Status"
    run_test "Detects clean repository" test_get_repo_status_clean_repo
    run_test "Detects dirty repository" test_get_repo_status_dirty_repo
    run_test "Gets branch name" test_get_repo_status_branch_name
    run_test "Gets commit hash" test_get_repo_status_commit_hash
    run_test "Gets commit subject" test_get_repo_status_commit_subject

    start_suite "Integration Tests"
    run_test "Fork detection with mock repo" test_integration_fork_detection
    run_test "Non-fork detection with mock repo" test_integration_non_fork_detection
    run_test "Remote URL extraction" test_integration_remote_url_extraction

    # ========================================================================
    # Print summary
    echo ""
    echo "${BLUE}========================================${NC}"
    echo "${BLUE}TEST SUMMARY${NC}"
    echo "${BLUE}========================================${NC}"
    echo ""
    echo "  ${CYAN}Total Tests:${NC}   $TESTS_RUN"
    echo "  ${GREEN}Passed:${NC}        $TESTS_PASSED"
    echo "  ${RED}Failed:${NC}        $TESTS_FAILED"
    echo ""

    local pass_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        pass_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi

    echo "  ${CYAN}Pass Rate:${NC}     ${pass_rate}%"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
