#!/usr/bin/env pwsh
# File: check-environment.ps1
#
# Usage:
#   check-environment.ps1 [-Help]
#
# Purpose:
#   Gathers diagnostic information about a Windows PC to understand the
#   target environment before writing deployment scripts.
#
# Author: Ops Team
# Created: February 2026
#
# Run from USB: powershell -ExecutionPolicy Bypass -File "E:\diagnostics\check-environment.ps1"
# Output is saved to logs/environment.log in the same folder as this script.

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

$SCRIPT_ID          = "check-environment"
$SCRIPT_NAME        = "Windows Environment Diagnostic"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Gathers target environment info for deployment script development."
$SCRIPT_CATEGORY    = "DEVOPS"

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
    Write-Host "Output:"
    Write-Host "  logs/environment.log    Full diagnostic output"
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
# SETUP
#------------------------------------------------------------------------------

log_start

$ScriptDir = Split-Path -Parent $PSCommandPath
$LogDir = Join-Path $ScriptDir "logs"
$LogFile = Join-Path $LogDir "environment.log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Tee output to both console and log file
Start-Transcript -Path $LogFile -Force | Out-Null

#------------------------------------------------------------------------------
# HELPER
#------------------------------------------------------------------------------

function section {
    param([string]$title)
    Write-Host ""
    Write-Host "================================================================"
    Write-Host "  $title"
    Write-Host "================================================================"
    Write-Host ""
}

function safe_run {
    param([string]$label, [scriptblock]$cmd)
    try {
        $result = & $cmd 2>&1
        if ($null -ne $result) {
            Write-Host "${label}: $result"
        } else {
            Write-Host "${label}: (no output)"
        }
    }
    catch {
        Write-Host "${label}: ERROR - $_"
    }
}

#------------------------------------------------------------------------------
# DIAGNOSTICS
#------------------------------------------------------------------------------

section "Windows Environment Diagnostic"
log_info "Script: $SCRIPT_ID v$SCRIPT_VER"
log_info "Date: $(Get-Date)"
log_info "Run by: $env:USERNAME"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator"
)
if (-not $isAdmin) {
    log_warning "NOT running as Administrator - some checks will be incomplete"
    log_warning "Re-run with: powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    log_warning "from an Administrator PowerShell prompt (Win+X > Terminal (Admin))"
}
Write-Host ""

# --- SYSTEM INFO ---

section "System Information"

safe_run "Computer name" { $env:COMPUTERNAME }
safe_run "OS" { (Get-CimInstance Win32_OperatingSystem).Caption }
safe_run "OS version" { (Get-CimInstance Win32_OperatingSystem).Version }
safe_run "OS build" { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion }
safe_run "Architecture" { $env:PROCESSOR_ARCHITECTURE }
safe_run "CPU" { (Get-CimInstance Win32_Processor).Name }
safe_run "RAM (GB)" { [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1) }
safe_run "System type" { (Get-CimInstance Win32_ComputerSystem).SystemType }

# --- DISK ---

section "Disk Space"

Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $free = [math]::Round($_.FreeSpace / 1GB, 1)
    $total = [math]::Round($_.Size / 1GB, 1)
    Write-Host "$($_.DeviceID) $free GB free / $total GB total"
}

# --- VIRTUALIZATION ---

section "Virtualization Support"

try {
    $hyperv = systeminfo 2>&1 | Select-String "Hyper-V"
    if ($hyperv) {
        $hyperv | ForEach-Object { Write-Host $_.Line.Trim() }
    } else {
        Write-Host "No Hyper-V information found in systeminfo"
    }
}
catch {
    Write-Host "Could not run systeminfo: $_"
}

# --- POWERSHELL ---

section "PowerShell"

safe_run "PowerShell version" { $PSVersionTable.PSVersion.ToString() }
safe_run "PowerShell edition" { $PSVersionTable.PSEdition }
safe_run "Execution policy (CurrentUser)" { Get-ExecutionPolicy -Scope CurrentUser }
safe_run "Execution policy (LocalMachine)" { Get-ExecutionPolicy -Scope LocalMachine }
safe_run "Execution policy (effective)" { Get-ExecutionPolicy }

# --- WSL ---

section "WSL Status"

$wslExe = "$env:SystemRoot\System32\wsl.exe"
safe_run "wsl.exe exists" { Test-Path $wslExe }

try {
    $wslVersion = wsl --version 2>&1
    Write-Host "wsl --version output:"
    $wslVersion | ForEach-Object { Write-Host "  $_" }
}
catch {
    Write-Host "wsl --version: not available or error"
}

Write-Host ""

try {
    $wslList = wsl --list --verbose 2>&1
    Write-Host "wsl --list --verbose output:"
    $wslList | ForEach-Object { Write-Host "  $_" }
}
catch {
    Write-Host "wsl --list: not available or error"
}

Write-Host ""
Write-Host "Windows features:"

