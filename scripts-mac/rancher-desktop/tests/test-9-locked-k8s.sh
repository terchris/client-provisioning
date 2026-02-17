#!/bin/bash
# File: test-9-locked-k8s.sh
#
# Usage:
#   test-9-locked-k8s.sh [OPTIONS]
#   test-9-locked-k8s.sh [-h|--help]
#
# Purpose:
#   Test locked k8s profile overrides user settings
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

SCRIPT_ID="test-9-locked-k8s"
SCRIPT_NAME="Test 9: Locked K8s Profile"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test locked k8s profile overrides user settings."
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

    header "2.1" "Locked k8s profile overrides user settings"

    log_info "Running: sudo bash rancher-desktop-k8s.sh --disable --lock"
    bash "${SCRIPT_DIR}/rancher-desktop-k8s.sh" --disable --lock

    echo ""
    show_locked

    echo ""
    log_info "Auto-verifying locked profile values..."
    local test_ok=true
    verify_plist_value "$PROFILE_LOCKED" "enabled" "0" || test_ok=false

    if [ "$test_ok" = true ]; then
        log_success "Locked profile values correct (auto-verified)"
    else
        log_error "Locked profile values incorrect (auto-verified)"
    fi

    echo ""
    launch_rancher_desktop

    echo ""
    log_info "MANUAL CHECK: Verify in Preferences:"
    log_info "  - Preferences > Kubernetes shows DISABLED"
    log_info "  - The checkbox is greyed out (user cannot change it)"
    result_prompt "2.1" "greyed_out=yes/no"

    echo ""
    quit_rancher_desktop

    cleanup_locked

    log_success "$SCRIPT_NAME completed"
}

main "$@"
