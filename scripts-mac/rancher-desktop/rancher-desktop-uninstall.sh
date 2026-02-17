#!/bin/bash
# File: rancher-desktop-uninstall.sh
#
# Usage:
#   rancher-desktop-uninstall [OPTIONS]
#   rancher-desktop-uninstall [-h|--help]
#
# Purpose:
#   Uninstall Rancher Desktop and remove deployment profiles
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

SCRIPT_ID="rancher-desktop-uninstall"
SCRIPT_NAME="Rancher Desktop Uninstall"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Uninstall Rancher Desktop and remove deployment profiles"
SCRIPT_CATEGORY="DEVOPS"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

RANCHER_APP_NAME="Rancher Desktop"
RANCHER_INSTALL_DIR="/Applications"
RANCHER_PROFILE_DIR="/Library/Managed Preferences"
RANCHER_PROFILE_PREFIX="io.rancherdesktop.profile"

# User-level directories to remove (relative to home directory)
# Listed relative because when run via Jamf as root, $HOME is /var/root
RANCHER_USER_RELATIVE_DIRS=(
    "Library/Application Support/rancher-desktop"
    "Library/Application Support/Caches/rancher-desktop-updater"
    "Library/Caches/io.rancherdesktop.app"
    "Library/Logs/rancher-desktop"
    "Library/Preferences/rancher-desktop"
    "Library/rancher-desktop"
    ".rd"
)

# CLI symlinks that Rancher Desktop may have created
RANCHER_SYMLINK_DIRS=(
    "/usr/local/bin"
    "/opt/rancher-desktop"
)
RANCHER_SYMLINK_NAMES=(
    "rdctl"
    "docker"
    "kubectl"
    "nerdctl"
    "helm"
)

KEEP_PROFILE=false
CONFIRMED=false

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
  $SCRIPT_ID --confirm [options]

Options:
  -h, --help        Show this help message
  --confirm         Required. Confirms you understand this destroys all data
  --keep-profile    Keep the deployment profile in ${RANCHER_PROFILE_DIR}

WARNING:
  This script permanently destroys ALL container data including:
  - Docker images, containers, and volumes
  - Kubernetes resources (if k3s was enabled)
  Files bind-mounted from the host filesystem are NOT affected.

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
        --confirm)
            CONFIRMED=true
            shift
            ;;
        --keep-profile)
            KEEP_PROFILE=true
            shift
            ;;
        *)
            log_error "ERR001: Unknown option: $1"
            exit 1
            ;;
    esac
done

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

quit_rancher_desktop() {
    # pgrep -f matches "Rancher Desktop" (title case) — won't match this script
    # (rancher-desktop-uninstall, lowercase with hyphens)
    if ! pgrep -f "${RANCHER_APP_NAME}" >/dev/null 2>&1; then
        return 0
    fi

    log_info "Stopping ${RANCHER_APP_NAME}..."
    osascript -e "quit app \"${RANCHER_APP_NAME}\"" 2>/dev/null || true

    # Wait up to 15s for graceful quit
    local i
    for i in 1 2 3 4 5 6 7; do
        sleep 2
        if ! pgrep -f "${RANCHER_APP_NAME}" >/dev/null 2>&1; then
            log_info "${RANCHER_APP_NAME} stopped gracefully"
            return 0
        fi
        log_info "Waiting for ${RANCHER_APP_NAME} to quit... (${i}/7)"
    done

    # Force kill
    log_warning "${RANCHER_APP_NAME} did not quit gracefully, force killing..."
    pkill -9 -f "${RANCHER_APP_NAME}" 2>/dev/null || true

    # Wait up to 10s for force kill
    for i in 1 2 3 4 5; do
        sleep 2
        if ! pgrep -f "${RANCHER_APP_NAME}" >/dev/null 2>&1; then
            log_info "${RANCHER_APP_NAME} stopped after force kill"
            return 0
        fi
        log_info "Waiting for processes to exit... (${i}/5)"
    done

    log_error "ERR002: Failed to stop ${RANCHER_APP_NAME} after 25 seconds"
    exit 1
}

