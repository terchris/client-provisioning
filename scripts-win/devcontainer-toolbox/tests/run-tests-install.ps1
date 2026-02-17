#!/usr/bin/env pwsh
# File: run-tests-install.ps1
#
# Usage:
#   run-tests-install.ps1 [-Help]
#
# Purpose:
#   Runs install tests: admin check, Rancher Desktop check, install, file check, PATH check, detect.
#
# Author: Ops Team
# Created: February 2026
#
# Run from USB: powershell -ExecutionPolicy Bypass -File "D:\devcontainer-toolbox\tests\run-tests-install.ps1"
# Do not use em dashes or non-ASCII characters (Windows PowerShell 5.1 compatibility).

[CmdletBinding()]
param(
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

$SCRIPT_ID          = "run-tests-install"
$SCRIPT_NAME        = "Devcontainer Toolbox Install Tests"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Runs install tests: admin check, Rancher Desktop check, install, file check, PATH check, detect."
$SCRIPT_CATEGORY    = "TEST"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$INSTALL_DIR       = "C:\Program Files\devcontainer-toolbox"
$INIT_SCRIPT_NAME  = "devcontainer-init.ps1"

$RANCHER_EXE       = "Rancher Desktop.exe"
$RANCHER_INSTALL_PATHS = @(
    "$env:LOCALAPPDATA\Programs\Rancher Desktop",
    "$env:ProgramFiles\Rancher Desktop"
)

#------------------------------------------------------------------------------
# LOGGING
#------------------------------------------------------------------------------

function log_time    { Get-Date -Format 'HH:mm:ss' }
function log_info    { param([string]$msg) Write-Host "[$( log_time )] INFO  $msg" }
function log_success { param([string]$msg) Write-Host "[$( log_time )] OK    $msg" }
function log_error   { param([string]$msg) Write-Host "[$( log_time )] ERROR $msg" }
function log_warning { param([string]$msg) Write-Host "[$( log_time )] WARN  $msg" }

#------------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------------

function Show-Help {
    Write-Host "$SCRIPT_NAME (v$SCRIPT_VER)"
    Write-Host "$SCRIPT_DESCRIPTION"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  $SCRIPT_ID [-Help]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help     Show this help message"
    Write-Host ""
    Write-Host "Tests:"
    Write-Host "  1. Administrator check"
    Write-Host "  2. Rancher Desktop installed"
    Write-Host "  3. Install (runs install.ps1: pull image, install init tool, add to PATH)"
    Write-Host "  4. Verify devcontainer-init.ps1 exists at install location"
    Write-Host "  5. Verify install directory is in system PATH"
    Write-Host "  6. Detect (runs detect.ps1: verifies Intune detection reports installed)"
    Write-Host ""
    Write-Host "After these pass, use run-tests-init.ps1 to test devcontainer-init."
    Write-Host ""
    Write-Host "Metadata:"
    Write-Host "  ID:       $SCRIPT_ID"
    Write-Host "  Category: $SCRIPT_CATEGORY"
}

if ($Help) {
    Show-Help
    exit 0
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

# Dot-source test helpers
. "$PSScriptRoot\test-helpers.ps1"

# --- Start logging to file ---
$logsDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}
$logFile = Join-Path $logsDir "test-results-install.log"
Start-Transcript -Path $logFile -Append

log_start
log_info "Log file: $logFile"

$overallPass = $true
$parentDir = Split-Path $PSScriptRoot

# ================================================================
# Test 1: Administrator check
# ================================================================
Write-Host ""
Write-Host "================================================================"
log_info "Test 1: Administrator check"
Write-Host "================================================================"
Write-Host ""

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Test-Pass "Running as Administrator"
} else {
    Test-Fail "Running as Administrator" "Right-click PowerShell > 'Run as administrator'"
    $overallPass = $false
    log_error "Administrator required -- stopping tests"
    Stop-Transcript
    exit 1
}

# ================================================================
# Test 2: Rancher Desktop installed
# ================================================================
Write-Host ""
Write-Host "================================================================"
log_info "Test 2: Rancher Desktop installed"
Write-Host "================================================================"
Write-Host ""

