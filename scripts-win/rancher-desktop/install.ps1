#!/usr/bin/env pwsh
# File: install.ps1
#
# Usage:
#   install.ps1 [-Help]
#
# Purpose:
#   Downloads and installs Rancher Desktop on Windows via MSI (per-user).
#
# Author: Ops Team
# Created: February 2026
#
# Intune runs this in User context. Per-user install (MSIINSTALLPERUSER=1).
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

$SCRIPT_ID          = "rancher-desktop-install"
$SCRIPT_NAME        = "Rancher Desktop Installer"
$SCRIPT_VER         = "0.2.0"
$SCRIPT_DESCRIPTION = "Downloads and installs Rancher Desktop on Windows via MSI (per-user)."
$SCRIPT_CATEGORY    = "DEPLOY"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

$RANCHER_VERSION      = "1.22.0"
$RANCHER_BASE_URL     = "https://github.com/rancher-sandbox/rancher-desktop/releases/download"
$RANCHER_MSI_NAME     = "Rancher.Desktop.Setup.$RANCHER_VERSION.msi"
$RANCHER_DOWNLOAD_URL = "$RANCHER_BASE_URL/v$RANCHER_VERSION/$RANCHER_MSI_NAME"
$RANCHER_EXE          = "Rancher Desktop.exe"

# The MSI installs to different paths depending on scope:
#   Per-user:    %LOCALAPPDATA%\Programs\Rancher Desktop\
#   Per-machine: %ProgramFiles%\Rancher Desktop\
# We check both because the actual path depends on elevation context.
$RANCHER_INSTALL_PATHS = @(
    "$env:LOCALAPPDATA\Programs\Rancher Desktop",
    "$env:ProgramFiles\Rancher Desktop"
)

$WSL_FEATURE          = "Microsoft-Windows-Subsystem-Linux"
$VM_FEATURE           = "VirtualMachinePlatform"
$WSL_VERSION_TIMEOUT  = 10

$GITHUB_TEST_URL      = "https://github.com"
$MIN_DISK_SPACE_GB    = 2

$DOWNLOAD_TIMEOUT_SEC  = 1800
$DOWNLOAD_PROGRESS_SEC = 10
$DOWNLOAD_MIN_SIZE     = 100MB

# Deployment profile -- written to HKLM registry (requires admin).
# "defaults" profile applies on first launch only. The user can change
# settings afterwards (including enabling Kubernetes).
$PROFILE_REG_PATH       = "HKLM:\SOFTWARE\Policies\Rancher Desktop\defaults"
$PROFILE_VERSION        = 17
$PROFILE_CONTAINER_ENGINE = "moby"
$PROFILE_KUBERNETES     = $false

# Verification -- launch, backend readiness, Docker hello-world, shutdown.
# These run after install (and on "already installed") so Intune retries on failure.
$RANCHER_PROCESS       = "Rancher Desktop"
$RDCTL_RELATIVE_PATH   = "resources\resources\win32\bin\rdctl.exe"
$DOCKER_RELATIVE_PATH  = "resources\resources\win32\bin\docker.exe"
$RDCTL_READY_TIMEOUT   = 120
$RDCTL_POLL_SECONDS    = 3
$LAUNCH_WAIT_SECONDS   = 15