try {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    Write-Host "  Microsoft-Windows-Subsystem-Linux: $($wslFeature.State)"
}
catch {
    Write-Host "  Microsoft-Windows-Subsystem-Linux: ERROR - $_ (may need Administrator)"
}

try {
    $vmpFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
    Write-Host "  VirtualMachinePlatform: $($vmpFeature.State)"
}
catch {
    Write-Host "  VirtualMachinePlatform: ERROR - $_ (may need Administrator)"
}

# --- INSTALLED SOFTWARE ---

section "Installed Developer Tools"

# Rancher Desktop
$rdPaths = @(
    "$env:LOCALAPPDATA\Programs\Rancher Desktop\Rancher Desktop.exe",
    "C:\Program Files\Rancher Desktop\Rancher Desktop.exe"
)
$rdFound = $false
foreach ($p in $rdPaths) {
    if (Test-Path $p) {
        Write-Host "Rancher Desktop: INSTALLED at $p"
        try {
            $rdVer = (Get-Item $p).VersionInfo.ProductVersion
            Write-Host "  Version: $rdVer"
        } catch { Write-Host "  Version: unknown" }
        $rdFound = $true
        break
    }
}
if (-not $rdFound) {
    Write-Host "Rancher Desktop: NOT INSTALLED"
}

# Docker
safe_run "docker" {
    $d = Get-Command docker -ErrorAction SilentlyContinue
    if ($d) { "INSTALLED at $($d.Source)" } else { "NOT INSTALLED" }
}

# Git
safe_run "git" {
    $g = Get-Command git -ErrorAction SilentlyContinue
    if ($g) {
        $ver = git --version 2>&1
        "INSTALLED at $($g.Source) ($ver)"
    } else { "NOT INSTALLED" }
}

# VS Code
safe_run "VS Code" {
    $c = Get-Command code -ErrorAction SilentlyContinue
    if ($c) {
        $ver = code --version 2>&1 | Select-Object -First 1
        "INSTALLED at $($c.Source) (v$ver)"
    } else { "NOT INSTALLED" }
}

# Windows Terminal
safe_run "Windows Terminal" {
    $wt = Get-Command wt -ErrorAction SilentlyContinue
    if ($wt) { "INSTALLED at $($wt.Source)" } else { "NOT INSTALLED" }
}

# winget
safe_run "winget" {
    $w = Get-Command winget -ErrorAction SilentlyContinue
    if ($w) {
        $ver = winget --version 2>&1
        "INSTALLED ($ver)"
    } else { "NOT INSTALLED" }
}

# --- INTUNE / MDM ---

section "Intune / MDM Enrollment"

try {
    $mdm = Get-CimInstance -Namespace "root/cimv2/mdm/dmmap" -ClassName "MDM_DevDetail_Ext01" -ErrorAction SilentlyContinue
    if ($mdm) {
        Write-Host "MDM enrolled: YES"
        safe_run "Device ID" { $mdm.DeviceID }
    } else {
        Write-Host "MDM enrolled: Could not determine (WMI namespace may require SYSTEM)"
    }
}
catch {
    Write-Host "MDM enrolled: Could not determine ($_)"
}

# Alternative check via registry
try {
    $enrollments = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments" -ErrorAction SilentlyContinue |
        Where-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            $null -ne $props -and $props.PSObject.Properties.Name -contains 'ProviderID' -and $props.ProviderID -eq "MS DM Server"
        }
    if ($enrollments) {
        Write-Host "Intune enrollment found in registry: YES"
    } else {
        Write-Host "Intune enrollment found in registry: Not found (may need Administrator)"
    }
}
catch {
    Write-Host "Intune registry check: ERROR - $_"
}

# --- NETWORK ---

section "Network Connectivity"

$urls = @(
    @{ Name = "GitHub releases"; URL = "https://github.com" },
    @{ Name = "Docker Hub"; URL = "https://hub.docker.com" },
    @{ Name = "Microsoft CDN"; URL = "https://packages.microsoft.com" },
    @{ Name = "VS Code CDN"; URL = "https://update.code.visualstudio.com" }
)

foreach ($u in $urls) {
    try {
        $response = Invoke-WebRequest -Uri $u.URL -UseBasicParsing -TimeoutSec 5 -Method Head
        Write-Host "$($u.Name) ($($u.URL)): OK ($($response.StatusCode))"
    }
    catch {
        Write-Host "$($u.Name) ($($u.URL)): FAILED ($_)"
    }
}

# --- USER CONTEXT ---

section "User Context"

safe_run "Current user" { "$env:USERDOMAIN\$env:USERNAME" }
safe_run "Is Administrator" {
    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator"
    )
}
safe_run "User profile" { $env:USERPROFILE }
safe_run "LOCALAPPDATA" { $env:LOCALAPPDATA }

# --- SUMMARY ---

section "Done"

log_info "Diagnostic complete."
log_info "Log saved to: $LogFile"
log_info "Bring the USB back so Claude Code can read the log."

Stop-Transcript | Out-Null
