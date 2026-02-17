#!/bin/bash
# File: test-6-full-uninstall.sh
#
# Usage:
#   test-6-full-uninstall.sh [OPTIONS]
#   test-6-full-uninstall.sh [-h|--help]
#
# Purpose:
#   Test full uninstall removes app, profiles, and user data
#
# Author: Ops Team
# Created: February 2026
#
# Prereq: Rancher Desktop is installed
# Do not change the help() structure — the test runner validates it.

set -euo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-6-full-uninstall"
SCRIPT_NAME="Test 6: Full Uninstall"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test full uninstall removes app, profiles, and user data."
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

    header "1.7" "Full uninstall"

    log_info "Running: sudo bash rancher-desktop-uninstall.sh --confirm"
    bash "${SCRIPT_DIR}/rancher-desktop-uninstall.sh" --confirm

    echo ""
    log_info "--- Checking what was removed ---"

    verify_no_app

    # shellcheck disable=SC2012
    ls /Library/Managed\ Preferences/io.rancherdesktop.* 2>/dev/null \
        && log_error "Profiles still exist" \
        || log_success "Profiles removed"
    ls ~/Library/Application\ Support/rancher-desktop 2>/dev/null \
        && log_error "User data still exists" \
        || log_success "User data removed"
    which docker 2>/dev/null \
        && log_warning "docker still on PATH" \
        || log_success "docker symlink removed"
    which kubectl 2>/dev/null \
        && log_warning "kubectl still on PATH" \
        || log_success "kubectl symlink removed"

    result_prompt "1.7" "Everything removed cleanly? (yes/no + details)"

    log_success "$SCRIPT_NAME completed"
}

main "$@"
