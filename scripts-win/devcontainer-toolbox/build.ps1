#!/usr/bin/env pwsh
# File: build.ps1
#
# Usage:
#   build.ps1 [-Help]
#
# Purpose:
#   Creates the .intunewin package for the devcontainer-toolbox deployment.
#
# Author: Ops Team
# Created: February 2026
#
# Run in the devcontainer (Linux/pwsh). Requires SvRooij.ContentPrep.Cmdlet.

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

$SCRIPT_ID          = "devcontainer-toolbox-build"
$SCRIPT_NAME        = "Devcontainer Toolbox Package Builder"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Creates the .intunewin package for the devcontainer-toolbox deployment."
$SCRIPT_CATEGORY    = "DEVOPS"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$PACKAGE_DIR        = $PSScriptRoot
$SETUP_FILE         = "install.ps1"
$TOOL_OUTPUT_FILE   = "install.intunewin"       # Name the tool generates (based on setup file)
$OUTPUT_FILE        = "devcontainer-toolbox-install.intunewin"

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
    Write-Host "Prerequisites:"
    Write-Host "  SvRooij.ContentPrep.Cmdlet module must be installed"
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
log_info "Package directory: $PACKAGE_DIR"

# --- Check prerequisites ---
if ($null -eq (Get-Module -ListAvailable -Name 'SvRooij.ContentPrep.Cmdlet')) {
    log_error "ERR001: SvRooij.ContentPrep.Cmdlet module is not installed"
    log_error "ERR001: Run: Install-Module -Name SvRooij.ContentPrep.Cmdlet -Force -Scope AllUsers"
    exit 1
}
log_success "SvRooij.ContentPrep.Cmdlet is available"

$setupPath = Join-Path $PACKAGE_DIR $SETUP_FILE
if (-not (Test-Path $setupPath)) {
    log_error "ERR002: Setup file not found: $setupPath"
    exit 1
}
log_success "Setup file found: $SETUP_FILE"

# --- Remove old package if it exists ---
$outputPath = Join-Path $PACKAGE_DIR $OUTPUT_FILE
if (Test-Path $outputPath) {
    log_info "Removing old package: $OUTPUT_FILE"
    Remove-Item $outputPath -Force
}

# --- Build the .intunewin package ---
# DestinationPath cannot be the same as SourcePath, so we build to a temp dir and move back.
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "devcontainer-build-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

log_info "Building .intunewin package..."
try {
    New-IntuneWinPackage -SourcePath $PACKAGE_DIR -SetupFile $SETUP_FILE -DestinationPath $tempDir
}
catch {
    log_error "ERR003: Failed to build .intunewin package"
    log_error "ERR003: $_"
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Move the built package to the package directory
$builtFile = Join-Path $tempDir $TOOL_OUTPUT_FILE
if (-not (Test-Path $builtFile)) {
    log_error "ERR004: Package was not created in temp directory"
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Move-Item $builtFile $outputPath -Force
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# --- Verify the package was created ---
if (-not (Test-Path $outputPath)) {
    log_error "ERR004: Package was not found after move: $outputPath"
    exit 1
}

$fileSize = (Get-Item $outputPath).Length
log_success "Package created: $OUTPUT_FILE ($fileSize bytes)"
log_success "$SCRIPT_NAME completed"

exit 0
