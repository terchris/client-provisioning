#!/usr/bin/env pwsh
# File: install.ps1
#
# Usage:
#   install.ps1 [-Help]
#
# Purpose:
#   Pulls the devcontainer-toolbox Docker image and installs the devcontainer-init command globally.
#
# Author: Ops Team
# Created: February 2026
#
# Intune runs this in System context. Requires Rancher Desktop to be installed.
# Launches Rancher Desktop, pulls the image, installs devcontainer-init to
# C:\Program Files\devcontainer-toolbox\, adds to system PATH, shuts down.
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

$SCRIPT_ID          = "devcontainer-toolbox-install"
$SCRIPT_NAME        = "Devcontainer Toolbox Installer"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Pulls the devcontainer-toolbox Docker image and installs the devcontainer-init command globally."
$SCRIPT_CATEGORY    = "DEPLOY"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$CONTAINER_IMAGE       = "ghcr.io/terchris/devcontainer-toolbox:latest"
$INSTALL_DIR           = "C:\Program Files\devcontainer-toolbox"
$INIT_SCRIPT_NAME      = "devcontainer-init.ps1"
$INIT_CMD_NAME         = "devcontainer-init.cmd"

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
    Write-Host "Prerequisites:"
    Write-Host "  Rancher Desktop must be installed"
    Write-Host "  Internet access (pulls Docker image)"
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

function Test-RancherInstalled {
    foreach ($dir in $RANCHER_INSTALL_PATHS) {
        $exePath = Join-Path $dir $RANCHER_EXE
        if (Test-Path $exePath) {
            return $dir
        }
    }
    return $null
}

function Wait-ForBackendReady {
    param([string]$InstallDir)

    $script:vmState = $null
    $rdctlPath = Join-Path $InstallDir $RDCTL_RELATIVE_PATH
    $hasRdctl = Test-Path $rdctlPath

    if (-not $hasRdctl) {
        log_warning "rdctl not found at $rdctlPath -- falling back to timed wait"
        log_info "Waiting $LAUNCH_WAIT_SECONDS seconds for startup..."
        Start-Sleep -Seconds $LAUNCH_WAIT_SECONDS
        $proc = Get-Process -Name $RANCHER_PROCESS -ErrorAction SilentlyContinue
        if ($proc) {
            log_success "Rancher Desktop process is running (PID: $($proc[0].Id))"
        } else {
            log_error "ERR002: Rancher Desktop process not found after $LAUNCH_WAIT_SECONDS seconds"
        }
        return ($null -ne $proc)
    }

    log_info "Waiting for backend to reach ready state (timeout: $RDCTL_READY_TIMEOUT seconds)..."

    $elapsed = 0
    $processFound = $false
    while ($elapsed -lt $RDCTL_READY_TIMEOUT) {
        Start-Sleep -Seconds $RDCTL_POLL_SECONDS
        $elapsed += $RDCTL_POLL_SECONDS

        if (-not $processFound) {
            $proc = Get-Process -Name $RANCHER_PROCESS -ErrorAction SilentlyContinue
            if ($proc) {
                log_success "Rancher Desktop process is running (PID: $($proc[0].Id))"
                $processFound = $true
            } else {
                log_info "Waiting for process... ($elapsed/$RDCTL_READY_TIMEOUT sec)"
                continue
            }
        }

        try {
            $stateJson = & $rdctlPath api /v1/backend_state 2>$null
            if ($stateJson) {
                $state = $stateJson | ConvertFrom-Json
                $script:vmState = $state.vmState
                log_info "Backend state: $($script:vmState) ($elapsed/$RDCTL_READY_TIMEOUT sec)"
                if ($script:vmState -eq "STARTED" -or $script:vmState -eq "DISABLED") {
                    log_success "Backend is ready (state: $($script:vmState))"
                    return $true
                }
                if ($script:vmState -eq "ERROR") {
                    log_error "ERR002: Backend reported ERROR state"
                    return $false
                }
            }
        }
        catch {
            log_info "Waiting for rdctl... ($elapsed/$RDCTL_READY_TIMEOUT sec)"
        }
    }

    if (-not $processFound) {
        log_error "ERR002: Rancher Desktop process not found within $RDCTL_READY_TIMEOUT seconds"
    } else {
        log_error "ERR002: Backend did not reach ready state within $RDCTL_READY_TIMEOUT seconds"
    }
    return $false
}

function Stop-RancherDesktop {
    param([string]$InstallDir)

    log_info "Stopping Rancher Desktop..."

    $rdctlPath = Join-Path $InstallDir $RDCTL_RELATIVE_PATH
    if (Test-Path $rdctlPath) {
        try {
            & $rdctlPath shutdown 2>$null
            log_info "Sent rdctl shutdown, waiting for process to exit..."
            $elapsed = 0
            while ($elapsed -lt 30) {
                Start-Sleep -Seconds 2
                $elapsed += 2
                if (-not (Get-Process -Name $RANCHER_PROCESS -ErrorAction SilentlyContinue)) {
                    break
                }
            }
        }
        catch {
            log_warning "rdctl shutdown failed: $_"
        }
    }

    $proc = Get-Process -Name $RANCHER_PROCESS -ErrorAction SilentlyContinue
    if ($proc) {
        $proc | Stop-Process -Force
        Start-Sleep -Seconds 5

        $stillRunning = Get-Process -Name $RANCHER_PROCESS -ErrorAction SilentlyContinue
        if ($stillRunning) {
            log_warning "Rancher Desktop process still running after force stop"
        } else {
            log_success "Rancher Desktop stopped"
        }
    } else {
        log_success "Rancher Desktop stopped"
    }
}

