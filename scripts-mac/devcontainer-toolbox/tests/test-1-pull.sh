#!/bin/bash
# File: test-1-pull.sh
#
# Usage:
#   test-1-pull.sh [OPTIONS]
#   test-1-pull.sh [-h|--help]
#
# Purpose:
#   Test devcontainer-pull.sh — pull image and verify it exists locally
#
# Author: Ops Team
# Created: February 2026
#
# Do not change the help() structure — the test runner validates it.

set -uo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-1-pull"
SCRIPT_NAME="Test 1: Pull Image"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test devcontainer-pull.sh — pull image and verify it exists locally."
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

IMAGE_NAME="ghcr.io/terchris/devcontainer-toolbox:latest"

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

header "1" "Pull image (devcontainer-pull.sh)"

log_info "Running: devcontainer-pull.sh"
echo ""
bash "${SCRIPT_DIR}/devcontainer-pull.sh"
pull_exit=$?
echo ""

test_ok=true

verify_exit_code "$pull_exit" 0 "devcontainer-pull.sh exited cleanly" || test_ok=false

echo ""
log_info "Verifying image exists locally..."
verify_image_exists "$IMAGE_NAME" || test_ok=false

if [ "$test_ok" = true ]; then
    echo ""
    log_success "Image pull verified"
else
    echo ""
    log_error "Image pull failed"
    exit 1
fi