$rancherFound = $false
foreach ($dir in $RANCHER_INSTALL_PATHS) {
    $exePath = Join-Path $dir $RANCHER_EXE
    if (Test-Path $exePath) {
        $rancherFound = $true
        Test-Pass "Rancher Desktop found at $dir"
        break
    }
}

if (-not $rancherFound) {
    Test-Fail "Rancher Desktop installed" "Not found at any known location"
    $overallPass = $false
    log_error "Rancher Desktop required -- stopping tests"
    Stop-Transcript
    exit 1
}

# ================================================================
# Test 3: Install (runs install.ps1)
# ================================================================
Write-Host ""
Write-Host "================================================================"
log_info "Test 3: Install (runs install.ps1)"
Write-Host "================================================================"
Write-Host ""

$installScript = Join-Path $parentDir "install.ps1"
if (-not (Test-Path $installScript)) {
    Test-Fail "Find install.ps1" "Not found at $installScript"
    $overallPass = $false
    log_error "Install script not found -- stopping tests"
    Stop-Transcript
    exit 1
}

log_info "Running install.ps1 (pulls image, installs init tool, adds to PATH)..."
Write-Host ""

powershell.exe -ExecutionPolicy Bypass -File $installScript 2>&1 | ForEach-Object { Write-Host $_ }
$installExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }

Write-Host ""
if ($installExit -eq 0) {
    Test-Pass "install.ps1 (exit code 0)"
} else {
    Test-Fail "install.ps1" "Exit code: $installExit"
    $overallPass = $false
    log_error "Install failed -- stopping tests"
    Stop-Transcript
    exit 1
}

# ================================================================
# Test 4: Verify devcontainer-init.ps1 exists
# ================================================================
Write-Host ""
Write-Host "================================================================"
log_info "Test 4: Verify devcontainer-init.ps1 at install location"
Write-Host "================================================================"
Write-Host ""

$initPath = Join-Path $INSTALL_DIR $INIT_SCRIPT_NAME
if (Test-Path $initPath) {
    Test-Pass "devcontainer-init.ps1 exists at $INSTALL_DIR"
} else {
    Test-Fail "devcontainer-init.ps1 exists" "Not found at $initPath"
    $overallPass = $false
}

# ================================================================
# Test 5: Verify install directory is in system PATH
# ================================================================
Write-Host ""
Write-Host "================================================================"
log_info "Test 5: Verify install directory is in system PATH"
Write-Host "================================================================"
Write-Host ""

$systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
if ($systemPath -like "*$INSTALL_DIR*") {
    Test-Pass "$INSTALL_DIR is in system PATH"
} else {
    Test-Fail "$INSTALL_DIR in system PATH" "Not found in system PATH"
    $overallPass = $false
}

# ================================================================
# Test 6: Detect (runs detect.ps1)
# ================================================================
Write-Host ""
Write-Host "================================================================"
log_info "Test 6: Detect (runs detect.ps1)"
Write-Host "================================================================"
Write-Host ""

$detectScript = Join-Path $parentDir "detect.ps1"
if (-not (Test-Path $detectScript)) {
    Test-Fail "Find detect.ps1" "Not found at $detectScript"
    $overallPass = $false
    log_error "Detect script not found -- stopping tests"
    Stop-Transcript
    exit 1
}

$output = & $detectScript
$detectExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }

if ($detectExit -ne 0) {
    Test-Fail "detect.ps1 exit code" "Expected 0, got $detectExit"
    $overallPass = $false
} else {
    Test-Pass "detect.ps1 exit code 0"
}

if ($output) {
    Test-Pass "detect.ps1 produced output: $output"
} else {
    Test-Fail "detect.ps1 produced output" "No output (means not detected)"
    $overallPass = $false
}

# ================================================================
# Summary
# ================================================================
$allPassed = Test-Summary

Write-Host ""
Write-Host "================================================================"
if ($overallPass -and $allPassed) {
    log_success "ALL INSTALL TESTS PASSED"
    Write-Host ""
    log_info "devcontainer-toolbox is installed."
    log_info "Next: run-tests-init.ps1 to test devcontainer-init"
    log_info "Then: run-tests-uninstall.ps1 to test removal"
} else {
    log_error "SOME TESTS FAILED"
    $overallPass = $false
}
Write-Host "================================================================"

Stop-Transcript

if (-not $overallPass) {
    exit 1
}
exit 0
