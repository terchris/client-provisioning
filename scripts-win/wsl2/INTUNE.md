# WSL2 - Intune Portal Configuration

Settings for creating the Win32 app in the Intune portal.

---

## App Information

| Field | Value |
|-------|-------|
| Name | WSL2 Features |
| Description | Enables Windows Subsystem for Linux v2 features (Microsoft-Windows-Subsystem-Linux and VirtualMachinePlatform). Required for Rancher Desktop. |
| Publisher | IT Operations |
| Category | Developer Tools |

---

## Program

| Field | Value |
|-------|-------|
| Install command | `powershell.exe -ExecutionPolicy Bypass -File install.ps1` |
| Uninstall command | *(none - WSL2 features cannot be easily disabled via Intune)* |
| Install behavior | System |
| Device restart behavior | App install may force a device restart |
| Return codes | 0 = Success, 3010 = Soft reboot |

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

The detection script checks that both `Microsoft-Windows-Subsystem-Linux` and `VirtualMachinePlatform` features are `Enabled` or `EnablePending`. It is uploaded separately from the `.intunewin` package.

---

## Dependencies

None. This is the base package that other packages (e.g., Rancher Desktop) depend on.

---

## Assignments

| Field | Value |
|-------|-------|
| Required | Developer machines group |

---

## Notes

- The install script exits with code **3010** after enabling features, which tells Intune a reboot is needed.
- Intune will show a "restart required" notification to the user.
- After reboot, the detection script confirms the features are active.
- The `.intunewin` package is built with `build.ps1` in the devcontainer.
