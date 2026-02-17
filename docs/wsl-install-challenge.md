# WSL2 Silent Deployment via Intune: The Challenge

**Author**: terchris
**Date**: 2026-02-13
**Purpose**: Brief my Intune consulting partner on the WSL2 deployment challenge so I can find a working solution together with them.

---

## Executive Summary

I need to deploy WSL2 (Windows Subsystem for Linux) silently to managed Windows machines via Microsoft Intune. Our users do not have admin rights and cannot install software themselves.

I have successfully automated **Step 1** -- enabling the required Windows features via DISM. This works reliably in Intune's SYSTEM context.

I am stuck on **Step 2** -- installing the WSL kernel. Microsoft's recommended command (`wsl --install`) **does not work in SYSTEM context**, and Microsoft has closed the bug reports without fixing them. The Store-based WSL MSI also fails with error 1603 when run as SYSTEM.

I have found **no official Microsoft solution** for deploying WSL silently via Intune. I have identified four possible approaches and need help from my Intune partner to evaluate them and pick the best path forward:

| # | Approach | Pros | Cons |
|---|----------|------|------|
| A | Intune Win32 app in **user context** | Runs in user session (avoids Session 0 bug), may have elevation from SYSTEM | Requires logged-in user, conflicting docs on whether elevation is enough |
| B | First-login script or scheduled task | Transparent to user, runs once automatically | More complex to set up, timing depends on login |
| C | Manual step during onboarding | Simplest, fully supported, uses Store WSL | Not fully automated -- user must act |
| D | Legacy inbox kernel MSI in SYSTEM context | Fully silent, no user needed | Legacy technology, Microsoft may deprecate |

I recommend discussing options A, B, and C with our Intune partner. Option D (legacy MSI) works as a fallback but should not be the long-term strategy.

---

## Why I Need WSL2

I deploy Rancher Desktop to developer machines for container-based development. On Windows, Rancher Desktop requires WSL2 as its backend. Without WSL2, Rancher Desktop cannot start.

My deployment chain on Windows is:

```text
WSL2 (features + kernel)  -->  Rancher Desktop  -->  Devcontainer Toolbox
```

Each package depends on the one before it. All three must be deployed silently via Intune because our users do not have admin rights.

---

## What WSL2 Actually Is

WSL2 is not a single installable application. It consists of three separate components:

| Component | What it is | How to install |
|-----------|-----------|----------------|
| **Windows features** | Two OS-level features: `Microsoft-Windows-Subsystem-Linux` and `VirtualMachinePlatform` | DISM commands (works in SYSTEM context) |
| **WSL kernel** | The Linux kernel binary that runs inside WSL2 | Separate MSI installer or `wsl --install` |
| **Linux distribution** | A distro like Ubuntu | Not needed (Rancher Desktop manages its own) |

The features require a reboot after enabling. The kernel must be installed after the reboot (features must show `Enabled`, not `EnablePending`).

---

## What I Have Built (Step 1: Features)

I have a working Intune Win32 app package that enables both Windows features:

**Package location**: `scripts-win/wsl2/` in my repo
**Built and tested**: Yes, on the test PC (XYZ-PW0MKCB1)

### What it does

