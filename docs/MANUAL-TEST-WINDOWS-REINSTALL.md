# Manual Test: Windows Full Reinstall (USB Stick)

End-to-end test of the Windows install pipeline: uninstall everything, reinstall from scratch, verify it all works.

## When to use this

Run this test after making changes to any install, uninstall, or detect script in `scripts-win/`. It verifies the full pipeline works on a real Windows PC -- something that cannot be tested in the devcontainer.

Typical scenarios:
- After modifying `install.ps1` or `uninstall.ps1` in any package
- Before deploying updated scripts to Intune
- When onboarding a new Windows PC to verify the environment is ready

**Scope:** WSL2 stays installed. Rancher Desktop and devcontainer-toolbox get uninstalled then reinstalled.

## Before you start

**Admin access is required.** Most scripts need Administrator PowerShell. Request admin rights via Admin on Demand before going to the PC.

**WSL2 must already be working.** This test does not install WSL2 -- it assumes WSL2 is already deployed and functional.

**Internet access is required.** Rancher Desktop install downloads ~500 MB from GitHub. The devcontainer-toolbox install pulls a Docker image from ghcr.io.

## Prepare the USB stick

Copy the entire `scripts-win/` folder to the USB stick:

```
D:\scripts-win\
  diagnostics\
    check-environment.ps1
  wsl2\
    detect.ps1
    install.ps1
  rancher-desktop\
    detect.ps1
    install.ps1
    uninstall.ps1
  devcontainer-toolbox\
    detect.ps1
    install.ps1
    uninstall.ps1
    devcontainer-init.ps1
    devcontainer-init.cmd
```

Adjust the drive letter if your USB mounts differently (E:\, F:\, etc.).

Optional: include the `tests/` folders for automated validation.

---

## Phase 1: Diagnose current state

Open PowerShell **as Administrator** (right-click > "Run as administrator"). Navigate to the USB drive.

Run all four detection scripts:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\diagnostics\check-environment.ps1"
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\wsl2\detect.ps1"
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\rancher-desktop\detect.ps1"
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\devcontainer-toolbox\detect.ps1"
```

**How to read the output:**

| Script | Installed | Not installed |
|--------|-----------|---------------|
| wsl2/detect.ps1 | "WSL2 features detected (Enabled, Enabled)" | INFO line only, nothing after |
| rancher-desktop/detect.ps1 | "Rancher Desktop installed at ..." | INFO line only, nothing after |
| devcontainer-toolbox/detect.ps1 | "devcontainer-toolbox installed at ..." | INFO line only, nothing after |

The `INFO: Starting...` line always appears -- it is informational logging. The **detection result** is the line after it. No line after INFO = not installed. This follows the Intune convention: stdout output = detected, no output = not detected.

Note which components are currently installed before proceeding.

---

## Phase 2: Uninstall (reverse order)

Uninstall in reverse dependency order: devcontainer-toolbox first (depends on Rancher Desktop), then Rancher Desktop.

### 2.1 Uninstall devcontainer-toolbox

```powershell
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\devcontainer-toolbox\uninstall.ps1"
```

This removes `C:\Program Files\devcontainer-toolbox\` and cleans the system PATH.

### 2.2 Uninstall Rancher Desktop

```powershell
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\rancher-desktop\uninstall.ps1"
```

This stops running processes, runs MSI uninstall, removes the registry deployment profile.

### 2.3 Verify clean state

```powershell
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\rancher-desktop\detect.ps1"
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\devcontainer-toolbox\detect.ps1"
```

Both should show the INFO line only, with nothing after -- meaning "not detected."

WSL2 should still be detected:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\wsl2\detect.ps1"
```

---

## Phase 3: Reinstall (forward order)

Install in dependency order: Rancher Desktop first (provides Docker), then devcontainer-toolbox.

### 3.1 Install Rancher Desktop

```powershell
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\rancher-desktop\install.ps1"
```

This does the following (can take several minutes):

