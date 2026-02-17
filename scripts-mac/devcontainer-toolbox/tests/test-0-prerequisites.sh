#!/bin/bash
# File: test-0-prerequisites.sh
#
# Usage:
#   test-0-prerequisites.sh [OPTIONS]
#   test-0-prerequisites.sh [-h|--help]
#
# Purpose:
#   Verify Rancher Desktop is installed and Docker is running
#
# Author: Ops Team
# Created: February 2026
#
# Do not change the help() structure — the test runner validates it.

set -uo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-0-prerequisites"
SCRIPT_NAME="Test 0: Prerequisites"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Verify Rancher Desktop is installed and Docker is running."
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

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

header "0" "Prerequisites"

test_ok=true

log_info "Checking Rancher Desktop is installed..."
if [ -d "$APP_PATH" ]; then
    log_success "Rancher Desktop is installed"
else
    log_error "Rancher Desktop is not installed at ${APP_PATH}"
    log_info "Install Rancher Desktop first:"
    log_info "  sudo bash scripts-mac/rancher-desktop/rancher-desktop-install.sh"
    test_ok=false
fi

echo ""
log_info "Checking Docker is available..."
verify_command_available "docker" || test_ok=false

echo ""
log_info "Checking Docker daemon is running..."
verify_docker_running || test_ok=false

if [ "$test_ok" = true ]; then
    echo ""
    log_success "All prerequisites met"
else
    echo ""
    log_error "Prerequisites not met — cannot continue"
    log_info "Make sure Rancher Desktop is installed and running."
    exit 1
fi
