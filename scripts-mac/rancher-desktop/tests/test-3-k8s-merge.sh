#!/bin/bash
# File: test-3-k8s-merge.sh
#
# Usage:
#   test-3-k8s-merge.sh [OPTIONS]
#   test-3-k8s-merge.sh [-h|--help]
#
# Purpose:
#   Test Kubernetes enable via plist merge preserving other keys
#
# Author: Ops Team
# Created: February 2026
#
# Prereq: Test 1 completed (defaults profile exists with install script keys)
# Do not change the help() structure — the test runner validates it.

set -euo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-3-k8s-merge"
SCRIPT_NAME="Test 3: K8s Plist Merge"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test Kubernetes enable via plist merge preserving other keys."
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

    header "1.4" "K8s script — plist merge"

    log_info "--- Profile BEFORE ---"
    show_defaults

    echo ""
    log_info "Running: sudo bash rancher-desktop-k8s.sh --enable"
    bash "${SCRIPT_DIR}/rancher-desktop-k8s.sh" --enable

    echo ""
    log_info "--- Profile AFTER ---"
    show_defaults

    echo ""
    log_info "Auto-verifying profile values..."
    local test_ok=true
    verify_plist_value "$PROFILE_DEFAULTS" "enabled" "1" || test_ok=false
    verify_plist_key_exists "$PROFILE_DEFAULTS" "name" || test_ok=false
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
