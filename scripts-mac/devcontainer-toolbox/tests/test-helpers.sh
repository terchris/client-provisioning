#!/bin/bash
# File: test-helpers.sh
#
# Usage:
#   source tests/test-helpers.sh
#
# Purpose:
#   Shared helpers for devcontainer-toolbox USB test scripts
#
# Author: Ops Team
# Created: February 2026
#
# This file is sourced by test scripts — not run directly.
# Argument parsing only handles -h when run directly (for test runner validation).
# Do not change the help() structure — the test runner validates it.

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-helpers"
SCRIPT_NAME="Test Helpers"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Shared helpers for devcontainer-toolbox USB test scripts"
SCRIPT_CATEGORY="DEVOPS"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_WORK_DIR="/tmp/devcontainer-toolbox-tests"
APP_PATH="/Applications/Rancher Desktop.app"

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
  source $SCRIPT_ID.sh

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
            shift
            ;;
    esac
done

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

header() {
    local test_id="$1"
    local description="$2"
    echo ""
    echo "================================================================"
    echo "  Test ${test_id}: ${description}"
    echo "================================================================"
    echo "  Time: $(date)"
    echo ""
}

verify_file_exists() {
    local file="$1"
    if [ -f "$file" ]; then
        log_success "File exists: ${file}"
        return 0
    else
        log_error "File not found: ${file}"
        return 1
    fi
}

verify_file_executable() {
    local file="$1"
    if [ -x "$file" ]; then
        log_success "File is executable: ${file}"
        return 0
    else
        log_error "File is not executable: ${file}"
        return 1
    fi
}

verify_dir_exists() {
    local dir="$1"
    if [ -d "$dir" ]; then
        log_success "Directory exists: ${dir}"
        return 0
    else
        log_error "Directory not found: ${dir}"
        return 1
    fi
}

verify_no_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        log_error "Directory still exists: ${dir}"
        return 1
    else
        log_success "Directory removed: ${dir}"
        return 0
    fi
}

verify_no_file() {
    local file="$1"
    if [ -f "$file" ]; then
        log_error "File still exists: ${file}"
        return 1
    else
        log_success "File removed: ${file}"
        return 0
    fi
}

verify_command_available() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        log_success "Command available: ${cmd}"
        return 0
    else
        log_error "Command not found: ${cmd}"
        return 1
    fi
}

verify_json_valid() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_error "JSON file not found: ${file}"
        return 1
    fi
    if python3 -m json.tool "$file" >/dev/null 2>&1; then
        log_success "Valid JSON: ${file}"
        return 0
    else
        log_error "Invalid JSON: ${file}"
        return 1
    fi
}

verify_docker_running() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed"
        return 1
    fi
    if ! docker ps >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    fi
    log_success "Docker is running"
    return 0
}

verify_image_exists() {
    local image="$1"
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${image}$"; then
        log_success "Image exists locally: ${image}"
        return 0
    else
        log_error "Image not found locally: ${image}"
        return 1
    fi
}

verify_exit_code() {
    local actual="$1"
    local expected="$2"
    local description="$3"
    if [ "$actual" -eq "$expected" ]; then
        log_success "${description} (exit code ${actual})"
        return 0
    else
        log_error "${description} — expected exit code ${expected}, got ${actual}"
        return 1
    fi
}

create_test_dir() {
    local dir="${1:-$TEST_WORK_DIR}"
    mkdir -p "$dir"
    if [ ! -d "$dir" ]; then
        log_error "Failed to create test directory: ${dir}"
        return 1
    fi
    log_info "Created test directory: ${dir}"
    return 0
}

cleanup_test_dir() {
    local dir="${1:-$TEST_WORK_DIR}"
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        if [ -d "$dir" ]; then
            log_warning "Failed to remove test directory: ${dir}"
            return 1
        fi
        log_success "Removed test directory: ${dir}"
    fi
    return 0
}