# User data paths -- settings.json must be removed before first launch
# so the defaults profile takes effect. These are leftover from previous installs.
$RANCHER_USER_DATA_PATHS = @(
    "$env:APPDATA\rancher-desktop",
    "$env:LOCALAPPDATA\rancher-desktop"
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
    Write-Host "  WSL2 must be installed (features enabled + kernel)"
    Write-Host "  Internet access (downloads ~500 MB MSI)"
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

function Test-WslFeatures {
    # Check that both WSL2 Windows features are Enabled (not EnablePending or Disabled).
    # Uses Get-WindowsOptionalFeature which is safe (no interactive prompts).
    #
    # NOTE: On Windows 11+ with WSL installed via Microsoft Store ('wsl --install'),
    # the Microsoft-Windows-Subsystem-Linux optional feature may show as Disabled
    # even though WSL2 is fully functional. We detect this case by looking for
    # wsl.exe and defer to Test-WslKernel for the definitive check.
    try {
        $wsl = Get-WindowsOptionalFeature -Online -FeatureName $WSL_FEATURE
        $vmp = Get-WindowsOptionalFeature -Online -FeatureName $VM_FEATURE
    }
    catch {
        log_error "ERR001: Cannot check WSL2 features: $_"
        log_error "ERR001: This may require running as Administrator"
        return $false
    }

    $wslState = $wsl.State.ToString()
    $vmpState = $vmp.State.ToString()

    if (($wslState -eq "Enabled") -and ($vmpState -eq "Enabled")) {
        log_success "WSL2 features: $WSL_FEATURE=Enabled, $VM_FEATURE=Enabled"
        return $true
    }

    # One or both features are not Enabled. On Windows 11+ with WSL installed
    # via Microsoft Store, the optional feature stays Disabled but wsl.exe is
    # present and fully functional. Detect this and defer to Test-WslKernel.
    $wslExe = Join-Path $env:SystemRoot "system32\wsl.exe"
    if (Test-Path $wslExe) {
        if ($wslState -ne "Enabled") {
            log_warning "$WSL_FEATURE is $wslState -- this is expected when WSL is installed via Microsoft Store"
        }
        if ($vmpState -ne "Enabled") {
            log_warning "$VM_FEATURE is $vmpState -- may be managed by the Store WSL install"
        }
        log_warning "Optional feature check inconclusive -- wsl.exe found, deferring to kernel check"
        return $true
    }

    # wsl.exe not found -- WSL is genuinely not installed
    if ($wslState -ne "Enabled") {
        log_error "ERR001: $WSL_FEATURE is $wslState (must be Enabled)"
        log_error "ERR001: Deploy the WSL2 package first, then reboot"
    }
    if ($vmpState -ne "Enabled") {
        log_error "ERR001: $VM_FEATURE is $vmpState (must be Enabled)"
        log_error "ERR001: Deploy the WSL2 package first, then reboot"
    }
    return $false
}

function Test-WslKernel {
    # Verify the WSL kernel is installed and wsl.exe responds.
    # IMPORTANT: wsl commands hang with an interactive "Press any key to install..."
    # prompt if the kernel is not present. We run wsl.exe --version as a separate
    # process with a timeout to avoid blocking forever.
    $wslExe = Join-Path $env:SystemRoot "system32\wsl.exe"
    if (-not (Test-Path $wslExe)) {
        log_error "ERR001: wsl.exe not found at $wslExe"
        return $false
    }

    log_info "Checking WSL kernel (timeout: $WSL_VERSION_TIMEOUT seconds)..."

    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $wslExe
        $pinfo.Arguments = "--version"
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
        # wsl.exe outputs UTF-16LE
        $pinfo.StandardOutputEncoding = [System.Text.Encoding]::Unicode

        $proc = [System.Diagnostics.Process]::Start($pinfo)
        # Read stdout before WaitForExit to avoid deadlock on large output
        $stdout = $proc.StandardOutput.ReadToEnd()
        $exited = $proc.WaitForExit($WSL_VERSION_TIMEOUT * 1000)

        if (-not $exited) {
            # Process hung -- kernel is not installed, wsl is showing interactive prompt
            $proc.Kill()
            log_error "ERR001: wsl --version timed out after $WSL_VERSION_TIMEOUT seconds"
            log_error "ERR001: The WSL kernel is likely not installed"
            log_error "ERR001: Run 'wsl --install' interactively or deploy the WSL kernel package"
            return $false
        }

        $exitCode = $proc.ExitCode

        if ($exitCode -ne 0) {
            log_error "ERR001: wsl --version exited with code $exitCode"
            log_error "ERR001: The WSL kernel may not be installed"
            return $false
        }

        # Show the first line of version info
        $firstLine = ($stdout -split "`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1)
        if ($firstLine) {
            log_success "WSL kernel: $($firstLine.Trim())"
        } else {
            log_success "WSL kernel: wsl --version returned exit code 0"
        }
        return $true
    }
    catch {
        log_error "ERR001: Failed to run wsl --version: $_"
        return $false
    }
}

function Test-InternetAccess {
    # Check that GitHub is reachable before attempting the ~500 MB download.
    # Fails early with a clear error instead of a confusing download timeout.
    try {
        $response = Invoke-WebRequest -Uri $GITHUB_TEST_URL -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            log_success "Internet access: github.com reachable"
            return $true
        } else {
            log_error "ERR001: github.com returned status $($response.StatusCode)"
            return $false
        }
    }
    catch {
        log_error "ERR001: Cannot reach github.com: $_"
        log_error "ERR001: Internet access is required to download the MSI"
        return $false
    }
}

