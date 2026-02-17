# Investigate: Intune scripts for Windows application deployment

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Goal**: Determine how to create Windows deployment scripts for Intune, mirroring the approach we use for Mac with Jamf (`scripts-mac/`).

**Last Updated**: 2026-02-10

---

## Context

This repo (`jamf`) contains Jamf deployment scripts for Macs in `scripts-mac/`. We now need to do the equivalent for Windows using **Microsoft Intune**. The organization uses Intune for managing Windows devices.

We have no prior Intune experience. This investigation covers how Intune works, how it compares to Jamf, and what the repo structure should look like.

---

## What is Intune?

Microsoft Intune is a cloud-based endpoint management service. For Windows, it does what Jamf does for Macs — deploy apps, push configuration, enforce compliance, and run scripts remotely.

### How Intune compares to Jamf

| Concept | Jamf (Mac) | Intune (Windows) |
| ------- | ---------- | ---------------- |
| Script language | Bash | PowerShell |
| Script runs as | `root` | `SYSTEM` (equivalent to root) |
| App packaging | `.pkg` or `.dmg` | `.intunewin` (via Win32 Content Prep Tool) |
| Script upload | Settings > Scripts | Devices > Scripts > Platform scripts |
| Check-in frequency | Every 5-15 minutes | Every 8 hours (+ on reboot) |
| Triggers | Login, logout, recurring, enrollment, Self Service | Enrollment + 8-hour check-in only |
| Self-service | Jamf Self Service app | Company Portal app |
| Verification | Extension attributes, Smart Groups | Detection rules, compliance policies |
| Config profiles | Jamf-managed MDM profiles | Intune Configuration Profiles + Settings Catalog |
| Remediation | Policies re-run on trigger | Proactive Remediations (detect + remediate script pairs) |

### Key differences for script authors

