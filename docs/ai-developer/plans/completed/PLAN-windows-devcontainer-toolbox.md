# Feature: Windows devcontainer-toolbox package

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) -- The implementation process
> - [PLANS.md](../../PLANS.md) -- Plan structure and best practices
> - [rules/script-standard.md](../../rules/script-standard.md) -- Shared script standard
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `-- DONE` to phase headers, update status.

## Status: Complete

**Goal**: Create a Windows package that pulls the devcontainer-toolbox Docker image and installs the `devcontainer-init` command globally, matching the Mac version's functionality. USB-test on a real Windows PC first, then package for Intune.

**Last Updated**: 2026-02-12

**Prerequisites**: `scripts-win/rancher-desktop/` and `scripts-win/wsl2/` must be complete (they are).

---

## Overview

Create `scripts-win/devcontainer-toolbox/` with scripts that can be tested from a USB drive on a real Windows PC. Once USB testing confirms everything works, wrap it as an Intune `.intunewin` package.

Based on [INVESTIGATE-windows-devcontainer-toolbox.md](../backlog/INVESTIGATE-windows-devcontainer-toolbox.md).

Reference implementation: `scripts-mac/devcontainer-toolbox/` (Mac/Jamf equivalent).

---

## Phase 1: devcontainer-init tool -- DONE

Create the user-facing `devcontainer-init.ps1` tool and the `.cmd` shim. This is the script users will run in their project folders.

### Tasks

- [x] 1.1 Create `scripts-win/devcontainer-toolbox/` directory
- [x] 1.2 Create `devcontainer-init.ps1` -- native PowerShell port of `scripts-mac/devcontainer-toolbox/devcontainer-init.sh`:
  - Accept optional folder path argument (default: current directory)
  - Confirm with user when using current directory (interactive prompt)
  - Backup existing `.devcontainer/` to `.devcontainer.backup/` (fail if backup already exists)
  - Check connectivity to `raw.githubusercontent.com` before downloading
  - Download `devcontainer.json` from GitHub (`Invoke-WebRequest` with URL logging and 30s timeout)
  - Create `.devcontainer/` with the downloaded config (no JSON validation -- file uses JSONC comments)
  - Print next steps
  - Follow script standard (metadata, help, logging, error codes)
- [x] 1.3 Create `devcontainer-init.cmd` -- one-line shim: `@pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0devcontainer-init.ps1" %*`
- [x] 1.4 Create `.gitignore` -- ignore `*.intunewin` build artifacts
- [x] 1.5 Run `bash docs/ai-developer/tools/validate-powershell.sh devcontainer-toolbox`

### Validation

User confirms `devcontainer-init.ps1` looks correct and validation passes.

---

## Phase 2: install.ps1, detect.ps1, uninstall.ps1 -- DONE

Create the core scripts. Reuse the launch/wait/shutdown pattern from `scripts-win/rancher-desktop/install.ps1`.

### Tasks

