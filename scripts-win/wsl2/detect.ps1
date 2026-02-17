#!/usr/bin/env pwsh
# File: detect.ps1
#
# Usage:
#   detect.ps1 [-Help]
#
# Purpose:
#   Intune detection script for WSL2 features.
#
# Author: Ops Team
# Created: February 2026
#
# Detection convention:
#   Exit 0 + stdout output = detected (installed)
#   Exit 0 + no output     = NOT detected (not installed)
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

$SCRIPT_ID          = "wsl2-detect"
$SCRIPT_NAME        = "WSL2 Detection Script"
$SCRIPT_VER         = "0.2.1"
$SCRIPT_DESCRIPTION = "Intune detection script for WSL2 features."
$SCRIPT_CATEGORY    = "DEPLOY"

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
function log_start   { log_info "Starting: $SCRIPT_NAME Ver: $SCRIPT_VER" }

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
    Write-Host "Detection logic:"
    Write-Host "  Both features Enabled or EnablePending = detected"
    Write-Host "  Otherwise = not detected"
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

log_start

# Detection scripts must be fast - they run every Intune check-in (every 8 hours).
# No logging in detection scripts - only stdout output matters to Intune.

$validStates = @("Enabled", "EnablePending")

try {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName $WSL_FEATURE
    $vmFeature  = Get-WindowsOptionalFeature -Online -FeatureName $VM_FEATURE

    if ($wslFeature.State.ToString() -in $validStates -and $vmFeature.State.ToString() -in $validStates) {
        # Stdout output = detected
        Write-Host "WSL2 features detected ($($wslFeature.State), $($vmFeature.State))"
        exit 0
    }

    # No output = not detected (Intune convention)
    log_info "WSL2 features are not installed"
    exit 0
}
catch {
    # Detection error - exit non-zero
    exit 1
}