1. Checks prerequisites (WSL2, internet, disk space)
2. Downloads the MSI (~500 MB) from GitHub -- progress reported every 10 seconds
3. Installs per-user via MSI
4. Deploys registry defaults (container engine: moby, Kubernetes: off)
5. Launches Rancher Desktop
6. Polls backend until ready (timeout: 120 seconds)
7. Runs `docker run --rm hello-world`
8. Shuts down cleanly

**Note:** Rancher Desktop install runs in **user context**. Administrator is needed for the deployment profile (registry write) but the MSI itself installs per-user.

### 3.2 Install devcontainer-toolbox

```powershell
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\devcontainer-toolbox\install.ps1"
```

This does the following:

1. Launches Rancher Desktop
2. Waits for Docker backend to be ready
3. Pulls the toolbox Docker image from ghcr.io
4. Installs `devcontainer-init` to `C:\Program Files\devcontainer-toolbox\`
5. Adds install directory to system PATH
6. Shuts down Rancher Desktop

---

## Phase 4: Verify

### 4.1 Run detection scripts

```powershell
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\wsl2\detect.ps1"
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\rancher-desktop\detect.ps1"
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\devcontainer-toolbox\detect.ps1"
```

All three should report installed (output after the INFO line).

### 4.2 Test devcontainer-init

**Open a new PowerShell window** (the current session does not see PATH changes). Navigate to a project folder or create a temp folder:

```powershell
mkdir C:\temp\test-project
cd C:\temp\test-project
devcontainer-init
```

This should download `devcontainer.json` from GitHub and create the `.devcontainer/` folder. Verify:

```powershell
dir .devcontainer\devcontainer.json
```

### 4.3 Open in VS Code (optional)

Open the project folder in VS Code. The Dev Containers extension should prompt to reopen in container. Verify the devcontainer starts and tools are available.

---

## Troubleshooting

**detect.ps1 shows INFO line only** -- This means the component is not installed. This is correct behavior, not an error. See the output table in Phase 1.

**"Running as Administrator" check fails** -- You opened PowerShell normally. Close it and reopen with right-click > "Run as administrator". Having admin rights via Admin on Demand is NOT the same as running PowerShell elevated -- both are required.

**Rancher Desktop download fails** -- Check internet access. The script downloads from github.com. Progress is reported every 10 seconds. If behind a proxy, the download may fail.

**"Download appears truncated"** -- The connection dropped during the ~500 MB download. Run the install script again.

**Backend not ready (timeout)** -- Rancher Desktop needs WSL2 to start properly. If WSL2 features are not fully enabled, the backend will fail within 120 seconds.

**Docker pull fails** -- Check internet access. The devcontainer-toolbox install pulls from ghcr.io (GitHub Container Registry). If behind a proxy, the pull may fail.

**devcontainer-init not found in new window** -- PATH changes only take effect in new terminal sessions. Make sure you opened a **new** PowerShell window after the install completed.

**Script errors with ERR codes** -- All scripts use numbered error codes (ERR001, ERR002, etc.) in their output. The error message describes what failed. Check the specific script's README for details.

---

## Running automated tests (optional)

If you included the `tests/` folders on the USB, you can use the automated test runners instead of running scripts manually. These provide pass/fail results and log to files you can bring back for review.

### Rancher Desktop tests

```powershell
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\rancher-desktop\tests\run-tests-install.ps1"
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\rancher-desktop\tests\run-tests-uninstall.ps1"
```

### Devcontainer-toolbox tests

```powershell
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\devcontainer-toolbox\tests\run-tests-install.ps1"
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\devcontainer-toolbox\tests\run-tests-init.ps1"
powershell -ExecutionPolicy Bypass -File "D:\scripts-win\devcontainer-toolbox\tests\run-tests-uninstall.ps1"
```

Logs are saved to `tests/logs/` in each package folder. Bring the USB back so the logs can be reviewed.

See individual TESTING.md files for details:
- [rancher-desktop/TESTING.md](rancher-desktop/TESTING.md)
- [devcontainer-toolbox/TESTING.md](devcontainer-toolbox/TESTING.md)
- [wsl2/TESTING.md](wsl2/TESTING.md)
