#!/bin/bash
# File: test-2-install.sh
#
# Usage:
#   test-2-install.sh [OPTIONS]
#   test-2-install.sh [-h|--help]
#
# Purpose:
#   Test devcontainer-init-install.sh — install command and verify in PATH
#
# Author: Ops Team
# Created: February 2026
#
# Do not change the help() structure — the test runner validates it.

set -uo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-2-install"
SCRIPT_NAME="Test 2: Install Command"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test devcontainer-init-install.sh — install command and verify in PATH."
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

header "2" "Install command (devcontainer-init-install.sh)"

log_info "Running: devcontainer-init-install.sh"
echo ""
bash "${SCRIPT_DIR}/devcontainer-init-install.sh"
install_exit=$?
echo ""

test_ok=true

verify_exit_code "$install_exit" 0 "devcontainer-init-install.sh exited cleanly" || test_ok=false

echo ""
log_info "Verifying installation..."
verify_file_exists "$DEST" || test_ok=false
verify_file_executable "$DEST" || test_ok=false
verify_command_available "devcontainer-init" || test_ok=false

echo ""
log_info "Verifying help output works..."
if devcontainer-init -h >/dev/null 2>&1; then
    log_success "devcontainer-init -h works"
else
    log_error "devcontainer-init -h failed"
    test_ok=false
fi

if [ "$test_ok" = true ]; then
    echo ""
    log_success "Install verified"
else
    echo ""
    log_error "Install failed"
    exit 1
fi