function Test-DiskSpace {
    # Check that there is enough free space for the MSI download + install.
    try {
        $drive = Get-PSDrive -Name ($env:LOCALAPPDATA.Substring(0,1))
        $freeGB = [math]::Round($drive.Free / 1GB, 1)
        if ($freeGB -ge $MIN_DISK_SPACE_GB) {
            log_success "Disk space: $freeGB GB free (minimum: $MIN_DISK_SPACE_GB GB)"
            return $true
        } else {
            log_error "ERR001: Only $freeGB GB free, need at least $MIN_DISK_SPACE_GB GB"
            return $false
        }
    }
    catch {
        log_warning "Could not check disk space: $_"
        return $true  # Non-fatal -- proceed and let the download fail if needed
    }
}

function Get-RancherMsi {
    $msiPath = Join-Path $env:TEMP $RANCHER_MSI_NAME

    # Clean up leftover file from a previous failed run
    if (Test-Path $msiPath) {
        log_info "Removing leftover file from previous download attempt..."
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
    }

    log_info "Downloading Rancher Desktop v$RANCHER_VERSION..."
    log_info "URL: $RANCHER_DOWNLOAD_URL"
    log_info "Destination: $msiPath"

    # PowerShell 5.1 may default to TLS 1.0 which GitHub rejects
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # --- Connect and validate response ---
    $response = $null
    try {
        $request = [System.Net.HttpWebRequest]::Create($RANCHER_DOWNLOAD_URL)
        $request.Timeout = $DOWNLOAD_TIMEOUT_SEC * 1000
        $request.ReadWriteTimeout = $DOWNLOAD_TIMEOUT_SEC * 1000
        $request.UserAgent = "RancherDesktopInstaller/$SCRIPT_VER"
        $response = $request.GetResponse()
    }
    catch [System.Net.WebException] {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($statusCode -eq 404) {
            log_error "ERR002: Download URL returned 404 (not found)"
            log_error "ERR002: Version $RANCHER_VERSION may not exist"
            log_error "ERR002: URL: $RANCHER_DOWNLOAD_URL"
        } else {
            log_error "ERR002: Cannot reach download URL"
            log_error "ERR002: $_"
        }
        exit 1
    }
    catch {
        log_error "ERR002: Failed to start download"
        log_error "ERR002: $_"
        exit 1
    }

    # Check Content-Type -- GitHub serves MSIs as application/octet-stream.
    # If we get text/html, the URL is probably wrong (error page).
    $contentType = $response.ContentType
    if ($contentType -and $contentType -match 'text/html') {
        $response.Close()
        log_error "ERR002: URL returned HTML instead of a file (Content-Type: $contentType)"
        log_error "ERR002: Version $RANCHER_VERSION may not exist on GitHub"
        exit 1
    }

    $expectedSize = $response.ContentLength  # -1 if unknown
    if ($expectedSize -gt 0) {
        $expectedMB = [math]::Round($expectedSize / 1MB, 1)
        log_info "Expected file size: $expectedMB MB"
    }

    # --- Stream download with progress reporting ---
    # We use HttpWebRequest + manual streaming instead of Invoke-WebRequest because:
    # 1. Invoke-WebRequest progress bar on PS 5.1 is extremely slow (~10x slower)
    # 2. We need progress feedback for the human running USB tests
    # 3. We need control over timeouts and response validation
    $responseStream = $null
    $fileStream = $null
    $downloadFailed = $false
    $downloadError = $null

    try {
        $responseStream = $response.GetResponseStream()
        $fileStream = New-Object System.IO.FileStream($msiPath, [System.IO.FileMode]::Create)
        $buffer = New-Object byte[] 65536
        $totalRead = [long]0
        $lastReport = [DateTime]::Now
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        while ($true) {
            $bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -eq 0) { break }

            $fileStream.Write($buffer, 0, $bytesRead)
            $totalRead += $bytesRead

            # Report progress every N seconds
            if (([DateTime]::Now - $lastReport).TotalSeconds -ge $DOWNLOAD_PROGRESS_SEC) {
                $currentMB = [math]::Round($totalRead / 1MB, 1)
                if ($expectedSize -gt 0) {
                    $pct = [math]::Round(($totalRead / $expectedSize) * 100)
                    $totalMB = [math]::Round($expectedSize / 1MB, 1)
                    log_info "Downloading... $pct% ($currentMB / $totalMB MB)"
                } else {
                    log_info "Downloading... $currentMB MB"
                }
                $lastReport = [DateTime]::Now
            }

            # Check timeout
            if ($stopwatch.Elapsed.TotalSeconds -gt $DOWNLOAD_TIMEOUT_SEC) {
                throw "Download timed out after $DOWNLOAD_TIMEOUT_SEC seconds"
            }
        }

        $stopwatch.Stop()
    }
    catch {
        $downloadFailed = $true
        $downloadError = $_
    }
    finally {
        if ($fileStream) { try { $fileStream.Close() } catch {} }
        if ($responseStream) { try { $responseStream.Close() } catch {} }
        if ($response) { try { $response.Close() } catch {} }
    }

    if ($downloadFailed) {
        log_error "ERR002: Download failed during transfer"
        log_error "ERR002: $downloadError"
        if (Test-Path $msiPath) { Remove-Item $msiPath -Force -ErrorAction SilentlyContinue }
        exit 1
    }

    # --- Verify download ---
    if (-not (Test-Path $msiPath)) {
        log_error "ERR003: Download completed but file not found at $msiPath"
        exit 1
    }

    $fileSize = (Get-Item $msiPath).Length

    if ($fileSize -eq 0) {
        log_error "ERR003: Downloaded file is empty (0 bytes)"
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # Check for truncated download (compare to Content-Length from server)
    if ($expectedSize -gt 0 -and $fileSize -ne $expectedSize) {
        $fileSizeMB = [math]::Round($fileSize / 1MB, 1)
        $expectedMB = [math]::Round($expectedSize / 1MB, 1)
        log_error "ERR003: Download appears truncated: got $fileSizeMB MB, expected $expectedMB MB"
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # Sanity check: MSI should be well over 100 MB. A small file is likely
    # an HTML error page that GitHub returned instead of the binary.
    if ($fileSize -lt $DOWNLOAD_MIN_SIZE) {
        $fileSizeMB = [math]::Round($fileSize / 1MB, 1)
        log_error "ERR003: Downloaded file is suspiciously small ($fileSizeMB MB)"
        log_error "ERR003: Expected ~500 MB MSI. File may be an error page."
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
        exit 1
    }

    $fileSizeMB = [math]::Round($fileSize / 1MB, 1)
    $elapsedSec = [math]::Round($stopwatch.Elapsed.TotalSeconds)
    log_success "Downloaded $RANCHER_MSI_NAME ($fileSizeMB MB in ${elapsedSec}s)"

    return $msiPath
}

function Install-RancherMsi {
    param([string]$MsiPath)

    log_info "Installing Rancher Desktop v$RANCHER_VERSION (per-user, silent)..."

    $msiArgs = "/i `"$MsiPath`" /qn /norestart MSIINSTALLPERUSER=1 WSLINSTALLED=1 /l*v `"$env:TEMP\RancherDesktop-install.log`""
    log_info "msiexec $msiArgs"

    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

    $exitCode = $process.ExitCode
    if ($exitCode -eq 0) {
        log_success "MSI install completed (exit code 0)"
    }
    elseif ($exitCode -eq 3010) {
        log_success "MSI install completed (exit code 3010 -- reboot may be needed)"
    }
    else {
        log_error "ERR004: MSI install failed with exit code $exitCode"
        exit 1
    }
}

function Deploy-Profile {
    # Write defaults deployment profile to HKLM registry.
    # Requires admin rights. If not admin, logs a warning and skips.
    # This sets sensible defaults so the first-run wizard does not appear.
    # The user can change these settings afterwards via the GUI.

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        log_warning "Not running as Administrator -- skipping deployment profile"
        log_warning "Profile must be deployed separately (Intune SYSTEM script or manual)"
        return
    }

    log_info "Deploying defaults profile to registry..."
    log_info "  Container engine: $PROFILE_CONTAINER_ENGINE"
    log_info "  Kubernetes: $PROFILE_KUBERNETES"

    try {
        # Create registry key hierarchy
        New-Item -Path "$PROFILE_REG_PATH\containerEngine" -Force | Out-Null
        New-Item -Path "$PROFILE_REG_PATH\kubernetes" -Force | Out-Null

        # version (required by Rancher Desktop profile schema)
        Set-ItemProperty -Path $PROFILE_REG_PATH -Name "version" -Value $PROFILE_VERSION -Type DWord

        # containerEngine.name
        Set-ItemProperty -Path "$PROFILE_REG_PATH\containerEngine" -Name "name" -Value $PROFILE_CONTAINER_ENGINE -Type String

        # kubernetes.enabled
        $k8sValue = if ($PROFILE_KUBERNETES) { 1 } else { 0 }
        Set-ItemProperty -Path "$PROFILE_REG_PATH\kubernetes" -Name "enabled" -Value $k8sValue -Type DWord

        # NOTE: virtualMachine.type is NOT settable via deployment profiles.
        # Rancher Desktop auto-detects WSL2 on Windows. The settings.json cleanup
        # (earlier in this script) ensures stale values like "qemu" are removed.

        log_success "Deployment profile written to $PROFILE_REG_PATH"
    }
    catch {
        log_error "ERR006: Failed to write deployment profile: $_"
        log_error "ERR006: Rancher Desktop will work but may show first-run wizard"
        # Non-fatal -- install succeeded, profile is optional
    }
}

