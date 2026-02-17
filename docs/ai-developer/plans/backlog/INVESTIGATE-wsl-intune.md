# Investigate: WSL2 deployment via Intune

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) -- The implementation process
> - [PLANS.md](../../PLANS.md) -- Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `-- DONE` to phase headers, update status.

## Status: Backlog

**Goal**: Document everything we know about deploying WSL2 to Windows machines via Intune, including what we built, what worked, what didn't, and what was done manually. This file is the single reference for WSL2 deployment if we revisit automation later.

**Last Updated**: 2026-02-13

**Related**:
- [INVESTIGATE-intune-windows-deployment.md](INVESTIGATE-intune-windows-deployment.md) -- the parent investigation (Intune, repo structure, all apps)
- `scripts-win/wsl2/` -- the features package we built (install.ps1, detect.ps1, build.ps1, tests)

---

## Context

Rancher Desktop on Windows requires WSL2. WSL2 is not a standalone app -- it is a set of Windows components that must be enabled and installed. We needed to automate this via Intune for enterprise deployment.

This turned out to be harder than expected. We built a package that enables the Windows features, but the kernel component could not be installed silently via Intune. The user installed WSL manually on the test PC. The test PC now has a working WSL2 and we are moving on to Rancher Desktop.

---

## What WSL2 requires

WSL2 has three separate components:

1. **Windows features** -- `Microsoft-Windows-Subsystem-Linux` and `VirtualMachinePlatform`, enabled via DISM. These are OS-level plumbing. Requires a reboot after enabling.
2. **WSL kernel** -- the Linux kernel that runs inside WSL2. Distributed as a separate MSI installer (`wsl_update_x64.msi` or `wsl_update_arm64.msi`). Must be installed AFTER the features are enabled and the PC has rebooted.
3. **Linux distribution** -- a distro like Ubuntu. Not needed for our use case (Rancher Desktop manages its own WSL distributions).

Other prerequisites:
- Windows 10 version 2004+ (Build 19041+) or Windows 11
- CPU virtualization enabled in BIOS/UEFI (Intel VT-x or AMD-V)

---

## What we built: WSL2 features package

**Location**: `scripts-win/wsl2/`

A complete Intune Win32 app package that enables both Windows features using DISM. All phases were completed and tested on the Windows test PC.

### Package contents

| File | Purpose |
| ---- | ------- |
| `install.ps1` | Enables both features via DISM, exits 3010 for reboot |
| `detect.ps1` | Intune detection script (checks both features are Enabled/EnablePending) |
| `build.ps1` | Creates `.intunewin` package from the devcontainer |
| `INTUNE.md` | Documents portal configuration |
| `README.md` | Package documentation |
| `TESTING.md` | USB testing instructions |
| `tests/` | 5 test scripts + test runner + helpers |

### What install.ps1 does

1. Checks prerequisites (admin, Windows version, virtualization)
2. Checks if features are already enabled (idempotent)
3. Enables both features via DISM:
   ```
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```
4. Verifies features are now Enabled or EnablePending
5. Exits 3010 (Intune interprets this as "soft reboot required")

### Test results (USB testing on test PC)

- Session 1 (pre-reboot): install.ps1 enabled both features, detect.ps1 confirmed, exit 3010
- Session 2 (post-reboot): both features `Enabled`, all tests passed
- **But**: WSL2 was NOT usable after this -- the kernel was missing (see next section)

### USB testing workflow (two sessions required)

Copy `scripts-win/wsl2/` to USB as `D:\wsl2\`.

```text
Session 1 (before reboot):
  1. Request Admin on Demand (PC reboots with admin rights)
  2. Plug USB, open PowerShell as Administrator
  3. Run: powershell -ExecutionPolicy Bypass -File "D:\wsl2\tests\run-all-tests.ps1"
  4. test-0: prerequisites pass
  5. test-1: install.ps1 enables features, exit 3010
  6. test-2: detect.ps1 outputs "detected" (EnablePending counts)
  7. Script says: "Reboot required. Re-run after reboot."
  8. Reboot the PC

