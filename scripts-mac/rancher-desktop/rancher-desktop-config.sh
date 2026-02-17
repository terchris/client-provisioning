#!/bin/bash
# File: rancher-desktop-config.sh
#
# Usage:
#   rancher-desktop-config --memory <GB> [--cpus <N>] [OPTIONS]
#   rancher-desktop-config --cpus <N> [--memory <GB>] [OPTIONS]
#   rancher-desktop-config [-h|--help]
#
# Purpose:
#   Configure Rancher Desktop VM resources via deployment profile
#
# Author: Ops Team
# Created: February 2026
#
# The help() function, logging, and argument parsing are ready to use.
# Do not change the help() structure — the test runner validates it.

set -euo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="rancher-desktop-config"
SCRIPT_NAME="Rancher Desktop Config"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Configure Rancher Desktop VM resources via deployment profile"
SCRIPT_CATEGORY="DEVOPS"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

PLISTBUDDY="/usr/libexec/PlistBuddy"
RANCHER_PROFILE_DIR="/Library/Managed Preferences"
PROFILE_DEFAULTS="io.rancherdesktop.profile.defaults.plist"
PROFILE_LOCKED="io.rancherdesktop.profile.locked.plist"
PROFILE_VERSION=10

MEMORY_GB=""
CPUS=""
USE_LOCKED=false

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
  $SCRIPT_ID --memory <GB> [--cpus <N>] [options]
  $SCRIPT_ID --cpus <N> [--memory <GB>] [options]

Options:
  -h, --help      Show this help message
  --memory <GB>   RAM allocation in GB
  --cpus <N>      CPU allocation
  --lock          Write to locked profile (user cannot change setting)

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
        --memory)
            shift
            MEMORY_GB="${1:?--memory requires a value}"
            shift
            ;;
        --cpus)
            shift
            CPUS="${1:?--cpus requires a value}"
            shift
            ;;
        --lock)
            USE_LOCKED=true
            shift
            ;;
        *)
            log_error "ERR001: Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate at least one setting is provided
if [ -z "$MEMORY_GB" ] && [ -z "$CPUS" ]; then
    log_error "ERR002: At least one of --memory or --cpus is required"
    help
    exit 1
fi

# Validate numeric inputs
if [ -n "$MEMORY_GB" ] && ! [[ "$MEMORY_GB" =~ ^[1-9][0-9]*$ ]]; then
    log_error "ERR003: --memory must be a positive integer, got: $MEMORY_GB"
    exit 1
fi
if [ -n "$CPUS" ] && ! [[ "$CPUS" =~ ^[1-9][0-9]*$ ]]; then
    log_error "ERR004: --cpus must be a positive integer, got: $CPUS"
    exit 1
fi

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

plist_ensure_dict() {
    local file="$1" key="$2"
    "$PLISTBUDDY" -c "Print ${key}" "$file" 2>/dev/null \
        || "$PLISTBUDDY" -c "Add ${key} dict" "$file"
}

plist_set() {
    local file="$1" key="$2" type="$3" value="$4"
    "$PLISTBUDDY" -c "Set ${key} ${value}" "$file" 2>/dev/null \
        || "$PLISTBUDDY" -c "Add ${key} ${type} ${value}" "$file"
}

write_profile() {
    local profile_file
    local profile_type

    if [ "$USE_LOCKED" = true ]; then
        profile_file="$PROFILE_LOCKED"
        profile_type="locked"
    else
        profile_file="$PROFILE_DEFAULTS"
        profile_type="defaults"
    fi

    local profile_path="${RANCHER_PROFILE_DIR}/${profile_file}"

    log_info "Writing ${profile_type} profile..."

    mkdir -p "$RANCHER_PROFILE_DIR"
    if [ ! -d "$RANCHER_PROFILE_DIR" ]; then
        log_error "ERR005: Failed to create directory $RANCHER_PROFILE_DIR"
        exit 1
    fi

    # Use PlistBuddy to merge keys — preserves existing keys in the file
    plist_set "$profile_path" ":version" "integer" "$PROFILE_VERSION"
    plist_ensure_dict "$profile_path" ":virtualMachine"

    if [ -n "$MEMORY_GB" ]; then
        plist_set "$profile_path" ":virtualMachine:memoryInGB" "integer" "$MEMORY_GB"
        log_info "Setting memoryInGB = ${MEMORY_GB}"
    fi
    if [ -n "$CPUS" ]; then
        plist_set "$profile_path" ":virtualMachine:numberCPUs" "integer" "$CPUS"
        log_info "Setting numberCPUs = ${CPUS}"
    fi

    if [ ! -f "$profile_path" ]; then
        log_error "ERR006: Failed to write deployment profile to $profile_path"
        exit 1
    fi

    log_success "Deployment profile written to $profile_path"

    if [ "$USE_LOCKED" = true ]; then
        log_info "Profile is locked — settings are enforced on every launch"
    else
        log_info "Profile is defaults — only applies on first launch or after factory reset"
        log_info "Use --lock to override existing user settings"
    fi

    log_warning "Changing RAM/CPU will restart the VM on next Rancher Desktop launch"
    log_warning "All running containers will be stopped"
    log_warning "Restart Rancher Desktop for changes to take effect"
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    log_start
    [ -n "$MEMORY_GB" ] && log_info "  Memory: ${MEMORY_GB} GB"
    [ -n "$CPUS" ] && log_info "  CPUs: ${CPUS}"
    log_info "  Profile: $([ "$USE_LOCKED" = true ] && echo "locked" || echo "defaults")"

    if ! command -v "$PLISTBUDDY" >/dev/null 2>&1; then
        log_error "ERR007: PlistBuddy not found at $PLISTBUDDY — this script must run on macOS"
        exit 1
    fi

    if [ ! -w "$RANCHER_PROFILE_DIR" ] 2>/dev/null && [ ! -w "$(dirname "$RANCHER_PROFILE_DIR")" ] 2>/dev/null; then
        log_error "ERR008: Cannot write to $RANCHER_PROFILE_DIR — run with sudo"
        exit 1
    fi

    write_profile

    log_success "$SCRIPT_NAME completed"
}

main "$@"
