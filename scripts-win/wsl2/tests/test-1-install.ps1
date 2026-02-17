#!/usr/bin/env pwsh
# File: test-1-install.ps1
#
# Usage:
#   test-1-install.ps1 [-Help]
#
# Purpose:
#   Runs install.ps1 and verifies WSL2 features are enabled or pending reboot.
#
# Author: Ops Team
# Created: February 2026
#
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

$SCRIPT_ID          = "test-1-install"
$SCRIPT_NAME        = "WSL2 Install Test"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Runs install.ps1 and verifies WSL2 features are enabled."
$SCRIPT_CATEGORY    = "TEST"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$WSL_FEATURE        = "Microsoft-Windows-Subsystem-Linux"
$VM_FEATURE         = "VirtualMachinePlatform"
$INSTALL_SCRIPT     = "install.ps1"

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

log_info "Running $SCRIPT_NAME"
Write-Host ""

$validStates = @("Enabled", "EnablePending")

# --- Check if features are already Enabled (skip install) ---
$wslState = (Get-WindowsOptionalFeature -Online -FeatureName $WSL_FEATURE).State.ToString()
$vmState  = (Get-WindowsOptionalFeature -Online -FeatureName $VM_FEATURE).State.ToString()

if ($wslState -eq "Enabled" -and $vmState -eq "Enabled") {
    Test-Skip "Run install.ps1" "Features already Enabled (post-reboot)"
    Test-Pass "$WSL_FEATURE is $wslState"
    Test-Pass "$VM_FEATURE is $vmState"
    $allPassed = Test-Summary
    if (-not $allPassed) { exit 1 }
    exit 0
}

# --- Run install.ps1 ---
$installPath = Join-Path $PSScriptRoot "..\$INSTALL_SCRIPT"
if (-not (Test-Path $installPath)) {
    Test-Fail "Find install.ps1" "Not found at: $installPath"
    $allPassed = Test-Summary
    if (-not $allPassed) { exit 1 }
    exit 0
}

log_info "Running install.ps1..."
Write-Host ""
& $installPath
$installExitCode = $LASTEXITCODE
Write-Host ""

# --- Test: exit code ---
if ($installExitCode -eq 0) {
    Test-Pass "install.ps1 exit code: 0 (no reboot needed)"
} elseif ($installExitCode -eq 3010) {
    Test-Pass "install.ps1 exit code: 3010 (reboot needed)"
} else {
    Test-Fail "install.ps1 exit code: $installExitCode" "Expected 0 or 3010"
    $allPassed = Test-Summary
    if (-not $allPassed) { exit 1 }
    exit 0
}

# --- Test: feature states after install ---
$wslStateAfter = (Get-WindowsOptionalFeature -Online -FeatureName $WSL_FEATURE).State.ToString()
$vmStateAfter  = (Get-WindowsOptionalFeature -Online -FeatureName $VM_FEATURE).State.ToString()

if ($wslStateAfter -in $validStates) {
    Test-Pass "$WSL_FEATURE is $wslStateAfter"
} else {
    Test-Fail "$WSL_FEATURE is $wslStateAfter" "Expected Enabled or EnablePending"
}

if ($vmStateAfter -in $validStates) {
    Test-Pass "$VM_FEATURE is $vmStateAfter"
} else {
    Test-Fail "$VM_FEATURE is $vmStateAfter" "Expected Enabled or EnablePending"
}

# --- Summary ---
$allPassed = Test-Summary
if (-not $allPassed) {
    exit 1
}