Session 2 (after reboot):
  1. If Admin on Demand has expired, request it again (PC reboots)
  2. Open PowerShell as Administrator
  3. Run: powershell -ExecutionPolicy Bypass -File "D:\wsl2\tests\run-all-tests.ps1"
  4. test-0: prerequisites pass
  5. test-1: skipped (features already Enabled)
  6. test-2: detect.ps1 outputs "detected"
  7. test-3: features are Enabled (post-reboot verification)
  8. All tests pass
```

### Implementation notes

- DISM exit codes: 0 = success, 3010 = success + reboot needed, anything else = failure
- `/norestart` prevents DISM from forcing an immediate reboot
- `/all` enables parent features if needed
- After enabling features, `Get-WindowsOptionalFeature` may show `EnablePending` instead of `Enabled` until reboot
- The script does NOT run `wsl --install --no-distribution` -- that was deferred to a kernel package that was never built

---

## The kernel problem

After enabling features + reboot, `wsl` commands (`wsl --version`, `wsl --status`, `wsl --install`) all trigger an interactive prompt:

> "Press any key to install Windows Subsystem for Linux..."

This prompt waits 60 seconds before timing out. In Intune's non-interactive SYSTEM context, this would hang.

### Why this happens

The Windows features are just plumbing. The actual Linux kernel is a separate component. Without it, every `wsl` command tries to install WSL interactively via the Microsoft Store.

### The proposed automation (abandoned)

The proposed kernel automation plan (since abandoned) was to download and silently install the inbox kernel MSI:

- x64: `https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi`
- ARM64: `https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_arm64.msi`

Install command: `msiexec /i wsl_update_x64.msi /qn /norestart`

Verification: check if `$env:SystemRoot\system32\lxss\tools\kernel` exists.

**This was never tested.** The user installed WSL manually instead.

### What the user did manually

After the features package completed (features enabled + reboot), the user ran interactively:

```powershell
wsl --install
wsl --install ubuntu
```

This installed the Store-based WSL (not the inbox version) and got WSL2 working. The test PC now has a functional WSL2.

### Why automation was abandoned

- The kernel MSI approach was untested and adds another Intune package with a dependency chain
- `wsl --install` does not work in SYSTEM context (known issue, see below)
- The test PC only needed WSL once -- manual install was faster than debugging automation
- We can revisit if we need to deploy WSL2 to many machines

---

## Installation approaches researched

### What is DISM?

DISM (Deployment Image Servicing and Management) is a built-in Windows command-line tool for managing OS-level features -- similar to `apt` or `dnf` on Linux. We use it to enable the two Windows features that WSL2 requires. DISM works reliably as SYSTEM (how Intune runs scripts), unlike `wsl --install` which has known bugs in that context.

### DISM (what we used for features)

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

- Works reliably as SYSTEM
- DISM exit codes: 0 = success, 3010 = success + reboot needed
- `/norestart` prevents forced reboot
- `/all` enables parent features if needed
- This only enables the features, not the kernel

### `wsl --install` (does NOT work in SYSTEM context)

- Produces garbled output, ignores flags, sometimes prints usage instead of installing ([GitHub WSL #11142](https://github.com/microsoft/WSL/issues/11142))
- The Store-based WSL MSI also fails in SYSTEM context ([GitHub WSL #10906](https://github.com/microsoft/WSL/issues/10906)) with error 1603
- Works fine interactively (which is how the user installed it)

### Inbox kernel MSI (proposed but untested)

- Microsoft provides standalone kernel MSIs that can be installed silently with `msiexec /qn`
- This installs the legacy (inbox) kernel, not the Store-based WSL
- The MSI requires both Windows features to be Enabled first -- if features are not enabled, the MSI fails with: "This update only applies to machines with the Windows Subsystem for Linux"
- No reboot needed after kernel MSI installation (unlike the features step)
- ~15 MB download -- small enough to download at install time, or could be bundled in the .intunewin package if internet access is unreliable

Source: [Manual WSL Installation Steps](https://learn.microsoft.com/en-us/windows/wsl/install-manual) (see Step 4: "Download the Linux kernel update package")

---

## Store-based WSL vs inbox WSL

Since late 2022, there are two separate versions of WSL:

| Aspect | Inbox WSL (legacy) | Store WSL (new default) |
| ------ | ------------------ | ----------------------- |
| Delivery | Windows optional feature + separate kernel MSI + separate WSLg MSI | Single Microsoft Store package (MSIX) |
| Updates | Via Windows Update (tied to OS release cycle, slow) | Via Microsoft Store (independent, faster) |
| Kernel | Separate MSI (`wsl_update_x64.msi`) | Bundled in the Store package |
| WSLg | Separate MSI | Bundled in the Store package |
| Install command | `wsl --install --inbox` or DISM | `wsl --install` (default) |
| SYSTEM context | DISM works; `wsl --install` does not | Does not work ([Blog: Store WSL will not start in session 0](https://devblogs.microsoft.com/commandline/the-windows-subsystem-for-linux-in-the-microsoft-store-is-now-generally-available-on-windows-10-and-11/)) |
| Intune deployment | Win32 app with PowerShell scripts | Cannot set Store app dependencies on Win32 apps ([GitHub #12895](https://github.com/microsoft/WSL/issues/12895)) |

**Key points:**

- The Store version is designed for users who have admin rights and can install apps themselves (e.g. developers on personal machines). It does not work for automated enterprise deployment via Intune.
- In our environment, users do not have admin rights -- they cannot install WSL themselves via the Store or `wsl --install`. Everything must be pushed via Intune.
- `VirtualMachinePlatform` is still required by both versions
- The inbox kernel MSI is the reliable path for Intune SYSTEM context deployment
- Microsoft continues to ship critical fixes for the inbox version, but new features go to the Store version only

Source: [Store WSL GA Announcement](https://devblogs.microsoft.com/commandline/the-windows-subsystem-for-linux-in-the-microsoft-store-is-now-generally-available-on-windows-10-and-11/)

---

## Industry research: Best practices (2026-02-13)

We conducted thorough research into WSL2 enterprise deployment best practices. The conclusion is sobering: **there is no clean, Microsoft-supported method for fully automated WSL2 deployment via Intune.** Our DISM-based approach is actually the industry standard.

### What Microsoft officially recommends

Microsoft's enterprise documentation ([enterprise guide](https://learn.microsoft.com/en-us/windows/wsl/enterprise), [Intune settings](https://learn.microsoft.com/en-us/windows/wsl/intune)) focuses almost entirely on **managing and securing WSL after it is already installed**. They do not provide an official guide for silent enterprise deployment via Intune.

Their Intune documentation covers:
- **Settings Catalog**: Configure WSL behavior (AllowWSL, AllowWSL1, AllowInboxWSL, AllowDebugShell, etc.)
- **Compliance policies**: Check WSL distribution versions via the Intune WSL compliance plugin
- **Defender integration**: Deploy `IntuneWSLPluginInstaller.msi` for endpoint security monitoring

None of these install WSL itself.

### GitHub issue status (as of 2026-02-13)

| Issue | Problem | Status | Resolution |
| ----- | ------- | ------ | ---------- |
| [#11142](https://github.com/microsoft/WSL/issues/11142) | `wsl --install` doesn't work in SYSTEM context | **Closed** (auto-closed after 1 year of inactivity, Nov 2025) | **No fix.** Microsoft assigned the issue but never posted a solution. |
| [#10906](https://github.com/microsoft/WSL/issues/10906) | WSL Store MSI fails with error 1603 in SYSTEM context | **Closed** ("completed") | **No public fix.** Multiple users confirmed the issue persists across versions (2.0.9, 2.0.14). |
| [#12895](https://github.com/microsoft/WSL/issues/12895) | WSL via Store apps in Intune Company Portal fails | **Open** | Microsoft confirmed: Store UWP app cannot handle VMP enablement. Recommended `wsl --install` CLI instead (which itself doesn't work in SYSTEM context). |

**Bottom line**: Microsoft has closed the SYSTEM context issues without fixing them. The community is left without an official solution.

### What the community does

Every enterprise deployment guide we found uses the same fundamental approach we already built:

1. **DISM to enable features** (works in SYSTEM context) -- this is what `scripts-win/wsl2/install.ps1` does
2. **Reboot** (exit code 3010)
3. **Install the kernel** -- this is the step we never automated

The community splits on step 3:

| Approach | How | Works in SYSTEM? | Status |
| -------- | --- | ---------------- | ------ |
| Inbox kernel MSI (`wsl_update_x64.msi`) | `msiexec /i wsl_update_x64.msi /qn` | Likely yes (standard MSI, used on Windows Server) | **Untested by us** |
| Store WSL MSI (from GitHub releases) | `msiexec /i wsl.2.x.x.msi /qn` | **No** -- fails with error 1603 | Confirmed broken |
| `wsl --install` | Runs in user context via PSADT `Start-ADTProcessAsUser` | Only in USER context (requires logged-in user) | Works but defeats purpose of silent deployment |
| Manual user install | User runs `wsl --install` interactively | N/A | What we did on the test PC |

### The inbox kernel MSI is the most promising untested approach

The legacy `wsl_update_x64.msi` from Microsoft's [manual install page](https://learn.microsoft.com/en-us/windows/wsl/install-manual) is a different MSI than the Store-based WSL MSI that fails with error 1603. Key differences:

- It is a simple MSI that installs just the kernel binary -- no Store components, no MSIX, no UWP
- It has been used successfully on Windows Server with `msiexec /quiet` ([Windows Server WSL docs](https://learn.microsoft.com/en-us/windows/wsl/install-on-server))
- It is small (~15 MB) and can be bundled in an `.intunewin` package
- It requires the Windows features to be Enabled first (not just EnablePending)
- Download URLs:
  - x64: `https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi`
  - ARM64: `https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_arm64.msi`

**This MSI is NOT the same as the Store WSL MSI.** The GitHub issues (#10906, #11142) that report SYSTEM context failures are about the Store-based WSL MSI (v2.0.x). The legacy kernel MSI is older, simpler, and likely works in SYSTEM context because it is a straightforward MSI with no Store/UWP dependencies.

### IntuneWSLPluginInstaller.msi -- NOT for installation

The `IntuneWSLPluginInstaller.msi` (from [Microsoft shell-intune-samples](https://github.com/microsoft/shell-intune-samples)) is sometimes mentioned in WSL deployment guides, but it is **not** a WSL installer. It installs:

- The **Intune WSL compliance plugin** (checks WSL distro versions for compliance policies)
- The **Defender for Endpoint WSL plugin** (onboards WSL containers into Defender)

Install command: `msiexec /i IntuneWSLPluginInstaller.msi /qn`
Detection: MSI product code `{DFAEA0AE-7022-4982-8581-8A95A20A6C86}`

This is a post-installation step for security/compliance, not for deploying WSL itself.

### `wsl --install --web-download`

Microsoft's install page mentions `--web-download` as a flag that downloads WSL from the web instead of the Microsoft Store. This could theoretically bypass Store dependencies. However:

- No evidence it works in SYSTEM context
- Documented primarily as a workaround for hung Store downloads
- The PSAppDeployToolkit community confirms that even `wsl --install --from-file` silently fails in SYSTEM context (returns exit code 0 but installs nothing)

Source: [PSAppDeployToolkit discussion](https://discourse.psappdeploytoolkit.com/t/start-adtprocess-with-wsl-exe-install-from-file-returns-success-but-doesn-t-install-distro-in-intune-deployment/6607)

---

## How to check if WSL is installed

Run these on a Windows PC in an Administrator PowerShell prompt.

**Quick check:**

```powershell
wsl --version
```

If WSL is installed, prints version info. If not, prints an error.

**Check Windows features:**

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux | Select-Object State
Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform | Select-Object State
```

