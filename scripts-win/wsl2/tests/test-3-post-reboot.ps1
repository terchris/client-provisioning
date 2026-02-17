#!/usr/bin/env pwsh
# File: test-3-post-reboot.ps1
#
# Usage:
#   test-3-post-reboot.ps1 [-Help]
#
# Purpose:
#   Verifies WSL2 features are active after reboot.
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

$SCRIPT_ID          = "test-3-post-reboot"
$SCRIPT_NAME        = "WSL2 Post-Reboot Test"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Verifies WSL2 features are active after reboot."
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

# --- Test: features are Enabled (not EnablePending) ---
$wslState = (Get-WindowsOptionalFeature -Online -FeatureName $WSL_FEATURE).State.ToString()
$vmState  = (Get-WindowsOptionalFeature -Online -FeatureName $VM_FEATURE).State.ToString()

if ($wslState -eq "Enabled") {
    Test-Pass "$WSL_FEATURE is Enabled"
} else {
    Test-Fail "$WSL_FEATURE is $wslState" "Expected Enabled after reboot"
}

if ($vmState -eq "Enabled") {
    Test-Pass "$VM_FEATURE is Enabled"
} else {
    Test-Fail "$VM_FEATURE is $vmState" "Expected Enabled after reboot"
}

# NOTE: We do NOT run wsl --version or wsl --status here.
# The WSL kernel component is not installed by this package (only the Windows features).
# Running wsl commands without the kernel triggers an interactive prompt that hangs for
# 60 seconds ("Press any key to install..."). The kernel is handled by Rancher Desktop
# or a later Intune package.

# --- Summary ---
$allPassed = Test-Summary
if (-not $allPassed) {
    exit 1
}
