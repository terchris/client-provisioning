#!/usr/bin/env pwsh
# File: uninstall.ps1
#
# Usage:
#   uninstall.ps1 [-Help]
#
# Purpose:
#   Silently uninstalls Rancher Desktop on Windows (per-user MSI).
#
# Author: Ops Team
# Created: February 2026
#
# Intune runs this in User context. Finds the product code from the registry
# and runs msiexec /x to remove the per-user installation.
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

$SCRIPT_ID          = "rancher-desktop-uninstall"
$SCRIPT_NAME        = "Rancher Desktop Uninstaller"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Silently uninstalls Rancher Desktop on Windows (per-user MSI)."
$SCRIPT_CATEGORY    = "DEPLOY"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$RANCHER_EXE           = "Rancher Desktop.exe"
$RANCHER_DISPLAY_NAME  = "Rancher Desktop"
$RANCHER_PROCESS_NAMES = @("Rancher Desktop", "rdctl")
$PROCESS_STOP_TIMEOUT  = 15
$PROCESS_KILL_TIMEOUT  = 10

# Check both per-user and per-machine install paths
$RANCHER_INSTALL_PATHS = @(
    "$env:LOCALAPPDATA\Programs\Rancher Desktop",
    "$env:ProgramFiles\Rancher Desktop"
)

# Check both per-user (HKCU) and per-machine (HKLM) registry
$UNINSTALL_REG_PATHS   = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
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

function Stop-RancherProcesses {
    $found = $false
    foreach ($name in $RANCHER_PROCESS_NAMES) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($procs) {
            $found = $true
            log_info "Stopping $name processes..."
            $procs | ForEach-Object { $_.CloseMainWindow() | Out-Null }
        }
    }

    if (-not $found) {
        log_info "No Rancher Desktop processes running"
        return
    }

    # Wait for graceful shutdown
    $elapsed = 0
    while ($elapsed -lt $PROCESS_STOP_TIMEOUT) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        $stillRunning = $false
        foreach ($name in $RANCHER_PROCESS_NAMES) {
            if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
                $stillRunning = $true
                break
            }
        }
        if (-not $stillRunning) {
            log_info "Rancher Desktop stopped gracefully"
            return
        }
        log_info "Waiting for processes to exit... ($elapsed/$PROCESS_STOP_TIMEOUT sec)"
    }

    # Force kill
    log_warning "Rancher Desktop did not quit gracefully, force killing..."
    foreach ($name in $RANCHER_PROCESS_NAMES) {
        Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
    }

    $elapsed = 0
    while ($elapsed -lt $PROCESS_KILL_TIMEOUT) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        $stillRunning = $false
        foreach ($name in $RANCHER_PROCESS_NAMES) {
            if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
                $stillRunning = $true
                break
            }
        }
        if (-not $stillRunning) {
            log_info "Rancher Desktop stopped after force kill"
            return
        }
        log_info "Waiting for processes to exit... ($elapsed/$PROCESS_KILL_TIMEOUT sec)"
    }

    log_error "ERR002: Failed to stop Rancher Desktop after $($PROCESS_STOP_TIMEOUT + $PROCESS_KILL_TIMEOUT) seconds"
    exit 1
}

function Get-RancherProductCode {
    foreach ($regPath in $UNINSTALL_REG_PATHS) {
        $entries = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
            Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -like "*$RANCHER_DISPLAY_NAME*" }

        if ($entries) {
            $entry = $entries | Select-Object -First 1
            $keyName = Split-Path $entry.PSPath -Leaf
            log_info "Found in registry: $regPath"
            return $keyName
        }
    }
    return $null
}

function Invoke-MsiUninstall {
    param([string]$ProductCode)

    log_info "Uninstalling Rancher Desktop (product code: $ProductCode)..."

    $msiArgs = "/x `"$ProductCode`" /qn /norestart"
    log_info "msiexec $msiArgs"

    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

    $exitCode = $process.ExitCode
    if ($exitCode -eq 0) {
        log_success "MSI uninstall completed (exit code 0)"
    }
    elseif ($exitCode -eq 3010) {
        log_success "MSI uninstall completed (exit code 3010 -- reboot may be needed)"
    }
    elseif ($exitCode -eq 1605) {
        # 1605 = product not installed -- treat as success (idempotent)
        log_warning "Product not found by msiexec (exit code 1605) -- already uninstalled"
    }
    else {
        log_error "ERR004: MSI uninstall failed with exit code $exitCode"
        exit 1
    }
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

log_start

# --- Check if installed ---
$installedDir = $null
foreach ($dir in $RANCHER_INSTALL_PATHS) {
    $exePath = Join-Path $dir $RANCHER_EXE
    if (Test-Path $exePath) {
        $installedDir = $dir
        break
    }
}

if (-not $installedDir) {
    log_info "Rancher Desktop is not installed"
    log_info "Checked: $($RANCHER_INSTALL_PATHS -join ', ')"
    log_success "Nothing to do -- already uninstalled"
    exit 0
}
log_info "Found Rancher Desktop at $installedDir"

# --- Find product code ---
$productCode = Get-RancherProductCode
if (-not $productCode) {
    log_error "ERR003: Rancher Desktop files exist but no registry entry found"
    log_error "ERR003: Searched HKCU and HKLM Uninstall keys for '$RANCHER_DISPLAY_NAME'"
    exit 1
}
log_info "Found product code: $productCode"

# --- Stop processes ---
Stop-RancherProcesses

# --- Uninstall ---
Invoke-MsiUninstall -ProductCode $productCode

# --- Verify ---
$stillExists = $false
foreach ($dir in $RANCHER_INSTALL_PATHS) {
    $exePath = Join-Path $dir $RANCHER_EXE
    if (Test-Path $exePath) {
        log_error "ERR005: Rancher Desktop.exe still exists at $dir"
        $stillExists = $true
    }
}
if ($stillExists) {
    exit 1
}
log_success "Verified: Rancher Desktop.exe no longer exists"

# --- Remove deployment profile ---
$profilePath = "HKLM:\SOFTWARE\Policies\Rancher Desktop"
if (Test-Path $profilePath) {
    try {
        Remove-Item -Path $profilePath -Recurse -Force
        log_success "Removed deployment profile from registry"
    }
    catch {
        log_warning "Could not remove deployment profile: $_"
    }
} else {
    log_info "No deployment profile found in registry"
}

# --- Verify registry entry is gone (same check Intune detect.ps1 relies on) ---
$registryStillPresent = Get-RancherProductCode
if ($registryStillPresent) {
    log_error "ERR005: Rancher Desktop registry entry still present after uninstall"
    log_error "ERR005: Product code: $registryStillPresent"
    exit 1
}
log_success "Verified: Rancher Desktop registry entry removed"

log_success "$SCRIPT_NAME completed -- Rancher Desktop removed"
exit 0