Both should show `Enabled`.

**Check installed distributions:**

```powershell
wsl --list --verbose
```

**Check virtualization support:**

```powershell
systeminfo | Select-String "Hyper-V"
```

Should show "VM Monitor Mode Extensions: Yes" and "Virtualization Enabled In Firmware: Yes."

**All-in-one diagnostic:**

```powershell
Write-Host "=== WSL Status Check ==="
Write-Host ""

Write-Host "--- wsl --version ---"
wsl --version 2>&1
Write-Host ""

Write-Host "--- Windows Features ---"
$wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
$vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
Write-Host "Microsoft-Windows-Subsystem-Linux: $($wsl.State)"
Write-Host "VirtualMachinePlatform: $($vmp.State)"
Write-Host ""

Write-Host "--- WSL Distributions ---"
wsl --list --verbose 2>&1
Write-Host ""

Write-Host "--- Virtualization Support ---"
systeminfo | Select-String "Hyper-V"
```

Save this as `check-wsl.ps1` on the USB stick and run with:

```powershell
powershell -ExecutionPolicy Bypass -File "E:\check-wsl.ps1"
```

---

## Detection rules for Intune

### For the features package (what we built)

```powershell
# Check both required features are enabled
$wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
$vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
if ($wsl.State -eq "Enabled" -and $vmp.State -eq "Enabled") {
    Write-Host "WSL2 prerequisites enabled"
    exit 0
}
exit 0
```

