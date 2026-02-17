# USB Testing on a Windows PC

How to test the Rancher Desktop install scripts on a Windows PC, emulating Intune behavior.

## Before you start

**Admin access is required.** Request admin rights before going to the PC.

**WSL2 must be working.** Rancher Desktop needs WSL2. The WSL2 package should already be deployed on the test PC.

**Internet access is required.** The install script downloads the MSI (~500 MB) from GitHub at install time.

## Log files

Each test runner creates its own log file in `tests/logs/`:

- `test-results-install.log` -- from `run-tests-install.ps1`
- `test-results-uninstall.log` -- from `run-tests-uninstall.ps1`

Logs append on each run. Bring the USB back so Claude Code can read the logs.

## Example logs

See the `tests/` folder for example logs from a successful test run on a Windows 11 PC:

- [example-test-results-install.log](tests/example-test-results-install.log) -- all install tests passing, including prerequisites, download, MSI install, backend readiness, and Docker hello-world
- [example-test-results-uninstall.log](tests/example-test-results-uninstall.log) -- uninstall test passing, including MSI removal, exe verification, and registry cleanup

## What Intune does

Intune runs this package in **User context** (not SYSTEM). The install script runs as the logged-in user with `-ExecutionPolicy Bypass`. Running PowerShell as Administrator on the PC gives more privileges than Intune would, but is needed for the deployment profile.

`install.ps1` includes full verification: after installing, it launches Rancher Desktop, polls rdctl for backend readiness, runs Docker hello-world, and shuts down cleanly. If any verification step fails, the script exits 1 so Intune retries.

`uninstall.ps1` includes full verification: after uninstalling, it verifies the exe is removed and the registry entry is gone.

## Preparation

