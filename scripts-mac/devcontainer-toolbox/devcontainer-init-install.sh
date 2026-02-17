#!/bin/bash
# File: devcontainer-init-install.sh
#
# Usage:
#   devcontainer-init-install [OPTIONS]
#   devcontainer-init-install [-h|--help]
#
# Purpose:
#   Install devcontainer-init script into /usr/local/bin.
#
# Author: terchris
# Created: February 2026
#

set -euo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="devcontainer-init-install"
SCRIPT_NAME="Devcontainer Init Installer"
SCRIPT_VER="0.2.1"
SCRIPT_DESCRIPTION="Install devcontainer-init script into /usr/local/bin."
SCRIPT_CATEGORY="DEVOPS"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

DEST_DIR="/usr/local/bin"
DEST_NAME="devcontainer-init"

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
  $SCRIPT_ID [SOURCE_SCRIPT]

Options:
  SOURCE_SCRIPT  Path to devcontainer-init.sh (auto-detected if omitted)
  -h, --help     Show this help message

If SOURCE_SCRIPT is not provided, the installer will look for
devcontainer-init.sh in the current directory or the
scripts-mac/devcontainer-toolbox directory.

Metadata:
  ID:       $SCRIPT_ID
  Category: $SCRIPT_CATEGORY
EOF
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

SOURCE_SCRIPT="${1:-}"
if [ "${SOURCE_SCRIPT:-}" = "-h" ] || [ "${SOURCE_SCRIPT:-}" = "--help" ]; then
    help
    exit 0
fi

if [ -z "$SOURCE_SCRIPT" ]; then
    if [ -f "./devcontainer-init.sh" ]; then
        SOURCE_SCRIPT="./devcontainer-init.sh"
    elif [ -f "scripts-mac/devcontainer-toolbox/devcontainer-init.sh" ]; then
        SOURCE_SCRIPT="scripts-mac/devcontainer-toolbox/devcontainer-init.sh"
    else
        log_error "ERR001: Could not find devcontainer-init.sh in current directory or scripts-mac/devcontainer-toolbox/"
        exit 1
    fi
fi

if [ ! -f "$SOURCE_SCRIPT" ]; then
    log_error "ERR002: Source script does not exist: $SOURCE_SCRIPT"
    exit 1
fi

if [ ! -w "$DEST_DIR" ]; then
    log_error "ERR003: Destination directory is not writable: $DEST_DIR"
    log_info "Try: sudo $0 $SOURCE_SCRIPT"
    exit 1
fi

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

install_script() {
    local cp_err
    if ! cp_err=$(cp "$SOURCE_SCRIPT" "$DEST_DIR/$DEST_NAME" 2>&1); then
        log_error "ERR004: Failed to copy $SOURCE_SCRIPT to $DEST_DIR/$DEST_NAME"
        log_error "ERR004: cp: $cp_err"
        exit 1
    fi
    if [ ! -f "$DEST_DIR/$DEST_NAME" ]; then
        log_error "ERR005: Copy completed but file not found at $DEST_DIR/$DEST_NAME"
        exit 1
    fi

    local chmod_err
    if ! chmod_err=$(chmod +x "$DEST_DIR/$DEST_NAME" 2>&1); then
        log_error "ERR006: Failed to make $DEST_DIR/$DEST_NAME executable"
        log_error "ERR006: chmod: $chmod_err"
        exit 1
    fi

    log_success "Installed $DEST_DIR/$DEST_NAME"
}

verify_installation() {
    if command -v "$DEST_NAME" >/dev/null 2>&1; then
        log_success "$DEST_NAME is available in PATH"
    else
        log_error "ERR007: $DEST_NAME is not available in PATH after install"
        exit 1
    fi
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    log_start

    install_script
    verify_installation

    log_info "Next steps:"
    log_info "  - Run: $DEST_NAME --help"
    log_info "  - If install required sudo, run the installer with sudo."
}

main "$@"
