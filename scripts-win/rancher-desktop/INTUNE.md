# Rancher Desktop -- Intune Portal Configuration

Settings for creating the Win32 app in the Intune portal.

---

## App Information

| Field | Value |
|-------|-------|
| Name | Rancher Desktop |
| Description | Installs Rancher Desktop for Windows. Downloads MSI from GitHub releases and installs per-user. Requires WSL2. |
| Publisher | IT Operations |
| Category | Developer Tools |

---

## Program

| Field | Value |
|-------|-------|
| Install command | `powershell.exe -ExecutionPolicy Bypass -File install.ps1` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -File uninstall.ps1` |
| Install behavior | **User** |
| Device restart behavior | No specific action |
| Return codes | 0 = Success |

**Important:** Install behavior must be **User**, not System. Rancher Desktop's MSI fails in SYSTEM context with error `0x80070643` ([GitHub #7356](https://github.com/rancher-sandbox/rancher-desktop/issues/7356)).

---

## Requirements

| Field | Value |
|-------|-------|
| Operating system architecture | 64-bit |
| Minimum operating system | Windows 10 2004 (build 19041) |

---

## Detection Rules

| Field | Value |
|-------|-------|
| Rules format | Use a custom detection script |
| Script file | `detect.ps1` |
| Run script as 32-bit process | No |
| Enforce script signature check | No |

The detection script checks for `Rancher Desktop.exe` in both the per-user path (`%LOCALAPPDATA%\Programs\Rancher Desktop\`) and the per-machine path (`%ProgramFiles%\Rancher Desktop\`). It is uploaded separately from the `.intunewin` package.

---

## Dependencies

| Dependency | Auto install |
|------------|-------------|
| WSL2 Features | Yes |

Rancher Desktop requires WSL2. The WSL2 Features package must be installed first. Intune handles this via the dependency chain -- it installs WSL2 before attempting Rancher Desktop.

---

## Assignments

| Field | Value |
|-------|-------|
| Required | Developer machines group |

Since install behavior is User, the install triggers when the user logs in and Intune checks in (every 8 hours). The user must be logged in for the install to run.

---

## Notes

- The install script includes full verification: after installing, it launches Rancher Desktop, polls `rdctl` for backend readiness, runs `docker run --rm hello-world`, and shuts down cleanly. If any verification step fails, the script exits 1 so Intune retries the install. This means Intune will keep retrying until Rancher Desktop is fully working (not just installed).
- The install script downloads the MSI at runtime (~500 MB from GitHub releases). This requires internet access on the endpoint.
- Expected install paths: `%LOCALAPPDATA%\Programs\Rancher Desktop\` (per-user) or `%ProgramFiles%\Rancher Desktop\` (per-machine). The MSI uses a custom WiX installer that may install to either location.
- The MSI is called with `MSIINSTALLPERUSER=1` (per-user) and `WSLINSTALLED=1` (skip WSL check). Note: `ALLUSERS=0` is undefined behavior per Microsoft documentation and was found to install to `%ProgramFiles%` instead of the per-user path.
- MSI verbose logging is enabled: install log written to `%TEMP%\RancherDesktop-install.log`.
- The `.intunewin` package is built with `build.ps1` in the devcontainer.
- The install script deploys a **defaults** profile to `HKLM\SOFTWARE\Policies\Rancher Desktop\defaults` (container engine: moby, Kubernetes: off). This requires admin rights -- when running in Intune User context without admin, the profile is skipped. Deploy it separately via an Intune script running as SYSTEM, or accept that users see the first-run wizard.
- To disable auto-updates, consider a **locked** profile instead ([GitHub #6377](https://github.com/rancher-sandbox/rancher-desktop/issues/6377)).
