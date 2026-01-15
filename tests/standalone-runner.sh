#!/bin/bash
# standalone-runner.sh - Simple test runner for fork-report.sh without BATS
# This provides basic validation when BATS is not available

set -o pipefail

# Get script directory and resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/../fork-report.sh"
SCRIPT_SOURCE="${SCRIPT_SOURCE:-/usr/local/bin/fork-report}"

# Colors for output
if [[ -z "${NO_COLOR:-}" ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' BLUE='' NC=''
fi

TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracker
test_pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_skip() {
    echo -e "${YELLOW}SKIP${NC}: $1"
}

# Ensure we have a script to test
if [[ ! -f "$SCRIPT_PATH" ]]; then
    if [[ -f "$SCRIPT_SOURCE" ]]; then
        SCRIPT_PATH="$SCRIPT_SOURCE"
    else
        echo "ERROR: Cannot find fork-report.sh" >&2
        exit 1
    fi
fi

echo "================================================================"
echo "      fork-report.sh Standalone Test Runner"
echo "================================================================"
echo ""
echo "Script: $SCRIPT_PATH"
echo ""

# Test 1: --help flag
echo "Testing --help flag..."
if output=$("$SCRIPT_PATH" --help 2>&1); then
    if echo "$output" | grep -q "USAGE:" && echo "$output" | grep -q "OPTIONS:"; then
        test_pass "Help flag shows usage and options"
    else
        test_fail "Help output missing expected sections"
    fi
else
    test_fail "Help flag returned non-zero exit"
fi

# Test 2: -h short flag
echo "Testing -h flag..."
if "$SCRIPT_PATH" -h 2>&1 | grep -q "USAGE:"; then
    test_pass "-h flag shows help"
else
    test_fail "-h flag failed"
fi

# Test 3: --version flag
echo "Testing --version flag..."
if output=$("$SCRIPT_PATH" --version 2>&1); then
    if echo "$output" | grep -qE "v[0-9]+\.[0-9]+\.[0-9]+"; then
        test_pass "Version shows semver format"
        echo "  Version: $output"
    else
        test_fail "Version format incorrect"
    fi
else
    test_fail "Version flag returned non-zero exit"
fi

# Test 4: -v short flag
echo "Testing -v flag..."
if "$SCRIPT_PATH" -v 2>&1 | grep -q "fork-report.sh v"; then
    test_pass "-v flag shows version"
else
    test_fail "-v flag failed"
fi

# Test 5: --config flag
echo "Testing --config flag..."
if output=$("$SCRIPT_PATH" --config 2>&1); then
    if echo "$output" | grep -q "Platform:" && echo "$output" | grep -q "Search Directories:"; then
        test_pass "Config shows platform and search directories"
    else
        test_fail "Config output missing expected sections"
    fi
else
    test_fail "Config flag returned non-zero exit"
fi

# Test 6: Platform detection
echo "Testing platform detection..."
if [[ "$(uname -s)" == "Darwin" ]]; then
    if output=$("$SCRIPT_PATH" --config 2>&1) && echo "$output" | grep -q "Platform: macos"; then
        test_pass "Platform detection identifies macOS"
    else
        test_fail "Platform detection failed for macOS"
    fi
elif [[ "$(uname -s)" == "Linux" ]]; then
    if "$SCRIPT_PATH" --config 2>&1 | grep -q "Platform: linux"; then
        test_pass "Platform detection identifies Linux"
    else
        test_fail "Platform detection failed for Linux"
    fi
else
    test_skip "Platform detection (not macOS/Linux)"
fi

# Test 7: GITHUB_USERNAMES env var
echo "Testing GITHUB_USERNAMES environment variable..."
if output=$(GITHUB_USERNAMES="testuser" "$SCRIPT_PATH" --config 2>&1) && echo "$output" | grep -q "GITHUB_USERNAMES"; then
    test_pass "GITHUB_USERNAMES is recognized in config"
else
    test_fail "GITHUB_USERNAMES not shown in config"
fi

# Test 8: FORK_SEARCH_DIRS env var
echo "Testing FORK_SEARCH_DIRS environment variable..."
if output=$(FORK_SEARCH_DIRS="/tmp/test" "$SCRIPT_PATH" --config 2>&1) && echo "$output" | grep -q "/tmp/test"; then
    test_pass "FORK_SEARCH_DIRS is recognized in config"
else
    test_fail "FORK_SEARCH_DIRS not shown in config"
fi

# Test 9: NO_COLOR env var
echo "Testing NO_COLOR environment variable..."
if NO_COLOR=1 "$SCRIPT_PATH" --config 2>&1 | grep -q "NO_COLOR"; then
    test_pass "NO_COLOR is recognized in config"
else
    test_fail "NO_COLOR not shown in config"
fi

# Test 10: Markdown format
echo "Testing markdown output format..."
if "$SCRIPT_PATH" --help 2>&1 | grep -q "markdown"; then
    test_pass "Markdown format is documented"
else
    test_fail "Markdown format not in help"
fi

# Test 11: JSON format
echo "Testing JSON output format..."
if "$SCRIPT_PATH" --help 2>&1 | grep -q "json"; then
    test_pass "JSON format is documented"
else
    test_fail "JSON format not in help"
fi

# Test 12: Unknown option error handling
echo "Testing unknown option error handling..."
if output=$("$SCRIPT_PATH" --invalid-option 2>&1 || true) && echo "$output" | grep -qi "unknown\|error"; then
    test_pass "Unknown option returns error"
else
    test_fail "Unknown option handling failed"
fi

# Test 13: Script is executable
echo "Testing script permissions..."
if [[ -x "$SCRIPT_PATH" ]]; then
    test_pass "Script is executable"
else
    test_fail "Script is not executable"
fi

# Test 14: Script has shebang
echo "Testing script shebang..."
first_line=$(head -n 1 "$SCRIPT_PATH")
if [[ "$first_line" == "#!/bin/bash" ]] || [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
    test_pass "Script has valid shebang"
else
    test_fail "Script shebang is invalid"
fi

# Test 15: Script functions exist
echo "Testing script functions..."
missing_funcs=0
for func in detect_platform setup_colors is_fork show_help show_config generate_markdown generate_json; do
    if ! grep -q "${func}()" "$SCRIPT_PATH"; then
        echo "  Missing: $func"
        ((missing_funcs++))
    fi
done
if [[ $missing_funcs -eq 0 ]]; then
    test_pass "All required functions defined"
else
    test_fail "$missing_funcs function(s) missing"
fi

# Test 16: VERSION variable
echo "Testing VERSION variable..."
if grep -q 'VERSION=' "$SCRIPT_PATH"; then
    test_pass "VERSION variable defined"
else
    test_fail "VERSION variable not found"
fi

# Test 17: Help documentation
echo "Testing help documentation completeness..."
missing_docs=0
for var in GITHUB_USERNAMES FORK_SEARCH_DIRS GITHUB_TOKEN NO_COLOR; do
    if ! "$SCRIPT_PATH" --help 2>&1 | grep -q "$var"; then
        echo "  Missing doc: $var"
        ((missing_docs++))
    fi
done
if [[ $missing_docs -eq 0 ]]; then
    test_pass "Help documents all environment variables"
else
    test_fail "$missing_docs env var(s) not documented"
fi

# Summary
echo ""
echo "================================================================"
echo "                    Test Results Summary"
echo "================================================================"
echo ""
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo "Failed: $TESTS_FAILED"
fi
echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "For full BATS test suite, run: bats test-fork-report.sh"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
