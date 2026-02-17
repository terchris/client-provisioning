#!/bin/bash
# File: devcontainer-init.sh
#
# Usage:
#   devcontainer-init [OPTIONS] [FOLDER_PATH]
#   devcontainer-init [-y|--yes] [FOLDER_PATH]
#
# Options:
#   -y, --yes   Run non-interactively (skip confirmation prompts)
#   -h, --help  Show this help message
#
# Purpose:
#   Initialize a repo folder for use with devcontainer by creating a .devcontainer folder and copying the necessary configuration files.
#
# Author: terchris
# Created: February 2026
#

set -euo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="devcontainer-init"
SCRIPT_NAME="Devcontainer Initialization"
SCRIPT_VER="0.2.3"
SCRIPT_DESCRIPTION="Initialize a repo folder for use with devcontainer by creating a .devcontainer folder and copying the necessary configuration files."
SCRIPT_CATEGORY="DEVOPS"


#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

# Repository and image configuration (from devcontainer-toolbox install.sh)
REPO="terchris/devcontainer-toolbox"
DEVCONTAINER_JSON_URL="https://raw.githubusercontent.com/$REPO/main/devcontainer-user-template.json"

#------------------------------------------------------------------------------
# LOGGING
#------------------------------------------------------------------------------

log_time() { date +%H:%M:%S; }
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
  $SCRIPT_ID [OPTIONS] [FOLDER_PATH]

Options:
  -y, --yes          Run non-interactively (skip confirmation prompts)
  -h, --help         Show this help message
  [FOLDER_PATH]      Target folder to initialize (default: current directory)

Examples:
  devcontainer-init                    # Initialize current directory (with prompt)
  devcontainer-init /path/to/repo      # Initialize specific folder (with prompt)
  devcontainer-init -y                 # Initialize current directory (no prompt)
  devcontainer-init -y /path/to/repo   # Initialize specific folder (no prompt)

Prerequisites:
  • Docker must be installed and running
  • Write permission to the target directory

Next Steps (after successful initialization):
  1. Run: devcontainer-pull
  2. Open the folder in VS Code
  3. Click 'Reopen in Container' when prompted
  4. Inside the container, run: dev-help

Metadata:
  ID:       $SCRIPT_ID
  Category: $SCRIPT_CATEGORY

EOF
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------
YES=0
while [ "${1:-}" != "" ] && [[ "${1:-}" == -* ]]; do
    case "$1" in
        -y|--yes)
            YES=1
            shift
            ;;
        -h|--help)
            help
            exit 0
            ;;
        *)
            log_error "ERR001: Unknown option: $1"
            exit 1
            ;;
    esac
done

# Capture whether a folder argument was provided
ARG_PROVIDED=0
if [ -n "${1:-}" ]; then
    ARG_PROVIDED=1
fi

TARGET_DIR="${1:-.}"

## Resolve and validate target directory