remove_app() {
    local app_path="${RANCHER_INSTALL_DIR}/${RANCHER_APP_NAME}.app"

    if [ -d "$app_path" ]; then
        log_info "Removing ${app_path}..."
        rm -rf "$app_path"
        if [ -d "$app_path" ]; then
            log_error "ERR003: Failed to remove ${app_path}"
            exit 1
        fi
    else
        log_info "${app_path} not found, skipping"
    fi
}

remove_profiles() {
    if [ "$KEEP_PROFILE" = true ]; then
        log_info "Keeping deployment profiles (--keep-profile)"
        return 0
    fi

    local found=false
    for plist in "${RANCHER_PROFILE_DIR}/${RANCHER_PROFILE_PREFIX}".*; do
        if [ -f "$plist" ]; then
            log_info "Removing profile: $plist"
            rm -f "$plist"
            if [ -f "$plist" ]; then
                log_error "ERR004: Failed to remove profile: $plist"
                exit 1
            fi
            found=true
        fi
    done

    if [ "$found" = false ]; then
        log_info "No deployment profiles found, skipping"
    fi
}

remove_user_data() {
    # When run as root (via Jamf), clean all user home directories
    # When run as regular user, clean only their home directory
    local homes=()
    if [ "$(id -u)" -eq 0 ]; then
        for home in /Users/*; do
            if [ -d "$home" ] && [ "$home" != "/Users/Shared" ]; then
                homes+=("$home")
            fi
        done
    else
        homes+=("$HOME")
    fi

    for home in "${homes[@]}"; do
        for rel_dir in "${RANCHER_USER_RELATIVE_DIRS[@]}"; do
            local dir="$home/$rel_dir"
            if [ -d "$dir" ]; then
                log_info "Removing ${dir}..."
                rm -rf "$dir"
                if [ -d "$dir" ]; then
                    log_error "ERR005: Failed to remove ${dir}"
                    exit 1
                fi
            fi
        done
    done
}

remove_symlinks() {
    for dir in "${RANCHER_SYMLINK_DIRS[@]}"; do
        for name in "${RANCHER_SYMLINK_NAMES[@]}"; do
            local link_path="${dir}/${name}"
            if [ -L "$link_path" ]; then
                local target
                target=$(readlink "$link_path" 2>/dev/null || true)
                # Only remove if it points to Rancher Desktop
                if [[ "$target" == *"rancher-desktop"* ]] || [[ "$target" == *"Rancher Desktop"* ]] || [[ "$target" == *"/opt/rancher-desktop/"* ]]; then
                    log_info "Removing symlink: ${link_path} -> ${target}"
                    rm -f "$link_path"
                    if [ -L "$link_path" ]; then
                        log_error "ERR006: Failed to remove symlink: ${link_path}"
                        exit 1
                    fi
                fi
            fi
        done
    done
}

remove_rancher_opt() {
    if [ -d "/opt/rancher-desktop" ]; then
        log_info "Removing /opt/rancher-desktop/..."
        rm -rf "/opt/rancher-desktop"
        if [ -d "/opt/rancher-desktop" ]; then
            log_error "ERR007: Failed to remove /opt/rancher-desktop"
            exit 1
        fi
    fi
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    log_start
    log_info "  Keep profile: ${KEEP_PROFILE}"

    if [ "$CONFIRMED" != true ]; then
        log_error "ERR008: --confirm is required"
        log_error "ERR008: This script permanently destroys ALL Docker images, containers, and volumes"
        log_error "ERR008: Run with --confirm to proceed"
        exit 1
    fi

    if [ "$(id -u)" -ne 0 ]; then
        log_error "ERR009: This script must be run as root (sudo)"
        exit 1
    fi

    quit_rancher_desktop
    remove_app
    remove_profiles
    remove_user_data
    remove_symlinks
    remove_rancher_opt

    log_success "$SCRIPT_NAME completed — Rancher Desktop removed"
}

main "$@"
