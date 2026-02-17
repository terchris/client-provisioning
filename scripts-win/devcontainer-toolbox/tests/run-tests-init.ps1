#!/usr/bin/env pwsh
# File: run-tests-init.ps1
#
# Usage:
#   run-tests-init.ps1 [-Help]
#
# Purpose:
#   Tests devcontainer-init by running it on a temp folder and verifying the output.
#
# Author: Ops Team
# Created: February 2026
#
# Run from USB: powershell -ExecutionPolicy Bypass -File "D:\devcontainer-toolbox\tests\run-tests-init.ps1"
# Requires: install tests must have passed first (devcontainer-init must be installed).
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

$SCRIPT_ID          = "run-tests-init"
$SCRIPT_NAME        = "Devcontainer Init Tests"
$SCRIPT_VER         = "0.2.1"
$SCRIPT_DESCRIPTION = "Tests devcontainer-init by running it on a temp folder and verifying the output."
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
    Write-Host "  1. Create temp folder"
    Write-Host "  2. Run devcontainer-init.ps1 on temp folder"
    Write-Host "  3. Verify .devcontainer/devcontainer.json exists"
    Write-Host "  4. Verify file is not empty and contains expected content"
    Write-Host "  5. Verify .vscode/extensions.json was created with Dev Containers extension"
    Write-Host ""
    Write-Host "Prerequisites:"
    Write-Host "  Install tests must have passed (devcontainer-init must be installed)"
    Write-Host "  Internet access (downloads devcontainer.json from GitHub)"
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
$logFile = Join-Path $logsDir "test-results-init.log"
Start-Transcript -Path $logFile -Append

log_start
log_info "Log file: $logFile"

$overallPass = $true
$tempDir = $null

try {
    # ================================================================
    # Test 1: Create temp folder
    # ================================================================
    Write-Host ""
    Write-Host "================================================================"
    log_info "Test 1: Create temp folder"
    Write-Host "================================================================"
    Write-Host ""

    $tempDir = Join-Path $env:TEMP "devcontainer-init-test-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    if (Test-Path $tempDir) {
        Test-Pass "Created temp folder: $tempDir"
    } else {
        Test-Fail "Create temp folder" "Failed to create $tempDir"
        $overallPass = $false
        Stop-Transcript
        exit 1
    }

    # ================================================================
    # Test 2: Run devcontainer-init.ps1
    # ================================================================
    Write-Host ""
    Write-Host "================================================================"
    log_info "Test 2: Run devcontainer-init.ps1 on temp folder"
    Write-Host "================================================================"
    Write-Host ""

    $initScript = Join-Path $INSTALL_DIR $INIT_SCRIPT_NAME
    if (-not (Test-Path $initScript)) {
        Test-Fail "Find devcontainer-init.ps1" "Not found at $initScript"
        $overallPass = $false
        log_error "devcontainer-init.ps1 not installed -- run install tests first"
        Stop-Transcript
        exit 1
    }

    log_info "Running devcontainer-init.ps1 with folder: $tempDir"
    Write-Host ""

    # Pass the folder path as argument so it skips the interactive prompt
    powershell.exe -ExecutionPolicy Bypass -File $initScript $tempDir 2>&1 | ForEach-Object { Write-Host $_ }
    $initExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }

    Write-Host ""
    if ($initExit -eq 0) {
        Test-Pass "devcontainer-init.ps1 (exit code 0)"
    } else {
        Test-Fail "devcontainer-init.ps1" "Exit code: $initExit"
        $overallPass = $false
    }

    # ================================================================
    # Test 3: Verify .devcontainer/devcontainer.json exists
    # ================================================================
    Write-Host ""
    Write-Host "================================================================"
    log_info "Test 3: Verify .devcontainer/devcontainer.json exists"
    Write-Host "================================================================"
    Write-Host ""

    $jsonPath = Join-Path $tempDir ".devcontainer\devcontainer.json"
    if (Test-Path $jsonPath) {
        Test-Pass ".devcontainer/devcontainer.json exists at $jsonPath"
    } else {
        Test-Fail ".devcontainer/devcontainer.json exists" "Not found at $jsonPath"
        $overallPass = $false
    }

    # ================================================================
    # Test 4: Verify file is not empty and contains expected content
    # ================================================================
    Write-Host ""
    Write-Host "================================================================"
    log_info "Test 4: Verify file is not empty and contains expected content"
    Write-Host "================================================================"
    Write-Host ""

    if (Test-Path $jsonPath) {
        $fileSize = (Get-Item $jsonPath).Length
        if ($fileSize -gt 0) {
            Test-Pass "devcontainer.json is not empty ($fileSize bytes)"
        } else {
            Test-Fail "devcontainer.json is not empty" "File is 0 bytes"
            $overallPass = $false
        }

        # Check for a known key (devcontainer.json uses comments so ConvertFrom-Json fails on PS 5.1)
        $content = Get-Content $jsonPath -Raw
        if ($content -match '"name"') {
            Test-Pass "devcontainer.json contains expected content"
        } else {
            Test-Fail "devcontainer.json contains expected content" "Missing 'name' key"
            $overallPass = $false
        }
    } else {
        Test-Skip "devcontainer.json content check" "File does not exist (previous test failed)"
    }
    # ================================================================
    # Test 5: Verify .vscode/extensions.json was created
    # ================================================================
    Write-Host ""
    Write-Host "================================================================"
    log_info "Test 5: Verify .vscode/extensions.json was created with Dev Containers extension"
    Write-Host "================================================================"
    Write-Host ""

    $extJsonPath = Join-Path $tempDir ".vscode\extensions.json"
    if (Test-Path $extJsonPath) {
        Test-Pass ".vscode/extensions.json exists at $extJsonPath"

        $extContent = Get-Content $extJsonPath -Raw
        if ($extContent -match 'ms-vscode-remote\.remote-containers') {
            Test-Pass ".vscode/extensions.json contains Dev Containers extension"
        } else {
            Test-Fail ".vscode/extensions.json contains Dev Containers extension" "Missing ms-vscode-remote.remote-containers"
            $overallPass = $false
        }
    } else {
        Test-Fail ".vscode/extensions.json exists" "Not found at $extJsonPath"
        $overallPass = $false
    }
}
finally {
    # --- Cleanup ---
    if ($tempDir -and (Test-Path $tempDir)) {
        log_info "Cleaning up temp folder: $tempDir"
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ================================================================
# Summary
# ================================================================
$allPassed = Test-Summary

Write-Host ""
Write-Host "================================================================"
if ($overallPass -and $allPassed) {
    log_success "ALL INIT TESTS PASSED"
    Write-Host ""
    log_info "devcontainer-init works correctly."
    log_info "Next: run-tests-uninstall.ps1 to test removal"
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
