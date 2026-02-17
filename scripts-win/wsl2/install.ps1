#!/usr/bin/env pwsh
# File: install.ps1
#
# Usage:
#   install.ps1 [-Help]
#
# Purpose:
#   Enables the WSL2 Windows features via DISM for Intune deployment.
#
# Author: Ops Team
# Created: February 2026
#
# Intune runs this as SYSTEM. Exit 3010 = soft reboot required.
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

$SCRIPT_ID          = "wsl2-install"
$SCRIPT_NAME        = "WSL2 Feature Installer"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Enables WSL2 Windows features via DISM for Intune deployment."
$SCRIPT_CATEGORY    = "DEPLOY"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$WSL_FEATURE        = "Microsoft-Windows-Subsystem-Linux"
$VM_FEATURE         = "VirtualMachinePlatform"
$MIN_BUILD          = 19041

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
    Write-Host "Exit codes:"
    Write-Host "  0         Features already enabled (no action needed)"
    Write-Host "  3010      Features enabled, reboot required"
    Write-Host "  1         Error"
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

function Get-FeatureState {
    param([string]$FeatureName)
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName
        return $feature.State.ToString()
    }
    catch {
        log_error "ERR005: Failed to query feature $FeatureName"
        log_error "ERR005: $_"
        exit 1
    }
}

function Enable-Feature {
    param([string]$FeatureName)
    log_info "Enabling feature: $FeatureName"
    & dism.exe /online /enable-feature /featurename:$FeatureName /all /norestart
    switch ($LASTEXITCODE) {
        0       { log_success "Feature enabled: $FeatureName" }
        3010    { log_success "Feature enabled (reboot needed): $FeatureName" }
        default {
            log_error "ERR006: DISM failed for $FeatureName with exit code $LASTEXITCODE"
            exit 1
        }
    }
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

log_start

# --- Prerequisite: Administrator/SYSTEM ---
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    log_error "ERR001: This script must run as Administrator or SYSTEM"
    log_error "ERR001: Right-click PowerShell > 'Run as administrator'"
    exit 1
}
log_success "Running as Administrator"

# --- Prerequisite: Windows version ---
$build = [System.Environment]::OSVersion.Version.Build
if ($build -lt $MIN_BUILD) {
    log_error "ERR002: Windows build $build is too old (minimum: $MIN_BUILD)"
    log_error "ERR002: WSL2 requires Windows 10 version 2004 or later"
    exit 1
}
log_success "Windows build $build meets minimum ($MIN_BUILD)"

# --- Prerequisite: Virtualization ---
try {
    $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
    if (-not $computerInfo.HypervisorPresent) {
        log_error "ERR003: Virtualization is not enabled"
        log_error "ERR003: Enable Intel VT-x or AMD-V in BIOS/UEFI settings"
        exit 1
    }
    log_success "Virtualization is enabled"
}
catch {
    log_warning "Could not check virtualization status: $_"
    log_warning "Continuing anyway - DISM will fail if virtualization is missing"
}

# --- Check current feature state ---
$wslState = Get-FeatureState $WSL_FEATURE
$vmState  = Get-FeatureState $VM_FEATURE
log_info "Current state: $WSL_FEATURE = $wslState"
log_info "Current state: $VM_FEATURE = $vmState"

# Already fully enabled - nothing to do
if ($wslState -eq "Enabled" -and $vmState -eq "Enabled") {
    log_success "Both features are already enabled"
    log_success "$SCRIPT_NAME completed - no action needed"
    exit 0
}

# EnablePending - install already ran, just needs reboot
if ($wslState -eq "EnablePending" -or $vmState -eq "EnablePending") {
    log_warning "Features are pending reboot"
    log_warning "$WSL_FEATURE = $wslState"
    log_warning "$VM_FEATURE = $vmState"
    log_info "$SCRIPT_NAME completed - reboot required"
    exit 3010
}

# --- Enable features ---
$needsReboot = $false

Enable-Feature $WSL_FEATURE
if ($LASTEXITCODE -eq 3010) { $needsReboot = $true }

Enable-Feature $VM_FEATURE
if ($LASTEXITCODE -eq 3010) { $needsReboot = $true }

# --- Verify features are now enabled (or pending) ---
$wslStateAfter = Get-FeatureState $WSL_FEATURE
$vmStateAfter  = Get-FeatureState $VM_FEATURE
log_info "After install: $WSL_FEATURE = $wslStateAfter"
log_info "After install: $VM_FEATURE = $vmStateAfter"

$validStates = @("Enabled", "EnablePending")
if ($wslStateAfter -notin $validStates) {
    log_error "ERR007: $WSL_FEATURE is in unexpected state: $wslStateAfter"
    exit 1
}
if ($vmStateAfter -notin $validStates) {
    log_error "ERR007: $VM_FEATURE is in unexpected state: $vmStateAfter"
    exit 1
}

log_success "Both features verified"

# --- Exit with correct code ---
if ($needsReboot -or $wslStateAfter -eq "EnablePending" -or $vmStateAfter -eq "EnablePending") {
    log_info "$SCRIPT_NAME completed - reboot required"
    exit 3010
}

log_success "$SCRIPT_NAME completed"
exit 0
