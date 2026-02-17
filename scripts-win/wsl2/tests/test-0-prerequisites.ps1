#!/usr/bin/env pwsh
# File: test-0-prerequisites.ps1
#
# Usage:
#   test-0-prerequisites.ps1 [-Help]
#
# Purpose:
#   Checks prerequisites for WSL2 installation (admin, Windows version, virtualization).
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

$SCRIPT_ID          = "test-0-prerequisites"
$SCRIPT_NAME        = "WSL2 Prerequisites Test"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Checks prerequisites for WSL2 installation."
$SCRIPT_CATEGORY    = "TEST"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$MIN_BUILD          = 19041

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

# --- Test: Administrator ---
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Test-Pass "Running as Administrator"
} else {
    Test-Fail "Running as Administrator" "Right-click PowerShell > 'Run as administrator'"
}

# --- Test: Windows version ---
$build = [System.Environment]::OSVersion.Version.Build
if ($build -ge $MIN_BUILD) {
    Test-Pass "Windows build $build (minimum: $MIN_BUILD)"
} else {
    Test-Fail "Windows build $build (minimum: $MIN_BUILD)" "WSL2 requires Windows 10 version 2004 or later"
}

# --- Test: Virtualization ---
try {
    $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
    if ($computerInfo.HypervisorPresent) {
        Test-Pass "Virtualization is enabled"
    } else {
        Test-Fail "Virtualization is enabled" "Enable Intel VT-x or AMD-V in BIOS/UEFI settings"
    }
}
catch {
    Test-Skip "Virtualization check" "Could not query WMI: $_"
}

# --- Summary ---
$allPassed = Test-Summary
if (-not $allPassed) {
    exit 1
}