1. Copy the `scripts-win/rancher-desktop/` folder to a USB stick so it appears as `D:\rancher-desktop\` (adjust drive letter if your USB mounts differently)
2. Request admin rights via **Admin on Demand** (reason: "Testing Rancher Desktop deployment scripts -- need to run PowerShell as Administrator"). Someone in the organization must approve.
3. The PC reboots after approval -- the user gets temporary admin rights
4. After reboot, open PowerShell **as Administrator** (right-click > "Run as administrator", or Win+X > "Terminal (Admin)"). The title bar must say "Administrator:". Having admin rights is NOT the same as running as Administrator -- both steps are required.

## How to run the tests

Testing is split into two parts so you can verify the install works before testing uninstall.

### Part 1: Install tests

```powershell
powershell -ExecutionPolicy Bypass -File "D:\rancher-desktop\tests\run-tests-install.ps1"
```

This runs 3 tests:

1. **Administrator check** -- verifies PowerShell is running as Administrator (needed for profile deployment)
2. **Install** -- runs `install.ps1`, which checks prerequisites (WSL2, internet, disk space), downloads MSI (~500 MB), installs per-user, deploys defaults profile, launches Rancher Desktop, verifies backend readiness via rdctl, runs Docker hello-world, and shuts down
3. **Detect** -- runs `detect.ps1`, verifies it outputs text (Intune would see the app as installed)

After all pass, bring the USB back with `tests/logs/test-results-install.log` for review.

Rancher Desktop stays installed on the PC.

### Part 2: Uninstall tests (after reviewing install log)

```powershell
powershell -ExecutionPolicy Bypass -File "D:\rancher-desktop\tests\run-tests-uninstall.ps1"
```

This runs 1 test:

1. **Uninstall** -- runs `uninstall.ps1`, which stops processes, runs MSI uninstall, verifies exe is removed, verifies registry entry is gone, and removes deployment profile

This removes Rancher Desktop from the PC. To reinstall, run part 1 again.

---

## What install.ps1 verifies

The install script does all of the following (both for fresh installs and "already installed"):

1. Checks WSL2 features are enabled
2. Checks WSL kernel is installed
3. Checks internet access (github.com reachable)
4. Checks disk space (minimum 2 GB)
5. Downloads the MSI (~500 MB) from GitHub
6. Installs per-user via MSI
7. Deploys a defaults profile to the registry (container engine: moby, Kubernetes: off)
8. Launches Rancher Desktop
9. Polls `rdctl api /v1/backend_state` until `STARTED` or `DISABLED` (timeout: 120 seconds). `DISABLED` is normal when Kubernetes is off -- Docker still works via moby/WSL2
10. Runs `docker run --rm hello-world` and checks for "Hello from Docker" in output
11. Shuts down cleanly via `rdctl shutdown` (falls back to `Stop-Process -Force`)

If already installed, steps 4-7 are skipped but steps 8-11 still run.

## What uninstall.ps1 verifies

1. Stops running Rancher Desktop processes (graceful, then force kill)
2. Finds the MSI product code from the registry
3. Runs `msiexec /x` to remove the MSI
4. Verifies `Rancher Desktop.exe` no longer exists at either install path
5. Verifies the registry uninstall entry is gone
6. Removes the deployment profile from `HKLM\SOFTWARE\Policies\Rancher Desktop`

---

## Build tests (devcontainer)

The build test runs in the devcontainer (Linux/pwsh) and verifies the `.intunewin` package round-trip: build, extract, check contents.

```bash
pwsh scripts-win/rancher-desktop/tests/run-tests-build.ps1
```

This runs 3 tests:

1. **Build** -- runs `build.ps1`, checks exit code and that `install.intunewin` is created with non-zero size
2. **Extract** -- uses `Unlock-IntuneWinPackage` to extract the `.intunewin` to a temp directory
3. **Verify** -- checks all expected files are present (`install.ps1`, `uninstall.ps1`, `detect.ps1`, `build.ps1`, `README.md`, `INTUNE.md`, `TESTING.md`, `.gitignore`) and that `.ps1` file sizes match the originals

Cleanup removes the extracted temp directory and the built `install.intunewin` (it is a build artifact, gitignored).

Log output: `tests/logs/test-results-build.log`

---

## Differences from WSL2 testing

- **No reboot required.** All tests run in a single USB session.
- **Two-part testing.** Install and uninstall are separate test runners so you can review the install log before removing.
- **User context.** Rancher Desktop installs per-user (not system-level), unlike WSL2 features which require SYSTEM/admin.
- **Download at runtime.** The install downloads ~500 MB from GitHub. Ensure internet access before testing. Progress is reported every 10 seconds.

---

## Troubleshooting

**"Not found at ..."** -- Make sure the USB is mounted and the path is correct. Adjust the drive letter if needed.

**"WSL2 features are not ready"** -- Both features must be Enabled (not EnablePending), or WSL must be installed via Microsoft Store (`wsl.exe` present). Deploy the WSL2 package and reboot first.

**"wsl --version timed out"** -- The WSL kernel is not installed. Run `wsl --install` interactively on the PC first.

**Download fails** -- Check internet access. The script downloads from `github.com`. If the PC is behind a proxy, the download may fail. The script forces TLS 1.2 for PowerShell 5.1 compatibility.

**"Download appears truncated"** -- The connection dropped during the 500 MB download. Try again.

**Install hangs** -- The MSI install can take a few minutes. If it seems stuck, check Task Manager for `msiexec.exe` processes.

**Verification fails (backend not ready)** -- Rancher Desktop needs WSL2 to start properly. If WSL2 is not working, the backend will fail to reach a ready state within 120 seconds.

**Backend stays DISABLED** -- The container engine did not start. Common causes: wrong `virtualMachine.type` (e.g. `qemu` instead of `wsl2`), stale `settings.json` from a previous install. The script will attempt remediation via `rdctl set` automatically. If it still fails, try deleting `%APPDATA%\rancher-desktop\settings.json` and `%LOCALAPPDATA%\rancher-desktop\settings.json`, then rerun.

**Docker hello-world fails** -- The Docker daemon may not be fully ready. The install script will exit 1 and Intune will retry.

**"Running as Administrator" fails** -- You opened PowerShell normally. Close it and re-open with right-click > "Run as administrator".
