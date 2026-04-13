#!/usr/bin/env bash
# test-fork-check.sh - Behavior tests for fork-check.sh
#
# These tests execute fork-check.sh against real temporary git fixtures
# and assert on its output and exit codes. No grep-the-source theater.
#
# Usage: ./test-fork-check.sh
#        (or via Makefile: make test)

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/../fork-check.sh"
TMP_ROOT=""

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_NAMES=()

if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]] && [[ -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
else
    RED='' GREEN='' NC=''
fi

# ---- Test runner --------------------------------------------------------

run_test() {
    local name="$1"
    local fn="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    printf '  [%d] %s ... ' "$TESTS_RUN" "$name"
    if ( set -e; "$fn" ) >/tmp/fc_test_out 2>&1; then
        printf '%sPASS%s\n' "$GREEN" "$NC"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        printf '%sFAIL%s\n' "$RED" "$NC"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_NAMES+=("$name")
        sed 's/^/      | /' /tmp/fc_test_out
    fi
}

setup_tmp() {
    TMP_ROOT=$(mktemp -d -t fork-check-test.XXXXXX)
}

cleanup_tmp() {
    [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]] && rm -rf "$TMP_ROOT"
    TMP_ROOT=""
}

# Create a plain git repo at $1 (no commits, no remotes).
make_empty_repo() {
    local path="$1"
    mkdir -p "$path"
    git -C "$path" init -q
}

# Create a git repo with an upstream remote pointing at a bare repo.
# Returns the fork path via echo.
make_fork_with_upstream() {
    local parent="$1"
    local name="$2"
    local bare="$parent/${name}-upstream.git"
    local fork="$parent/$name"
    git init --bare -q "$bare"
    mkdir -p "$fork"
    git -C "$fork" init -q
    git -C "$fork" remote add upstream "$bare"
    echo "$fork"
}

# ---- Tests --------------------------------------------------------------

test_script_exists_and_executable() {
    [[ -f "$SCRIPT_PATH" ]]
    [[ -x "$SCRIPT_PATH" ]]
}

test_script_has_valid_bash_syntax() {
    bash -n "$SCRIPT_PATH"
}

test_empty_repos_and_no_discovery_exits_one_with_message() {
    setup_tmp
    local rc=0
    local out
    out=$(FORK_SEARCH_DIRS="$TMP_ROOT/empty" REPOS="" "$SCRIPT_PATH" 2>&1) || rc=$?
    cleanup_tmp
    [[ "$rc" -eq 1 ]] || { echo "expected exit 1, got $rc"; return 1; }
    echo "$out" | grep -q "no forks to check" \
        || { echo "expected 'no forks to check' in output, got: $out"; return 1; }
}

test_repos_env_with_nonexistent_path_warns_not_found() {
    setup_tmp
    local out
    out=$(REPOS="$TMP_ROOT/does-not-exist" "$SCRIPT_PATH" 2>&1) || true
    cleanup_tmp
    echo "$out" | grep -q "not found" \
        || { echo "expected 'not found' warning, got: $out"; return 1; }
}

test_repo_without_upstream_warns() {
    setup_tmp
    make_empty_repo "$TMP_ROOT/plain"
    local out
    out=$(REPOS="$TMP_ROOT/plain" "$SCRIPT_PATH" 2>&1) || true
    cleanup_tmp
    echo "$out" | grep -q "No upstream remote" \
        || { echo "expected 'No upstream remote', got: $out"; return 1; }
}

test_autodiscover_finds_repo_with_upstream() {
    setup_tmp
    make_fork_with_upstream "$TMP_ROOT" myfork >/dev/null
    local out rc=0
    # Point FORK_SEARCH_DIRS at the tmp root so the script finds the fork.
    out=$(FORK_SEARCH_DIRS="$TMP_ROOT" REPOS="" "$SCRIPT_PATH" 2>&1) || rc=$?
    cleanup_tmp
    # Auto-discovery succeeded if we do NOT see the "no forks to check" error.
    if echo "$out" | grep -q "no forks to check"; then
        echo "auto-discovery failed (exit=$rc): $out"
        return 1
    fi
    return 0
}

test_watch_mode_prints_header_and_can_be_killed() {
    setup_tmp
    make_empty_repo "$TMP_ROOT/plain"
    local out_file="$TMP_ROOT/watch.out"
    REPOS="$TMP_ROOT/plain" "$SCRIPT_PATH" 1 >"$out_file" 2>&1 &
    local pid=$!
    # Give the script a moment to print its header and enter the loop.
    sleep 0.5
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    local result=0
    grep -q "Watching" "$out_file" || result=1
    if (( result )); then
        echo "expected 'Watching' in watch-mode output, got:"
        cat "$out_file"
    fi
    cleanup_tmp
    return "$result"
}

test_non_numeric_arg_runs_single_check_not_watch() {
    setup_tmp
    make_empty_repo "$TMP_ROOT/plain"
    local out
    out=$(REPOS="$TMP_ROOT/plain" "$SCRIPT_PATH" "notanumber" 2>&1) || true
    cleanup_tmp
    if echo "$out" | grep -q "Watching"; then
        echo "non-numeric arg should not trigger watch mode, but it did: $out"
        return 1
    fi
    return 0
}

# ---- Main ---------------------------------------------------------------

main() {
    echo "=========================================="
    echo "fork-check.sh behavior tests"
    echo "=========================================="
    echo ""

    run_test "Script exists and is executable"            test_script_exists_and_executable
    run_test "Script has valid bash syntax"                test_script_has_valid_bash_syntax
    run_test "Empty REPOS + no forks → exit 1 with help"   test_empty_repos_and_no_discovery_exits_one_with_message
    run_test "REPOS with missing path warns 'not found'"   test_repos_env_with_nonexistent_path_warns_not_found
    run_test "Repo without upstream warns"                 test_repo_without_upstream_warns
    run_test "Auto-discover finds repo with upstream"      test_autodiscover_finds_repo_with_upstream
    run_test "Watch mode prints header and can be killed"  test_watch_mode_prints_header_and_can_be_killed
    run_test "Non-numeric arg runs single check not watch" test_non_numeric_arg_runs_single_check_not_watch

    echo ""
    echo "=========================================="
    echo "  Passed: $TESTS_PASSED / $TESTS_RUN"
    if (( TESTS_FAILED > 0 )); then
        echo "  Failed: $TESTS_FAILED"
        for name in "${FAILED_NAMES[@]}"; do
            echo "    - $name"
        done
        echo "=========================================="
        exit 1
    fi
    echo "=========================================="
    exit 0
}

trap cleanup_tmp EXIT

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
