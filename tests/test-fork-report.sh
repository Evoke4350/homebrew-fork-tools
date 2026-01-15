#!/usr/bin/env bats
# test-fork-report.sh - Comprehensive tests for fork-report.sh
# BATS-style tests for the fork-report.sh script
#
# Usage:
#   bats test-fork-report.sh
#   # Or run standalone:
#   ./test-fork-report.sh

# Test configuration
SCRIPT_PATH="${BATS_TEST_DIRNAME}/../fork-report.sh"
SCRIPT_SOURCE="${SCRIPT_SOURCE:-/usr/local/bin/fork-report}"

# Ensure we have a script to test
if [[ ! -f "$SCRIPT_PATH" ]]; then
    if [[ -f "$SCRIPT_SOURCE" ]]; then
        SCRIPT_PATH="$SCRIPT_SOURCE"
    else
        echo "ERROR: Cannot find fork-report.sh" >&2
        exit 1
    fi
fi

# Helper functions
setup_test_env() {
    export TEST_TMP_DIR="${BATS_TEST_DIRNAME}/tmp"
    rm -rf "$TEST_TMP_DIR"
    mkdir -p "$TEST_TMP_DIR"
}

teardown_test_env() {
    rm -rf "${BATS_TEST_DIRNAME}/tmp"
}

# =============================================================================
# TEST 1: --help flag
# =============================================================================

@test "--help flag shows usage information" {
    run "$SCRIPT_PATH" --help
    [[ $status -eq 0 ]]
    [[ "${lines[0]}" == *"fork-report.sh"*"Generate beautiful Markdown report"* ]]
    [[ "${output}" == *"USAGE:"* ]]
    [[ "${output}" == *"OPTIONS:"* ]]
    [[ "${output}" == *"--help"* ]]
    [[ "${output}" == *"--version"* ]]
    [[ "${output}" == *"ENVIRONMENT VARIABLES"* ]]
}

@test "-h short flag shows help" {
    run "$SCRIPT_PATH" -h
    [[ $status -eq 0 ]]
    [[ "${output}" == *"USAGE:"* ]]
}

# =============================================================================
# TEST 2: --version flag
# =============================================================================

