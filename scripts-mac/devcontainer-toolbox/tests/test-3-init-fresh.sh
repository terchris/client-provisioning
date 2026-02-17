#!/bin/bash
# File: test-3-init-fresh.sh
#
# Usage:
#   test-3-init-fresh.sh [OPTIONS]
#   test-3-init-fresh.sh [-h|--help]
#
# Purpose:
#   Test devcontainer-init.sh — fresh init on an empty folder
#
# Author: Ops Team
# Created: February 2026
#
# Do not change the help() structure — the test runner validates it.

set -uo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-3-init-fresh"
SCRIPT_NAME="Test 3: Fresh Init"
SCRIPT_VER="0.2.1"
SCRIPT_DESCRIPTION="Test devcontainer-init.sh — fresh init on an empty folder."
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

PROJECT_DIR="${TEST_WORK_DIR}/test-3-fresh"

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

header "3" "Fresh init (devcontainer-init.sh)"

# Clean up from any previous run
cleanup_test_dir "$PROJECT_DIR" 2>/dev/null
create_test_dir "$PROJECT_DIR"

echo ""
log_info "Running: devcontainer-init.sh -y ${PROJECT_DIR}"
echo ""
bash "${SCRIPT_DIR}/devcontainer-init.sh" -y "$PROJECT_DIR"
init_exit=$?
echo ""

test_ok=true

verify_exit_code "$init_exit" 0 "devcontainer-init.sh exited cleanly" || test_ok=false

echo ""
log_info "Verifying .devcontainer/ was created..."
verify_dir_exists "${PROJECT_DIR}/.devcontainer" || test_ok=false
verify_file_exists "${PROJECT_DIR}/.devcontainer/devcontainer.json" || test_ok=false
verify_json_valid "${PROJECT_DIR}/.devcontainer/devcontainer.json" || test_ok=false

echo ""
log_info "Verifying .vscode/extensions.json was created..."
verify_dir_exists "${PROJECT_DIR}/.vscode" || test_ok=false
verify_file_exists "${PROJECT_DIR}/.vscode/extensions.json" || test_ok=false
verify_json_valid "${PROJECT_DIR}/.vscode/extensions.json" || test_ok=false

if [ -f "${PROJECT_DIR}/.vscode/extensions.json" ]; then
    if grep -q 'ms-vscode-remote.remote-containers' "${PROJECT_DIR}/.vscode/extensions.json"; then
        log_success "extensions.json contains Dev Containers extension"
    else
        log_error "extensions.json missing ms-vscode-remote.remote-containers"
        test_ok=false
    fi
fi

echo ""
log_info "Verifying no backup was created (fresh folder)..."
if [ -d "${PROJECT_DIR}/.devcontainer.backup" ]; then
    log_error "Unexpected .devcontainer.backup/ on fresh init"
    test_ok=false
else
    log_success "No .devcontainer.backup/ (correct for fresh init)"
fi

if [ "$test_ok" = true ]; then
    echo ""
    log_success "Fresh init verified"
else
    echo ""
    log_error "Fresh init failed"
    exit 1
fi