```powershell
# My install.ps1 runs these DISM commands:
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

- Runs as SYSTEM (Intune default) -- works reliably
- Checks prerequisites first (admin, Windows version, virtualization)
- Idempotent (safe to run twice)
- Exits with code 3010 (tells Intune to schedule a reboot)

### Detection script

```powershell
$wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
$vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
if ($wsl.State -eq "Enabled" -and $vmp.State -eq "Enabled") {
    Write-Host "WSL2 prerequisites enabled"
    exit 0
}
exit 0
```

### Test results

- Both features enable successfully via DISM
- After reboot, both features show `Enabled`
- **But WSL2 is NOT usable** -- the kernel is missing (Step 2)

---

## Where I Am Stuck (Step 2: Kernel)

After enabling features and rebooting, any `wsl` command triggers an interactive prompt:

> "Press any key to install Windows Subsystem for Linux..."

This prompt waits 60 seconds and times out. In Intune's non-interactive SYSTEM context, this hangs.

### Why `wsl --install` Does Not Work in SYSTEM Context

| Approach | Problem | Evidence |
|----------|---------|----------|
| `wsl --install` in SYSTEM context | Garbled output, ignores flags, prints usage text instead of installing | [GitHub WSL #11142](https://github.com/microsoft/WSL/issues/11142) -- **closed without fix** (auto-closed Nov 2025 after 1 year of inactivity) |
| Store WSL MSI (`wsl.2.x.x.msi`) via Intune | Fails with error 1603 in SYSTEM context | [GitHub WSL #10906](https://github.com/microsoft/WSL/issues/10906) -- **closed without fix**, confirmed across versions 2.0.9 and 2.0.14 |
| WSL via Store/Company Portal | Store UWP app cannot enable VirtualMachinePlatform | [GitHub WSL #12895](https://github.com/microsoft/WSL/issues/12895) -- **still open**, Microsoft confirmed limitation |
| `wsl --install --web-download` | No evidence it works in SYSTEM context | [PSAppDeployToolkit discussion](https://discourse.psappdeploytoolkit.com/t/start-adtprocess-with-wsl-exe-install-from-file-returns-success-but-doesn-t-install-distro-in-intune-deployment/6607) -- silently fails (exit 0, installs nothing) |

**Microsoft has closed both SYSTEM context bugs without fixing them.** There is no official Microsoft solution for deploying WSL silently via Intune in SYSTEM context.

However, `wsl --install` **does work in user context** -- the problem is specifically with SYSTEM (Session 0). This opens up alternative approaches.

### What I did manually on the test PC

```powershell
# Ran interactively (with admin rights):
wsl --install
wsl --install ubuntu
```

This installed the modern Store-based WSL and got WSL2 working. But this requires a user with admin rights, which our managed users don't have.

---

## Possible Solutions

I have identified four approaches. Each solves the kernel installation problem differently. I want to discuss these with my Intune partner and pick the best option.

### Option A: Intune Win32 App in User Context (Recommended to explore)

Intune Win32 apps can be configured to install in **user context** instead of SYSTEM context. The `wsl --install` problem is specifically with Session 0 (SYSTEM). User context runs in the **user's session** (Session 1+), which avoids the Session 0 bug.

**How Intune user context actually works:**

When a Win32 app is set to "User" install behavior, Intune's `MDMAppInstaller` calls `CreateProcessAsUserW`. This spawns the process **in the user's session** (not Session 0) but with elevated privileges inherited from SYSTEM. The process appears to run as the user but can still write to protected locations like `Program Files`. ([Source: PatchMyPC](https://patchmypc.com/blog/intune-app-install-context-user-installs-program-files/))

This is promising because:
- The process runs in **the user's interactive session** (Session 1+), not Session 0
- `wsl --install` fails specifically in Session 0 -- this avoids that bug
- The process has elevated privileges from SYSTEM, which `wsl --install` needs

**However, there is conflicting information.** Some sources say user context does NOT have full admin elevation and apps requiring admin rights will fail. The elevated privilege may only apply to MSI installs, not arbitrary commands like `wsl --install`. ([Source: Andrew Taylor](https://andrewstaylor.com/2022/11/22/intune-comparing-system-vs-user-for-everything/))

**How it would work:**

1. Step 1 (DISM features) runs as SYSTEM -- already built and working
2. Intune reboots the machine (exit code 3010)
3. A second Win32 app runs `wsl --install --no-distribution` in **user context**
4. This installs the modern Store-based WSL (not the legacy inbox version)

**Key questions for Intune partner:**

- Does a Win32 app in user context have enough elevation to run `wsl --install`?
- The process runs in the user's session (not Session 0) -- does this avoid the `wsl --install` bug?
- Can I set a dependency from a user-context app to a system-context app?
- What happens if no user is logged in when Intune tries to install?

**Also worth exploring: Intune Endpoint Privilege Management (EPM)**

Microsoft recently added a feature called "Elevate as current user" in Intune EPM. It elevates specific applications with admin rights in the user's session, with user confirmation via PIN or password. This could be a supported way to run `wsl --install` as a non-admin user. ([Source: Mike's MDM Blog](https://mikemdm.de/2025/10/26/intune-endpoint-privilege-management-now-supports-elevation-in-user-context/))

**Pros:**

- Uses the modern Store WSL (actively maintained, not legacy)
- `wsl --install` is Microsoft's supported command
- Runs in user session, avoiding the Session 0 bug
- No deprecated components

**Cons:**

- Requires a logged-in user at install time
- Unclear whether user context has enough elevation -- **needs testing**
- EPM requires user confirmation (not fully silent)
- Conflicting documentation about actual privilege level

---

### Option B: First-Login Script or Scheduled Task

Deploy a script via Intune that runs `wsl --install` automatically at the next user login. The user doesn't need to do anything -- it happens in the background.

**How it would work:**

1. Step 1 (DISM features) runs as SYSTEM -- already built and working
2. Intune reboots the machine (exit code 3010)
3. Intune deploys a PowerShell script configured to run in user context, or creates a scheduled task triggered at logon
4. On next login, the script runs `wsl --install --no-distribution`
5. The script deletes itself / the scheduled task after success

**Key questions for Intune partner:**

- Can Intune Platform Scripts run as the logged-in user with admin elevation?
- Is a scheduled task with `RunLevel=Highest` a better approach?
- How do I detect success and report it back to Intune?
- What if the user logs in before the reboot from Step 1 is complete?

**Pros:**
- Transparent to the user -- happens automatically at login
- Uses the modern Store WSL
- Runs once and cleans up after itself

**Cons:**
- More complex to set up and debug
- Timing depends on when the user logs in after the reboot
- Admin elevation may still be required
- Detection/reporting back to Intune is more complex

---

### Option C: Manual Step During Onboarding

Accept that WSL kernel installation requires one manual command from the user (or IT support during setup). Everything else is automated.

**How it would work:**

1. Step 1 (DISM features) is deployed silently via Intune -- already built and working
2. Intune reboots the machine
3. During onboarding (or via remote IT support), someone runs:

```powershell
wsl --install --no-distribution
```

4. After this one-time command, all remaining packages (Rancher Desktop, Devcontainer Toolbox) install automatically via Intune

**Pros:**
- Simplest approach -- no complex Intune configuration
- Uses the modern Store WSL (fully supported, actively maintained)
- `wsl --install` is the Microsoft-recommended command
- Can be part of existing onboarding checklist
- Could be done remotely by IT support

**Cons:**
- Not fully automated -- someone must run one command
- Adds a manual step to the onboarding process
- User needs admin rights (temporary) or IT support must connect remotely

---

### Option D: Legacy Inbox Kernel MSI (Fallback)

Microsoft's [manual WSL installation page](https://learn.microsoft.com/en-us/windows/wsl/install-manual) documents a legacy approach using a standalone kernel MSI. This is labeled "for older versions" by Microsoft.

**How it would work:**

1. Step 1 (DISM features) runs as SYSTEM -- already built and working
2. Intune reboots the machine
3. A second Win32 app downloads and installs the kernel MSI in SYSTEM context:

```powershell
msiexec /i wsl_update_x64.msi /qn /norestart
```

**Download URLs:**

- x64: `https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi`
- ARM64: `https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_arm64.msi`

**Why it might work:**

This MSI is fundamentally different from the Store WSL MSI that fails with error 1603:

| Aspect | Inbox kernel MSI (`wsl_update_x64.msi`) | Store WSL MSI (`wsl.2.x.x.msi`) |
|--------|----------------------------------------|----------------------------------|
| What it installs | Just the kernel binary (~15 MB) | Full WSL runtime, kernel, WSLg |
| Store/UWP dependencies | None -- pure Windows Installer | Depends on Store components |
| Used on Windows Server | Yes, documented by Microsoft | No |
| SYSTEM context | Should work (standard MSI) | Fails with error 1603 |

It has been used on Windows Server with `msiexec /quiet` ([Windows Server WSL docs](https://learn.microsoft.com/en-us/windows/wsl/install-on-server)).

**Detection rule:**

```powershell
if (Test-Path "$env:SystemRoot\system32\lxss\tools\kernel") {
    Write-Host "WSL kernel installed"
    exit 0
}
exit 0
```

**Why I hesitate:**

- This is a **legacy component**. Microsoft's page is titled "Manual installation steps for older versions of WSL."
- Microsoft is moving everything to Store WSL. The inbox kernel may stop receiving updates.
- The download URL is static -- unclear if Microsoft still updates the MSI file.
- Rancher Desktop might eventually require features only available in Store WSL.
- Building enterprise infrastructure on a deprecated component is risky.

**When to use this:**

- As a **fallback** if Options A, B, and C all fail
- As a **temporary** solution while waiting for Microsoft to fix SYSTEM context
- On machines where no user login is expected (kiosk, shared devices)

---

## Proposed Intune Deployment Flow

The exact flow depends on which option is chosen for Step 3:

```text
Step 1: Win32 App - WSL Features          (DONE - built and tested)
  |  install.ps1 enables DISM features
  |  Exit code 3010 -> Intune triggers reboot
  v