### For the kernel package (proposed, untested)

Check if `$env:SystemRoot\system32\lxss\tools\kernel` exists.

---

## Intune Settings Catalog (post-install)

After WSL2 is installed, use Intune Configuration Profiles (Settings Catalog) to enforce security:

| Setting | Recommended value | Purpose |
| ------- | ----------------- | ------- |
| AllowWSL | Enabled | Allow WSL on the device |
| AllowWSL1 | Disabled | Force WSL 2 only (Rancher Desktop requires WSL 2) |
| AllowInboxWSL | Enabled | Allow the inbox (legacy) version of WSL |
| AllowCustomKernelConfiguration | Disabled | Prevent custom kernels |
| AllowDebugShell | Disabled | Prevent `wsl --debug-shell` |

These settings only control behavior of an already-installed WSL -- they cannot install WSL by themselves.

Source: [Intune settings for WSL](https://learn.microsoft.com/en-us/windows/wsl/intune)

---

## Recommended deployment flow (if revisiting automation)

Based on our research, this is the most reliable approach for enterprise WSL2 deployment via Intune:

### Step 1: Enable Windows features (DONE -- exists)

**Intune Win32 app**: `scripts-win/wsl2/install.ps1` uses DISM to enable both features.
- Install context: SYSTEM (works reliably)
- Return code: 3010 (triggers Intune soft reboot)
- Detection: `detect.ps1` checks both features are Enabled

### Step 2: Reboot

Intune handles this automatically when it sees exit code 3010.

### Step 3: Install the inbox kernel MSI (NOT YET BUILT)

**Intune Win32 app**: PowerShell script that downloads and installs `wsl_update_x64.msi`.
- Must depend on Step 1 (features must be Enabled, not just EnablePending)
- Install command: `msiexec /i wsl_update_x64.msi /qn /norestart`
- Detection: check if `$env:SystemRoot\system32\lxss\tools\kernel` exists
- This MSI is a standard MSI (not Store/MSIX), so it should work in SYSTEM context
- **This needs to be built and tested**

### Step 4: Intune Settings Catalog (security hardening)

Configuration Profile with recommended security settings (see table above).

### Step 5: Intune compliance plugin (optional)

Deploy `IntuneWSLPluginInstaller.msi` as a Win32 app for Defender integration and compliance checks.

### What we do NOT need

- A Linux distribution (Rancher Desktop manages its own WSL distros)
- Store-based WSL (the inbox kernel MSI is sufficient for our use case)
- `wsl --install` (broken in SYSTEM context, unnecessary if we install the kernel MSI directly)

---

## Open questions for future automation

1. **Does the inbox kernel MSI (`wsl_update_x64.msi`) install successfully in SYSTEM context?** This is the critical untested question. The MSI is a standard Windows Installer package (not Store/MSIX), and it works on Windows Server with `msiexec /quiet`, so it should work. But we need to test it on the test PC (or a fresh machine) to confirm.

2. **Does Rancher Desktop work with the inbox kernel?** The inbox kernel is older than the Store version. Rancher Desktop may need specific kernel features. Needs testing on a machine with inbox WSL (not Store WSL).

3. **Does the inbox kernel MSI conflict with Store WSL?** Our test PC has Store-based WSL. If we deploy the inbox kernel MSI to other machines, will it cause issues if a user later runs `wsl --install` (which installs Store WSL)?

4. **What version of the inbox kernel does the MSI install?** The download URL is static (`wsl_update_x64.msi`) -- does Microsoft update this file, or is it stuck at an old version? We need to check the installed kernel version after running the MSI.

---

## Test PC WSL status (as of 2026-02-12)

| Component | Status | How |
| --------- | ------ | --- |
| `Microsoft-Windows-Subsystem-Linux` feature | Enabled | `scripts-win/wsl2/install.ps1` (automated via DISM) |
| `VirtualMachinePlatform` feature | Enabled | `scripts-win/wsl2/install.ps1` (automated via DISM) |
| WSL kernel | Installed | Manual `wsl --install` |
| Ubuntu distribution | Installed | Manual `wsl --install ubuntu` |
| WSL version | Store-based (not inbox) | Installed via `wsl --install` default |

The test PC (XYZ-PW0MKCB1) is ready for Rancher Desktop deployment.

---

## Sources

- [Microsoft: Install WSL](https://learn.microsoft.com/en-us/windows/wsl/install) -- official install guide
- [Microsoft: Manual WSL installation steps](https://learn.microsoft.com/en-us/windows/wsl/install-manual) -- legacy 6-step approach with kernel MSI download
- [Microsoft: WSL enterprise setup](https://learn.microsoft.com/en-us/windows/wsl/enterprise) -- enterprise management guide (post-install)
- [Microsoft: Intune settings for WSL](https://learn.microsoft.com/en-us/windows/wsl/intune) -- Settings Catalog configuration
- [Microsoft: WSL compliance in Intune](https://learn.microsoft.com/en-us/intune/intune-service/protect/compliance-wsl) -- compliance plugin
- [GitHub WSL #11142](https://github.com/microsoft/WSL/issues/11142) -- `wsl --install` SYSTEM context failure (closed, no fix)
- [GitHub WSL #10906](https://github.com/microsoft/WSL/issues/10906) -- WSL Store MSI error 1603 in SYSTEM context (closed, no fix)
- [GitHub WSL #12895](https://github.com/microsoft/WSL/issues/12895) -- Store app deployment via Intune fails (open)
- [GitHub WSL Releases](https://github.com/microsoft/wsl/releases) -- WSL 2.6.3 (Dec 2025), 2.7.0 pre-release
- [Peter van der Woude: WSL compliance](https://petervanderwoude.nl/post/working-with-device-compliance-for-windows-subsystem-for-linux/) -- IntuneWSLPluginInstaller.msi deployment
- [Wolkenman: WSL2 security with Intune](https://wolkenman.wordpress.com/2024/12/22/security-compliance-for-wsl2-on-windows-11-with-intune/) -- Defender integration
- [HTMD Blog: Manage WSL with Intune](https://www.anoopcnair.com/manage-windows-subsystem-for-linux-using-intune/) -- Settings Catalog (management only)
- [PSAppDeployToolkit discussion](https://discourse.psappdeploytoolkit.com/t/start-adtprocess-with-wsl-exe-install-from-file-returns-success-but-doesn-t-install-distro-in-intune-deployment/6607) -- `wsl --install --from-file` silently fails in SYSTEM context
- [Store WSL GA Announcement](https://devblogs.microsoft.com/commandline/the-windows-subsystem-for-linux-in-the-microsoft-store-is-now-generally-available-on-windows-10-and-11/) -- Store vs inbox WSL
