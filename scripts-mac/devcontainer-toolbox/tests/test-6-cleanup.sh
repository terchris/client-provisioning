#!/bin/bash
# File: test-6-cleanup.sh
#
# Usage:
#   test-6-cleanup.sh [OPTIONS]
#   test-6-cleanup.sh [-h|--help]
#
# Purpose:
#   Clean up after tests — remove installed command and test directories
#
# Author: Ops Team
# Created: February 2026
#
# Do not change the help() structure — the test runner validates it.

set -uo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-6-cleanup"
SCRIPT_NAME="Test 6: Cleanup"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Clean up after tests — remove installed command and test directories."
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

DEST="/usr/local/bin/devcontainer-init"

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

header "6" "Cleanup"

test_ok=true

# Remove installed command
log_info "Removing ${DEST}..."
if [ -f "$DEST" ]; then
    rm -f "$DEST"
    verify_no_file "$DEST" || test_ok=false
else
    log_info "${DEST} not found (already clean)"
fi

# Remove test directories
echo ""
log_info "Removing test directories..."
cleanup_test_dir "$TEST_WORK_DIR" || test_ok=false

if [ "$test_ok" = true ]; then
    echo ""
    log_success "Cleanup complete"
else
    echo ""
    log_error "Cleanup had issues"
    exit 1
fi
