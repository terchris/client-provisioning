#!/usr/bin/env pwsh
# File: detect.ps1
#
# Usage:
#   detect.ps1 [-Help]
#
# Purpose:
#   Intune detection script for Rancher Desktop (per-user install).
#
# Author: Ops Team
# Created: February 2026
#
# Intune detection convention:
#   Exit 0 + stdout output = app is detected (installed)
#   Exit 0 + no output     = app is NOT detected (not installed)
#   Exit non-zero           = detection error
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

$SCRIPT_ID          = "rancher-desktop-detect"
$SCRIPT_NAME        = "Rancher Desktop Detection"
$SCRIPT_VER         = "0.2.1"
$SCRIPT_DESCRIPTION = "Intune detection script for Rancher Desktop (per-user install)."
$SCRIPT_CATEGORY    = "DEPLOY"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$RANCHER_EXE          = "Rancher Desktop.exe"

# The MSI installs to different paths depending on scope:
#   Per-user:    %LOCALAPPDATA%\Programs\Rancher Desktop\
#   Per-machine: %ProgramFiles%\Rancher Desktop\
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
    Write-Host "  Checks for $RANCHER_EXE in known install paths"
    Write-Host "  Output + exit 0 = detected (installed)"
    Write-Host "  No output + exit 0 = not detected (not installed)"
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

foreach ($dir in $RANCHER_INSTALL_PATHS) {
    $exePath = Join-Path $dir $RANCHER_EXE
    if (Test-Path $exePath) {
        Write-Output "Rancher Desktop installed at $dir"
        exit 0
    }
}

# No output = not detected (Intune convention)
log_info "Rancher Desktop is not installed"
exit 0
