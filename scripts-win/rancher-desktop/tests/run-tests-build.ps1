#!/usr/bin/env pwsh
# File: run-tests-build.ps1
#
# Usage:
#   run-tests-build.ps1 [-Help]
#
# Purpose:
#   Builds the .intunewin package and verifies its contents by extracting and checking files.
#
# Author: Ops Team
# Created: February 2026
#
# Run in devcontainer: pwsh scripts-win/rancher-desktop/tests/run-tests-build.ps1
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

$SCRIPT_ID          = "rancher-desktop-build-tests"
$SCRIPT_NAME        = "Rancher Desktop Build Tests"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Builds the .intunewin package and verifies its contents by extracting and checking files."
$SCRIPT_CATEGORY    = "TEST"

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
    Write-Host "  1. Build (runs build.ps1, verifies .intunewin created)"
    Write-Host "  2. Extract (uses Unlock-IntuneWinPackage to extract contents)"
    Write-Host "  3. Verify (checks all expected files present, .ps1 sizes match originals)"
    Write-Host ""
    Write-Host "Run in devcontainer: pwsh scripts-win/rancher-desktop/tests/run-tests-build.ps1"
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
. (Join-Path $PSScriptRoot "test-helpers.ps1")

# --- Start logging to file ---
$logsDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}
$logFile = Join-Path $logsDir "test-results-build.log"
Start-Transcript -Path $logFile -Append

log_start
log_info "Log file: $logFile"

$overallPass = $true
$skipRemaining = $false
$parentDir = Split-Path $PSScriptRoot

# Paths for cleanup
$extractDir = $null
$intunewinPath = Join-Path $parentDir "rancher-desktop-install.intunewin"

try {

    # ================================================================
    # Test 1: Build (run build.ps1)
    # ================================================================
    Write-Host ""
    Write-Host "================================================================"
    log_info "Test 1: Build (run build.ps1)"
    Write-Host "================================================================"
    Write-Host ""

    $buildScript = Join-Path $parentDir "build.ps1"
    if (-not (Test-Path $buildScript)) {
        Test-Fail "Find build.ps1" "Not found at $buildScript"
        $overallPass = $false
        $skipRemaining = $true
        log_error "Build script not found -- stopping tests"
    }

    if (-not $skipRemaining) {
        log_info "Running build.ps1..."
        Write-Host ""

        # Run as child process, pipe output through Write-Host so Start-Transcript captures it.
        pwsh -File $buildScript 2>&1 | ForEach-Object { Write-Host $_ }
        $buildExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }

        Write-Host ""
        if ($buildExit -eq 0) {
            Test-Pass "build.ps1 exit code 0"
        } else {
            Test-Fail "build.ps1 exit code" "Expected 0, got $buildExit"
            $overallPass = $false
            $skipRemaining = $true
        }
    }

    if (-not $skipRemaining) {
        # Check .intunewin file exists
        if (Test-Path $intunewinPath) {
            Test-Pass "rancher-desktop-install.intunewin exists"
        } else {
            Test-Fail "rancher-desktop-install.intunewin exists" "Not found at $intunewinPath"
            $overallPass = $false
            $skipRemaining = $true
        }
    }

    if (-not $skipRemaining) {
        # Check file size > 0
        $fileSize = (Get-Item $intunewinPath).Length
        if ($fileSize -gt 0) {
            Test-Pass "rancher-desktop-install.intunewin size ($fileSize bytes)"
        } else {
            Test-Fail "rancher-desktop-install.intunewin size" "File is empty (0 bytes)"
            $overallPass = $false
            $skipRemaining = $true
        }
    }

    # ================================================================
    # Test 2: Extract (Unlock-IntuneWinPackage)
    # ================================================================
    if (-not $skipRemaining) {
        Write-Host ""
        Write-Host "================================================================"
        log_info "Test 2: Extract (Unlock-IntuneWinPackage)"
        Write-Host "================================================================"
        Write-Host ""

        $extractDir = Join-Path ([System.IO.Path]::GetTempPath()) "rancher-extract-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

        log_info "Extracting to: $extractDir"
        try {
            Unlock-IntuneWinPackage -SourceFile $intunewinPath -DestinationPath $extractDir
            Test-Pass "Unlock-IntuneWinPackage succeeded"
        }
        catch {
            Test-Fail "Unlock-IntuneWinPackage" "ERR: $_"
            $overallPass = $false
            $skipRemaining = $true
        }
    }

    # ================================================================
    # Test 3: Verify contents
    # ================================================================
    if (-not $skipRemaining) {
        Write-Host ""
        Write-Host "================================================================"
        log_info "Test 3: Verify contents"
        Write-Host "================================================================"
        Write-Host ""

        # Find the extracted files -- Unlock-IntuneWinPackage may nest them in a subdirectory
        $extractedFiles = Get-ChildItem -Path $extractDir -Recurse -File
        $installFile = $extractedFiles | Where-Object { $_.Name -eq 'install.ps1' } | Select-Object -First 1

        if ($null -eq $installFile) {
            Test-Fail "Find install.ps1 in extracted output" "Not found anywhere under $extractDir"
            $overallPass = $false
            $skipRemaining = $true
        }
    }

    if (-not $skipRemaining) {
        $extractRoot = $installFile.DirectoryName
        log_info "Extracted root: $extractRoot"

        # Expected files to check for existence
        $expectedFiles = @(
            "install.ps1",
            "uninstall.ps1",
            "detect.ps1",
            "build.ps1",
            "README.md",
            "INTUNE.md",
            "TESTING.md",
            ".gitignore"
        )

        foreach ($fileName in $expectedFiles) {
            $filePath = Join-Path $extractRoot $fileName
            if (Test-Path $filePath) {
                Test-Pass "Found: $fileName"
            } else {
                Test-Fail "Found: $fileName" "Not found in extracted package"
                $overallPass = $false
            }
        }

        # Compare .ps1 file sizes against originals
        $ps1Files = @("install.ps1", "uninstall.ps1", "detect.ps1", "build.ps1")
        foreach ($fileName in $ps1Files) {
            $originalPath = Join-Path $parentDir $fileName
            $extractedPath = Join-Path $extractRoot $fileName
            if ((Test-Path $originalPath) -and (Test-Path $extractedPath)) {
                $originalSize = (Get-Item $originalPath).Length
                $extractedSize = (Get-Item $extractedPath).Length
                if ($originalSize -eq $extractedSize) {
                    Test-Pass "Size match: $fileName ($originalSize bytes)"
                } else {
                    Test-Fail "Size match: $fileName" "Original: $originalSize bytes, Extracted: $extractedSize bytes"
                    $overallPass = $false
                }
            }
        }
    }

}
finally {
    # ================================================================
    # Cleanup (always runs, even on failure)
    # ================================================================
    Write-Host ""
    Write-Host "================================================================"
    log_info "Cleanup"
    Write-Host "================================================================"
    Write-Host ""

    if (($null -ne $extractDir) -and (Test-Path $extractDir)) {
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        log_info "Removed extract directory"
    }

    if (Test-Path $intunewinPath) {
        Remove-Item $intunewinPath -Force -ErrorAction SilentlyContinue
        log_info "Removed rancher-desktop-install.intunewin"
    }
}

# ================================================================
# Summary
# ================================================================
$allPassed = Test-Summary

Write-Host ""
Write-Host "================================================================"
if ($overallPass -and $allPassed) {
    log_success "ALL BUILD TESTS PASSED"
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
