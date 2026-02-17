# USB Testing on a Windows PC

How to test the WSL2 install scripts on a Windows PC, emulating Intune behavior.

## Test result

**This package alone does not produce a working WSL2.** It enables the two Windows features, but the WSL kernel is not installed. After features are enabled and the PC reboots, any `wsl` command triggers an interactive 60-second prompt. The user had to manually run `wsl --install` to complete the setup. See PLAN-001b for the kernel deployment package.

## Before you start

This package enables two Windows features (`Microsoft-Windows-Subsystem-Linux` and `VirtualMachinePlatform`). These are OS-level features, not app installs. Enabling them requires a **reboot**. The test takes two sessions on the PC.

**Admin access is required.** DISM and `Get-WindowsOptionalFeature` need Administrator privileges.

## test-results.log

When running the tests a file `tests/logs/test-results.log` is created. It appends to the file on each run, so both session 1 (pre-reboot) and session 2 (post-reboot) end up in the same log. Bring the USB back so Claude Code can read the log.

## What Intune does

Intune runs PowerShell scripts as `NT AUTHORITY\SYSTEM` with `-ExecutionPolicy Bypass`. Running PowerShell **as Administrator** on the PC is equivalent for testing purposes.

## Preparation

1. Copy the `scripts-win/wsl2/` folder to a USB stick so it appears as `D:\wsl2\` (adjust drive letter if your USB mounts differently)
2. Request admin rights via **Admin on Demand** (the PC will reboot after approval)

## How to run the tests

### Session 1 (pre-reboot)

1. Plug the USB into the PC
2. Open PowerShell **as Administrator** (right-click > "Run as administrator")
3. Run:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\wsl2\tests\run-all-tests.ps1"
```

The script runs tests in order:

- **test-0: Prerequisites** — checks admin rights, Windows version, virtualization
- **test-1: Install** — runs `install.ps1`, verifies features are `Enabled` or `EnablePending`
- **test-2: Detect** — runs `detect.ps1`, verifies it outputs text (detected)
- **test-3: Post-reboot** — skipped (features not yet fully enabled)

After test-1, the script will say: **"Reboot required. Re-run after reboot."**

1. Reboot the PC

### Session 2 (post-reboot)

1. If Admin on Demand has expired, request it again (the PC will reboot)
2. Open PowerShell **as Administrator**
3. Run the same command:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\wsl2\tests\run-all-tests.ps1"
```

This time the script detects that features are already `Enabled` and runs all tests:

- **test-0: Prerequisites** — pass
- **test-1: Install** — skipped (features already Enabled)
- **test-2: Detect** — `detect.ps1` outputs "detected"
- **test-3: Post-reboot** — verifies both features are `Enabled` (not `EnablePending`)

---

## Running individual tests

If you need to re-run a single test:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\wsl2\tests\test-0-prerequisites.ps1"
powershell -ExecutionPolicy Bypass -File "D:\wsl2\tests\test-1-install.ps1"
powershell -ExecutionPolicy Bypass -File "D:\wsl2\tests\test-2-detect.ps1"
powershell -ExecutionPolicy Bypass -File "D:\wsl2\tests\test-3-post-reboot.ps1"
```

Individual tests don't log to file. Use `run-all-tests.ps1` for a full logged session.

---

## What each test checks

### test-0: Prerequisites (fully automated)

| Check | Pass condition |
| ----- | ------------- |
| Administrator | Running as Administrator or SYSTEM |
| Windows version | Build 19041+ (Windows 10 2004 or later) |
| Virtualization | Hypervisor is present (Intel VT-x / AMD-V enabled in BIOS) |

### test-1: Install (fully automated)

| Check | Pass condition |
| ----- | ------------- |
| install.ps1 exit code | 0 (already installed) or 3010 (reboot needed) |
| Feature state | Both features are `Enabled` or `EnablePending` |

If features are already `Enabled`, the test is skipped (post-reboot session).

### test-2: Detect (fully automated)

| Check | Pass condition |
| ----- | ------------- |
| detect.ps1 exit code | 0 |
| detect.ps1 output | Non-empty (any stdout = detected) |

### test-3: Post-reboot (fully automated)

| Check | Pass condition |
| ----- | ------------- |
| Feature state | Both features are `Enabled` (not `EnablePending`) |

This test does NOT run `wsl --version` or `wsl --status`. The WSL kernel component is not installed by this package, and running `wsl` commands without the kernel triggers an interactive prompt that hangs for 60 seconds.

---

## Troubleshooting

**"This script must run as Administrator or SYSTEM"** — You opened PowerShell normally. Close it and re-open with right-click > "Run as administrator". Having admin rights (via Admin on Demand) is not the same as running PowerShell elevated. See the investigation for details.

**"Virtualization is not enabled"** — Intel VT-x or AMD-V must be enabled in the BIOS/UEFI. This is a hardware setting that cannot be changed from Windows.

**"Windows build is too old"** — WSL2 requires Windows 10 version 2004 (build 19041) or later.

**Features stuck in `EnablePending`** — The PC needs a reboot. Reboot and re-run the tests.

**`wsl --version` or `wsl --status` hangs** — Do not run these manually unless the WSL kernel is installed (`wsl --update`). Without the kernel, these commands show an interactive prompt that waits 60 seconds. This is why test-3 does not run them.