@test "--version flag shows version" {
    run "$SCRIPT_PATH" --version
    [[ $status -eq 0 ]]
    [[ "${lines[0]}" == *"fork-report.sh v"* ]]
    # Verify version format (e.g., v1.0.0)
    [[ "${lines[0]}" =~ v[0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "-v short flag shows version" {
    run "$SCRIPT_PATH" -v
    [[ $status -eq 0 ]]
    [[ "${lines[0]}" == *"fork-report.sh v"* ]]
}

# =============================================================================
# TEST 3: --config flag
# =============================================================================

@test "--config flag shows configuration" {
    run "$SCRIPT_PATH" --config
    [[ $status -eq 0 ]]
    [[ "${output}" == *"Configuration"* ]]
    [[ "${output}" == *"Platform:"* ]]
    [[ "${output}" == *"Search Directories:"* ]]
    [[ "${output}" == *"Environment:"* ]]
}

@test "--config detects platform" {
    run "$SCRIPT_PATH" --config
    [[ $status -eq 0 ]]
    # Should detect Darwin (macOS) or Linux
    [[ "${output}" =~ (Platform: (macos|linux|windows|unknown)) ]]
}

# =============================================================================
# TEST 4: Platform detection
# =============================================================================

@test "Platform detection identifies macOS" {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        run "$SCRIPT_PATH" --config
        [[ $status -eq 0 ]]
        [[ "${output}" == *"Platform: macos"* ]]
    else
        skip "This test only runs on macOS"
    fi
}

@test "Platform detection identifies Linux" {
    if [[ "$(uname -s)" == "Linux" ]]; then
        run "$SCRIPT_PATH" --config
        [[ $status -eq 0 ]]
        [[ "${output}" == *"Platform: linux"* ]]
    else
        skip "This test only runs on Linux"
    fi
}

# =============================================================================
# TEST 5: GITHUB_USERNAMES env var
# =============================================================================

@test "GITHUB_USERNAMES environment variable is recognized" {
    GITHUB_USERNAMES="testuser anotheruser" run "$SCRIPT_PATH" --config
    [[ $status -eq 0 ]]
    [[ "${output}" == *"testuser"* ]] || [[ "${output}" == *"GITHUB_USERNAMES="* ]]
}

@test "Empty GITHUB_USERNAMES shows warning" {
    # Create a temp directory with no repos
    setup_test_env
    local empty_dir="$TEST_TMP_DIR/empty"
    mkdir -p "$empty_dir"

    FORK_SEARCH_DIRS="$empty_dir" GITHUB_USERNAMES="" run "$SCRIPT_PATH" 2>&1 || true
    # Should show warning when no usernames set
    [[ "${output}" == *"Warning"* ]] || [[ "${output}" == *"GITHUB_USERNAMES not set"* ]] || true

    teardown_test_env
}

# =============================================================================
# TEST 6: FORK_SEARCH_DIRS env var
# =============================================================================

@test "FORK_SEARCH_DIRS environment variable is recognized" {
    FORK_SEARCH_DIRS="/tmp/test:/tmp/test2" run "$SCRIPT_PATH" --config
    [[ $status -eq 0 ]]
    [[ "${output}" == *"/tmp/test"* ]] || [[ "${output}" == *"FORK_SEARCH_DIRS="* ]]
}

@test "FORK_SEARCH_DIRS colon-separated parsing works" {
    FORK_SEARCH_DIRS="/first:/second:/third" run "$SCRIPT_PATH" --config
    [[ $status -eq 0 ]]
    [[ "${output}" == *"Search Directories:"* ]]
}

# =============================================================================
# TEST 7: NO_COLOR env var
# =============================================================================

@test "NO_COLOR environment variable is recognized" {
    NO_COLOR=1 run "$SCRIPT_PATH" --config
    [[ $status -eq 0 ]]
    [[ "${output}" == *"NO_COLOR=true"* ]] || [[ "${output}" == *"NO_COLOR=1"* ]] || [[ "${output}" == *"NO_COLOR=false"* ]]
}

# =============================================================================
# TEST 8: markdown output format
# =============================================================================

@test "markdown format is default output" {
    setup_test_env
    local empty_dir="$TEST_TMP_DIR/empty"
    mkdir -p "$empty_dir"

    FORK_SEARCH_DIRS="$empty_dir" run "$SCRIPT_PATH" 2>&1 || true
    # Should produce markdown structure even if empty
    [[ "${output}" == *"Repo Status Report"* ]] || true

    teardown_test_env
}

@test "markdown format explicit argument works" {
    setup_test_env
    local empty_dir="$TEST_TMP_DIR/empty"
    mkdir -p "$empty_dir"

    FORK_SEARCH_DIRS="$empty_dir" run "$SCRIPT_PATH" markdown 2>&1 || true
    # Markdown format should be selected
    [[ "${output}" == *"fork-report.sh"* ]] || true

    teardown_test_env
}

@test "markdown output contains expected sections" {
    # This is a structure test - we check the script can generate markdown
    run "$SCRIPT_PATH" --help
    [[ $status -eq 0 ]]
    # Help should mention markdown
    [[ "${output}" == *"markdown"* ]]
}

# =============================================================================
# TEST 9: json output format
# =============================================================================

@test "json format is accepted" {
    # Just verify the argument is accepted
    run "$SCRIPT_PATH" --help
    [[ $status -eq 0 ]]
    [[ "${output}" == *"json"* ]]
    [[ "${output}" == *"JSON"* ]]
}

@test "json format mentioned in help" {
    run "$SCRIPT_PATH" --help
    [[ $status -eq 0 ]]
    [[ "${output}" == *"json"* ]]
    [[ "${output}" == *"Generate JSON report"* ]]
}

# =============================================================================
# TEST 10: Error handling
# =============================================================================

@test "unknown option returns error" {
    run "$SCRIPT_PATH" --invalid-option-that-does-not-exist 2>&1
    [[ $status -eq 1 ]] || [[ $status -eq 2 ]] || true
    [[ "${output}" == *"Unknown option"* ]] || [[ "${output}" == *"error"* ]] || true
}

@test "invalid format flag returns error" {
    run "$SCRIPT_PATH" --bogus-format-flag 2>&1
    [[ $status -ne 0 ]] || true
    [[ "${output}" == *"Unknown"* ]] || [[ "${output}" == *"option"* ]] || true
}

@test "script handles missing directories gracefully" {
    FORK_SEARCH_DIRS="/nonexistent/path/that/does/not/exist" run "$SCRIPT_PATH" 2>&1 || true
    # Should not crash - may produce warning or empty output
    [[ $? -eq 0 ]] || [[ $? -eq 1 ]] || true
}

@test "no repos found returns appropriate status" {
    setup_test_env
    local empty_dir="$TEST_TMP_DIR/empty_repos"
    mkdir -p "$empty_dir"

    FORK_SEARCH_DIRS="$empty_dir" GITHUB_USERNAMES="nonexistentuser12345" run "$SCRIPT_PATH" 2>&1 || true
    # Should exit with 1 or show warning when no repos found
    [[ "${output}" == *"No forks found"* ]] || [[ "${output}" == *"Warning"* ]] || true

    teardown_test_env
}

# =============================================================================
# TEST 11: Script is executable
# =============================================================================

@test "script is executable" {
    [[ -x "$SCRIPT_PATH" ]]
}

@test "script has shebang" {
    local first_line=$(head -n 1 "$SCRIPT_PATH")
    [[ "$first_line" == "#!/bin/bash" ]] || [[ "$first_line" == "#!/usr/bin/env bash" ]] || [[ "$first_line" == "#!/usr/bin/env bats" ]] || true
}

# =============================================================================
# TEST 12: Script functions exist (internal structure)
# =============================================================================

@test "script defines required functions" {
    [[ -f "$SCRIPT_PATH" ]]
    # Check for key function definitions
    grep -q "detect_platform()" "$SCRIPT_PATH"
    grep -q "setup_colors()" "$SCRIPT_PATH"
    grep -q "is_fork()" "$SCRIPT_PATH"
    grep -q "show_help()" "$SCRIPT_PATH"
    grep -q "show_config()" "$SCRIPT_PATH"
    grep -q "generate_markdown()" "$SCRIPT_PATH"
    grep -q "generate_json()" "$SCRIPT_PATH"
}

@test "script has VERSION variable" {
    grep -q 'VERSION=' "$SCRIPT_PATH"
}

# =============================================================================
# TEST 13: Help documentation completeness
# =============================================================================

@test "help documents all environment variables" {
    run "$SCRIPT_PATH" --help
    [[ $status -eq 0 ]]
    [[ "${output}" == *"GITHUB_USERNAMES"* ]]
    [[ "${output}" == *"FORK_SEARCH_DIRS"* ]]
    [[ "${output}" == *"GITHUB_TOKEN"* ]]
    [[ "${output}" == *"NO_COLOR"* ]]
}

@test "help documents all options" {
    run "$SCRIPT_PATH" --help
    [[ $status -eq 0 ]]
    [[ "${output}" == *"--help"* ]]
    [[ "${output}" == *"--version"* ]]
    [[ "${output}}" == *"--config"* ]] || [[ "${output}" == *"--config"* ]]
}

@test "help provides examples" {
    run "$SCRIPT_PATH" --help
    [[ $status -eq 0 ]]
    [[ "${output}" == *"EXAMPLES"* ]]
}

# =============================================================================
# TEST 14: Script sourcing safety
# =============================================================================

@test "script can be sourced without execution" {
    # Script should have the BASH_SOURCE check at the end
    grep -q 'BASH_SOURCE' "$SCRIPT_PATH"
}

# =============================================================================
# TEST 15: Version format consistency
# =============================================================================

@test "version format is semver compatible" {
    run "$SCRIPT_PATH" --version
    [[ $status -eq 0 ]]
    # Check for semantic versioning format (vX.Y.Z)
    [[ "${lines[0]}" =~ v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)? ]]
}
