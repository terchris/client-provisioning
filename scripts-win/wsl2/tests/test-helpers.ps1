#!/usr/bin/env pwsh
# File: test-helpers.ps1
#
# Usage:
#   . .\test-helpers.ps1
#   test-helpers.ps1 [-Help]
#
# Purpose:
#   Shared test functions for WSL2 USB tests. Dot-source this from test scripts.
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

$SCRIPT_ID          = "test-helpers"
$SCRIPT_NAME        = "WSL2 Test Helpers"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Shared test functions for WSL2 USB tests."
$SCRIPT_CATEGORY    = "TEST"

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
    Write-Host "  . .\$SCRIPT_ID.ps1"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help     Show this help message"
    Write-Host ""
    Write-Host "Functions:"
    Write-Host "  Test-Pass     Report a passing test"
    Write-Host "  Test-Fail     Report a failing test"
    Write-Host "  Test-Skip     Report a skipped test"
    Write-Host "  Test-Summary  Print test summary and exit"
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
# TEST STATE
#------------------------------------------------------------------------------

$script:TestsPassed  = 0
$script:TestsFailed  = 0
$script:TestsSkipped = 0

#------------------------------------------------------------------------------
# TEST FUNCTIONS
#------------------------------------------------------------------------------

function Test-Pass {
    param([string]$Name)
    $script:TestsPassed++
    Write-Host "  PASS  $Name"
}

function Test-Fail {
    param([string]$Name, [string]$Reason = "")
    $script:TestsFailed++
    Write-Host "  FAIL  $Name"
    if ($Reason) {
        Write-Host "        $Reason"
    }
}

function Test-Skip {
    param([string]$Name, [string]$Reason = "")
    $script:TestsSkipped++
    Write-Host "  SKIP  $Name"
    if ($Reason) {
        Write-Host "        $Reason"
    }
}

function Test-Summary {
    Write-Host ""
    Write-Host "================================================================"
    $total = $script:TestsPassed + $script:TestsFailed + $script:TestsSkipped
    Write-Host "Results: $total total, $($script:TestsPassed) passed, $($script:TestsFailed) failed, $($script:TestsSkipped) skipped"
    Write-Host "================================================================"
    if ($script:TestsFailed -gt 0) {
        return $false
    }
    return $true
}
