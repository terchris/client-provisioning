#!/bin/bash
# File: run-all-tests.sh
#
# Usage:
#   run-all-tests.sh [OPTIONS]
#   run-all-tests.sh [-h|--help]
#
# Purpose:
#   Master test runner for USB testing of Rancher Desktop scripts
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
SCRIPT_NAME="Rancher Desktop Test Runner"
SCRIPT_VER="0.2.0"
SCRIPT_DESCRIPTION="Master test runner for USB testing of Rancher Desktop scripts."
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
    log_warning "THIS WILL DESTROY ALL CONTAINER DATA ON THIS MAC"
    echo "================================================================"
    echo ""
    log_info "These tests will install, configure, and uninstall Rancher Desktop"
    log_info "multiple times. The following will be PERMANENTLY DELETED:"
    echo ""
    log_info "  - All Docker images, containers, and volumes"
    log_info "  - All Kubernetes resources (if k3s was enabled)"
    log_info "  - All Rancher Desktop configuration and preferences"
    echo ""
    log_info "Files on the host filesystem (outside containers) are NOT affected."
    echo ""
    log_info "The scripts require root access (sudo). You will be asked for"
    log_info "your password after confirming."
    echo ""
    # Read the version from the install script so we don't hardcode it here
    _rd_ver=$(grep '^RANCHER_VERSION=' "$(dirname "$0")/../rancher-desktop-install.sh" 2>/dev/null | head -1 | cut -d'"' -f2)
    _rd_ver="${_rd_ver:-unknown}"
    log_info "The tests download Rancher Desktop v${_rd_ver} (~300 MB) from GitHub"
    log_info "multiple times (install, uninstall, reinstall). Depending on your"
    log_info "internet speed, the full test session can take 30-60 minutes."
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
for _script in "${SCRIPT_DIR}"/rancher-desktop-*.sh; do
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

# Ask a specific yes/no verification question. y = pass, n = fail.
verify_ask() {
    local question="$1"
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: ${question}"
    echo "---------------------------------------------------------------"
    read -r -p "  (y/n): " answer
    case "$answer" in
        y|Y|yes) mark_pass ;;
        *) mark_fail ;;
    esac
}


#------------------------------------------------------------------------------
# PART 1: Clean machine
#------------------------------------------------------------------------------

echo "================================================================"
echo "  PART 1: Clean machine (Rancher Desktop NOT installed)"
echo "================================================================"
echo ""

# Check if Rancher Desktop is already installed and clean up if needed
if [ -d "/Applications/Rancher Desktop.app" ]; then
    log_info "Rancher Desktop is currently INSTALLED on this Mac."
    log_info "Part 1 requires a clean machine (not installed)."
    echo ""
    log_info "We need to uninstall it first. This will remove:"
    log_info "  - /Applications/Rancher Desktop.app"
    log_info "  - All deployment profiles"
    log_info "  - All user data and preferences"
    log_info "  - All Docker images, containers, and volumes"
    echo ""
    read -r -p "Type 'yes' to uninstall now (anything else will abort): " uninstall_confirm
    if [ "$uninstall_confirm" != "yes" ]; then
        echo ""
        log_info "Aborted. Rancher Desktop was NOT uninstalled."
        exit 0
    fi
    echo ""
    log_info "Uninstalling Rancher Desktop..."
    bash "${SCRIPT_DIR}/rancher-desktop-uninstall.sh" --confirm
    echo ""
    log_success "Rancher Desktop uninstalled. Continuing with Part 1."
else
    log_info "Rancher Desktop is NOT installed. Good — starting from clean state."
fi
echo ""

# Detect this Mac's hardware so we can tell the tester what to expect
TOTAL_RAM_GB=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%d", $1/1024/1024/1024}')
TOTAL_CPUS=$(sysctl -n hw.ncpu 2>/dev/null)
EXPECTED_RAM=$((TOTAL_RAM_GB / 4))
EXPECTED_CPUS=$((TOTAL_CPUS / 2))
[ "$EXPECTED_RAM" -lt 2 ] && EXPECTED_RAM=2
[ "$EXPECTED_CPUS" -lt 1 ] && EXPECTED_CPUS=1
log_info "This Mac: ${TOTAL_RAM_GB} GB RAM, ${TOTAL_CPUS} CPUs"
log_info "Expected defaults: memoryInGB = ${EXPECTED_RAM} (25% of ${TOTAL_RAM_GB}), numberCPUs = ${EXPECTED_CPUS} (50% of ${TOTAL_CPUS})"
echo ""

# --- Test 1: Fresh install ---
header "1" "Fresh install (default settings)"

