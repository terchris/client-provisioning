# Devcontainer Toolbox -- Intune Portal Configuration

Settings for creating the Win32 app in the Intune portal.

---

## App Information

| Field | Value |
|-------|-------|
| Name | Devcontainer Toolbox |
| Description | Pulls the devcontainer-toolbox Docker image and installs the devcontainer-init command globally. Users can then run devcontainer-init in any project folder to set up devcontainer configuration. |
| Publisher | IT Operations |
| Category | Developer Tools |

---

## Program

| Field | Value |
|-------|-------|
| Install command | `powershell.exe -ExecutionPolicy Bypass -File install.ps1` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -File uninstall.ps1` |
| Install behavior | **System** |
| Device restart behavior | No specific action |
| Return codes | 0 = Success |

**Note:** Install behavior is **System** because the script writes to `C:\Program Files\` and modifies the system PATH. The install script launches Rancher Desktop (which is a per-user app) using the current user's install path.

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

The detection script checks if `devcontainer-init.ps1` exists at `C:\Program Files\devcontainer-toolbox\`. It is uploaded separately from the `.intunewin` package.

---

## Dependencies

| Dependency | Auto install |
|------------|-------------|
| Rancher Desktop | Yes |

The devcontainer-toolbox needs Docker (provided by Rancher Desktop) to pull the image during install. Rancher Desktop in turn depends on WSL2. Intune handles the dependency chain: WSL2 -> Rancher Desktop -> Devcontainer Toolbox.

---

## Assignments

| Field | Value |
|-------|-------|
| Required | Developer machines group |

---

## Notes

- The install script launches Rancher Desktop, waits for the Docker backend, pulls `ghcr.io/terchris/devcontainer-toolbox:latest`, copies the init tool to `C:\Program Files\devcontainer-toolbox\`, adds it to the system PATH, then shuts down Rancher Desktop. If any step fails, exit 1 triggers Intune retry.
- The `devcontainer-init` command does NOT require Docker -- it only downloads a config file from GitHub. Docker is only needed during the install step (to pull the image).
- The uninstall script removes the install directory and PATH entry. It attempts to remove the Docker image if Docker is running; otherwise it skips image removal (best effort).
- PATH changes only take effect in new terminal sessions. Users who had a terminal open during install need to open a new one.
- The `.intunewin` package is built with `build.ps1` in the devcontainer.