1. **Slower feedback loop** — Intune checks in every 8 hours (vs Jamf's 5-15 minutes). You can force a sync from the device or the Intune portal.
2. **No event triggers** — Unlike Jamf's login/logout/recurring triggers, Intune scripts run once on check-in. For recurring tasks, use Proactive Remediations.
3. **Everything needs packaging** — Jamf lets you attach scripts directly to policies. Intune's Win32 approach requires packaging with the Content Prep Tool for anything beyond a one-off script.
4. **Detection rules are essential** — Intune determines whether to install an app based on detection rules. If the app is detected, Intune skips installation. This is how Intune achieves idempotency.
5. **PowerShell replaces bash** — Same concepts (silent, unattended, system-level), different language.
6. **Scripts run once** — Intune platform scripts execute once per device (unless the script content changes). For apps, use Win32 packaging instead.

---

## How Intune deploys applications

### Method 1: Microsoft Store apps (simplest)

Intune integrates with the Microsoft Store. Admins search, select, and assign apps directly. Updates are automatic. Best for standard tools that are available in the Store.

### Method 2: Win32 apps (recommended for most scenarios)

The most flexible method. You package installers and scripts into a `.intunewin` file using the **Microsoft Win32 Content Prep Tool**, then upload to Intune with install/uninstall commands and detection rules.

**Workflow:**

1. Write `install.ps1` and `uninstall.ps1` PowerShell scripts
2. Place scripts + any installers in a folder
3. Run `IntuneWinAppUtil.exe -c <folder> -s install.ps1 -o <output>` to create `.intunewin`
4. Upload to Intune portal (Apps > Windows > Add > Win32)
5. Set install command: `powershell.exe -ExecutionPolicy Bypass -File install.ps1`
6. Set uninstall command: `powershell.exe -ExecutionPolicy Bypass -File uninstall.ps1`
7. Configure detection rules (file exists, registry key, or custom script)
8. Assign to groups: Required (auto-install) or Available (self-service via Company Portal)

### Method 3: Direct PowerShell scripts (one-off tasks)

Upload a `.ps1` file directly in Intune (Devices > Scripts > Platform scripts). Limited: runs once, 200 KB max, 30-minute timeout, no detection rules. Best for configuration tasks, not app installs.

### Method 4: winget integration (auto-updating)

Package a PowerShell script that calls `winget install <package-id>` as a Win32 app. Gives you always-latest-version deployments. Winget is the Windows equivalent of Homebrew.

---

## What is a .intunewin file?

Intune's packaging format. Created by the Win32 Content Prep Tool (`IntuneWinAppUtil.exe`, available on [GitHub](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)). It is a compressed and encrypted archive containing:

- All source files (installer, scripts, supporting files)
- Encryption metadata for secure transport
- MSI metadata (product code, version) if the source is an MSI

**Packaging command:**

```
IntuneWinAppUtil.exe -c <source_folder> -s <setup_file> -o <output_folder> [-q]
```

---

## Detection rules

Detection rules tell Intune how to verify whether an app is already installed. Without correct detection rules, Intune will keep trying to install (or skip when it shouldn't).

| Type | How it works |
| ---- | ------------ |
| MSI product code | Check if a specific MSI product GUID is registered |
| File/folder | Check if a file exists at a path, optionally with version/size |
| Registry | Check if a registry key/value exists and matches expected data |
| Custom script | Run a PowerShell script — exit code 0 + stdout output = detected |

---

## Questions and Answers

### Q1–Q3: Repo structure and standards

Answered earlier in this document:

- **Q1**: Use `scripts-win/` parallel to `scripts-mac/`.
- **Q2**: Yes, one folder per app with install, uninstall, detect, README, and INTUNE.md.
- **Q3**: Yes. Created `rules/powershell.md` (PowerShell equivalent of `rules/bash.md`). Template and validation tool still needed.

### Q4: Should .intunewin files be checked into the repo?

**No — treat them as build artifacts.** The `.intunewin` format is a compressed+encrypted binary archive. It cannot be diffed or merged by git. The repo contains only the source scripts and documentation. Each package has a `build.ps1` that creates the `.intunewin` on demand from the devcontainer.

Packaging is done using `SvRooij.ContentPrep.Cmdlet` — a clean-room reimplementation that works on PowerShell 7/Linux. Falls back to the official Windows-only `IntuneWinAppUtil.exe` if needed. See the "Repo structure" section for details.

### Q5: PowerShell script standard

Answered. Created `rules/powershell.md` with the same structure as `rules/bash.md`: metadata, logging, help, strict mode, error codes, verification patterns.

### Q6: Winget vs our own install scripts

**Recommendation: Use our own PowerShell install scripts wrapped in .intunewin. Do not rely on winget.**

| Factor | Winget | Our install scripts (.intunewin) |
| ------ | ------ | -------------------------------- |
| Setup effort | Low (one-liner) | Medium (write script + package) |
| Maintenance | Low (auto-latest) | Low (change URL + version in script) |
| Reliability as SYSTEM | Poor — known issues | Good (we control the download + install) |
| Offline support | None | None (both download at runtime) |
| Intune detection/reporting | Custom scripts only | Native detection rules |
| Error handling | Generic winget errors | Custom error codes and logging |
| Works on all Windows editions | No (LTSC, Store-disabled) | Yes |

**Why winget fails in enterprise:**

1. **SYSTEM context problems** — winget is installed per-user via MSIX. The SYSTEM account may not have winget in PATH, may not have sources configured, and the Store source requires a user token.
2. **Not guaranteed present** — Windows 10 LTSC, machines with Store disabled, and fresh images may not have winget.
3. **We lose control** — winget decides how to install, what flags to use, where to download from. With our own scripts we control every step, add retry logic, hash verification, and structured error codes that match our script standard.

### Q7: Detection scripts — separate files or embedded?

**Separate `.ps1` files in the repo, uploaded to Intune as custom detection scripts.**

Each package folder contains a `detect.ps1` script. This script is:

1. Developed and validated in the repo alongside install/uninstall scripts
2. Tested locally on a Windows machine
3. Uploaded to Intune when configuring the Win32 app (Apps > Win32 > Detection rules > Custom detection script)

Detection scripts follow a strict Intune convention:

- Exit 0 + stdout output = app is detected (installed)
- Exit 0 + no output = app is NOT detected (not installed)
- Exit non-zero = detection error

Keeping detection scripts as separate files means they are version-controlled, testable, and reviewable — not buried in Intune portal configuration.

### Q8–Q9: Windows developer toolset

**Mirror the Mac toolset, plus Windows-specific prerequisites.**

The core developer workflow is identical on both platforms: clone a repo, open in VS Code, work inside a devcontainer. The tools that enable that are the same:

| Capability | Mac | Windows |
| ---------- | --- | ------- |
| Container runtime | Rancher Desktop | Rancher Desktop (WSL2 backend) |
| Code editor | VS Code | VS Code |
| Git | Xcode CLT | Git for Windows |
| Devcontainer setup | devcontainer-toolbox (bash) | devcontainer-toolbox (PowerShell) |
| Linux subsystem | N/A (Mac is Unix) | WSL2 (required prerequisite) |

**Why Rancher Desktop on Windows (not Docker Desktop):**

- Zero licensing cost (Apache 2.0) — Docker Desktop requires paid subscriptions for companies above 250 employees or $10M revenue
- Cross-platform consistency — same tool on both platforms, one set of docs
- Deployment profiles work the same way (plist on Mac, registry on Windows)
- The WSL2 dependency is not a drawback — WSL2 is needed anyway for good devcontainer performance

**Windows-specific additions:**

- **WSL2** — must be deployed first. Mac doesn't need this because macOS is already Unix.
- **Git for Windows** — includes Git Credential Manager for Azure DevOps authentication. On Mac, git comes with Xcode CLT and uses macOS Keychain.

**Filesystem performance note:** On Windows, repos should be cloned into the WSL filesystem (`\\wsl$\...`) for native performance. Cloning to the Windows filesystem (`C:\Users\...`) causes slow cross-OS filesystem access in devcontainers. This is a key difference from Mac where there is no such split.

### Q10: Testing without Intune — USB disk workflow

**Yes. Same approach as Mac: copy scripts to USB, run on a Windows machine.**

| Concept | Mac (Jamf) | Windows (Intune) |
| ------- | ---------- | ---------------- |
| Script language | bash | PowerShell |
| Run as admin | `sudo bash script.sh` | Admin PowerShell: `powershell -ExecutionPolicy Bypass -File script.ps1` |
| Match MDM context | Already root via sudo | Use PsExec: `psexec -i -s powershell.exe -ExecutionPolicy Bypass -File script.ps1` |
| USB filesystem | exFAT (works on both Mac and Windows) | exFAT |

**Practical workflow:**

1. Format USB as **exFAT** (native on both Mac and Windows, avoids NTFS Zone.Identifier issues)
2. Copy `scripts-win/` folder to USB
3. Plug USB into test Windows machine
4. Open PowerShell as Administrator (Win+X > "Terminal (Admin)")
5. Run: `powershell -ExecutionPolicy Bypass -File "E:\wsl2\tests\run-all-tests.ps1"`
6. Bring USB back with `logs/test.log`

**For SYSTEM context testing** (matches Intune exactly):

Use PsExec from Sysinternals to run as NT AUTHORITY\SYSTEM:

```powershell
psexec -accepteula -i -s powershell.exe -ExecutionPolicy Bypass -File "E:\wsl2\tests\run-all-tests.ps1"
```

Running as Administrator is close enough for most tests. The differences (user profile paths, HKCU registry hive) only matter for scripts that read/write user-specific state.

**`-ExecutionPolicy Bypass`** is critical — it matches what Intune uses and avoids execution policy friction on the test machine.

### Q11: Testing .intunewin packaging locally

**Partially possible:**

- **Extract and inspect**: Use `Unlock-IntuneWinPackage` (from SvRooij.ContentPrep.Cmdlet) to decrypt and verify the contents are correct.
- **Test install commands before packaging**: Run the install/uninstall scripts directly on a test machine (the USB workflow above). This tests the actual logic.
- **Windows Sandbox**: The `Intune-App-Sandbox` PowerShell module can run `.intunewin` packages in Windows Sandbox as SYSTEM, mimicking Intune behavior.
- **What you cannot test locally**: Intune's download-decrypt pipeline, dependency chains, assignment targeting, and compliance reporting require actual Intune.

---

## Current State

| Tool | Mac (Jamf) | Windows (Intune) |
| ---- | ---------- | ---------------- |
| Rancher Desktop | `scripts-mac/rancher-desktop/` (install, config, k8s, uninstall + tests) | Not started |
| Devcontainer toolbox | `scripts-mac/devcontainer-toolbox/` (pull, init-install, init + tests) | Not started |
| VS Code | Not automated (manual install) | Not started |
| Git | Not automated (Xcode CLT) | Not started |
| WSL2 | N/A (Mac doesn't have WSL) | Done (features automated, kernel manual). See [INVESTIGATE-wsl-intune.md](INVESTIGATE-wsl-intune.md). |

---

## What goes in the .intunewin package?

This is the key design decision. Intune requires `.intunewin` packages for Win32 app deployment (the only method with detection rules, dependencies, and reporting). But there are two approaches to what the package contains.

### Option A: Bundle the installer in the package

The `.intunewin` contains the full installer (MSI/EXE) plus the install script. Intune delivers everything to the endpoint.

```
rancher-desktop/
└── source/
    ├── install.ps1                          # Runs msiexec on the bundled MSI
    ├── Rancher.Desktop.Setup.1.22.0.msi     # ~500 MB
    └── uninstall.ps1
```

**Pros:**

- Self-contained — works even if the endpoint has no internet access
- Exact version guaranteed — no risk of a newer version behaving differently
- The enterprise "textbook" approach

**Cons:**

- Large packages (Rancher Desktop MSI is ~500 MB, Git ~60 MB, VS Code ~100 MB)
- Must repackage every time a new version is released (download new installer, rebuild .intunewin, re-upload to Intune)
- Repo cannot store the MSI files (too large for git) — need a separate download step before packaging
- High maintenance burden for keeping versions current

### Option B: Script downloads the installer at runtime

The `.intunewin` contains only the PowerShell script. The script downloads the installer from the vendor at install time, then runs it. This is how our Mac scripts work.

```
rancher-desktop/
└── source/
    ├── install.ps1      # Downloads MSI from GitHub releases, runs msiexec
    └── uninstall.ps1
```

**Pros:**

- Tiny packages (just the script, a few KB)
- Updating version = change a URL and version number in the script
- Same pattern as our Mac bash scripts (download → install → verify)
- No large binaries to manage outside the repo
- `.intunewin` can be rebuilt from the repo scripts alone — no external files needed

**Cons:**

- Requires internet access on the endpoint at install time
- Download can fail (network issues, vendor CDN down)
- Slightly slower install (download time)
- Less predictable — the download URL could break if the vendor changes their release structure

### Option B-hybrid: Script downloads, with retry and verification

Same as Option B, but the script includes:

- Download with retry logic
- Hash verification after download (SHA256 checksum from the vendor)
- Clear error messages if the download fails
- Cleanup of partial downloads

This addresses the reliability concerns while keeping the maintenance benefits.

### Recommendation: Option B-hybrid (download at runtime)

Reasons:

1. **Matches what works on Mac.** Our bash scripts already follow this pattern and it works well. Not because we want to copy Mac, but because the pattern has proven reliable for our use case.
2. **Lowest maintenance.** Updating a deployment = edit a version number and URL in the script. No repackaging, no re-uploading large files.
3. **Our endpoints have internet access.** These are developer workstations, not air-gapped factory machines. The offline argument doesn't apply to us.
4. **The .intunewin can be built entirely from the repo.** No external dependencies, no MSI files stored elsewhere. Run `build.ps1` in the devcontainer and the package is ready.
5. **Hash verification makes it safe.** The script verifies the download before installing, which is actually safer than Option A where an admin could accidentally bundle the wrong MSI.

If we later need offline deployment (air-gapped environments), we can switch specific packages to Option A. But that's not our situation today.

### Per-tool approach

| Tool | .intunewin contains | Why |
| ---- | ------------------- | --- |
| WSL2 | Script only (DISM commands) | No installer to download — it's a Windows feature |
| Rancher Desktop | Script that downloads MSI | MSI is ~500 MB, available from GitHub releases |
| Git for Windows | Script that downloads EXE | EXE is ~60 MB, available from GitHub releases |
| VS Code | Script that downloads EXE | EXE is ~100 MB, available from vendor CDN |
| Windows Terminal | N/A (Microsoft Store) | Pre-installed on Win 11 |

---

## Repo structure

One folder per app under `scripts-win/`. Each folder is a self-contained package.

```
scripts-win/
├── wsl2/
│   ├── README.md
│   ├── install.ps1
│   ├── detect.ps1
│   ├── INTUNE.md
│   ├── build.ps1
│   ├── .gitignore
│   └── tests/
│       ├── test-helpers.ps1
│       ├── test-0-prerequisites.ps1
│       ├── ...
│       └── run-all-tests.ps1
├── rancher-desktop/
│   ├── README.md
│   ├── install.ps1
│   ├── uninstall.ps1
│   ├── detect.ps1
│   ├── INTUNE.md
│   ├── build.ps1
│   ├── .gitignore
│   └── tests/
├── git/
├── vscode/
└── devcontainer-toolbox/
```

| File | Purpose |
| ---- | ------- |
| `install.ps1` | Downloads and installs the app (the main deployment script) |
| `uninstall.ps1` | Removes the app (not all packages need this — e.g. WSL2) |
| `detect.ps1` | Intune detection script (exit 0 + output = detected) |
| `build.ps1` | Creates the `.intunewin` package from the scripts in this folder |
| `INTUNE.md` | Documents the Intune portal configuration (install command, detection rule, assignments) |
| `README.md` | What the package does, how it works |
| `.gitignore` | Ignores `logs/` and `*.intunewin` |
| `tests/` | USB test scripts mirroring the Mac test pattern |

### Why this structure

- **Flat and simple** — one folder per app, no nested `packages/` or `source/` directories
- **Self-contained** — each folder has everything needed to build, deploy, and test
- **`build.ps1` in each folder** — creates the `.intunewin` from the devcontainer. No need for a Windows machine just to package.
- **`INTUNE.md` instead of Intune portal screenshots** — documents the exact settings to configure in the Intune portal (install command, uninstall command, detection rule, requirement rules, assignment groups). This is the source of truth for portal configuration.
- **`.gitignore` per package** — ignores `logs/` (test output) and `*.intunewin` (build artifacts)

### .intunewin packaging from the devcontainer

Each package has a `build.ps1` that creates the `.intunewin`:

```powershell
# Requires: SvRooij.ContentPrep.Cmdlet
# Install once: Install-Module SvRooij.ContentPrep.Cmdlet -Scope AllUsers
New-IntuneWinPackage -SourcePath ./source -SetupFile install.ps1 -DestinationPath ./
```

This runs on Linux (PowerShell 7) using the `SvRooij.ContentPrep.Cmdlet` module. The generated `.intunewin` is a build artifact — not checked into git.

If Linux packaging fails for any reason, the same scripts can be packaged on a Windows machine using the official `IntuneWinAppUtil.exe`.

---

## Deployment strategy

### Intune deployment method per tool

| Tool | Intune method | Context | Reboot | Dependency |
| ---- | ------------- | ------- | ------ | ---------- |
| WSL2 | Win32 app (script-only) | SYSTEM | Yes | None |
| Rancher Desktop | Win32 app (downloads MSI) | User | No | WSL2 |
| Git for Windows | Win32 app (downloads EXE) | SYSTEM | No | None |
| VS Code | Win32 app (downloads EXE) | SYSTEM | No | None |
| Windows Terminal | Microsoft Store | N/A | No | None |

### Rancher Desktop requires User context

Rancher Desktop must deploy in User context (`ALLUSERS=0`) because SYSTEM context installation fails with error `0x80070643`. This means:

- The user must be logged in for the install to run
- Intune triggers the install at next check-in after the user logs in
- The app installs to `%LOCALAPPDATA%\Programs\Rancher Desktop\` (per-user)

This affects the deployment timeline: on a brand new machine, WSL2 installs first (SYSTEM, during setup), then after reboot and first user login, Rancher Desktop installs.

### Reboot handling for WSL2

WSL2 enables Windows features that require a reboot. Options in Intune:

- **Return code 3010** — the install script exits with code 3010 ("soft reboot"), Intune prompts the user to restart
- **Intune restart policy** — configure a grace period (e.g. 24 hours) before forcing a restart
- **Proactive Remediation** — detect if reboot is pending, notify the user

The smoothest experience: exit 3010 from the WSL2 install script, let Intune show a "restart required" toast notification. The user reboots when convenient.

### Suggested starting order

1. ~~**PowerShell tooling**~~ — DONE
2. ~~**WSL2**~~ — DONE (features automated, kernel installed manually). See [INVESTIGATE-wsl-intune.md](INVESTIGATE-wsl-intune.md).
3. **Rancher Desktop** — next up, depends on WSL2 (working), tests User context deployment
4. **Git for Windows** — no dependencies, tests standard SYSTEM context deployment
5. **VS Code** — no dependencies, similar to Git
6. **Devcontainer toolbox** — depends on Rancher Desktop + Git, do last

---

## PowerShell in the devcontainer

We develop in a Linux devcontainer. PowerShell 7 (`pwsh`) runs on Linux and can validate scripts (syntax, linting, metadata) — but cannot test Windows-specific operations (registry, MSI, services).

### Installing PowerShell

All three are installed via `.devcontainer.extend/project-installs.sh`:

- **PowerShell 7** (`pwsh`) -- from GitHub release tar.gz (the Microsoft APT repo only has amd64, our devcontainer runs on arm64)
- **PSScriptAnalyzer** -- linter for `.ps1` files (equivalent of shellcheck)
- **SvRooij.ContentPrep.Cmdlet** -- creates `.intunewin` packages on Linux (cross-platform alternative to Windows-only `IntuneWinAppUtil.exe`)

This is a temporary solution. A proper `tool-powershell` has been requested from the devcontainer-toolbox maintainers -- see `docs/ai-developer/devcontainer-toolbox-issues/ISSUE-lightweight-powershell.md`.

### What we can validate from Linux

| Check | How | Works on Linux? |
| ----- | --- | --------------- |
| Syntax | PowerShell AST parser (`[Parser]::ParseFile()`) | Yes |
| Linting | PSScriptAnalyzer module | Yes |
| Metadata fields | grep for `$SCRIPT_ID`, `$SCRIPT_NAME`, etc. | Yes |
| Help output format | `pwsh -File script.ps1 -Help` | Yes |
| Logic testing | Pester framework with mocked Windows cmdlets | Yes |

### What we cannot test from Linux

| Category | Why | Workaround |
| -------- | --- | ---------- |
| Registry reads/writes | No Windows registry on Linux | Mock in Pester; test on Windows |
| MSI/EXE installation | No Windows installer | Test on Windows VM |
| Windows services | No Service Control Manager | Mock in Pester; test on Windows |
| Detection scripts | Check Windows-specific state | Must test on Windows endpoint |
| File paths (`C:\Program Files`) | Paths don't exist | Test on Windows |

### Validation tool

We can create a `validate-powershell.sh` (bash wrapper calling `pwsh`) mirroring the existing `validate-bash.sh`. It would check syntax, PSScriptAnalyzer, metadata fields, and help output — all from Linux.

### Testing workflow

```
Devcontainer (Linux)          Windows VM/Device
├── validate-powershell.sh    ├── Run scripts locally
│   ├── Syntax parse          ├── Test MSI install/uninstall
│   ├── PSScriptAnalyzer      ├── Verify detection rules
│   ├── Metadata check        ├── Test registry operations
│   └── Help output check     └── Intune test deployment
└── Pester unit tests
    └── Mocked Windows cmdlets
```

---

## Rancher Desktop on Windows — enterprise deployment research

### MSI installer

Rancher Desktop provides an MSI installer (`Rancher.Desktop.Setup.X.Y.Z.msi`) from the [GitHub releases page](https://github.com/rancher-sandbox/rancher-desktop/releases). Current version: 1.22.0.

**Silent install commands:**

```powershell
# Per-user (recommended for Intune — works in User context)
msiexec /i "Rancher.Desktop.Setup.1.22.0.msi" /qn /norestart ALLUSERS=0 WSLINSTALLED=1

# Per-machine (problematic in Intune SYSTEM context)
msiexec /i "Rancher.Desktop.Setup.1.22.0.msi" /qn /norestart ALLUSERS=1 WSLINSTALLED=1
```

**MSI properties:**

| Property | Values | Purpose |
| -------- | ------ | ------- |
| `ALLUSERS` | `0` (per-user), `1` (per-machine) | Installation scope |
| `WSLINSTALLED` | `1` | Skip WSL detection (use when WSL is pre-installed) |
| `APPLICATIONFOLDER` | Path | Custom install directory |

**Install paths:**

| Mode | Path |
| ---- | ---- |
| Per-machine | `C:\Program Files\Rancher Desktop\` |
| Per-user | `%LOCALAPPDATA%\Programs\Rancher Desktop\` |

### Known Intune deployment issues

From [GitHub issue #7356](https://github.com/rancher-sandbox/rancher-desktop/issues/7356):

1. **SYSTEM context fails** — Deploying in Intune's default SYSTEM context causes error `0x80070643`. The working solution is deploying in **User context** with `ALLUSERS=0`.
2. **WSL must be pre-installed** — The installer tries to install WSL if missing, but this fails in silent/SYSTEM context. Deploy WSL separately first.
3. **Auto-updater elevation issue** ([#6377](https://github.com/rancher-sandbox/rancher-desktop/issues/6377)) — The auto-updater suppresses UAC prompts, causing updates to fail for non-admin users. Workaround: disable auto-updates via locked deployment profile.

### Deployment profiles on Windows

Windows uses **registry keys** instead of macOS plist files:

| Registry path | Purpose |
| ------------- | ------- |
| `HKLM\Software\Policies\Rancher Desktop\Defaults` | Default settings (first run only) |
| `HKLM\Software\Policies\Rancher Desktop\Locked` | Locked settings (enforced every startup) |

Profiles are generated using `rdctl`:

```bash
# Export current settings as .reg file
rdctl create-profile --output reg --hive hklm --type locked --from-settings > locked.reg

# Import on target machine (requires admin)
reg import locked.reg
```

This is the Windows equivalent of our macOS plist approach (`rancher-desktop-k8s.sh --lock`).

### Detection rules for Intune

- **File-based** (recommended): Check for `%LOCALAPPDATA%\Programs\Rancher Desktop\Rancher Desktop.exe` (per-user install)
- **Registry-based**: Check under `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\` for per-user
- **Custom script**: PowerShell script checking multiple possible paths

### Recommended Intune deployment approach

1. **Pre-deploy WSL** as a separate Intune package (dependency)
2. **Deploy Rancher Desktop** in User context: `msiexec /i "Rancher.Desktop.Setup.1.22.0.msi" /qn /norestart ALLUSERS=0 WSLINSTALLED=1`
3. **Deploy locked profile** via registry import script (disable auto-updates, set container engine, etc.)
4. **Detection rule**: File exists `%LOCALAPPDATA%\Programs\Rancher Desktop\Rancher Desktop.exe`

---

## WSL2 deployment

**Full details**: See [INVESTIGATE-wsl-intune.md](INVESTIGATE-wsl-intune.md) — all WSL2 research, implementation details, test results, and future automation notes are consolidated there.

**Summary**: We built a features package (`scripts-win/wsl2/`) that enables WSL2 Windows features via DISM. It works, but WSL2 also needs a kernel component that could not be automated via Intune. The user installed WSL manually on the test PC (`wsl --install` + `wsl --install ubuntu`). WSL2 is now working. Automated kernel deployment was planned but abandoned.

**Current status**: WSL2 is a solved prerequisite for the test PC. If we need to deploy to more machines, revisit `INVESTIGATE-wsl-intune.md`.

---

## Test environment

### What we have

| Item | Details |
| ---- | ------- |
| **Windows PC** | XYZ-PW0MKCB1, enrolled in the organization's Intune. This is a real managed machine, not a lab VM. |
| **USB stick** | Drive letter D:. Same stick used for Mac testing (exFAT). |
| **Devcontainer** | Linux (Debian 12 bookworm, arm64). Has PowerShell 7, PSScriptAnalyzer, and shellcheck. |

### Getting admin rights on the Windows PC

The PC is managed — users do not have admin rights by default. To get temporary admin access:

1. Open the **Admin on Demand** application on the PC
2. Enter a reason explaining why admin access is needed (e.g. "Testing developer deployment scripts — need to run PowerShell as Administrator to check Windows features and WSL status")
3. Submit the request — someone in the organization must approve it
4. After approval, the PC reboots
5. When the PC comes back up, the user has admin rights (temporary)

This means:
- **USB testing requires planning** — you need admin rights approved before you can run scripts as Administrator. Request access before going to the PC.
- **Intune deployments are not affected** — Intune runs scripts as SYSTEM, which has admin-level privileges regardless of the user's rights.

### Important: "Admin user" vs "Run as Administrator"

Having admin rights on the PC (via Admin on Demand) is **not the same** as running PowerShell as Administrator. Windows uses User Account Control (UAC) — even admin users run with standard user tokens by default. Each PowerShell window must be explicitly launched elevated.

**Two steps are required:**

1. **Get admin rights** via Admin on Demand (makes your account a member of the Administrators group)
2. **Launch PowerShell as Administrator** — right-click Windows Terminal or PowerShell and choose "Run as administrator", or use Win+X > "Terminal (Admin)". Click Yes on the UAC prompt. The title bar should say **"Administrator: Windows PowerShell"**.

If you skip step 2, commands like `Get-WindowsOptionalFeature` and WMI MDM queries will fail with "requires elevation" even though you are an admin user. This was confirmed by three diagnostic runs where the user had admin rights but PowerShell was not elevated.

### Windows PC specs (from diagnostic run 2026-02-11)

| Item | Value |
| ---- | ----- |
| OS | Windows 11 Pro 24H2 (build 10.0.26100) |
| Architecture | AMD64 (x64-based PC) |
| CPU | AMD Ryzen 7 Pro 7735U with Radeon Graphics |
| RAM | 14.8 GB |
| Disk | C: 407 GB free / 475 GB total |
| Virtualization | Hypervisor detected (BIOS virtualization enabled) |
| PowerShell | 5.1.26100.3624 (Desktop edition — Windows PowerShell, not PowerShell 7) |
| Execution policy | Bypass (effective) |
| User | AzureAD\terchris |

### WSL status

**Installed (manually).** Both Windows features enabled via our install script (DISM), kernel installed manually by the user (`wsl --install` + `wsl --install ubuntu`). WSL2 is working. See [INVESTIGATE-wsl-intune.md](INVESTIGATE-wsl-intune.md) for full history.

### Installed developer tools

| Tool | Status |
| ---- | ------ |
| Rancher Desktop | Not installed |
| Docker | Not installed |
| Git | Not installed |
| VS Code | Not installed |
| Windows Terminal | Installed |
| winget | Installed (v1.12.460) |

This is a clean machine — no developer tools to conflict with. We can install everything from scratch.

### Network connectivity

| Endpoint | Status |
| -------- | ------ |
| GitHub (github.com) | OK |
| Docker Hub (hub.docker.com) | OK |
| Microsoft CDN (packages.microsoft.com) | OK |
| VS Code CDN (update.code.visualstudio.com) | OK |

No network restrictions — the download-at-runtime approach (Option B-hybrid) will work.

### Intune enrollment

**Confirmed enrolled.** Both the WMI query (admin run) and registry check confirm MDM enrollment.

### Diagnostic script

`scripts-win/diagnostics/check-environment.ps1` gathers all of the above in one run. Output goes to both console and `logs/environment.log`. The `logs/` folder is gitignored.

**How to run it:**

1. Copy `scripts-win/diagnostics/` to the USB stick
2. Plug USB into the Windows PC
3. Open PowerShell **as Administrator** (see "Admin user vs Run as Administrator" above)
4. Run: `powershell -ExecutionPolicy Bypass -File "D:\diagnostics\check-environment.ps1"`
5. Bring the USB back — the log is at `diagnostics/logs/environment.log`

**Completed:** See [PLAN-windows-environment-diagnostic.md](completed/PLAN-windows-environment-diagnostic.md) for the full run history (4 runs, final run elevated with all checks complete).

### Testing considerations

Since the Windows PC is a real enrolled machine:

- **Be careful with uninstall testing** — don't uninstall something the organization depends on
- **WSL2 is safe to enable** — it's a Windows feature, enabling it doesn't break anything
- **Rancher Desktop is safe to install** — we want it on developer machines anyway
- **Run the diagnostic first** before running any install scripts

---

## USB testing workflow for Windows

Same approach as Mac: copy scripts to USB, run on a Windows machine. Uses exFAT filesystem so the same USB works on both Mac and Windows.

### Why exFAT

- Works natively on both Mac and Windows (no extra drivers)
- Does not support NTFS alternate data streams, so Zone.Identifier "downloaded from internet" flags are never an issue
- No 4 GB file size limit (unlike FAT32)
- PowerShell `.ps1` files work identically on all filesystems

### Test runner pattern

The Windows test runner (`run-all-tests.ps1`) mirrors the Mac pattern:

1. Warning banner explaining what the tests do
2. Elevation to Administrator (equivalent of Mac's `exec sudo bash "$0"`)
3. Logging to `logs/test.log`
4. Run tests in order, track pass/fail/skip
5. Print summary

### Administrator vs SYSTEM context

| Context | How to get it | When to use |
| ------- | ------------- | ----------- |
| Administrator | Open PowerShell as Admin, run script | Good enough for most tests |
| SYSTEM | PsExec: `psexec -i -s powershell.exe -ExecutionPolicy Bypass -File script.ps1` | Matches Intune exactly |

Running as Administrator is close enough for most scripts. The differences (user profile paths, HKCU registry hive) only matter for scripts that read/write user-specific state. PsExec is available from [Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec).

---

## PowerShell tooling for the devcontainer

To develop and validate PowerShell scripts from the Linux devcontainer we need tooling that mirrors what we have for bash. The bash equivalents are listed for reference.

### What exists

| Item | Status | Notes |
| ---- | ------ | ----- |
| PowerShell 7 (`pwsh`) | Installed | Temporary install via `project-installs.sh` -- requested as proper toolbox tool in ISSUE-lightweight-powershell.md |
| PSScriptAnalyzer 1.24.0 | Installed | Linter, equivalent of shellcheck |
| `rules/powershell.md` | Created | PowerShell equivalent of `rules/bash.md` |
| `templates/powershell/script-template.ps1` | Created | Standard PowerShell script template |
| `tools/validate-powershell.sh` | Created | Validates syntax, help, metadata, and PSScriptAnalyzer lint |
| `tools/set-version-powershell.sh` | Created | Version bump tool for `.ps1` files |
| `SvRooij.ContentPrep.Cmdlet` v0.4.0 | Installed | Creates `.intunewin` packages from the devcontainer |

See [PLAN-powershell-tooling.md](active/PLAN-powershell-tooling.md) for implementation details.

### ARM64 limitation

Microsoft's APT repository only ships PowerShell for amd64. Our devcontainer runs on arm64 (Apple Silicon Macs). The workaround is installing from the GitHub release tar.gz instead of APT. This is documented in ISSUE-lightweight-powershell.md for the toolbox maintainer.

---

## Next Steps

### Done

- [x] Decide on repo structure — `scripts-win/`, flat, one folder per app
- [x] Install PowerShell in devcontainer — temporary install via `project-installs.sh`
- [x] Create PowerShell script rules — `rules/powershell.md`
- [x] Research all open questions (Q4–Q11)
- [x] Research WSL2 deployment (DISM approach, reboot handling, detection rules)
- [x] Research USB testing workflow for Windows (exFAT, PsExec, Administrator vs SYSTEM)
- [x] Decide winget vs own scripts — own scripts for control and reliability
- [x] Decide what goes in .intunewin — script-only packages that download at runtime (Option B-hybrid)
- [x] Decide .intunewin packaging location — devcontainer using `SvRooij.ContentPrep.Cmdlet`
- [x] Diagnose Windows test PC — all checks complete (see [PLAN-windows-environment-diagnostic.md](completed/PLAN-windows-environment-diagnostic.md))

### Remaining

- [x] Install `SvRooij.ContentPrep.Cmdlet` in devcontainer
- [x] Create PowerShell script template
- [x] Create `tools/validate-powershell.sh` validation tool
- [x] Create `tools/set-version-powershell.sh` version bump tool
- [x] Create PLAN for PowerShell tooling (see [PLAN-powershell-tooling.md](active/PLAN-powershell-tooling.md))
- [x] WSL2 deployment — features automated, kernel installed manually. All details consolidated in [INVESTIGATE-wsl-intune.md](INVESTIGATE-wsl-intune.md).
- [x] Create PLAN for Rancher Desktop Intune package — see [PLAN-002-rancher-desktop.md](completed/PLAN-002-rancher-desktop.md) (completed)
