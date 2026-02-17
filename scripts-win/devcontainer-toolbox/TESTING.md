# USB Testing on a Windows PC

How to test the devcontainer-toolbox scripts on a Windows PC, emulating Intune behavior.

## Before you start

**Admin access is required.** The install script writes to `C:\Program Files\` and modifies the system PATH.

**Rancher Desktop must be installed and working.** The devcontainer-toolbox needs Docker, which comes from Rancher Desktop. The Rancher Desktop package should already be deployed on the test PC.

**Internet access is required.** The install script pulls a Docker image, and `devcontainer-init` downloads `devcontainer.json` from GitHub.

## Log files

Each test runner creates its own log file in `tests/logs/`:

- `test-results-install.log` -- from `run-tests-install.ps1`
- `test-results-init.log` -- from `run-tests-init.ps1`
- `test-results-uninstall.log` -- from `run-tests-uninstall.ps1`

Logs append on each run. Bring the USB back so Claude Code can read the logs.

## Example logs

Example logs from a successful Windows 11 test run (Feb 12, 2026) are saved in `tests/logs/`:

- [example-install.log](tests/example-install.log) -- 7 tests passed, shows Rancher Desktop launch, image pull, PATH setup
- [example-init.log](tests/example-init.log) -- 5 tests passed, shows devcontainer.json download from GitHub
- [example-uninstall.log](tests/example-uninstall.log) -- 3 tests passed, shows file removal and PATH cleanup

Use these as a reference for what a passing run looks like.

## What Intune does

Intune runs `install.ps1` in **System context** (not user). The install script launches Rancher Desktop, waits for the backend to be ready, pulls the Docker image, installs the `devcontainer-init` command to `C:\Program Files\devcontainer-toolbox\`, and adds it to the system PATH. Running PowerShell as Administrator on the PC gives similar privileges.

`detect.ps1` checks if `devcontainer-init.ps1` exists at the install location.

`uninstall.ps1` removes the install directory and cleans the PATH entry.

## Preparation

1. Copy the `scripts-win/devcontainer-toolbox/` folder to a USB stick so it appears as `D:\devcontainer-toolbox\` (adjust drive letter if your USB mounts differently)
2. Request admin rights via **Admin on Demand** (reason: "Testing devcontainer-toolbox deployment scripts -- need to run PowerShell as Administrator"). Someone in the organization must approve.
3. The PC reboots after approval -- the user gets temporary admin rights
4. After reboot, open PowerShell **as Administrator** (right-click > "Run as administrator", or Win+X > "Terminal (Admin)"). The title bar must say "Administrator:". Having admin rights is NOT the same as running as Administrator -- both steps are required.

## How to run the tests

Testing is split into three parts so you can verify each stage before moving on.

### Part 1: Install tests

```powershell
powershell -ExecutionPolicy Bypass -File "D:\devcontainer-toolbox\tests\run-tests-install.ps1"
```

This runs 6 tests:

1. **Administrator check** -- verifies PowerShell is running as Administrator
2. **Rancher Desktop installed** -- verifies Rancher Desktop is present
3. **Install** -- runs `install.ps1`, which launches Rancher Desktop, pulls the Docker image, installs `devcontainer-init` to `C:\Program Files\devcontainer-toolbox\`, adds to PATH, and shuts down
4. **File check** -- verifies `devcontainer-init.ps1` exists at the install location
5. **PATH check** -- verifies the install directory is in the system PATH
6. **Detect** -- runs `detect.ps1`, verifies it outputs text (Intune would see the app as installed)

After all pass, proceed to Part 2.

### Part 2: Init test

```powershell
powershell -ExecutionPolicy Bypass -File "D:\devcontainer-toolbox\tests\run-tests-init.ps1"
```

This runs 4 tests:

1. **Create temp folder** -- creates a temporary directory for the test
2. **Run devcontainer-init** -- runs `devcontainer-init.ps1` on the temp folder (downloads devcontainer.json from GitHub)
3. **File check** -- verifies `.devcontainer/devcontainer.json` was created
4. **Content check** -- verifies the downloaded file is not empty and contains expected content

The temp folder is cleaned up automatically.

### Part 3: Uninstall tests (after reviewing install and init logs)

```powershell
powershell -ExecutionPolicy Bypass -File "D:\devcontainer-toolbox\tests\run-tests-uninstall.ps1"
```

This runs 3 tests:

1. **Uninstall** -- runs `uninstall.ps1`, which removes the install directory and PATH entry
2. **File check** -- verifies `devcontainer-init.ps1` no longer exists at the install location
3. **PATH check** -- verifies the install directory is removed from the system PATH

This removes devcontainer-toolbox from the PC. To reinstall, run Part 1 again.

---

## Troubleshooting

**"Not found at ..."** -- Make sure the USB is mounted and the path is correct. Adjust the drive letter if needed.

**"Rancher Desktop is not installed"** -- The Rancher Desktop package must be deployed first. Run the rancher-desktop install tests first.

**"Running as Administrator" fails** -- You opened PowerShell normally. Close it and re-open with right-click > "Run as administrator".

**Docker pull fails** -- Check internet access. The script pulls from `ghcr.io` (GitHub Container Registry). If behind a proxy, the pull may fail.

**devcontainer-init download fails** -- Check internet access. The script downloads from `raw.githubusercontent.com`. The script forces TLS 1.2 for PowerShell 5.1 compatibility.

**Backend not ready** -- Rancher Desktop needs WSL2 to start properly. If WSL2 is not working, the backend will fail to reach a ready state within 120 seconds.

**PATH changes not visible** -- PATH modifications only take effect in new terminal sessions. The test scripts read the registry directly, so they see the change immediately. But if you open a new cmd/PowerShell to test `devcontainer-init` manually, it will only work in that new session.
