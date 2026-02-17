# Plan: Rancher Desktop Intune deployment package

## Status: Complete

**Goal**: Create the Rancher Desktop deployment package for Windows via Intune -- download-at-runtime install with full verification, silent uninstall, detection script, .intunewin packaging, and USB tests.

**Completed**: 2026-02-12

**Prerequisites**: WSL2 must be working on the test PC (it is -- installed manually, see [INVESTIGATE-wsl-intune.md](../active/INVESTIGATE-wsl-intune.md)).

**Based on**: [INVESTIGATE-intune-windows-deployment.md](../active/INVESTIGATE-intune-windows-deployment.md)

---

## Problem

The ops team needs Rancher Desktop on Windows developer machines. On Mac this is solved (`scripts-mac/rancher-desktop/`). On Windows, nothing existed.

Rancher Desktop on Windows has specific deployment challenges:

1. **Must deploy in User context** -- SYSTEM context fails with error `0x80070643` ([GitHub #7356](https://github.com/rancher-sandbox/rancher-desktop/issues/7356)). Uses `MSIINSTALLPERUSER=1` for per-user install.
2. **WSL2 must be pre-installed** -- the installer tries to install WSL in silent mode and fails. We pass `WSLINSTALLED=1` to skip that check.
3. **Auto-updater has elevation issues** ([GitHub #6377](https://github.com/rancher-sandbox/rancher-desktop/issues/6377)) -- non-admin users can't update.
4. **MSI is ~500 MB** -- we download at runtime rather than bundling it in the .intunewin package.
5. **Intune must verify the install works** -- not just that files exist, but that Rancher Desktop launches, the backend reaches a ready state, and Docker works.

---

## Phase 1: Create the package structure -- DONE

- [x] 1.1 Create `scripts-win/rancher-desktop/` folder
- [x] 1.2 Create `.gitignore` with `logs/`, `*.intunewin`, and `*.msi`
- [x] 1.3 Create `README.md`

---

## Phase 2: Create install.ps1 -- DONE

The install script downloads the MSI from GitHub releases, installs silently, and verifies the full stack works.

- [x] 2.1 Create `install.ps1` from the PowerShell template
- [x] 2.2 Configuration section with version, URLs, paths, timeouts
- [x] 2.3 Idempotent -- if already installed, run verification only
- [x] 2.4 Download MSI with `HttpWebRequest` streaming, progress reporting, TLS 1.2, validation
- [x] 2.5 Silent MSI install with `MSIINSTALLPERUSER=1 WSLINSTALLED=1`
- [x] 2.6 Prerequisite checks: WSL2 features, WSL kernel, internet access, disk space
- [x] 2.7 Deploy defaults profile to HKLM registry (container engine: moby, Kubernetes: off)
- [x] 2.8 Remove leftover settings.json from previous installs
- [x] 2.9 Launch Rancher Desktop and poll `rdctl api /v1/backend_state` for readiness (120s timeout)
- [x] 2.10 Run `docker run --rm hello-world` to verify Docker works
- [x] 2.11 Clean shutdown via `rdctl shutdown` (falls back to `Stop-Process -Force`)
- [x] 2.12 Exit 1 if any verification step fails so Intune retries

### Key implementation notes

- **User context, not SYSTEM**: Intune runs this as the logged-in user.
- **`MSIINSTALLPERUSER=1`**: Per-user install. `ALLUSERS=0` is undefined behavior per Microsoft.
- **Both install paths checked**: All scripts check both `%LOCALAPPDATA%\Programs\Rancher Desktop\` and `%ProgramFiles%\Rancher Desktop\`.
- **Download uses `HttpWebRequest` streaming**: Avoids PS 5.1 progress bar performance penalty (~10x slower).
- **WSL kernel check uses process with timeout**: Avoids the interactive "Press any key" hang.
- **Full verification on every run**: Both fresh installs and "already installed" run launch + backend readiness + Docker hello-world + shutdown.

---

## Phase 3: Create uninstall.ps1 -- DONE

- [x] 3.1 Create `uninstall.ps1` from the PowerShell template
- [x] 3.2 Find MSI product code from registry (HKCU and HKLM)
- [x] 3.3 Stop Rancher Desktop processes (graceful, then force kill)
- [x] 3.4 Silent MSI uninstall via `msiexec /x`
- [x] 3.5 Verify exe is removed from both install paths
- [x] 3.6 Verify registry uninstall entry is gone
- [x] 3.7 Remove deployment profile from `HKLM\SOFTWARE\Policies\Rancher Desktop`
- [x] 3.8 Idempotent -- if not installed, exit 0

---

## Phase 4: Create detect.ps1 -- DONE

- [x] 4.1 Create `detect.ps1` following Intune detection convention
- [x] 4.2 Check for exe in both install paths; output = detected, no output = not detected
- [x] 4.3 Standard metadata, help, and logging sections

---

## Phase 5: Create build.ps1 -- DONE

- [x] 5.1 Create `build.ps1` using `New-IntuneWinPackage` from `SvRooij.ContentPrep.Cmdlet`
- [x] 5.2 Packages `install.ps1` as the setup file, outputs `install.intunewin`

---

## Phase 6: Create INTUNE.md -- DONE

- [x] 6.1 Document all Intune portal settings including User context, WSL2 dependency, detection rules

---

## Phase 7: USB tests -- DONE

Test scripts for verifying install and uninstall on the Windows test PC.

- [x] 7.1 Create `tests/` folder with `test-helpers.ps1` (Test-Pass, Test-Fail, Test-Summary)
- [x] 7.2 Create `run-tests-install.ps1` -- admin check, runs install.ps1, runs detect.ps1 (with logging)
- [x] 7.3 Create `run-tests-uninstall.ps1` -- runs uninstall.ps1 (with logging)
- [x] 7.4 Create `TESTING.md` with USB testing instructions
- [x] 7.5 All logic lives in main scripts -- test runners are thin orchestrators
- [x] 7.6 Example logs from successful Windows 11 test run included

### USB testing workflow

```text
Part 1 -- Install (at the PC):
  1. Plug USB, open PowerShell as Administrator
  2. Run: powershell -ExecutionPolicy Bypass -File "D:\rancher-desktop\tests\run-tests-install.ps1"
  3. Admin check passes
  4. install.ps1: prerequisites, download (~500 MB), MSI install, profile, launch, rdctl readiness, Docker hello-world, shutdown
  5. detect.ps1: outputs "detected"
  6. Bring USB back with logs/test-results-install.log

Part 2 -- Uninstall (after reviewing install log):
  1. Plug USB, open PowerShell as Administrator
  2. Run: powershell -ExecutionPolicy Bypass -File "D:\rancher-desktop\tests\run-tests-uninstall.ps1"
  3. uninstall.ps1: stop processes, MSI uninstall, verify exe + registry gone, remove profile
  4. Bring USB back with logs/test-results-uninstall.log
```

---

## Phase 8: Deployment profile (future)

- [ ] 8.1 Discuss: which settings should be locked? (auto-updates, container engine, Kubernetes, memory/CPU)
- [ ] 8.2 If wanted: locked profile via `HKLM\Software\Policies\Rancher Desktop\Locked` (requires SYSTEM script)

Currently using a **defaults** profile (user can change settings). A **locked** profile would prevent users from changing settings and disable auto-updates.

---

## Acceptance Criteria

- [x] `install.ps1` downloads MSI, installs per-user, deploys profile, verifies launch + Docker
- [x] `install.ps1` exits 1 if any verification fails (Intune retries)
- [x] `install.ps1` always attempts shutdown before exiting (even on failure)
- [x] `install.ps1` checks prerequisites (WSL2, internet, disk space)
- [x] `uninstall.ps1` silently removes Rancher Desktop, verifies exe + registry gone
- [x] `detect.ps1` correctly reports install status for Intune
- [x] `build.ps1` creates `.intunewin` package from devcontainer
- [x] `INTUNE.md` documents all portal settings
- [x] All `.ps1` files pass `validate-powershell.sh`
- [x] USB tests pass on the Windows test PC
- [x] Rancher Desktop launches and runs with WSL2 backend on the test PC

---

## Final file listing

| File | Purpose |
|------|---------|
| `scripts-win/rancher-desktop/install.ps1` | Downloads MSI, installs, deploys profile, verifies launch + Docker |
| `scripts-win/rancher-desktop/uninstall.ps1` | Stops processes, uninstalls MSI, verifies exe + registry removal |
| `scripts-win/rancher-desktop/detect.ps1` | Intune detection script (exit 0 + output = installed) |
| `scripts-win/rancher-desktop/build.ps1` | Creates `.intunewin` package from devcontainer |
| `scripts-win/rancher-desktop/README.md` | Package overview |
| `scripts-win/rancher-desktop/INTUNE.md` | Intune portal configuration |
| `scripts-win/rancher-desktop/TESTING.md` | USB testing instructions |
| `scripts-win/rancher-desktop/.gitignore` | Excludes logs/, *.intunewin, *.msi |
| `scripts-win/rancher-desktop/tests/run-tests-install.ps1` | Install test runner (admin check + install + detect) |
| `scripts-win/rancher-desktop/tests/run-tests-uninstall.ps1` | Uninstall test runner |
| `scripts-win/rancher-desktop/tests/test-helpers.ps1` | Shared test functions (Test-Pass, Test-Fail, Test-Summary) |
| `scripts-win/rancher-desktop/tests/example-test-results-install.log` | Example log from successful Windows 11 test |
| `scripts-win/rancher-desktop/tests/example-test-results-uninstall.log` | Example log from successful Windows 11 test |
