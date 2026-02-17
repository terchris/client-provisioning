# Rancher Desktop -- Windows Intune Package

Deploys Rancher Desktop on Windows via Intune as a Win32 app.

## What it does

- Downloads the Rancher Desktop MSI from GitHub releases
- Installs silently in per-user mode (`MSIINSTALLPERUSER=1`)
- Skips built-in WSL check (`WSLINSTALLED=1`) -- WSL2 is deployed separately
- Deploys a defaults profile (container engine: moby, Kubernetes: off) to skip the first-run wizard
- Launches Rancher Desktop and verifies backend readiness via `rdctl`
- Runs `docker run --rm hello-world` to confirm Docker works
- Shuts down cleanly -- exits 1 if any step fails so Intune retries

## Prerequisites

- WSL2 must be installed (see `scripts-win/wsl2/`)
- Internet access (downloads ~500 MB MSI at install time)

## Files

| File | Purpose |
| ---- | ------- |
| `install.ps1` | Downloads MSI, installs, deploys profile, verifies launch + Docker |
| `uninstall.ps1` | Stops processes, uninstalls MSI, verifies exe and registry removal |
| `detect.ps1` | Intune detection script (exit 0 + output = installed) |
| `build.ps1` | Creates `.intunewin` package from the devcontainer |
| `INTUNE.md` | Intune portal configuration settings |
| `TESTING.md` | USB testing instructions |

## Tests folder

| File | Purpose |
| ---- | ------- |
| `tests/run-tests-install.ps1` | Runs admin check, install.ps1, detect.ps1 (with logging) |
| `tests/run-tests-uninstall.ps1` | Runs uninstall.ps1 (with logging) |
| `tests/run-tests-build.ps1` | Builds .intunewin, extracts, verifies contents (devcontainer) |
| `tests/test-helpers.ps1` | Shared test functions (Test-Pass, Test-Fail, Test-Summary) |
| `tests/logs/` | Log output from test runners |

## Intune configuration

See `INTUNE.md` for exact portal settings.

**Key difference from other packages:** This deploys in **User context** (not System) because Rancher Desktop's MSI fails in SYSTEM context with error `0x80070643`.

## Testing

See `TESTING.md` for USB testing instructions.

## Related

- `scripts-mac/rancher-desktop/` -- Mac equivalent (Jamf)
- `scripts-win/wsl2/` -- WSL2 prerequisite package
- [PLAN-002-rancher-desktop.md](../../docs/ai-developer/plans/completed/PLAN-002-rancher-desktop.md) -- implementation plan (completed)