function Wait-ForBackendReady {
    param([string]$InstallDir)

    # Poll rdctl api /v1/backend_state until STARTED or DISABLED.
    # DISABLED is the normal state when Kubernetes is off -- Docker still works.
    # Returns $true/$false and sets $script:vmState.
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
            log_error "ERR007: Rancher Desktop process not found after $LAUNCH_WAIT_SECONDS seconds"
        }
        return ($null -ne $proc)
    }

    log_info "Found rdctl at $rdctlPath"
    log_info "Waiting for backend to reach ready state (timeout: $RDCTL_READY_TIMEOUT seconds)..."

    $elapsed = 0
    $processFound = $false
    while ($elapsed -lt $RDCTL_READY_TIMEOUT) {
        Start-Sleep -Seconds $RDCTL_POLL_SECONDS
        $elapsed += $RDCTL_POLL_SECONDS

        # Check process appeared
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

        # Check backend state via rdctl
        try {
            $stateJson = & $rdctlPath api /v1/backend_state 2>$null
            if ($stateJson) {
                $state = $stateJson | ConvertFrom-Json
                $script:vmState = $state.vmState
                log_info "Backend state: $($script:vmState) ($elapsed/$RDCTL_READY_TIMEOUT sec)"
                if ($script:vmState -eq "STARTED" -or $script:vmState -eq "DISABLED") {
                    # DISABLED is the normal state when Kubernetes is off.
                    # The container engine (moby/Docker) still runs via WSL2.
                    log_success "Backend is ready (state: $($script:vmState))"
                    return $true
                }
                if ($script:vmState -eq "ERROR") {
                    log_error "ERR007: Backend reported ERROR state"
                    return $false
                }
            }
        }
        catch {
            log_info "Waiting for rdctl... ($elapsed/$RDCTL_READY_TIMEOUT sec)"
        }
    }

    if (-not $processFound) {
        log_error "ERR007: Rancher Desktop process not found within $RDCTL_READY_TIMEOUT seconds"
    } else {
        log_error "ERR007: Backend did not reach ready state within $RDCTL_READY_TIMEOUT seconds"
    }
    return $false
}

