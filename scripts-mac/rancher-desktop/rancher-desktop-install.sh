#!/bin/bash
# File: rancher-desktop-install.sh
#
# Usage:
#   rancher-desktop-install [OPTIONS]
#   rancher-desktop-install [-h|--help]
#
# Purpose:
#   Install Rancher Desktop on Apple Silicon Macs via Jamf
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

SCRIPT_ID="rancher-desktop-install"
SCRIPT_NAME="Rancher Desktop Install"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Install Rancher Desktop on Apple Silicon Macs via Jamf"
SCRIPT_CATEGORY="DEVOPS"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

RANCHER_VERSION="1.22.0"
RANCHER_BASE_URL="https://github.com/rancher-sandbox/rancher-desktop/releases/download"
RANCHER_ARCH="aarch64"
RANCHER_APP_NAME="Rancher Desktop"
RANCHER_INSTALL_DIR="/Applications"
RANCHER_PROFILE_DIR="/Library/Managed Preferences"
RANCHER_TMP_DIR="/tmp"
KUBERNETES_ENABLED=false
MEMORY_GB=""
CPUS=""

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
  $SCRIPT_ID [options]

Options:
  -h, --help            Show this help message
  --version <VER>       Rancher Desktop version to install (default: $RANCHER_VERSION)
  --kubernetes          Enable Kubernetes (k3s)
  --no-kubernetes       Disable Kubernetes (k3s) (default)
  --memory <GB>         RAM allocation in GB (default: 25% of host RAM)
  --cpus <N>            CPU allocation (default: 50% of host cores)

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
        --version)
            shift
            RANCHER_VERSION="${1:?--version requires a value}"
            shift
            ;;
        --kubernetes)
            KUBERNETES_ENABLED=true
            shift
            ;;
        --no-kubernetes)
            KUBERNETES_ENABLED=false
            shift
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
        *)
            log_error "ERR001: Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate numeric inputs
if [ -n "$MEMORY_GB" ] && ! [[ "$MEMORY_GB" =~ ^[1-9][0-9]*$ ]]; then
    log_error "ERR011: --memory must be a positive integer, got: $MEMORY_GB"
    exit 1
fi
if [ -n "$CPUS" ] && ! [[ "$CPUS" =~ ^[1-9][0-9]*$ ]]; then
    log_error "ERR012: --cpus must be a positive integer, got: $CPUS"
    exit 1
fi

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

detect_resources() {
    local total_ram_gb
    local total_cpus

    if ! total_ram_gb=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1024/1024/1024}'); then
        log_error "ERR013: Failed to detect system RAM (sysctl hw.memsize)"
        exit 1
    fi
    if [ -z "$total_ram_gb" ] || [ "$total_ram_gb" -le 0 ] 2>/dev/null; then
        log_error "ERR013: Failed to detect system RAM — got: ${total_ram_gb:-empty}"
        exit 1
    fi

    if ! total_cpus=$(sysctl -n hw.ncpu 2>/dev/null); then
        log_error "ERR014: Failed to detect CPU count (sysctl hw.ncpu)"
        exit 1
    fi
    if [ -z "$total_cpus" ] || [ "$total_cpus" -le 0 ] 2>/dev/null; then
        log_error "ERR014: Failed to detect CPU count — got: ${total_cpus:-empty}"
        exit 1
    fi

    if [ -z "$MEMORY_GB" ]; then
        MEMORY_GB=$((total_ram_gb / 4))
        # Minimum 2 GB
        if [ "$MEMORY_GB" -lt 2 ]; then
            MEMORY_GB=2
        fi
        log_info "Auto-detected RAM: ${total_ram_gb} GB total, allocating ${MEMORY_GB} GB"
    fi

    if [ -z "$CPUS" ]; then
        CPUS=$((total_cpus / 2))
        # Minimum 1 CPU
        if [ "$CPUS" -lt 1 ]; then
            CPUS=1
        fi
        log_info "Auto-detected CPUs: ${total_cpus} total, allocating ${CPUS}"
    fi
}

