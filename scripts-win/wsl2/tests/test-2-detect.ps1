#!/usr/bin/env pwsh
# File: test-2-detect.ps1
#
# Usage:
#   test-2-detect.ps1 [-Help]
#
# Purpose:
#   Runs detect.ps1 and verifies it outputs text (detected).
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

$SCRIPT_ID          = "test-2-detect"
$SCRIPT_NAME        = "WSL2 Detection Test"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Runs detect.ps1 and verifies it outputs text (detected)."
$SCRIPT_CATEGORY    = "TEST"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$DETECT_SCRIPT      = "detect.ps1"

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

# --- Find detect.ps1 ---
$detectPath = Join-Path $PSScriptRoot "..\$DETECT_SCRIPT"
if (-not (Test-Path $detectPath)) {
    Test-Fail "Find detect.ps1" "Not found at: $detectPath"
    $allPassed = Test-Summary
    if (-not $allPassed) { exit 1 }
    exit 0
}

# --- Run detect.ps1 and capture output ---
# Use powershell.exe subprocess so Write-Host output is captured as stdout
log_info "Running detect.ps1..."
$output = powershell.exe -ExecutionPolicy Bypass -File $detectPath 2>&1
$detectExitCode = $LASTEXITCODE

# --- Test: exit code ---
if ($detectExitCode -eq 0) {
    Test-Pass "detect.ps1 exit code: 0"
} else {
    Test-Fail "detect.ps1 exit code: $detectExitCode" "Expected 0"
}

# --- Test: stdout output (detected = has output) ---
$outputText = ($output | Out-String).Trim()
if ($outputText.Length -gt 0) {
    Test-Pass "detect.ps1 produced output (detected)"
    log_info "Detection output: $outputText"
} else {
    Test-Fail "detect.ps1 produced output" "No output means NOT detected"
}

# --- Summary ---
$allPassed = Test-Summary
if (-not $allPassed) {
    exit 1
}