function Test-DockerHelloWorld {
    param([string]$InstallDir)

    # Run docker hello-world to verify Docker is working.
    # Returns $true/$false.
    #
    # NOTE: Docker prints informational messages to stderr before pulling an image
    # (e.g. "Unable to find image 'hello-world:latest' locally"). With the global
    # $ErrorActionPreference = 'Stop' and 2>&1, these stderr lines are wrapped as
    # ErrorRecord objects in the pipeline and trigger a terminating error before
    # Docker even attempts the pull. Override locally -- function scope in
    # PowerShell is isolated, so the global 'Stop' is restored on return.
    $ErrorActionPreference = 'Continue'

    $dockerPath = Join-Path $InstallDir $DOCKER_RELATIVE_PATH
    if (-not (Test-Path $dockerPath)) {
        log_warning "docker.exe not found at $dockerPath -- skipping hello-world"
        return $false
    }

    # Use a clean temporary Docker config to avoid interference from leftover
    # config.json entries (e.g. "credsStore": "wincred" from a previous Docker
    # Desktop install). The hello-world image is public and needs no credentials.
    $tempDockerConfig = Join-Path $env:TEMP "rancher-docker-test"
    New-Item -Path $tempDockerConfig -ItemType Directory -Force | Out-Null

    log_info "Testing Docker: $dockerPath --config `"$tempDockerConfig`" run --rm hello-world"
    try {
        $dockerLines = [System.Collections.ArrayList]::new()
        & $dockerPath --config $tempDockerConfig run --rm hello-world 2>&1 | ForEach-Object {
            Write-Host $_
            $dockerLines.Add([string]$_) | Out-Null
        }
        $dockerExit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 1 }
        if ($dockerExit -eq 0 -and ($dockerLines -join "`n") -match "Hello from Docker") {
            log_success "Docker hello-world passed"
            return $true
        } else {
            log_error "ERR008: Docker hello-world failed (exit code: $dockerExit)"
            return $false
        }
    }
    catch {
        log_error "ERR008: Docker hello-world error: $_"
        return $false
    }
    finally {
        Remove-Item $tempDockerConfig -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Stop-RancherDesktop {
    param([string]$InstallDir)

    # Clean shutdown: rdctl shutdown, then force-kill if needed.
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

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

log_start
log_info "  Version: $RANCHER_VERSION"
log_info "  Checking paths: $($RANCHER_INSTALL_PATHS -join ', ')"

# --- Check if already installed ---
$existingDir = Test-RancherInstalled
if ($existingDir) {
    log_info "Rancher Desktop is already installed at $existingDir"

    # Remove leftover settings so the defaults profile takes effect on next launch.
    # Without this, stale settings.json (e.g. virtualMachine.type=qemu from a
    # macOS-oriented config) overrides the registry defaults profile silently.
    foreach ($dataDir in $RANCHER_USER_DATA_PATHS) {
        $settingsFile = Join-Path $dataDir "settings.json"
        if (Test-Path $settingsFile) {
            log_info "Removing leftover settings: $settingsFile"
            Remove-Item $settingsFile -Force -ErrorAction SilentlyContinue
        }
    }

    log_info "Updating deployment profile and running verification..."
    Deploy-Profile

    # --- Verification (same as fresh install) ---
    $verifyFailed = $false

    # Stop any existing instances before launching
    $existing = Get-Process -Name $RANCHER_PROCESS -ErrorAction SilentlyContinue
    if ($existing) {
        log_info "Rancher Desktop is already running, stopping it first..."
        $existing | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }

    log_info "Launching Rancher Desktop for verification..."
    try {
        $exePath = Join-Path $existingDir $RANCHER_EXE
        Start-Process -FilePath $exePath
    }
    catch {
        log_error "ERR007: Failed to launch Rancher Desktop: $_"
        exit 1
    }

    $backendReady = Wait-ForBackendReady -InstallDir $existingDir
    if (-not $backendReady) { $verifyFailed = $true }

    if ($backendReady) {
        $dockerOk = Test-DockerHelloWorld -InstallDir $existingDir
        if (-not $dockerOk) { $verifyFailed = $true }
    }

    Stop-RancherDesktop -InstallDir $existingDir

    if ($verifyFailed) {
        log_error "Verification failed -- exiting with error so Intune retries"
        exit 1
    }

    log_success "Already installed and verified -- Rancher Desktop is working"
    exit 0
}

# --- Check prerequisites ---
log_info "Checking prerequisites..."

if (-not (Test-WslFeatures)) {
    log_error "WSL2 features are not ready. Cannot install Rancher Desktop."
    exit 1
}

if (-not (Test-WslKernel)) {
    log_error "WSL kernel is not ready. Cannot install Rancher Desktop."
    exit 1
}

if (-not (Test-InternetAccess)) {
    log_error "No internet access. Cannot download Rancher Desktop MSI."
    exit 1
}

if (-not (Test-DiskSpace)) {
    log_error "Not enough disk space. Cannot install Rancher Desktop."
    exit 1
}

Write-Host ""

# --- Download the MSI ---
$msiPath = Get-RancherMsi

# --- Install ---
Install-RancherMsi -MsiPath $msiPath

# --- Verify ---
$installedDir = Test-RancherInstalled
if (-not $installedDir) {
    log_error "ERR005: Rancher Desktop.exe not found after install"
    log_error "ERR005: Checked: $($RANCHER_INSTALL_PATHS -join ', ')"
    log_error "ERR005: Check MSI log at $env:TEMP\RancherDesktop-install.log"
    # Clean up MSI
    if (Test-Path $msiPath) { Remove-Item $msiPath -Force -ErrorAction SilentlyContinue }
    exit 1
}
log_success "Verified: Rancher Desktop.exe exists at $installedDir"

# --- Remove leftover settings from previous installs ---
# The defaults profile only takes effect when no settings.json exists.
# If a previous install left settings.json behind, remove it so the
# profile applies on first launch.
foreach ($dataDir in $RANCHER_USER_DATA_PATHS) {
    $settingsFile = Join-Path $dataDir "settings.json"
    if (Test-Path $settingsFile) {
        log_info "Removing leftover settings: $settingsFile"
        Remove-Item $settingsFile -Force -ErrorAction SilentlyContinue
    }
}

# --- Deploy profile ---
Deploy-Profile

# --- Clean up MSI ---
log_info "Cleaning up downloaded MSI..."
if (Test-Path $msiPath) { Remove-Item $msiPath -Force -ErrorAction SilentlyContinue }

Write-Host ""

# --- Launch and verify ---
log_info "Launching Rancher Desktop for verification..."
$verifyFailed = $false

try {
    $exePath = Join-Path $installedDir $RANCHER_EXE
    Start-Process -FilePath $exePath
}
catch {
    log_error "ERR007: Failed to launch Rancher Desktop: $_"
    exit 1
}

$backendReady = Wait-ForBackendReady -InstallDir $installedDir
if (-not $backendReady) { $verifyFailed = $true }

if ($backendReady) {
    $dockerOk = Test-DockerHelloWorld -InstallDir $installedDir
    if (-not $dockerOk) { $verifyFailed = $true }
}

Stop-RancherDesktop -InstallDir $installedDir

if ($verifyFailed) {
    log_error "Verification failed -- exiting with error so Intune retries"
    exit 1
}

log_success "$SCRIPT_NAME completed -- Rancher Desktop v$RANCHER_VERSION installed and verified"
exit 0