log_info "Installing Rancher Desktop with default settings..."
bash "${SCRIPT_DIR}/rancher-desktop-install.sh"
echo ""
verify_app
echo ""
show_defaults

echo ""
log_info "Auto-verifying profile values..."
test1_ok=true
verify_plist_value "$PROFILE_DEFAULTS" "name" "moby" || test1_ok=false
verify_plist_value "$PROFILE_DEFAULTS" "enabled" "0" || test1_ok=false
verify_plist_value "$PROFILE_DEFAULTS" "memoryInGB" "${EXPECTED_RAM}" || test1_ok=false
verify_plist_value "$PROFILE_DEFAULTS" "numberCPUs" "${EXPECTED_CPUS}" || test1_ok=false

if [ "$test1_ok" = true ]; then
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Profile values correct (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_pass
else
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Profile values incorrect (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_fail
fi

if ! prompt_continue; then mark_skip; fi

# --- Test 2: First launch + Docker ---
header "2" "First launch + Docker"

launch_rancher_desktop true

echo ""
log_info "Now check Rancher Desktop Preferences:"
log_info "  1. Click on the Preferences button"
log_info "  2. Container Engine tab  -> should say 'dockerd (moby)'"
log_info "  3. Kubernetes tab        -> should be UNCHECKED"
log_info "  4. Virtual Machine tab   -> should show ${EXPECTED_RAM} GB memory and ${EXPECTED_CPUS} CPUs"

verify_ask "Do the Preferences match the values above?"

echo ""
log_info "Now testing Docker commands..."
echo ""

docker_ok=true

log_info "Running: docker version"
echo ""
if docker version; then
    echo ""
    log_success "docker version succeeded"
else
    echo ""
    log_error "docker version failed"
    docker_ok=false
fi

echo ""
log_info "Running: docker pull hello-world"
log_info "(downloading the image, this may take a moment)"
echo ""
docker pull hello-world
echo ""
log_info "Running: docker run --rm hello-world"
echo ""
hello_output=$(docker run --rm hello-world 2>&1)
hello_exit=$?
echo "$hello_output"
if [ $hello_exit -eq 0 ] && echo "$hello_output" | grep -q "Hello from Docker!"; then
    echo ""
    log_success "hello-world printed 'Hello from Docker!'"
else
    echo ""
    log_error "hello-world did not print 'Hello from Docker!'"
    docker_ok=false
fi

if [ "$docker_ok" = true ]; then
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Docker is working (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_pass
else
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Docker FAILED (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_fail
fi

quit_rancher_desktop

if ! prompt_continue; then mark_skip; fi

# --- Test 3: K8s plist merge ---
header "3" "K8s script — plist merge"

log_info "This test enables Kubernetes and checks that other profile keys survive."
echo ""
log_info "NOTE: We are only verifying the profile FILE was written correctly."
log_info "We do NOT launch Rancher Desktop here because this is a 'defaults' profile"
log_info "and Rancher Desktop was already launched in test 2. The defaults profile is"
log_info "only used on first launch — so Rancher Desktop would ignore this change."
log_info "Locked profiles (which DO override existing settings) are tested in Part 2."
echo ""
log_info "--- Profile BEFORE (should have containerEngine + virtualMachine) ---"
show_defaults

echo ""
log_info "Running: rancher-desktop-k8s.sh --enable"
bash "${SCRIPT_DIR}/rancher-desktop-k8s.sh" --enable

echo ""
log_info "--- Profile AFTER ---"
show_defaults

echo ""
log_info "Auto-verifying profile values..."
test3_ok=true
verify_plist_value "$PROFILE_DEFAULTS" "enabled" "1" || test3_ok=false
verify_plist_key_exists "$PROFILE_DEFAULTS" "name" || test3_ok=false
verify_plist_key_exists "$PROFILE_DEFAULTS" "memoryInGB" || test3_ok=false
verify_plist_key_exists "$PROFILE_DEFAULTS" "numberCPUs" || test3_ok=false

if [ "$test3_ok" = true ]; then
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: K8s enabled, all keys preserved (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_pass
else
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: K8s merge FAILED (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_fail
fi

if ! prompt_continue; then mark_skip; fi

# --- Test 4: Config partial update ---
header "4" "Config script — partial update (--memory 6)"

log_info "This test changes only memory. CPU and other keys should not change."
echo ""
log_info "NOTE: Same as test 3 — we only verify the profile file, not the app."
log_info "This is a 'defaults' profile so Rancher Desktop would ignore it on"
log_info "an existing install. Locked profiles are tested in Part 2."
echo ""
log_info "--- Profile BEFORE ---"
show_defaults

echo ""
log_info "Running: rancher-desktop-config.sh --memory 6"
bash "${SCRIPT_DIR}/rancher-desktop-config.sh" --memory 6

echo ""
log_info "--- Profile AFTER ---"
show_defaults

echo ""
log_info "Auto-verifying profile values..."
test4_ok=true
verify_plist_value "$PROFILE_DEFAULTS" "memoryInGB" "6" || test4_ok=false
verify_plist_key_exists "$PROFILE_DEFAULTS" "numberCPUs" || test4_ok=false
verify_plist_key_exists "$PROFILE_DEFAULTS" "enabled" || test4_ok=false
verify_plist_key_exists "$PROFILE_DEFAULTS" "name" || test4_ok=false

if [ "$test4_ok" = true ]; then
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Memory updated, all keys preserved (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_pass
else
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Config update FAILED (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_fail
fi

if ! prompt_continue; then mark_skip; fi

# --- Test 5: Uninstall safety check ---
header "5" "Uninstall safety check (no --confirm)"

log_info "Running uninstall WITHOUT --confirm. It should refuse and exit with an error."
echo ""
bash "${SCRIPT_DIR}/rancher-desktop-uninstall.sh"
test5_exit=$?

echo ""
test5_ok=true

if [ $test5_exit -eq 0 ]; then
    log_error "Script exited with code 0 (should have failed)"
    test5_ok=false
else
    log_success "Script exited with error code ${test5_exit}"
fi

if [ -d "/Applications/Rancher Desktop.app" ]; then
    log_success "App still installed (nothing was deleted)"
else
    log_error "App was deleted even without --confirm"
    test5_ok=false
fi

if [ "$test5_ok" = true ]; then
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Safety check worked — refused without --confirm (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_pass
else
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Safety check FAILED (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_fail
fi

if ! prompt_continue; then mark_skip; fi

# --- Test 6: Full uninstall ---
header "6" "Full uninstall"

log_info "Running full uninstall. Everything should be removed."
echo ""
bash "${SCRIPT_DIR}/rancher-desktop-uninstall.sh" --confirm

echo ""
log_info "--- Checking what was removed ---"
test6_ok=true

if [ -d "/Applications/Rancher Desktop.app" ]; then
    log_error "App still exists"
    test6_ok=false
else
    log_success "App removed"
fi

if ls /Library/Managed\ Preferences/io.rancherdesktop.* >/dev/null 2>&1; then
    log_error "Profiles still exist"
    test6_ok=false
else
    log_success "Profiles removed"
fi

if [ -d ~/Library/Application\ Support/rancher-desktop ]; then
    log_error "User data still exists"
    test6_ok=false
else
    log_success "User data removed"
fi

if [ "$test6_ok" = true ]; then
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Everything removed (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_pass
else
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Uninstall FAILED — some items remain (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_fail
fi

if ! prompt_continue; then mark_skip; fi

# --- Test 7: Reinstall with custom params ---
header "7" "Reinstall with custom params (--memory 8 --cpus 4 --kubernetes)"

log_info "Installing with custom settings after full uninstall..."
echo ""
bash "${SCRIPT_DIR}/rancher-desktop-install.sh" --memory 8 --cpus 4 --kubernetes

echo ""
verify_app
echo ""
show_defaults

echo ""
log_info "Auto-verifying profile values..."
test7_ok=true
verify_plist_value "$PROFILE_DEFAULTS" "enabled" "1" || test7_ok=false
verify_plist_value "$PROFILE_DEFAULTS" "memoryInGB" "8" || test7_ok=false
verify_plist_value "$PROFILE_DEFAULTS" "numberCPUs" "4" || test7_ok=false

if [ "$test7_ok" = true ]; then
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Profile values correct (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_pass
else
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Profile values incorrect (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_fail
fi

echo ""
log_info "Now launching Rancher Desktop to confirm Preferences match the profile."
launch_rancher_desktop

echo ""
log_info "Check the Preferences:"
log_info "  1. Click on the Preferences button"
log_info "  2. Container Engine tab  -> should say 'dockerd (moby)'"
log_info "  3. Kubernetes tab        -> should be CHECKED (enabled)"
log_info "  4. Virtual Machine tab   -> should show 8 GB memory and 4 CPUs"

verify_ask "Do the Preferences show moby, Kubernetes enabled, 8 GB memory, 4 CPUs?"
quit_rancher_desktop

if ! prompt_continue; then mark_skip; fi

# --- Test 8: Uninstall --keep-profile ---
header "8" "Uninstall with --keep-profile"

log_info "Uninstalling but keeping deployment profiles..."
echo ""
bash "${SCRIPT_DIR}/rancher-desktop-uninstall.sh" --confirm --keep-profile

echo ""
test8_ok=true

log_info "--- App should be removed ---"
if [ -d "/Applications/Rancher Desktop.app" ]; then
    log_error "App still exists"
    test8_ok=false
else
    log_success "App removed"
fi

echo ""
log_info "--- Profiles should STILL exist ---"
if ls /Library/Managed\ Preferences/io.rancherdesktop.* >/dev/null 2>&1; then
    log_success "Profiles kept"
else
    log_error "Profiles were removed (they should have been kept)"
    test8_ok=false
fi

if [ "$test8_ok" = true ]; then
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: App removed, profiles kept (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_pass
else
    echo ""
    echo "---------------------------------------------------------------"
    echo "  VERIFY: Test 8 FAILED (auto-verified)"
    echo "---------------------------------------------------------------"
    mark_fail
fi

echo ""
log_info "--- Cleaning up profiles for Part 2 ---"
rm -f /Library/Managed\ Preferences/io.rancherdesktop.*

#------------------------------------------------------------------------------
# PART 2: Locked profiles
#------------------------------------------------------------------------------

echo ""
echo "================================================================"
echo "  PART 2: Locked profiles"
echo "  (needs Rancher Desktop installed and launched at least once)"
echo "================================================================"
echo ""

if ! prompt_continue; then
    mark_skip; mark_skip
    print_summary
    exit 0
fi

log_info "Reinstalling Rancher Desktop for Part 2..."
bash "${SCRIPT_DIR}/rancher-desktop-install.sh"

echo ""
log_info "Launching Rancher Desktop for initial setup (creates user preferences)..."
log_info "This is needed because locked profiles only matter when user preferences exist."
launch_rancher_desktop true

echo ""
log_info "Initial setup complete. Quitting Rancher Desktop..."
quit_rancher_desktop

# --- Test 9: Locked k8s profile ---
header "9" "Locked k8s profile (--disable --lock)"

log_info "Writing a LOCKED profile that disables Kubernetes..."
echo ""
bash "${SCRIPT_DIR}/rancher-desktop-k8s.sh" --disable --lock

echo ""
show_locked

echo ""
log_info "Auto-verifying locked profile values..."
test9_ok=true
verify_plist_value "$PROFILE_LOCKED" "enabled" "0" || test9_ok=false

if [ "$test9_ok" = true ]; then
    log_success "Locked profile values correct (auto-verified)"
else
    log_error "Locked profile values incorrect (auto-verified)"
fi

echo ""
log_info "Launching Rancher Desktop to verify locked UI..."
launch_rancher_desktop
echo ""
log_info "Check the Preferences:"
log_info "  1. Click on the Preferences button"
log_info "  2. Go to the Kubernetes tab"
log_info "  3. Kubernetes should show DISABLED"
log_info "  4. The checkbox should be GREYED OUT (you cannot click it)"
verify_ask "Is Kubernetes disabled AND the checkbox greyed out?"
quit_rancher_desktop

cleanup_locked

if ! prompt_continue; then mark_skip; fi

# --- Test 10: Locked config profile ---
header "10" "Locked config profile (--memory 4 --cpus 2 --lock)"

log_info "Writing a LOCKED profile with memory=4GB and cpus=2..."
echo ""
bash "${SCRIPT_DIR}/rancher-desktop-config.sh" --memory 4 --cpus 2 --lock

echo ""
show_locked

echo ""
log_info "Auto-verifying locked profile values..."
test10_ok=true
verify_plist_value "$PROFILE_LOCKED" "memoryInGB" "4" || test10_ok=false
verify_plist_value "$PROFILE_LOCKED" "numberCPUs" "2" || test10_ok=false

if [ "$test10_ok" = true ]; then
    log_success "Locked profile values correct (auto-verified)"
else
    log_error "Locked profile values incorrect (auto-verified)"
fi

echo ""
log_info "Launching Rancher Desktop to verify locked UI..."
launch_rancher_desktop
echo ""
log_info "Check the Preferences:"
log_info "  1. Click on the Preferences button"
log_info "  2. Go to the Virtual Machine tab"
log_info "  3. Memory should show 4 GB"
log_info "  4. CPUs should show 2"
log_info "  5. The sliders should be GREYED OUT (you cannot drag them)"
verify_ask "Does it show 4 GB / 2 CPUs AND are the sliders greyed out?"
quit_rancher_desktop

cleanup_locked

#------------------------------------------------------------------------------
# SUMMARY
#------------------------------------------------------------------------------

print_summary
