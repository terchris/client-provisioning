#!/usr/bin/env pwsh
# File: uninstall.ps1
#
# Usage:
#   uninstall.ps1 [-Help]
#
# Purpose:
#   Removes the devcontainer-init tool and cleans up the system PATH entry.
#
# Author: Ops Team
# Created: February 2026
#
# Removes C:\Program Files\devcontainer-toolbox\ and its PATH entry.
# Optionally removes the Docker image (requires Rancher Desktop).
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

$SCRIPT_ID          = "devcontainer-toolbox-uninstall"
$SCRIPT_NAME        = "Devcontainer Toolbox Uninstaller"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Removes the devcontainer-init tool and cleans up the system PATH entry."
$SCRIPT_CATEGORY    = "DEPLOY"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$INSTALL_DIR        = "C:\Program Files\devcontainer-toolbox"
$CONTAINER_IMAGE    = "ghcr.io/terchris/devcontainer-toolbox:latest"

$RANCHER_EXE           = "Rancher Desktop.exe"
$RANCHER_PROCESS       = "Rancher Desktop"
$RDCTL_RELATIVE_PATH   = "resources\resources\win32\bin\rdctl.exe"
$DOCKER_RELATIVE_PATH  = "resources\resources\win32\bin\docker.exe"
$RDCTL_READY_TIMEOUT   = 120
$RDCTL_POLL_SECONDS    = 3
$LAUNCH_WAIT_SECONDS   = 15

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
    Write-Host "Metadata:"
    Write-Host "  ID:       $SCRIPT_ID"
    Write-Host "  Category: $SCRIPT_CATEGORY"
}

if ($Help) {
    Show-Help
    exit 0
}

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

function Find-RancherInstallDir {
    foreach ($dir in $RANCHER_INSTALL_PATHS) {
        $exePath = Join-Path $dir $RANCHER_EXE
        if (Test-Path $exePath) {
            return $dir
        }
    }
    return $null
}

function Remove-FromSystemPath {
    # Remove install directory from system PATH.
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($currentPath -notlike "*$INSTALL_DIR*") {
        log_info "$INSTALL_DIR is not in system PATH -- nothing to remove"
        return
    }

    log_info "Removing $INSTALL_DIR from system PATH..."

    # Split, filter, rejoin
    $parts = $currentPath -split ';' | Where-Object { $_ -ne $INSTALL_DIR -and $_ -ne "$INSTALL_DIR\" -and $_ -ne "" }
    $newPath = $parts -join ';'

    try {
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
    }
    catch {
        log_error "ERR002: Failed to update system PATH: $_"
        exit 1
    }

    # Verify
    $verifyPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($verifyPath -like "*$INSTALL_DIR*") {
        log_error "ERR002: PATH entry still present after removal"
        exit 1
    }

    log_success "Removed $INSTALL_DIR from system PATH"
}

function Remove-ContainerImage {
    # Try to remove the Docker image. Non-fatal if it fails.
    $rancherDir = Find-RancherInstallDir
    if (-not $rancherDir) {
        log_info "Rancher Desktop not installed -- skipping image removal"
        return
    }

    $dockerPath = Join-Path $rancherDir $DOCKER_RELATIVE_PATH
    if (-not (Test-Path $dockerPath)) {
        log_info "docker.exe not found -- skipping image removal"
        return
    }

    # Check if Docker is running
    $dockerRunning = $false
    try {
        $null = & $dockerPath ps 2>$null
        $dockerExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 1 }
        if ($dockerExit -eq 0) { $dockerRunning = $true }
    }
    catch {
        # Docker not responding
    }

    if (-not $dockerRunning) {
        log_info "Docker is not running -- skipping image removal"
        log_info "To remove the image manually, start Rancher Desktop and run:"
        log_info "  docker rmi $CONTAINER_IMAGE"
        return
    }

    log_info "Removing Docker image: $CONTAINER_IMAGE"
    try {
        & $dockerPath rmi $CONTAINER_IMAGE 2>&1 | ForEach-Object { Write-Host $_ }
        $rmiExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 1 }
        if ($rmiExit -eq 0) {
            log_success "Docker image removed: $CONTAINER_IMAGE"
        } else {
            log_warning "docker rmi exited with code $rmiExit -- image may still be present"
        }
    }
    catch {
        log_warning "Failed to remove Docker image: $_"
    }
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

log_start

# --- Check if installed ---
if (-not (Test-Path $INSTALL_DIR)) {
    log_info "Install directory does not exist: $INSTALL_DIR"
    log_success "Nothing to do -- already uninstalled"
    exit 0
}

# --- Remove install directory ---
log_info "Removing install directory: $INSTALL_DIR"
try {
    Remove-Item -Path $INSTALL_DIR -Recurse -Force
}
catch {
    log_error "ERR001: Failed to remove $INSTALL_DIR : $_"
    exit 1
}

if (Test-Path $INSTALL_DIR) {
    log_error "ERR001: Directory still exists after removal: $INSTALL_DIR"
    exit 1
}
log_success "Removed $INSTALL_DIR"

# --- Remove from system PATH ---
Remove-FromSystemPath

# --- Remove container image (best effort) ---
Remove-ContainerImage

Write-Host ""
log_success "$SCRIPT_NAME completed -- devcontainer-toolbox removed"

exit 0
