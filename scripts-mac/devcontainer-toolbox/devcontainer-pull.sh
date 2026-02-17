#!/bin/bash
# File: devcontainer-pull.sh
#
# Usage:
#   devcontainer-pull [OPTIONS]
#   devcontainer-pull [-h|--help]
#
# Purpose:
#   Pull the devcontainer toolbox Docker image.
#
# Author: terchris
# Created: February 2026
#

set -euo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="devcontainer-pull"
SCRIPT_NAME="Devcontainer Pull"
SCRIPT_VER="0.2.1"
SCRIPT_DESCRIPTION="Pull the devcontainer toolbox Docker image."
SCRIPT_CATEGORY="DEVOPS"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

IMAGE_NAME="ghcr.io/terchris/devcontainer-toolbox:latest"

#------------------------------------------------------------------------------
# LOGGING
#------------------------------------------------------------------------------

log_time()    { date +%H:%M:%S; }
log_info()    { echo "[$(log_time)] INFO  $*" >&2; }
log_success() { echo "[$(log_time)] OK    $*" >&2; }
log_error()   { echo "[$(log_time)] ERROR $*" >&2; }
log_warning() { echo "[$(log_time)] WARN  $*" >&2; }
log_start()   { log_info "Starting: $SCRIPT_NAME Ver: $SCRIPT_VER"; }

#------------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------------

help() {
    cat >&2 << EOF
$SCRIPT_NAME (v$SCRIPT_VER)
$SCRIPT_DESCRIPTION

Usage:
  $SCRIPT_ID [IMAGE]

Options:
  IMAGE       Optional image (defaults to $IMAGE_NAME)
  -h, --help  Show this help message

Metadata:
  ID:       $SCRIPT_ID
  Category: $SCRIPT_CATEGORY
EOF
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    help
    exit 0
fi

if [ -n "${1:-}" ]; then
    IMAGE_NAME="$1"
fi

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

check_docker_installed() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "ERR001: Docker is not installed."
        exit 1
    fi
}

check_docker_running() {
    local docker_err
    if ! docker_err=$(docker ps 2>&1); then
        log_error "ERR002: Docker daemon is not running."
        log_error "ERR002: docker: $docker_err"
        exit 1
    fi
}

pull_image() {
    log_info "Pulling image: $IMAGE_NAME"
    # Don't capture output — docker pull can take a long time and the user
    # needs to see progress. Errors will print to stderr naturally.
    if ! docker pull "$IMAGE_NAME"; then
        log_error "ERR003: Failed to pull image: $IMAGE_NAME"
        exit 1
    fi
    log_success "Pulled $IMAGE_NAME"
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    log_start
    check_docker_installed
    check_docker_running
    pull_image
}

main "$@"
