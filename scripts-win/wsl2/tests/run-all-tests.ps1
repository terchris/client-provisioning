#!/usr/bin/env pwsh
# File: run-all-tests.ps1
#
# Usage:
#   run-all-tests.ps1 [-Help]
#
# Purpose:
#   Runs all WSL2 USB tests in order with pass/fail summary.
#
# Author: Ops Team
# Created: February 2026
#
# Run from USB: powershell -ExecutionPolicy Bypass -File "D:\wsl2\tests\run-all-tests.ps1"
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

$SCRIPT_ID          = "run-all-tests"
$SCRIPT_NAME        = "WSL2 Test Runner"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Runs all WSL2 USB tests in order with pass/fail summary."
$SCRIPT_CATEGORY    = "TEST"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$WSL_FEATURE        = "Microsoft-Windows-Subsystem-Linux"
$VM_FEATURE         = "VirtualMachinePlatform"

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
    Write-Host "Test order:"
    Write-Host "  test-0  Prerequisites (admin, Windows version, virtualization)"
    Write-Host "  test-1  Install (run install.ps1, verify features)"
    Write-Host "  test-2  Detect (run detect.ps1, verify output)"
    Write-Host "  test-3  Post-reboot (verify features are Enabled, wsl info)"
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
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

function Run-TestScript {
    param([string]$Name, [string]$FileName)

    Write-Host ""
    Write-Host "================================================================"
    log_info "Running: $Name"
    Write-Host "================================================================"
    Write-Host ""

    $scriptPath = Join-Path $PSScriptRoot $FileName
    if (-not (Test-Path $scriptPath)) {
        log_error "Test script not found: $scriptPath"
        return $false
    }

    $output = powershell.exe -ExecutionPolicy Bypass -File $scriptPath 2>&1
    $exitCode = $LASTEXITCODE
    # Write subprocess output to host so Start-Transcript captures it
    $output | ForEach-Object { Write-Host $_ }
    return ($exitCode -eq 0)
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

# --- Start logging to file ---
$logsDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}
$logFile = Join-Path $logsDir "test-results.log"
Start-Transcript -Path $logFile -Append

log_start
log_info "Test scripts directory: $PSScriptRoot"
log_info "Log file: $logFile"

$overallPass = $true

# --- Determine current state ---
$featuresEnabled = $false
try {
    $wslState = (Get-WindowsOptionalFeature -Online -FeatureName $WSL_FEATURE).State.ToString()
    $vmState  = (Get-WindowsOptionalFeature -Online -FeatureName $VM_FEATURE).State.ToString()
    log_info "Current state: $WSL_FEATURE = $wslState, $VM_FEATURE = $vmState"

    if ($wslState -eq "Enabled" -and $vmState -eq "Enabled") {
        $featuresEnabled = $true
        log_info "Features are fully Enabled (post-reboot session)"
    } elseif ($wslState -eq "EnablePending" -or $vmState -eq "EnablePending") {
        log_info "Features are EnablePending (pre-reboot, install already ran)"
    } else {
        log_info "Features need to be enabled (first run)"
    }
}
catch {
    log_warning "Could not query feature state: $_"
}

# --- test-0: prerequisites ---
$result = Run-TestScript "test-0: Prerequisites" "test-0-prerequisites.ps1"
if (-not $result) {
    $overallPass = $false
    log_error "Prerequisites failed - stopping tests"
    Stop-Transcript
    exit 1
}

# --- test-1: install ---
$result = Run-TestScript "test-1: Install" "test-1-install.ps1"
if (-not $result) { $overallPass = $false }

# --- test-2: detect ---
$result = Run-TestScript "test-2: Detect" "test-2-detect.ps1"
if (-not $result) { $overallPass = $false }

# --- test-3: post-reboot (only if features are fully Enabled) ---
if ($featuresEnabled) {
    $result = Run-TestScript "test-3: Post-reboot" "test-3-post-reboot.ps1"
    if (-not $result) { $overallPass = $false }
} else {
    Write-Host ""
    Write-Host "================================================================"
    log_warning "SKIPPING test-3: Features are not yet fully Enabled"
    log_warning "Reboot the PC, then re-run this script for post-reboot tests"
    Write-Host "================================================================"
}

# --- Final summary ---
Write-Host ""
Write-Host "================================================================"
if ($overallPass) {
    if ($featuresEnabled) {
        log_success "ALL TESTS PASSED"
    } else {
        log_success "PRE-REBOOT TESTS PASSED"
        Write-Host ""
        log_warning "Reboot required. After reboot, re-run this script."
        log_warning "If Admin on Demand has expired, request it again before re-running."
    }
} else {
    log_error "SOME TESTS FAILED"
}
Write-Host "================================================================"

Stop-Transcript

if (-not $overallPass) {
    exit 1
}