# Expand tilde (~) if present
case "$TARGET_DIR" in
    ~/*) TARGET_DIR="${HOME}${TARGET_DIR#~}" ;;
    ~) TARGET_DIR="$HOME" ;;
esac

# If TARGET_DIR is '.' and no explicit arg provided, use pwd
if [ "$ARG_PROVIDED" -eq 0 ] && [ "$TARGET_DIR" = "." ]; then
    TARGET_DIR="$(pwd)"
fi

# Canonicalize if exists
if [ -e "$TARGET_DIR" ]; then
    TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd || printf '%s' "$TARGET_DIR")"
fi

if [ "$ARG_PROVIDED" -eq 1 ]; then
    # Explicit path provided: must exist and be writable
    if [ ! -e "$TARGET_DIR" ]; then
        log_error "ERR002: Target path does not exist: $TARGET_DIR"
        exit 1
    fi
    if [ ! -d "$TARGET_DIR" ]; then
        log_error "ERR003: Target exists and is not a directory: $TARGET_DIR"
        exit 1
    fi
    if [ ! -w "$TARGET_DIR" ]; then
        log_error "ERR004: No write permission for target directory: $TARGET_DIR"
        exit 1
    fi
else
    # No path provided: explicitly confirm using current directory unless -y
    if [ "$YES" -eq 0 ]; then
        printf "[$(log_time)] INFO  Devcontainer toolbox will be initiated in the default folder: %s\nProceed? [y/n] " "$TARGET_DIR" >&2
        read -r reply || exit 1
        case "$reply" in
            y|Y) ;;
            n|N) log_info "Aborted by user."; exit 1 ;;
            *) log_error "ERR005: Please answer 'y' or 'n'. Aborted."; exit 1 ;;
        esac
    fi
    # Ensure writable
    if [ ! -w "$TARGET_DIR" ]; then
        log_error "ERR006: No write permission for current directory: $TARGET_DIR"
        exit 1
    fi
fi

log_info "Using target directory: $TARGET_DIR"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

check_docker_installed() {
    log_info "Verifying Docker is installed..."
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "ERR007: Docker is not installed"
        log_info "Install Docker Desktop or Rancher Desktop:"
        log_info "  • macOS: https://rancher.com/docs/rancher/v2.x/en/installation/requirements/"
        log_info "  • Linux: sudo apt-get install docker.io"
        return 1
    fi
    
    log_success "Docker is installed"
}

check_docker_running() {
    log_info "Verifying Docker daemon is running..."

    local docker_err
    if ! docker_err=$(docker ps 2>&1); then
        log_error "ERR008: Docker daemon is not running"
        log_error "ERR008: docker: $docker_err"
        log_info "Start Docker:"
        log_info "  • macOS: Open Rancher Desktop or Docker Desktop"
        log_info "  • Linux: sudo systemctl start docker"
        return 1
    fi
    
    log_success "Docker daemon is running"
}

backup_existing_devcontainer() {
    if [ -d "$TARGET_DIR/.devcontainer" ]; then
        log_info "Found existing .devcontainer/ directory."
        
        if [ -d "$TARGET_DIR/.devcontainer.backup" ]; then
            log_error "ERR009: Backup already exists at .devcontainer.backup/"
            log_info "Please resolve this manually:"
            log_info "  • Remove or rename .devcontainer.backup/ if no longer needed"
            log_info "  • Or remove .devcontainer/ before running this script again"
            exit 1
        fi
        
        log_info "Creating backup at .devcontainer.backup/..."
        local mv_err
        if ! mv_err=$(mv "$TARGET_DIR/.devcontainer" "$TARGET_DIR/.devcontainer.backup" 2>&1); then
            log_error "ERR010: Failed to back up .devcontainer/"
            log_error "ERR010: mv: $mv_err"
            exit 1
        fi
        if [ ! -d "$TARGET_DIR/.devcontainer.backup" ]; then
            log_error "ERR011: Backup directory not found after move"
            exit 1
        fi
        log_success "Backup created."
    fi
}

create_devcontainer_json() {
    log_info "Creating .devcontainer/devcontainer.json from repository..."
    mkdir -p "$TARGET_DIR/.devcontainer"
    if [ ! -d "$TARGET_DIR/.devcontainer" ]; then
        log_error "ERR012: Failed to create directory $TARGET_DIR/.devcontainer"
        exit 1
    fi

    local dl_err
    if command -v curl >/dev/null 2>&1; then
        if ! dl_err=$(curl -fsSL "$DEVCONTAINER_JSON_URL" -o "$TARGET_DIR/.devcontainer/devcontainer.json" 2>&1); then
            log_error "ERR013: Failed to download devcontainer.json from $DEVCONTAINER_JSON_URL"
            log_error "ERR013: curl: $dl_err"
            rm -f "$TARGET_DIR/.devcontainer/devcontainer.json"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! dl_err=$(wget -qO "$TARGET_DIR/.devcontainer/devcontainer.json" "$DEVCONTAINER_JSON_URL" 2>&1); then
            log_error "ERR014: Failed to download devcontainer.json from $DEVCONTAINER_JSON_URL"
            log_error "ERR014: wget: $dl_err"
            rm -f "$TARGET_DIR/.devcontainer/devcontainer.json"
            exit 1
        fi
    else
        log_error "ERR015: Neither 'curl' nor 'wget' is available to fetch devcontainer.json"
        exit 1
    fi

    if [ ! -f "$TARGET_DIR/.devcontainer/devcontainer.json" ]; then
        log_error "ERR016: Download completed but devcontainer.json not found"
        exit 1
    fi

    log_success "Created .devcontainer/devcontainer.json"
}

ensure_vscode_extensions_json() {
    local ext_file="$TARGET_DIR/.vscode/extensions.json"
    local ext_id="ms-vscode-remote.remote-containers"

    log_info "Ensuring .vscode/extensions.json recommends Dev Containers extension..."

    mkdir -p "$TARGET_DIR/.vscode"

    python3 -c "
import json, os, sys
path = sys.argv[1]
ext_id = sys.argv[2]
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
else:
    data = {}
recs = data.setdefault('recommendations', [])
if ext_id in recs:
    print('already_present')
else:
    recs.append(ext_id)
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
    print('added')
" "$ext_file" "$ext_id"

    local result=$?
    if [ $result -ne 0 ]; then
        log_warning "Could not update .vscode/extensions.json (python3 not available?)"
        return 0
    fi

    log_success "Created .vscode/extensions.json with Dev Containers extension recommendation"
}

print_next_steps() {
    log_success "devcontainer configuration created!"
    log_info "Next steps:"
    log_info "  1. Pull the Docker image: ./devcontainer-pull.sh"
    log_info "  2. Open this folder in VS Code"
    log_info "  3. When prompted, click 'Reopen in Container'"
    log_info "     (or run: Cmd/Ctrl+Shift+P > 'Dev Containers: Reopen in Container')"
    log_info "  4. Inside the container, run: dev-help"
    
    if [ -d "$TARGET_DIR/.devcontainer.backup" ]; then
        log_warning "Your previous .devcontainer/ was backed up to .devcontainer.backup/"
    fi
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    log_start
    
    # Step 1: Check Docker installed
    check_docker_installed || exit 1
    
    # Step 2: Check Docker running
    check_docker_running || exit 1
    
    # Step 3: Backup existing .devcontainer/
    backup_existing_devcontainer
    
    # Step 4: Create .devcontainer/devcontainer.json
    create_devcontainer_json

    # Step 5: Ensure .vscode/extensions.json recommends Dev Containers
    ensure_vscode_extensions_json

    # Step 6: Print next steps
    print_next_steps
}

main "$@"
