#!/bin/bash
# File: test-10-locked-config.sh
#
# Usage:
#   test-10-locked-config.sh [OPTIONS]
#   test-10-locked-config.sh [-h|--help]
#
# Purpose:
#   Test locked config profile overrides user settings
#
# Author: Ops Team
# Created: February 2026
#
# Prereq: Rancher Desktop installed and launched at least once (starting point B)
# Do not change the help() structure — the test runner validates it.

set -euo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-10-locked-config"
SCRIPT_NAME="Test 10: Locked Config Profile"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test locked config profile overrides user settings."
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

    header "2.2" "Locked config profile overrides user settings"

    log_info "Running: sudo bash rancher-desktop-config.sh --memory 4 --cpus 2 --lock"
    bash "${SCRIPT_DIR}/rancher-desktop-config.sh" --memory 4 --cpus 2 --lock

    echo ""
    show_locked

    echo ""
    log_info "Auto-verifying locked profile values..."
    local test_ok=true
    verify_plist_value "$PROFILE_LOCKED" "memoryInGB" "4" || test_ok=false
    verify_plist_value "$PROFILE_LOCKED" "numberCPUs" "2" || test_ok=false

    if [ "$test_ok" = true ]; then
        log_success "Locked profile values correct (auto-verified)"
    else
        log_error "Locked profile values incorrect (auto-verified)"
    fi

    echo ""
    launch_rancher_desktop

    echo ""
    log_info "MANUAL CHECK: Verify in Preferences:"
    log_info "  - Preferences > Virtual Machine shows 4 GB RAM and 2 CPUs"
    log_info "  - The sliders are greyed out (user cannot change them)"
    result_prompt "2.2" "greyed_out=yes/no"

    echo ""
    quit_rancher_desktop

    cleanup_locked

    log_success "$SCRIPT_NAME completed"
}

main "$@"
