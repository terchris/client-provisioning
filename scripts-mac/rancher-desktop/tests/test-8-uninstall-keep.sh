#!/bin/bash
# File: test-8-uninstall-keep.sh
#
# Usage:
#   test-8-uninstall-keep.sh [OPTIONS]
#   test-8-uninstall-keep.sh [-h|--help]
#
# Purpose:
#   Test uninstall with --keep-profile preserves deployment profiles
#
# Author: Ops Team
# Created: February 2026
#
# Prereq: Test 7 completed (Rancher Desktop installed with custom params)
# Do not change the help() structure — the test runner validates it.

set -euo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-8-uninstall-keep"
SCRIPT_NAME="Test 8: Uninstall Keep Profile"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test uninstall with --keep-profile preserves deployment profiles."
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

    header "1.9" "Uninstall with --keep-profile"

    log_info "Running: sudo bash rancher-desktop-uninstall.sh --confirm --keep-profile"
    bash "${SCRIPT_DIR}/rancher-desktop-uninstall.sh" --confirm --keep-profile

    echo ""
    log_info "--- Verify app removed ---"
    verify_no_app

    echo ""
    log_info "--- Profiles should still exist ---"
    if ls /Library/Managed\ Preferences/io.rancherdesktop.* 2>/dev/null; then
        log_success "Profiles kept"
    else
        log_error "Profiles were removed"
    fi

    result_prompt "1.9" "App removed but profiles kept? (yes/no)"

    echo ""
    log_info "--- Cleaning up leftover profiles ---"
    rm -f /Library/Managed\ Preferences/io.rancherdesktop.*
    if ! ls /Library/Managed\ Preferences/io.rancherdesktop.* 2>/dev/null; then
        log_success "Profiles cleaned up"
    fi

    log_success "$SCRIPT_NAME completed"
}

main "$@"