install_rancher_desktop() {
    local dmg_file="Rancher.Desktop-${RANCHER_VERSION}.${RANCHER_ARCH}.dmg"
    local dmg_url="${RANCHER_BASE_URL}/v${RANCHER_VERSION}/${dmg_file}"
    local tmp_dmg="${RANCHER_TMP_DIR}/${dmg_file}"
    local mount_point="${RANCHER_TMP_DIR}/rancher-desktop-mount"

    log_info "Downloading Rancher Desktop v${RANCHER_VERSION}..."
    if ! curl -fSL --progress-bar -o "$tmp_dmg" "$dmg_url"; then
        log_error "ERR002: Failed to download Rancher Desktop from $dmg_url"
        rm -f "$tmp_dmg"
        exit 1
    fi
    if [ ! -f "$tmp_dmg" ]; then
        log_error "ERR003: Download completed but file not found at $tmp_dmg"
        exit 1
    fi

    log_info "Mounting disk image..."
    mkdir -p "$mount_point"
    if [ ! -d "$mount_point" ]; then
        log_error "ERR004: Failed to create mount point $mount_point"
        rm -f "$tmp_dmg"
        exit 1
    fi
    local hdiutil_err
    if ! hdiutil_err=$(hdiutil attach "$tmp_dmg" -mountpoint "$mount_point" -nobrowse 2>&1); then
        log_error "ERR005: Failed to mount disk image"
        log_error "ERR005: hdiutil: $hdiutil_err"
        rm -f "$tmp_dmg"
        exit 1
    fi

    log_info "Copying ${RANCHER_APP_NAME}.app to ${RANCHER_INSTALL_DIR}/..."
    local cp_err
    if ! cp_err=$(cp -R "${mount_point}/${RANCHER_APP_NAME}.app" "${RANCHER_INSTALL_DIR}/" 2>&1); then
        log_error "ERR006: Failed to copy application"
        log_error "ERR006: cp: $cp_err"
        hdiutil detach "$mount_point" -quiet 2>/dev/null || true
        rm -f "$tmp_dmg"
        exit 1
    fi
    if [ ! -d "${RANCHER_INSTALL_DIR}/${RANCHER_APP_NAME}.app" ]; then
        log_error "ERR007: ${RANCHER_APP_NAME}.app not found in ${RANCHER_INSTALL_DIR} after copy"
        hdiutil detach "$mount_point" -quiet 2>/dev/null || true
        rm -f "$tmp_dmg"
        exit 1
    fi

    log_info "Unmounting disk image..."
    hdiutil detach "$mount_point" -quiet 2>/dev/null || true

    log_info "Clearing Gatekeeper quarantine..."
    local xattr_err
    if ! xattr_err=$(xattr -cr "${RANCHER_INSTALL_DIR}/${RANCHER_APP_NAME}.app" 2>&1); then
        log_error "ERR008: Failed to clear Gatekeeper quarantine"
        log_error "ERR008: xattr: $xattr_err"
        exit 1
    fi

    log_info "Cleaning up..."
    rm -f "$tmp_dmg"
    rmdir "$mount_point" 2>/dev/null || true
}

deploy_profile() {
    local profile_path="${RANCHER_PROFILE_DIR}/io.rancherdesktop.profile.defaults.plist"

    log_info "Generating deployment profile..."
    log_info "  Container engine: moby (Docker)"
    log_info "  Kubernetes: ${KUBERNETES_ENABLED}"
    log_info "  Memory: ${MEMORY_GB} GB"
    log_info "  CPUs: ${CPUS}"

    mkdir -p "$RANCHER_PROFILE_DIR"
    if [ ! -d "$RANCHER_PROFILE_DIR" ]; then
        log_error "ERR009: Failed to create directory $RANCHER_PROFILE_DIR"
        exit 1
    fi

    # Write the plist directly — avoids dependency on plutil or rdctl
    cat > "$profile_path" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>version</key>
    <integer>10</integer>
    <key>containerEngine</key>
    <dict>
        <key>name</key>
        <string>moby</string>
    </dict>
    <key>kubernetes</key>
    <dict>
        <key>enabled</key>
        <${KUBERNETES_ENABLED}/>
    </dict>
    <key>virtualMachine</key>
    <dict>
        <key>memoryInGB</key>
        <integer>${MEMORY_GB}</integer>
        <key>numberCPUs</key>
        <integer>${CPUS}</integer>
    </dict>
</dict>
</plist>
PLIST

    if [ ! -f "$profile_path" ]; then
        log_error "ERR010: Failed to write deployment profile to $profile_path"
        exit 1
    fi

    log_info "Deployment profile written to $profile_path"
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    log_start
    log_info "  Version: ${RANCHER_VERSION}"
    log_info "  Kubernetes: ${KUBERNETES_ENABLED}"
    [ -n "$MEMORY_GB" ] && log_info "  Memory: ${MEMORY_GB} GB (user-specified)"
    [ -n "$CPUS" ] && log_info "  CPUs: ${CPUS} (user-specified)"

    if [ "$(id -u)" -ne 0 ]; then
        log_error "ERR015: This script must be run as root (sudo)"
        exit 1
    fi

    # Check if already installed
    if [ -d "${RANCHER_INSTALL_DIR}/${RANCHER_APP_NAME}.app" ]; then
        log_info "Rancher Desktop is already installed, skipping"
        log_info "Updating deployment profile only..."
        detect_resources
        deploy_profile
        log_success "Deployment profile updated"
        return 0
    fi

    detect_resources
    install_rancher_desktop
    deploy_profile

    log_success "$SCRIPT_NAME completed — Rancher Desktop v${RANCHER_VERSION} installed"
}

main "$@"