- [x] 2.1 Create `install.ps1` with these steps:
  - Verify Rancher Desktop is installed (check known install paths, same as `rancher-desktop/install.ps1`)
  - Launch Rancher Desktop (same `Start-Process` pattern)
  - Poll `rdctl api /v1/backend_state` until STARTED (same `Wait-ForBackendReady` pattern, timeout 120s)
  - Run `docker pull ghcr.io/terchris/devcontainer-toolbox:latest`
  - Copy `devcontainer-init.ps1` and `devcontainer-init.cmd` to `C:\Program Files\devcontainer-toolbox\`
  - Add `C:\Program Files\devcontainer-toolbox\` to system PATH via `[Environment]::SetEnvironmentVariable`
  - Shut down Rancher Desktop via `rdctl shutdown` (same `Stop-RancherDesktop` pattern)
  - If already installed (init tool exists + image present), still pull latest image and verify init tool is in place
  - Follow script standard (metadata, help, logging, error codes)
- [x] 2.2 Create `detect.ps1`:
  - Check `devcontainer-init.ps1` exists at `C:\Program Files\devcontainer-toolbox\`
  - Check `devcontainer-init.ps1` exists at install location (Docker may not be running, so only check the file)
  - Output text + exit 0 if installed, exit silently with no output if not
  - Follow script standard
- [x] 2.3 Create `uninstall.ps1`:
  - Remove `C:\Program Files\devcontainer-toolbox\` directory
  - Remove from system PATH
  - Optionally remove the container image (start Rancher Desktop, `docker rmi`, shut down)
  - Follow script standard
- [x] 2.4 Run `bash docs/ai-developer/tools/validate-powershell.sh devcontainer-toolbox`

### Validation

User confirms all three scripts look correct and validation passes.

---

## Phase 3: USB test scripts -- DONE

Create test runners for USB testing on a real Windows PC, following the same pattern as `scripts-win/rancher-desktop/tests/`.

### Tasks

- [x] 3.1 Create `tests/test-helpers.ps1` -- copy from `scripts-win/rancher-desktop/tests/test-helpers.ps1` (shared test functions: Test-Pass, Test-Fail, Test-Summary)
- [x] 3.2 Create `tests/run-tests-install.ps1`:
  - Test 1: Verify running as Administrator
  - Test 2: Verify Rancher Desktop is installed
  - Test 3: Run `install.ps1`, verify exit 0
  - Test 4: Verify `devcontainer-init.ps1` exists at `C:\Program Files\devcontainer-toolbox\`
  - Test 5: Verify `C:\Program Files\devcontainer-toolbox\` is in system PATH
  - Test 6: Run `detect.ps1`, verify it outputs text
  - Log to `tests/logs/test-results-install.log`
- [x] 3.3 Create `tests/run-tests-init.ps1`:
  - Test 1: Create temp folder
  - Test 2: Run `devcontainer-init.ps1` on temp folder (pass folder path as argument)
  - Test 3: Verify `.devcontainer/devcontainer.json` exists in temp folder
  - Test 4: Verify file is not empty and contains expected content
  - Cleanup temp folder
  - Log to `tests/logs/test-results-init.log`
- [x] 3.4 Create `tests/run-tests-uninstall.ps1`:
  - Test 1: Run `uninstall.ps1`, verify exit 0
  - Test 2: Verify `devcontainer-init.ps1` no longer exists at install location
  - Test 3: Verify install directory removed from system PATH
  - Log to `tests/logs/test-results-uninstall.log`
- [x] 3.5 Create `tests/logs/` directory with a `.gitkeep` placeholder

### Validation

User confirms test scripts look correct.

---

## Phase 4: USB testing documentation -- DONE

Create the documentation needed for USB testing on a real Windows PC.

### Tasks

- [x] 4.1 Create `TESTING.md` -- same structure as `scripts-win/rancher-desktop/TESTING.md`:
  - Before you start (admin access, prerequisites, internet)
  - Log files description
  - What Intune does (context for the tester)
  - Preparation (copy to USB, request admin rights, open PowerShell as Administrator)
  - Part 1: Install tests (`run-tests-install.ps1`)
  - Part 2: Init test (`run-tests-init.ps1`)
  - Part 3: Uninstall tests (`run-tests-uninstall.ps1`)
  - Troubleshooting
- [x] 4.2 Create `README.md` -- same structure as `scripts-win/rancher-desktop/README.md`:
  - What it does, prerequisites, files table, tests table, testing reference, related links
  - Note: Intune configuration section and build.ps1 entry are deferred to Phase 6

### Validation

User confirms documentation is complete enough for USB testing.

---

## Phase 5: USB testing on a real Windows PC -- DONE

Tested on Windows 11 (XYZ-PW0MKCB1, PowerShell 5.1.26100.3624) on 2026-02-12. Example logs saved in `tests/`.

### Tasks

- [x] 5.1 User copies folder to USB, runs `run-tests-install.ps1` on Windows PC -- 7/7 passed
- [x] 5.2 User runs `run-tests-init.ps1` on Windows PC -- 5/5 passed
- [x] 5.3 User runs `run-tests-uninstall.ps1` on Windows PC -- 3/3 passed
- [x] 5.4 User brings back USB with logs in `tests/logs/`
- [x] 5.5 Review logs, fix any issues, re-test if needed -- fixed: removed Docker check from init, removed JSON validation (JSONC), fixed image name to ghcr.io

### Validation

All three test runners pass on a real Windows PC. Logs confirm:
- `install.ps1` pulls image from `ghcr.io`, installs init tool, adds to PATH
- `devcontainer-init` downloads `devcontainer.json` from GitHub and creates `.devcontainer/`
- `uninstall.ps1` removes init tool and PATH entry
- `detect.ps1` correctly reports installed/not-installed state

---

## Phase 6: Intune packaging and pipeline -- DONE

### Tasks

- [x] 6.1 Create `build.ps1` -- builds `.intunewin` using SvRooij.ContentPrep.Cmdlet
- [x] 6.2 Create `INTUNE.md` -- Intune portal configuration (System context, dependencies on Rancher Desktop)
- [x] 6.3 Create `tests/run-tests-build.ps1` -- build, extract, verify 10 files + 5 size matches (19 tests total)
- [x] 6.4 Run `build.ps1` and `tests/run-tests-build.ps1` -- all 19 tests passed
- [x] 6.5 Update `README.md` -- added build.ps1, INTUNE.md to files table, run-tests-build.ps1 to tests table
- [x] 6.6 Add `devcontainer-toolbox` to `azure-pipelines.yml` packages parameter
- [x] 6.7 Update `docs/README.md` -- added devcontainer-toolbox to Windows packages table
- [x] 6.8 Run both validators -- all passed (5 PowerShell, 7 bash)

### Validation

Build test passes in devcontainer (19/19). Both validators pass. Pipeline entry added.

---

## Acceptance Criteria

### USB testing (Phases 1-5)

- [x] All `.ps1` scripts follow the script standard and pass `validate-powershell.sh`
- [x] `install.ps1` launches Rancher Desktop, pulls image, installs init tool, adds to PATH, shuts down
- [x] `detect.ps1` correctly detects installed state
- [x] `uninstall.ps1` removes init tool and PATH entry
- [x] `devcontainer-init` command works from any terminal (via `.cmd` shim)
- [x] `devcontainer-init` downloads `devcontainer.json` from GitHub and creates `.devcontainer/`
- [x] USB test scripts pass on a real Windows PC
- [x] `README.md` and `TESTING.md` are complete

### Intune packaging (Phase 6)

- [x] `build.ps1` creates `.intunewin` package
- [x] `run-tests-build.ps1` passes in devcontainer
- [x] `INTUNE.md` is complete
- [x] Package is added to the CI/CD pipeline

---

## Implementation Notes

### Reuse from rancher-desktop/install.ps1

The following patterns should be extracted or copied from `scripts-win/rancher-desktop/install.ps1`:

- `Test-RancherInstalled` -- check install paths
- `Wait-ForBackendReady` -- poll `rdctl api /v1/backend_state` until STARTED
- `Stop-RancherDesktop` -- `rdctl shutdown` with fallback to `Stop-Process`
- Launch via `Start-Process` on `Rancher Desktop.exe`
- Docker path resolution via `$DOCKER_RELATIVE_PATH`

### PATH modification

```powershell
$installDir = "C:\Program Files\devcontainer-toolbox"
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
if ($currentPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$installDir", "Machine")
}
```

Note: PATH changes only take effect in new terminal sessions. The USB test for `devcontainer-init` availability should open a new process to verify.

### devcontainer-init.ps1 differences from Mac version

- No `-y` flag needed (Intune is always non-interactive; user-facing usage is always interactive)
- Use `Invoke-WebRequest` instead of `curl`/`wget`
- No JSON validation (devcontainer.json uses JSONC comments, PowerShell 5.1 cannot parse them)
- Use `Move-Item` for backup, `New-Item` for directory creation
- Same error codes and flow as the bash version

---

## Files to Create

| File | Phase | Purpose |
| ---- | ----- | ------- |
| `scripts-win/devcontainer-toolbox/devcontainer-init.ps1` | 1 | User-facing init tool |
| `scripts-win/devcontainer-toolbox/devcontainer-init.cmd` | 1 | `.cmd` shim for `devcontainer-init` |
| `scripts-win/devcontainer-toolbox/.gitignore` | 1 | Ignore build artifacts |
| `scripts-win/devcontainer-toolbox/install.ps1` | 2 | Pull image, install init tool, add to PATH |
| `scripts-win/devcontainer-toolbox/detect.ps1` | 2 | Detection script |
| `scripts-win/devcontainer-toolbox/uninstall.ps1` | 2 | Remove init tool and PATH entry |
| `scripts-win/devcontainer-toolbox/tests/test-helpers.ps1` | 3 | Shared test functions |
| `scripts-win/devcontainer-toolbox/tests/run-tests-install.ps1` | 3 | USB install tests |
| `scripts-win/devcontainer-toolbox/tests/run-tests-init.ps1` | 3 | USB init test |
| `scripts-win/devcontainer-toolbox/tests/run-tests-uninstall.ps1` | 3 | USB uninstall tests |
| `scripts-win/devcontainer-toolbox/tests/logs/.gitkeep` | 3 | Log directory placeholder |
| `scripts-win/devcontainer-toolbox/TESTING.md` | 4 | USB testing instructions |
| `scripts-win/devcontainer-toolbox/README.md` | 4 | Package overview |
| `scripts-win/devcontainer-toolbox/build.ps1` | 6 | Build `.intunewin` package |
| `scripts-win/devcontainer-toolbox/INTUNE.md` | 6 | Intune portal configuration |
| `scripts-win/devcontainer-toolbox/tests/run-tests-build.ps1` | 6 | Devcontainer build test |

## Files to Modify

| File | Phase | Change |
| ---- | ----- | ------ |
| `azure-pipelines.yml` | 6 | Add `devcontainer-toolbox` to packages parameter |
| `docs/README.md` | 6 | Add devcontainer-toolbox to Windows packages table |
