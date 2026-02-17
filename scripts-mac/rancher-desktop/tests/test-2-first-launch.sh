#!/bin/bash
# File: test-2-first-launch.sh
#
# Usage:
#   test-2-first-launch.sh [OPTIONS]
#   test-2-first-launch.sh [-h|--help]
#
# Purpose:
#   Test first launch of Rancher Desktop and Docker verification
#
# Author: Ops Team
# Created: February 2026
#
# Prereq: Test 1 completed (Rancher Desktop installed but not yet launched)
# Do not change the help() structure — the test runner validates it.

set -euo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-2-first-launch"
SCRIPT_NAME="Test 2: First Launch"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Test first launch of Rancher Desktop and Docker verification."
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

    header "1.2" "First launch"

    launch_rancher_desktop true

    echo ""
    log_info "Verify in Preferences:"
    log_info "  - Container Engine = Docker (moby)"
    log_info "  - Kubernetes = disabled"
    log_info "  - Virtual Machine = auto-detected values"
    echo ""
    result_prompt "1.2" "engine=moby/other k8s=off/on memory=__GB cpus=__"

    header "1.3" "Docker works"

    log_info "Running: docker version"
    docker version || log_error "docker version failed"
    echo ""
    log_info "Running: docker run --rm hello-world"
    docker run --rm hello-world || log_error "docker run hello-world failed"

    echo ""
    quit_rancher_desktop

    log_success "$SCRIPT_NAME completed"
}

main "$@"
