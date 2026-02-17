#!/bin/bash
# File: test-teardown.sh
#
# Usage:
#   source tests/test-teardown.sh
#
# Purpose:
#   End the test session: print summary and remind tester to bring the USB back
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

SCRIPT_ID="test-teardown"
SCRIPT_NAME="Test Teardown"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="End the test session: print summary and remind tester to bring the USB back."
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
# TEARDOWN
#------------------------------------------------------------------------------

echo ""
echo "=== Test session ended: $(date) ==="
echo ""
log_info "Log file: logs/test.log"
log_info "Bring the USB back so Claude Code can read the log."
