#!/bin/bash
# File: test-helpers.sh
#
# Usage:
#   source tests/test-helpers.sh
#
# Purpose:
#   Shared helpers for Rancher Desktop USB test scripts
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
SCRIPT_VER="0.2.1"
SCRIPT_DESCRIPTION="Shared helpers for Rancher Desktop USB test scripts"
SCRIPT_CATEGORY="DEVOPS"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="/Library/Managed Preferences"
PROFILE_DEFAULTS="${PROFILE_DIR}/io.rancherdesktop.profile.defaults.plist"
PROFILE_LOCKED="${PROFILE_DIR}/io.rancherdesktop.profile.locked.plist"
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

show_defaults() {
    log_info "--- Defaults profile ---"
    if [ -f "$PROFILE_DEFAULTS" ]; then
        plutil -p "$PROFILE_DEFAULTS"
        plutil -lint "$PROFILE_DEFAULTS"
    else
        log_info "(not found)"
    fi
}

show_locked() {
    log_info "--- Locked profile ---"
    if [ -f "$PROFILE_LOCKED" ]; then
        plutil -p "$PROFILE_LOCKED"
        plutil -lint "$PROFILE_LOCKED"
    else
        log_info "(not found)"
    fi
}

verify_app() {
    log_info "--- Verify app installed ---"
    if [ -d "$APP_PATH" ]; then
        log_success "${APP_PATH} exists"
    else
        log_error "${APP_PATH} not found"
        return 1
    fi
}

verify_no_app() {
    log_info "--- Verify app removed ---"
    if [ -d "$APP_PATH" ]; then
        log_error "${APP_PATH} still exists"
        return 1
    else
        log_success "${APP_PATH} removed"
    fi
}

result_prompt() {
    local test_id="$1"
    local prompt="$2"
    echo ""
    log_info ">>> MANUAL CHECK for Test ${test_id}:"
    log_info ">>> ${prompt}"
    echo ""
    read -r -p "Record result (or press Enter to continue): " result
    if [ -n "$result" ]; then
        log_info "RESULT ${test_id}: ${result}"
    fi
}

verify_plist_value() {
    local file="$1" key="$2" expected="$3"
    if [ ! -f "$file" ]; then
        log_error "Profile not found: ${file}"
        return 1
    fi
    local actual
    actual=$(plutil -p "$file" 2>/dev/null | grep "\"${key}\"" | head -1 | sed 's/.*=> //' | tr -d ' "')
    if [ "$actual" = "$expected" ]; then
        log_success "${key} => ${actual}"
        return 0
    else
        log_error "${key} => ${actual} (expected ${expected})"
        return 1
    fi
}

verify_plist_key_exists() {
    local file="$1" key="$2"
    if plutil -p "$file" 2>/dev/null | grep "\"${key}\"" >/dev/null; then
        log_success "Key '${key}' present"
        return 0
    else
        log_error "Key '${key}' missing"
        return 1
    fi
}

launch_rancher_desktop() {
    local wait_for_docker="${1:-false}"
    local max_wait_docker=60
    local max_wait_app=30

    log_info "Launching Rancher Desktop..."
    open -a "Rancher Desktop"

    if [ "$wait_for_docker" = true ]; then
        log_info "Waiting for Docker to be ready (this may take a few minutes)..."
        local i
        for i in $(seq 1 "$max_wait_docker"); do
            if docker version >/dev/null 2>&1; then
                log_success "Docker is ready (waited ~$((i * 10)) seconds)"
                return 0
            fi
            sleep 10
        done
        log_error "Docker not ready after $((max_wait_docker * 10)) seconds"
        return 1
    else
        log_info "Waiting for Rancher Desktop to start..."
        local i
        for i in $(seq 1 "$max_wait_app"); do
            if pgrep -f "Rancher Desktop" >/dev/null 2>&1; then
                log_success "Rancher Desktop is running (waited ~$((i * 2)) seconds)"
                return 0
            fi
            sleep 2
        done
        log_error "Rancher Desktop not started after $((max_wait_app * 2)) seconds"
        return 1
    fi
}

quit_rancher_desktop() {
    if ! pgrep -f "Rancher Desktop" >/dev/null 2>&1; then
        log_info "Rancher Desktop is not running"
        return 0
    fi

    log_info "Stopping Rancher Desktop..."
    osascript -e 'quit app "Rancher Desktop"' 2>/dev/null || true

    local i
    for i in 1 2 3 4 5 6 7; do
        sleep 2
        if ! pgrep -f "Rancher Desktop" >/dev/null 2>&1; then
            log_success "Rancher Desktop stopped"
            return 0
        fi
        log_info "Waiting for Rancher Desktop to quit... (${i}/7)"
    done

    log_warning "Force killing Rancher Desktop..."
    pkill -9 -f "Rancher Desktop" 2>/dev/null || true
    sleep 2

    if ! pgrep -f "Rancher Desktop" >/dev/null 2>&1; then
        log_success "Rancher Desktop stopped (force killed)"
        return 0
    fi

    log_warning "Could not stop Rancher Desktop. Please quit it manually."
    read -r -p "Press Enter when Rancher Desktop is stopped..."
}

cleanup_locked() {
    if [ -f "$PROFILE_LOCKED" ]; then
        log_info "--- Cleaning up locked profile ---"
        rm -f "$PROFILE_LOCKED"
        if [ -f "$PROFILE_LOCKED" ]; then
            log_warning "Failed to remove locked profile"
        else
            log_success "Locked profile removed"
        fi
    fi
}
