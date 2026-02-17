#!/bin/bash
# File: test-4-init-backup.sh
#
# Usage:
#   test-4-init-backup.sh [OPTIONS]
#   test-4-init-backup.sh [-h|--help]
#
# Purpose:
#   Test devcontainer-init.sh — init with existing .devcontainer (backup test)
#
# Author: Ops Team
# Created: February 2026
#
# Do not change the help() structure — the test runner validates it.

set -uo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-4-init-backup"
SCRIPT_NAME="Test 4: Init with Backup"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test devcontainer-init.sh — init with existing .devcontainer (backup test)."
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

PROJECT_DIR="${TEST_WORK_DIR}/test-4-backup"
MARKER_FILE="original-marker.txt"
MARKER_CONTENT="This file proves the backup was preserved"

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

header "4" "Init with backup (devcontainer-init.sh)"

# Clean up from any previous run
cleanup_test_dir "$PROJECT_DIR" 2>/dev/null
create_test_dir "$PROJECT_DIR"

# Create an existing .devcontainer/ with a marker file
log_info "Creating existing .devcontainer/ with marker file..."
mkdir -p "${PROJECT_DIR}/.devcontainer"
echo "$MARKER_CONTENT" > "${PROJECT_DIR}/.devcontainer/${MARKER_FILE}"
log_success "Created ${PROJECT_DIR}/.devcontainer/${MARKER_FILE}"

echo ""
log_info "Running: devcontainer-init.sh -y ${PROJECT_DIR}"
echo ""
bash "${SCRIPT_DIR}/devcontainer-init.sh" -y "$PROJECT_DIR"
init_exit=$?
echo ""

test_ok=true

verify_exit_code "$init_exit" 0 "devcontainer-init.sh exited cleanly" || test_ok=false

echo ""
log_info "Verifying backup was created..."
verify_dir_exists "${PROJECT_DIR}/.devcontainer.backup" || test_ok=false
verify_file_exists "${PROJECT_DIR}/.devcontainer.backup/${MARKER_FILE}" || test_ok=false

# Verify marker content is preserved
if [ -f "${PROJECT_DIR}/.devcontainer.backup/${MARKER_FILE}" ]; then
    actual_content=$(cat "${PROJECT_DIR}/.devcontainer.backup/${MARKER_FILE}")
    if [ "$actual_content" = "$MARKER_CONTENT" ]; then
        log_success "Marker file content preserved in backup"
    else
        log_error "Marker file content changed in backup"
        test_ok=false
    fi
fi

echo ""
log_info "Verifying new .devcontainer/ was created..."
verify_dir_exists "${PROJECT_DIR}/.devcontainer" || test_ok=false
verify_file_exists "${PROJECT_DIR}/.devcontainer/devcontainer.json" || test_ok=false
verify_json_valid "${PROJECT_DIR}/.devcontainer/devcontainer.json" || test_ok=false

if [ "$test_ok" = true ]; then
    echo ""
    log_success "Backup test verified"
else
    echo ""
    log_error "Backup test failed"
    exit 1
fi
