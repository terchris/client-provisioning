#!/bin/bash
# File: run-all-tests.sh
#
# Usage:
#   run-all-tests.sh [OPTIONS]
#   run-all-tests.sh [-h|--help]
#
# Purpose:
#   Master test runner for USB testing of devcontainer-toolbox scripts
#
# Author: Ops Team
# Created: February 2026
#
# Do NOT use sudo — the script shows a warning first, then elevates itself.
# Do not change the help() structure — the test runner validates it.

set -uo pipefail

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

SCRIPT_ID="run-all-tests"
SCRIPT_NAME="Devcontainer Toolbox Test Runner"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Master test runner for USB testing of devcontainer-toolbox scripts."
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
  $SCRIPT_ID [options]

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
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

cd "$SCRIPT_DIR" || { log_error "Failed to cd to $SCRIPT_DIR"; exit 1; }

#------------------------------------------------------------------------------
# WARNING + SUDO ELEVATION
#------------------------------------------------------------------------------
# Show the warning BEFORE the sudo password prompt.
# If already running as root (re-exec or user ran with sudo), skip this.

if [ "$(id -u)" -ne 0 ]; then
    echo ""
    echo "================================================================"
    echo "  Devcontainer Toolbox Test Suite"
    echo "================================================================"
    echo ""
    log_info "These tests will:"
    log_info "  - Pull a Docker image (~1-2 GB download)"
    log_info "  - Install devcontainer-init to /usr/local/bin"
    log_info "  - Create and remove temp folders in /tmp"
    log_info "  - Clean up everything at the end"
    echo ""
    log_info "Prerequisites:"
    log_info "  - Rancher Desktop must be installed and running"
    echo ""
    log_info "The install test requires root access (sudo). You will be asked"
    log_info "for your password after confirming."
    echo ""
    read -r -p "  Type 'yes' to continue (anything else will abort): " confirm
    if [ "$confirm" != "yes" ]; then
        echo ""
        log_info "Aborted. Nothing was changed."
        exit 0
    fi
    echo ""
    log_info "Elevating to root (sudo)..."
    exec sudo bash "$0" "$@"
fi

#------------------------------------------------------------------------------
# SETUP (running as root from here)
#------------------------------------------------------------------------------

mkdir -p logs
if [ ! -d logs ]; then
    log_error "Failed to create logs directory"
    exit 1
fi

rm -f logs/*.log
exec > >(tee logs/test.log) 2>&1

log_info "=== Test session started: $(date) ==="
log_info "=== Mac: $(hostname), macOS $(sw_vers -productVersion), $(uname -m) ==="
log_info "=== Test runner: ${SCRIPT_ID} v${SCRIPT_VER} ==="

# Read script IDs and versions so the log shows exactly what code was tested
_id()  { grep "^SCRIPT_ID="  "$1" 2>/dev/null | head -1 | cut -d'"' -f2; }
_ver() { grep "^SCRIPT_VER=" "$1" 2>/dev/null | head -1 | cut -d'"' -f2; }
for _script in "${SCRIPT_DIR}"/devcontainer-*.sh; do
    log_info "=== Script: $(_id "$_script") v$(_ver "$_script") ==="
done
echo ""

#------------------------------------------------------------------------------
# HELPERS
#------------------------------------------------------------------------------

source "${TESTS_DIR}/test-helpers.sh"

pass_count=0
fail_count=0
skip_count=0

prompt_continue() {
    echo ""
    read -r -p "Press Enter to continue to the next test (or type 'skip' / 'quit'): " answer
    case "$answer" in
        skip) return 1 ;;
        quit|q|exit)
            echo ""
            log_info "=== Tester chose to stop ==="
            print_summary
            exit 0
            ;;
    esac
    return 0
}

mark_pass() {
    pass_count=$((pass_count + 1))
    log_success "RESULT: PASS"
}

mark_fail() {
    fail_count=$((fail_count + 1))
    log_error "RESULT: FAIL"
}

mark_skip() {
    skip_count=$((skip_count + 1))
}

print_summary() {
    echo ""
    echo "================================================================"
    echo "  TEST SESSION SUMMARY"
    echo "================================================================"
    log_info "  Passed:  ${pass_count}"
    log_info "  Failed:  ${fail_count}"
    log_info "  Skipped: ${skip_count}"
    log_info "  Total:   $((pass_count + fail_count + skip_count))"
    echo ""
    log_info "  Log file: logs/test.log"
    log_info "  Bring the USB back so Claude Code can read the log."
    echo ""
    log_info "=== Test session ended: $(date) ==="
}

run_test() {
    local test_script="$1"
    if bash "${TESTS_DIR}/${test_script}"; then
        mark_pass
    else
        mark_fail
    fi
}

#------------------------------------------------------------------------------
# TEST 0: Prerequisites
#------------------------------------------------------------------------------

run_test "test-0-prerequisites.sh"
if [ "$fail_count" -gt 0 ]; then
    log_error "Prerequisites failed — cannot continue"
    print_summary
    exit 1
fi
if ! prompt_continue; then mark_skip; fi

#------------------------------------------------------------------------------
# TEST 1: Pull image
#------------------------------------------------------------------------------

run_test "test-1-pull.sh"
if ! prompt_continue; then mark_skip; fi

#------------------------------------------------------------------------------
# TEST 2: Install command
#------------------------------------------------------------------------------

run_test "test-2-install.sh"
if ! prompt_continue; then mark_skip; fi

#------------------------------------------------------------------------------
# TEST 3: Fresh init
#------------------------------------------------------------------------------

run_test "test-3-init-fresh.sh"
if ! prompt_continue; then mark_skip; fi

#------------------------------------------------------------------------------
# TEST 4: Init with backup
#------------------------------------------------------------------------------

run_test "test-4-init-backup.sh"
if ! prompt_continue; then mark_skip; fi

#------------------------------------------------------------------------------
# TEST 5: Init error paths
#------------------------------------------------------------------------------

run_test "test-5-init-errors.sh"
if ! prompt_continue; then mark_skip; fi

#------------------------------------------------------------------------------
# TEST 6: Cleanup
#------------------------------------------------------------------------------

run_test "test-6-cleanup.sh"

#------------------------------------------------------------------------------
# SUMMARY
#------------------------------------------------------------------------------

print_summary
