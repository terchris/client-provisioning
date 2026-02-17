#!/bin/bash
# File: test-setup.sh
#
# Usage:
#   source tests/test-setup.sh
#
# Purpose:
#   Set up the test session: create logs dir, start logging, print machine info
#
# Author: Ops Team
# Created: February 2026
#
# This file is sourced by the test runner — not run directly.
# Argument parsing only handles -h when run directly (for test runner validation).
# Do not change the help() structure — the test runner validates it.

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="test-setup"
SCRIPT_NAME="Test Setup"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Set up the test session: create logs dir, start logging, print machine info."
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
# SETUP
#------------------------------------------------------------------------------

mkdir -p logs
if [ ! -d logs ]; then
    log_error "Failed to create logs directory"
    return 1 2>/dev/null || exit 1
fi

# Clear previous logs so this session starts clean
rm -f logs/*.log

exec > >(tee logs/test.log) 2>&1

echo "=== Test session started: $(date) ==="
echo "=== Mac: $(hostname), macOS $(sw_vers -productVersion), $(uname -m) ==="
echo "=== Directory: $(pwd) ==="
echo ""
log_info "Ready. Run tests one at a time, in order:"
log_info "  sudo bash tests/test-1-install.sh"
log_info "  sudo bash tests/test-2-first-launch.sh"
log_info "  ..."
echo ""
