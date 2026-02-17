# Devcontainer Toolbox -- Windows Package

Pulls the devcontainer-toolbox Docker image and installs the `devcontainer-init` command globally on Windows.

## What it does

- Launches Rancher Desktop and waits for the Docker backend to be ready
- Pulls `ghcr.io/terchris/devcontainer-toolbox:latest` Docker image
- Installs `devcontainer-init.ps1` and `devcontainer-init.cmd` to `C:\Program Files\devcontainer-toolbox\`
- Adds the install directory to the system PATH so users can type `devcontainer-init` from any terminal
- Shuts down Rancher Desktop cleanly
- Exits 1 if any step fails so Intune retries

## What users do after deployment

Run `devcontainer-init` in any project folder to set up `.devcontainer/` configuration. The command:

1. Downloads `devcontainer.json` from the toolbox GitHub repo
2. Creates `.devcontainer/devcontainer.json` in the target folder
3. Backs up any existing `.devcontainer/` to `.devcontainer.backup/`

## Prerequisites

- WSL2 must be installed (see `scripts-win/wsl2/`)
- Rancher Desktop must be installed (see `scripts-win/rancher-desktop/`)
- Internet access (pulls Docker image and downloads config from GitHub)

## Files

| File | Purpose |
| ---- | ------- |
| `install.ps1` | Launches Rancher Desktop, pulls image, installs init tool, adds to PATH |
| `uninstall.ps1` | Removes init tool, cleans PATH, optionally removes Docker image |
| `detect.ps1` | Intune detection script (exit 0 + output = installed) |
| `build.ps1` | Creates `.intunewin` package (run in devcontainer) |
| `devcontainer-init.ps1` | User-facing tool (installed to Program Files) |
| `devcontainer-init.cmd` | .cmd shim so users type `devcontainer-init` without .ps1 |
| `INTUNE.md` | Intune portal configuration settings |
| `TESTING.md` | USB testing instructions |

## Tests folder

| File | Purpose |
| ---- | ------- |
| `tests/run-tests-install.ps1` | USB: admin check, Rancher check, install, file check, PATH check, detect |
| `tests/run-tests-init.ps1` | USB: create temp folder, run devcontainer-init, verify content |
| `tests/run-tests-uninstall.ps1` | USB: uninstall, verify files removed, verify PATH cleaned |
| `tests/run-tests-build.ps1` | Devcontainer: build, extract, verify package contents |
| `tests/test-helpers.ps1` | Shared test functions (Test-Pass, Test-Fail, Test-Summary) |
| `tests/logs/` | Log output from test runners |

## Testing

See `TESTING.md` for USB testing instructions.

## Related

- `scripts-mac/devcontainer-toolbox/` -- Mac equivalent (Jamf)
- `scripts-win/rancher-desktop/` -- Rancher Desktop prerequisite package
- `scripts-win/wsl2/` -- WSL2 prerequisite package
