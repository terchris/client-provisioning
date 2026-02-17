#!/usr/bin/env pwsh
# File: devcontainer-init.ps1
#
# Usage:
#   devcontainer-init.ps1 [-Help] [FolderPath]
#
# Purpose:
#   Initialize a project folder with .devcontainer/ configuration for devcontainer-toolbox.
#
# Author: Ops Team
# Created: February 2026
#
# Downloads devcontainer.json from GitHub and creates .devcontainer/ in the target folder.
# Does not require Docker -- this only downloads a config file.
# Do not use em dashes or non-ASCII characters (Windows PowerShell 5.1 compatibility).

[CmdletBinding()]
param(
    [switch]$Help,
    [Parameter(Position=0)]
    [string]$FolderPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

#------------------------------------------------------------------------------
# SCRIPT METADATA
#------------------------------------------------------------------------------

$SCRIPT_ID          = "devcontainer-init"
$SCRIPT_NAME        = "Devcontainer Initialization"
$SCRIPT_VER         = "0.2.2"
$SCRIPT_DESCRIPTION = "Initialize a project folder with .devcontainer/ configuration for devcontainer-toolbox."
$SCRIPT_CATEGORY    = "DEVOPS"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$REPO                  = "terchris/devcontainer-toolbox"
$DEVCONTAINER_JSON_URL = "https://raw.githubusercontent.com/$REPO/main/devcontainer-user-template.json"

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
    Write-Host "  $SCRIPT_ID [-Help] [FolderPath]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help         Show this help message"
    Write-Host "  [FolderPath]  Target folder to initialize (default: current directory)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  devcontainer-init                    # Initialize current directory (with prompt)"
    Write-Host "  devcontainer-init C:\repos\myproject # Initialize specific folder"
    Write-Host ""
    Write-Host "Prerequisites:"
    Write-Host "  Internet access (downloads devcontainer.json from GitHub)"
    Write-Host ""
    Write-Host "Next Steps (after successful initialization):"
    Write-Host "  1. Open the folder in VS Code"
    Write-Host "  2. Click 'Reopen in Container' when prompted"
    Write-Host "  3. Inside the container, run: dev-help"
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

function Backup-ExistingDevcontainer {
    param([string]$TargetDir)

    $devcontainerDir = Join-Path $TargetDir ".devcontainer"
    if (-not (Test-Path $devcontainerDir)) {
        return
    }

    log_info "Found existing .devcontainer/ directory"

    $backupDir = Join-Path $TargetDir ".devcontainer.backup"
    if (Test-Path $backupDir) {
        log_error "ERR003: Backup already exists at .devcontainer.backup/"
        log_info "Please resolve this manually:"
        log_info "  Remove or rename .devcontainer.backup/ if no longer needed"
        log_info "  Or remove .devcontainer/ before running this script again"
        exit 1
    }

    log_info "Creating backup at .devcontainer.backup/..."
    try {
        Move-Item -Path $devcontainerDir -Destination $backupDir
    }
    catch {
        log_error "ERR004: Failed to back up .devcontainer/: $_"
        exit 1
    }

    if (-not (Test-Path $backupDir)) {
        log_error "ERR005: Backup directory not found after move"
        exit 1
    }
    log_success "Backup created"
}

function New-DevcontainerJson {
    param([string]$TargetDir)

    log_info "Downloading devcontainer.json..."
    log_info "  URL: $DEVCONTAINER_JSON_URL"

    # PowerShell 5.1 may default to TLS 1.0 which GitHub rejects
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Check that GitHub is reachable before attempting download
    try {
        $null = Invoke-WebRequest -Uri "https://raw.githubusercontent.com" -UseBasicParsing -TimeoutSec 10
    }
    catch {
        log_error "ERR006: Cannot reach raw.githubusercontent.com"
        log_error "ERR006: $_"
        log_error "ERR006: Check your internet connection"
        exit 1
    }

    $devcontainerDir = Join-Path $TargetDir ".devcontainer"
    New-Item -ItemType Directory -Path $devcontainerDir -Force | Out-Null

    if (-not (Test-Path $devcontainerDir)) {
        log_error "ERR007: Failed to create directory $devcontainerDir"
        exit 1
    }

    $jsonPath = Join-Path $devcontainerDir "devcontainer.json"

    try {
        Invoke-WebRequest -Uri $DEVCONTAINER_JSON_URL -OutFile $jsonPath -UseBasicParsing -TimeoutSec 30
    }
    catch {
        log_error "ERR008: Failed to download devcontainer.json"
        log_error "ERR008: URL: $DEVCONTAINER_JSON_URL"
        log_error "ERR008: $_"
        if (Test-Path $jsonPath) { Remove-Item $jsonPath -Force -ErrorAction SilentlyContinue }
        exit 1
    }

    if (-not (Test-Path $jsonPath)) {
        log_error "ERR009: Download completed but devcontainer.json not found"
        exit 1
    }

    # Verify file is not empty
    $fileSize = (Get-Item $jsonPath).Length
    if ($fileSize -eq 0) {
        log_error "ERR010: Downloaded file is empty (0 bytes)"
        Remove-Item $jsonPath -Force -ErrorAction SilentlyContinue
        exit 1
    }

    log_success "Created .devcontainer/devcontainer.json ($fileSize bytes)"
}

function Ensure-VscodeExtensionsJson {
    param([string]$TargetDir)

    $extFile = Join-Path $TargetDir ".vscode\extensions.json"
    $extId = "ms-vscode-remote.remote-containers"

    log_info "Ensuring .vscode/extensions.json recommends Dev Containers extension..."

    if (Test-Path $extFile) {
        $json = Get-Content $extFile -Raw | ConvertFrom-Json
        if (-not $json.recommendations) {
            $json | Add-Member -NotePropertyName recommendations -NotePropertyValue @($extId)
        } elseif ($json.recommendations -notcontains $extId) {
            $json.recommendations += $extId
        } else {
            log_success "Dev Containers extension already in .vscode/extensions.json"
            return
        }
    } else {
        New-Item -ItemType Directory -Path (Join-Path $TargetDir ".vscode") -Force | Out-Null
        $json = [PSCustomObject]@{ recommendations = @($extId) }
    }

    $json | ConvertTo-Json -Depth 10 | Set-Content $extFile -Encoding UTF8
    log_success "Created .vscode/extensions.json with Dev Containers extension recommendation"
}

function Show-NextSteps {
    param([string]$TargetDir)

    log_success "devcontainer configuration created!"
    log_info "Next steps:"
    log_info "  1. Open this folder in VS Code"
    log_info "  2. Click 'Reopen in Container' when prompted"
    log_info "     (or run: Ctrl+Shift+P > 'Dev Containers: Reopen in Container')"
    log_info "  3. Inside the container, run: dev-help"

    $backupDir = Join-Path $TargetDir ".devcontainer.backup"
    if (Test-Path $backupDir) {
        log_warning "Your previous .devcontainer/ was backed up to .devcontainer.backup/"
    }
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

# Determine target directory
$argProvided = $false
if ($FolderPath) {
    $argProvided = $true
    $targetDir = $FolderPath
} else {
    $targetDir = Get-Location
}

# Resolve to full path
$targetDir = [System.IO.Path]::GetFullPath($targetDir.ToString())

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

log_start

# --- Validate target directory ---
if ($argProvided) {
    if (-not (Test-Path $targetDir)) {
        log_error "ERR001: Target path does not exist: $targetDir"
        exit 1
    }
    if (-not (Test-Path $targetDir -PathType Container)) {
        log_error "ERR002: Target exists and is not a directory: $targetDir"
        exit 1
    }
} else {
    # No path provided: confirm with user
    $reply = Read-Host "[$( log_time )] INFO  Devcontainer toolbox will be initiated in: $targetDir`nProceed? [y/n]"
    if ($reply -ne 'y' -and $reply -ne 'Y') {
        log_info "Aborted by user."
        exit 1
    }
}

log_info "Using target directory: $targetDir"

# --- Backup existing .devcontainer/ ---
Backup-ExistingDevcontainer -TargetDir $targetDir

# --- Create .devcontainer/devcontainer.json ---
New-DevcontainerJson -TargetDir $targetDir

# --- Ensure .vscode/extensions.json recommends Dev Containers ---
Ensure-VscodeExtensionsJson -TargetDir $targetDir

# --- Print next steps ---
Show-NextSteps -TargetDir $targetDir

exit 0
