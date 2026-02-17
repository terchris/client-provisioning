#!/bin/bash
# File: test-5-uninstall-safety.sh
#
# Usage:
#   test-5-uninstall-safety.sh [OPTIONS]
#   test-5-uninstall-safety.sh [-h|--help]
#
# Purpose:
#   Test that uninstall refuses to run without --confirm
#
# Author: Ops Team
# Created: February 2026
#
# Prereq: Rancher Desktop is installed
# Do not change the help() structure — the test runner validates it.
# NOTE: Uses set -uo pipefail (not -euo) because we expect a command failure.

set -uo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-5-uninstall-safety"
SCRIPT_NAME="Test 5: Uninstall Safety Check"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test that uninstall refuses to run without --confirm."
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
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

HELPERS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${HELPERS_DIR}/test-helpers.sh"

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    log_start

    header "1.6" "Uninstall safety check"

    log_info "Running: sudo bash rancher-desktop-uninstall.sh (WITHOUT --confirm)"
    bash "${SCRIPT_DIR}/rancher-desktop-uninstall.sh" && {
        log_error "Script should have exited with error"
        exit 1
    }
    exit_code=$?
    echo ""
    log_info "Exit code: ${exit_code}"

    echo ""
    log_info "Expected: Script exited with error about --confirm being required"
    log_info "Verifying nothing was deleted..."
    verify_app
    show_defaults

    echo ""
    log_success "Safety check passed — nothing was deleted"

    log_success "$SCRIPT_NAME completed"
}

main "$@"
