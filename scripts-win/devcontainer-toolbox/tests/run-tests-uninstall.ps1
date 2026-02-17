#!/usr/bin/env pwsh
# File: run-tests-uninstall.ps1
#
# Usage:
#   run-tests-uninstall.ps1 [-Help]
#
# Purpose:
#   Runs uninstall tests: uninstall, verify files removed, verify PATH cleaned up.
#
# Author: Ops Team
# Created: February 2026
#
# Run from USB: powershell -ExecutionPolicy Bypass -File "D:\devcontainer-toolbox\tests\run-tests-uninstall.ps1"
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

$SCRIPT_ID          = "run-tests-uninstall"
$SCRIPT_NAME        = "Devcontainer Toolbox Uninstall Tests"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Runs uninstall tests: uninstall, verify files removed, verify PATH cleaned up."
$SCRIPT_CATEGORY    = "TEST"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$INSTALL_DIR       = "C:\Program Files\devcontainer-toolbox"
$INIT_SCRIPT_NAME  = "devcontainer-init.ps1"

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
    Write-Host "  1. Uninstall (runs uninstall.ps1: remove files, remove PATH entry)"
    Write-Host "  2. Verify devcontainer-init.ps1 no longer exists"
    Write-Host "  3. Verify install directory removed from system PATH"
    Write-Host ""
    Write-Host "Run install tests first: run-tests-install.ps1"
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
$logFile = Join-Path $logsDir "test-results-uninstall.log"
Start-Transcript -Path $logFile -Append

log_start
log_info "Log file: $logFile"

$overallPass = $true
$parentDir = Split-Path $PSScriptRoot

# ================================================================
# Test 1: Uninstall (runs uninstall.ps1)
# ================================================================
Write-Host ""
Write-Host "================================================================"
log_info "Test 1: Uninstall (runs uninstall.ps1)"
Write-Host "================================================================"
Write-Host ""

$uninstallScript = Join-Path $parentDir "uninstall.ps1"
if (-not (Test-Path $uninstallScript)) {
    Test-Fail "Find uninstall.ps1" "Not found at $uninstallScript"
    $overallPass = $false
    log_error "Uninstall script not found -- stopping tests"
    Stop-Transcript
    exit 1
}

log_info "Running uninstall.ps1 (removes files, cleans PATH)..."
Write-Host ""

powershell.exe -ExecutionPolicy Bypass -File $uninstallScript 2>&1 | ForEach-Object { Write-Host $_ }
$uninstallExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }

Write-Host ""
if ($uninstallExit -eq 0) {
    Test-Pass "uninstall.ps1 (exit code 0)"
} else {
    Test-Fail "uninstall.ps1" "Exit code: $uninstallExit"
    $overallPass = $false
}

# ================================================================
# Test 2: Verify devcontainer-init.ps1 no longer exists
# ================================================================
Write-Host ""
Write-Host "================================================================"
log_info "Test 2: Verify devcontainer-init.ps1 no longer exists"
Write-Host "================================================================"
Write-Host ""

$initPath = Join-Path $INSTALL_DIR $INIT_SCRIPT_NAME
if (Test-Path $initPath) {
    Test-Fail "devcontainer-init.ps1 removed" "Still exists at $initPath"
    $overallPass = $false
} else {
    Test-Pass "devcontainer-init.ps1 no longer exists at $INSTALL_DIR"
}

# ================================================================
# Test 3: Verify install directory removed from system PATH
# ================================================================
Write-Host ""
Write-Host "================================================================"
log_info "Test 3: Verify install directory removed from system PATH"
Write-Host "================================================================"
Write-Host ""

$systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
if ($systemPath -like "*$INSTALL_DIR*") {
    Test-Fail "PATH cleaned up" "$INSTALL_DIR still in system PATH"
    $overallPass = $false
} else {
    Test-Pass "$INSTALL_DIR removed from system PATH"
}

# ================================================================
# Summary
# ================================================================
$allPassed = Test-Summary

Write-Host ""
Write-Host "================================================================"
if ($overallPass -and $allPassed) {
    log_success "ALL UNINSTALL TESTS PASSED"
    Write-Host ""
    log_info "devcontainer-toolbox has been removed."
    log_info "To reinstall: run-tests-install.ps1"
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