function Install-InitTool {
    # Copy devcontainer-init.ps1 and devcontainer-init.cmd to install directory.
    log_info "Installing devcontainer-init to $INSTALL_DIR..."

    # Create install directory
    if (-not (Test-Path $INSTALL_DIR)) {
        try {
            New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
        }
        catch {
            log_error "ERR004: Failed to create directory $INSTALL_DIR : $_"
            exit 1
        }
    }

    if (-not (Test-Path $INSTALL_DIR)) {
        log_error "ERR004: Install directory not found after creation: $INSTALL_DIR"
        exit 1
    }

    # Copy files from the package directory (same folder as this script)
    $sourceScript = Join-Path $PSScriptRoot $INIT_SCRIPT_NAME
    $sourceCmd    = Join-Path $PSScriptRoot $INIT_CMD_NAME

    if (-not (Test-Path $sourceScript)) {
        log_error "ERR005: Source file not found: $sourceScript"
        exit 1
    }
    if (-not (Test-Path $sourceCmd)) {
        log_error "ERR005: Source file not found: $sourceCmd"
        exit 1
    }

    try {
        Copy-Item -Path $sourceScript -Destination $INSTALL_DIR -Force
        Copy-Item -Path $sourceCmd    -Destination $INSTALL_DIR -Force
    }
    catch {
        log_error "ERR005: Failed to copy files to $INSTALL_DIR : $_"
        exit 1
    }

    # Verify files were copied
    $destScript = Join-Path $INSTALL_DIR $INIT_SCRIPT_NAME
    $destCmd    = Join-Path $INSTALL_DIR $INIT_CMD_NAME
    if (-not (Test-Path $destScript)) {
        log_error "ERR005: $INIT_SCRIPT_NAME not found after copy"
        exit 1
    }
    if (-not (Test-Path $destCmd)) {
        log_error "ERR005: $INIT_CMD_NAME not found after copy"
        exit 1
    }

    log_success "Installed $INIT_SCRIPT_NAME and $INIT_CMD_NAME to $INSTALL_DIR"
}

function Add-ToSystemPath {
    # Add install directory to system PATH if not already present.
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($currentPath -like "*$INSTALL_DIR*") {
        log_info "$INSTALL_DIR is already in system PATH"
        return
    }

    log_info "Adding $INSTALL_DIR to system PATH..."
    try {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$INSTALL_DIR", "Machine")
    }
    catch {
        log_error "ERR006: Failed to update system PATH: $_"
        log_error "ERR006: This requires Administrator privileges"
        exit 1
    }

    # Verify
    $newPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($newPath -like "*$INSTALL_DIR*") {
        log_success "Added $INSTALL_DIR to system PATH"
        log_info "Note: PATH changes take effect in new terminal sessions"
    } else {
        log_error "ERR006: PATH update did not persist"
        exit 1
    }
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

log_start

# --- Check Rancher Desktop is installed ---
$rancherDir = Test-RancherInstalled
if (-not $rancherDir) {
    log_error "ERR001: Rancher Desktop is not installed"
    log_error "ERR001: Checked: $($RANCHER_INSTALL_PATHS -join ', ')"
    log_error "ERR001: Install Rancher Desktop first (scripts-win/rancher-desktop/)"
    exit 1
}
log_success "Rancher Desktop found at $rancherDir"

# --- Stop any existing Rancher Desktop instances ---
$existing = Get-Process -Name $RANCHER_PROCESS -ErrorAction SilentlyContinue
if ($existing) {
    log_info "Rancher Desktop is already running, stopping it first..."
    $existing | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

# --- Launch Rancher Desktop ---
log_info "Launching Rancher Desktop..."
try {
    $exePath = Join-Path $rancherDir $RANCHER_EXE
    Start-Process -FilePath $exePath
}
catch {
    log_error "ERR002: Failed to launch Rancher Desktop: $_"
    exit 1
}

$backendReady = Wait-ForBackendReady -InstallDir $rancherDir
if (-not $backendReady) {
    log_error "Rancher Desktop backend did not become ready -- exiting"
    exit 1
}

# --- Pull the container image ---
$dockerPath = Join-Path $rancherDir $DOCKER_RELATIVE_PATH
if (-not (Test-Path $dockerPath)) {
    log_error "ERR003: docker.exe not found at $dockerPath"
    Stop-RancherDesktop -InstallDir $rancherDir
    exit 1
}

log_info "Pulling Docker image: $CONTAINER_IMAGE"
try {
    & $dockerPath pull $CONTAINER_IMAGE 2>&1 | ForEach-Object { Write-Host $_ }
    $pullExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 1 }
    if ($pullExit -ne 0) {
        log_error "ERR003: docker pull failed with exit code $pullExit"
        Stop-RancherDesktop -InstallDir $rancherDir
        exit 1
    }
}
catch {
    log_error "ERR003: docker pull failed: $_"
    Stop-RancherDesktop -InstallDir $rancherDir
    exit 1
}
log_success "Docker image pulled: $CONTAINER_IMAGE"

# --- Install devcontainer-init ---
Install-InitTool

# --- Add to system PATH ---
Add-ToSystemPath

# --- Shut down Rancher Desktop ---
Stop-RancherDesktop -InstallDir $rancherDir

Write-Host ""
log_success "$SCRIPT_NAME completed"
log_success "  Image: $CONTAINER_IMAGE"
log_success "  Tool:  $INSTALL_DIR\$INIT_CMD_NAME"
log_info "Users can now run 'devcontainer-init' from any new terminal"

exit 0