Step 2: Reboot                             (Handled by Intune)
  |
  v
Step 3: WSL Kernel Install                 (NOT YET BUILT - needs partner input)
  |  Option A: Win32 app, user context, wsl --install
  |  Option B: Login script / scheduled task, wsl --install
  |  Option C: Manual onboarding step
  |  Option D: Win32 app, SYSTEM context, legacy kernel MSI
  v
Step 4: Win32 App - Rancher Desktop        (DONE - built and tested)
  |  Depends on Step 3
  v
Step 5: Win32 App - Devcontainer Toolbox   (DONE - built and tested)
  |  Depends on Step 4
  v
Step 6: Settings Catalog - WSL Security    (NOT YET CONFIGURED)
  |  Configuration Profile with security settings
```

### Intune Settings Catalog (Step 6)

After WSL2 is installed, enforce security via Configuration Profile (Settings Catalog > "Windows Subsystem for Linux"):

| Setting | Recommended value | Why |
|---------|-------------------|-----|
| AllowWSL | Enabled | Allow WSL on the device |
| AllowWSL1 | Disabled | Force WSL 2 only (Rancher Desktop requires WSL 2) |
| AllowInboxWSL | Enabled | Allow the inbox (legacy) version if used |
| AllowCustomKernelConfiguration | Disabled | Prevent custom kernels |
| AllowDebugShell | Disabled | Prevent `wsl --debug-shell` |

---

## What I Need Help With

### 1. Evaluate which approach to use for Step 3

I need my Intune partner's experience with:

- Can Intune Win32 apps run `wsl --install` in user context with elevation? (Option A)
- Can Intune Platform Scripts or scheduled tasks handle this at login? (Option B)
- Is a manual onboarding step acceptable given our scale? (Option C)
- Should I test the legacy kernel MSI as a fallback? (Option D)

### 2. Test the chosen approach

Whichever option is selected, test it on a machine where Step 1 is complete (features Enabled, rebooted):

- Verify `wsl --version` works without the interactive "Press any key" prompt
- Verify Rancher Desktop installs and starts successfully on top of it
- Verify the detection script correctly reports installation status

### 3. Configure the Intune dependency chain

Set up the package dependencies so Intune installs in the correct order:

```text
WSL Features  -->  (reboot)  -->  WSL Kernel  -->  Rancher Desktop  -->  Devcontainer Toolbox
```

### 4. Configure Settings Catalog

Set up the WSL security configuration profile with the recommended settings listed above.

---

## Two Versions of WSL -- Important Context

Since late 2022, there are two separate versions of WSL that cause confusion:

| | Inbox WSL (legacy) | Store WSL (current) |
|-|-------------------|---------------------|
| **Delivery** | Windows features + kernel MSI | Single Microsoft Store package |
| **Install command** | DISM + `msiexec` (or `wsl --install --inbox`) | `wsl --install` (default) |
| **Updates** | Via Windows Update (slow, tied to OS) | Via Microsoft Store (fast, independent) |
| **SYSTEM context** | DISM works. Kernel MSI likely works. | Does not work. |
| **Intune deployment** | Win32 app with PowerShell + MSI | Cannot set Store app dependencies on Win32 apps |
| **Future** | Microsoft may deprecate | Microsoft's active development path |

Microsoft's enterprise documentation assumes WSL is already installed and focuses on management/security, not on the initial deployment challenge. This is the gap that makes enterprise WSL deployment difficult.

---

## References

### Microsoft official documentation

- [Install WSL](https://learn.microsoft.com/en-us/windows/wsl/install) -- official install guide
- [Manual WSL installation steps](https://learn.microsoft.com/en-us/windows/wsl/install-manual) -- the legacy 6-step approach with kernel MSI download links
- [WSL on Windows Server](https://learn.microsoft.com/en-us/windows/wsl/install-on-server) -- uses `msiexec /quiet` for kernel MSI
- [WSL enterprise setup](https://learn.microsoft.com/en-us/windows/wsl/enterprise) -- enterprise management (post-install only)
- [Intune settings for WSL](https://learn.microsoft.com/en-us/windows/wsl/intune) -- Settings Catalog configuration
- [WSL compliance in Intune](https://learn.microsoft.com/en-us/intune/intune-service/protect/compliance-wsl) -- compliance plugin

### GitHub issues documenting the SYSTEM context problem

- [#11142: wsl --install doesn't work in SYSTEM context](https://github.com/microsoft/WSL/issues/11142) -- closed without fix (Nov 2025)
- [#10906: WSL Store MSI error 1603 in SYSTEM context](https://github.com/microsoft/WSL/issues/10906) -- closed without fix
- [#12895: WSL via Store apps in Intune fails](https://github.com/microsoft/WSL/issues/12895) -- open, Microsoft confirmed limitation

### Community resources

- [Peter van der Woude: WSL compliance with Intune](https://petervanderwoude.nl/post/working-with-device-compliance-for-windows-subsystem-for-linux/) -- IntuneWSLPluginInstaller.msi
- [Wolkenman: WSL2 security with Intune](https://wolkenman.wordpress.com/2024/12/22/security-compliance-for-wsl2-on-windows-11-with-intune/) -- Defender integration
- [PSAppDeployToolkit forum](https://discourse.psappdeploytoolkit.com/t/start-adtprocess-with-wsl-exe-install-from-file-returns-success-but-doesn-t-install-distro-in-intune-deployment/6607) -- confirms `wsl --install` fails silently in SYSTEM context
- [Store WSL GA announcement](https://devblogs.microsoft.com/commandline/the-windows-subsystem-for-linux-in-the-microsoft-store-is-now-generally-available-on-windows-10-and-11/) -- Store vs inbox WSL differences
