#!/bin/bash
# File: test-1-install.sh
#
# Usage:
#   test-1-install.sh [OPTIONS]
#   test-1-install.sh [-h|--help]
#
# Purpose:
#   Test fresh install of Rancher Desktop with default settings
#
# Author: Ops Team
# Created: February 2026
#
# Prereq: Rancher Desktop is NOT installed (clean machine / starting point A)
# Do not change the help() structure — the test runner validates it.

set -euo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-1-install"
SCRIPT_NAME="Test 1: Fresh Install"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test fresh install of Rancher Desktop with default settings."
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

    header "1.1" "Fresh install (default settings)"

    log_info "Running: sudo bash rancher-desktop-install.sh"
    bash "${SCRIPT_DIR}/rancher-desktop-install.sh"

    verify_app
    show_defaults

    echo ""
    log_info "Auto-verifying profile values..."
    local test_ok=true
    verify_plist_value "$PROFILE_DEFAULTS" "name" "moby" || test_ok=false
    verify_plist_value "$PROFILE_DEFAULTS" "enabled" "0" || test_ok=false
    verify_plist_key_exists "$PROFILE_DEFAULTS" "memoryInGB" || test_ok=false
    verify_plist_key_exists "$PROFILE_DEFAULTS" "numberCPUs" || test_ok=false

    if [ "$test_ok" = true ]; then
        log_success "Profile values correct (auto-verified)"
    else
        log_error "Profile values incorrect (auto-verified)"
    fi

    log_success "$SCRIPT_NAME completed"
}

main "$@"
