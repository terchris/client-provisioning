# Plan: Windows test PC environment diagnostic

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Complete

**Goal**: Gather full diagnostic information about the Windows test PC so we understand the target environment before writing deployment scripts.

**Last Updated**: 2026-02-11

**Based on**: [INVESTIGATE-intune-windows-deployment.md](../backlog/INVESTIGATE-intune-windows-deployment.md)

---

## Problem

We are about to write PowerShell deployment scripts for Windows (Intune). We have a Windows test PC enrolled in the organization's Intune, but we don't know what's already installed on it — Windows version, WSL status, virtualization support, existing developer tools, network access, etc. We need this information before writing any deployment scripts.

---

## Phase 1: Create diagnostic script — DONE

### Tasks

- [x] 1.1 Create `scripts-win/diagnostics/check-environment.ps1` that gathers:
  - System info (Windows version, build, CPU, RAM, architecture)
  - Disk space
  - Virtualization support (Hyper-V, BIOS settings)
  - PowerShell version and execution policy
  - WSL status (features, version, distributions)
  - Installed developer tools (Rancher Desktop, Docker, Git, VS Code, Windows Terminal, winget)
  - Intune/MDM enrollment status
  - Network connectivity (GitHub, Docker Hub, Microsoft CDN, VS Code CDN)
  - User context (current user, admin rights, profile paths)
- [x] 1.2 Script follows the standard template (metadata, logging, help, param block)
- [x] 1.3 Output goes to both console and `logs/environment.log`
- [x] 1.4 Syntax check passes (`pwsh` parser)
- [x] 1.5 PSScriptAnalyzer — no errors (warnings for `Write-Host` are expected per our standard)

### Validation

Script parses, help works, PSScriptAnalyzer has no errors.

---

## Phase 2: Run diagnostic on Windows PC — DONE

Four runs total. The 4th run was elevated (Administrator) and captured all checks.

### Lesson learned: "Admin user" vs "Run as Administrator" on Windows

Having admin rights on the PC (via Admin on Demand) is **not the same** as running PowerShell as Administrator. Windows uses User Account Control (UAC) — even admin users run with standard tokens by default. Each PowerShell window must be explicitly launched elevated.

You need both:

1. **Get admin rights** via Admin on Demand (makes your account a member of the Administrators group)
2. **Launch PowerShell as Administrator** — right-click > "Run as administrator", or Win+X > "Terminal (Admin)". The title bar should say **"Administrator: Windows PowerShell"**.

### Tasks

- [x] 2.1 Copy `scripts-win/diagnostics/` folder to the USB stick
- [x] 2.2 Plug USB into the Windows test PC
- [x] 2.3 Open PowerShell as Administrator
- [x] 2.4 Run: `powershell -ExecutionPolicy Bypass -File "D:\diagnostics\check-environment.ps1"`
- [x] 2.5 Verify output appears on screen and log file is created at `diagnostics/logs/environment.log`
- [x] 2.6 Bring USB back to the devcontainer

### Run history

| Run | Time | Admin? | New findings |
| --- | ---- | ------ | ------------ |
| 1st | 08:09 | No | All system info, dev tools, network |
| 2nd | 13:28 | No | Intune enrollment confirmed (registry fix worked) |
| 3rd | 13:35 | No | User had admin rights but PowerShell was not elevated |
| 4th | 13:42 | **Yes** | WSL features: both Disabled. MDM enrolled: YES. All checks complete. |

### Validation

`logs/environment.log` contains all diagnostic sections with no elevation errors.

---

## Phase 3: Analyze results and update investigation — DONE

All findings analyzed and investigation updated.

### Tasks

- [x] 3.1 Read `logs/environment.log` in the devcontainer
- [x] 3.2 Update the "Test environment" section in `INVESTIGATE-intune-windows-deployment.md` with the actual findings:
  - Windows version and build — Windows 11 Pro 24H2
  - Whether WSL is already installed — NOT installed (both features Disabled)
  - Whether virtualization is enabled — Hypervisor detected (yes)
  - Which developer tools are already present — None (clean machine, only Windows Terminal + winget)
  - Network connectivity status — All endpoints OK
  - Intune enrollment — YES (both WMI and registry confirmed)
- [x] 3.3 Identify any surprises that affect the deployment approach
  - No surprises — clean machine, virtualization enabled, network open. Ideal for testing.
- [x] 3.4 Update investigation with admin run results (WSL features Disabled, MDM enrolled YES)

### Validation

Investigation reflects the complete target environment. All checks passed with elevation.

---

## Acceptance Criteria

- [x] Diagnostic script created and validated
- [x] Script runs successfully on the Windows PC (4th run as Administrator — all checks complete)
- [x] `logs/environment.log` brought back and analyzed
- [x] Investigation updated with actual target environment details
- [x] Intune enrollment confirmed (WMI + registry)
- [x] WSL feature status confirmed (both Disabled)
- [x] Any deployment approach changes documented based on findings (none needed — clean machine, all good)

---

## Files

- `scripts-win/diagnostics/check-environment.ps1` (created)
- `docs/ai-developer/plans/backlog/INVESTIGATE-intune-windows-deployment.md` (to be updated in Phase 3)
