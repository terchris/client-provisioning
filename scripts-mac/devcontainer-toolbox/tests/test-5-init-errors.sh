#!/bin/bash
# File: test-5-init-errors.sh
#
# Usage:
#   test-5-init-errors.sh [OPTIONS]
#   test-5-init-errors.sh [-h|--help]
#
# Purpose:
#   Test devcontainer-init.sh error paths
#
# Author: Ops Team
# Created: February 2026
#
# Do not change the help() structure — the test runner validates it.

set -uo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-5-init-errors"
SCRIPT_NAME="Test 5: Init Error Paths"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test devcontainer-init.sh error paths."
SCRIPT_CATEGORY="DEVOPS"

#------------------------------------------------------------------------------
# LOGGING
#------------------------------------------------------------------------------

log_time()    { date +%H:%M:%S; }
log_info()    { echo "[$(log_time)] INFO  $*" >&2; }
log_success() { echo "[$(log_time)] OK    $*" >&2; }
log_error()   { echo "[$(log_time)] ERROR $*" >&2; }
log_warning() { echo "[$(log_time)] WARN  $*" >&2; }

#------------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------------

help() {
    cat >&2 << EOF
$SCRIPT_NAME (v$SCRIPT_VER)
$SCRIPT_DESCRIPTION

Usage:
  $SCRIPT_ID [options]

Options:
  -h, --help  Show this help message

Metadata:
  ID:       $SCRIPT_ID
  Category: $SCRIPT_CATEGORY
EOF
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

while [ "${1:-}" != "" ] && [[ "${1:-}" == -* ]]; do
    case "$1" in
        -h|--help)
            help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${TESTS_DIR}/test-helpers.sh"

PROJECT_DIR="${TEST_WORK_DIR}/test-5-errors"

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

header "5" "Init error paths (devcontainer-init.sh)"

test_ok=true

# --- Error test A: backup already exists (ERR009) ---
echo ""
log_info "--- Error A: .devcontainer.backup/ already exists (ERR009) ---"

cleanup_test_dir "$PROJECT_DIR" 2>/dev/null
create_test_dir "$PROJECT_DIR"
mkdir -p "${PROJECT_DIR}/.devcontainer"
mkdir -p "${PROJECT_DIR}/.devcontainer.backup"

echo ""
log_info "Running: devcontainer-init.sh -y ${PROJECT_DIR} (should fail)"
bash "${SCRIPT_DIR}/devcontainer-init.sh" -y "$PROJECT_DIR" 2>&1
err_exit=$?

if [ "$err_exit" -ne 0 ]; then
    log_success "Correctly refused — backup already exists (exit code ${err_exit})"
else
    log_error "Should have refused but exited with code 0"
    test_ok=false
fi

# --- Error test B: nonexistent path (ERR002) ---
echo ""
log_info "--- Error B: nonexistent path (ERR002) ---"

log_info "Running: devcontainer-init.sh -y /nonexistent/path/$(date +%s) (should fail)"
bash "${SCRIPT_DIR}/devcontainer-init.sh" -y "/nonexistent/path/$(date +%s)" 2>&1
err_exit=$?

if [ "$err_exit" -ne 0 ]; then
    log_success "Correctly refused — path does not exist (exit code ${err_exit})"
else
    log_error "Should have refused but exited with code 0"
    test_ok=false
fi

# --- Error test C: target is a file, not a directory (ERR003) ---
echo ""
log_info "--- Error C: target is a file, not a directory (ERR003) ---"

TEST_FILE="${TEST_WORK_DIR}/test-5-not-a-dir"
echo "I am a file" > "$TEST_FILE"

log_info "Running: devcontainer-init.sh -y ${TEST_FILE} (should fail)"
bash "${SCRIPT_DIR}/devcontainer-init.sh" -y "$TEST_FILE" 2>&1
err_exit=$?

if [ "$err_exit" -ne 0 ]; then
    log_success "Correctly refused — target is not a directory (exit code ${err_exit})"
else
    log_error "Should have refused but exited with code 0"
    test_ok=false
fi

rm -f "$TEST_FILE"

# --- Summary ---
if [ "$test_ok" = true ]; then
    echo ""
    log_success "All error paths handled correctly"
else
    echo ""
    log_error "Some error paths not handled correctly"
    exit 1
fi
