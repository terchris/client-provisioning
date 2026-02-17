# Feature: Rancher Desktop Install Script

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Complete

**Goal**: Create a Jamf-deployable script that installs Rancher Desktop on Apple Silicon Macs with Docker (moby) as the container engine and sensible resource defaults.

**Last Updated**: 2026-02-06

**Based on**: [INVESTIGATE-rancher-desktop-install.md](../backlog/INVESTIGATE-rancher-desktop-install.md)

---

## Overview

Install Rancher Desktop from the official `.dmg` release, configure it via a deployment profile (plist) with Docker (moby) engine, Kubernetes disabled, and auto-detected RAM/CPU defaults.

This script handles installation only. The uninstall script is covered in [PLAN-rancher-desktop-uninstall.md](PLAN-rancher-desktop-uninstall.md). Additional scripts are tracked in [INVESTIGATE-rancher-desktop-install.md](../backlog/INVESTIGATE-rancher-desktop-install.md).

---

## Phase 1: Create the install script from template — DONE

### Tasks

- [x] 1.1 Copy `docs/ai-developer/templates/script-template.sh` to `scripts/rancher-desktop/rancher-desktop-install.sh`
- [x] 1.2 Fill in metadata:
  - `SCRIPT_ID="rancher-desktop-install"`
  - `SCRIPT_NAME="Rancher Desktop Install"`
  - `SCRIPT_VER="0.1.0"`
  - `SCRIPT_DESCRIPTION="Install Rancher Desktop on Apple Silicon Macs via Jamf"`
  - `SCRIPT_CATEGORY="DEVOPS"`
- [x] 1.3 Add custom flags to help and argument parsing:
  - `--kubernetes` / `--no-kubernetes` — enable/disable k3s (default: disabled)
  - `--memory <GB>` — override RAM allocation (default: auto-detect 25% of host)
  - `--cpus <N>` — override CPU allocation (default: auto-detect 50% of host)
  - `--version <VER>` — Rancher Desktop version to install (default: `1.22.0`)
- [x] 1.4 Run tests to confirm template passes: `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop`

### Validation

Tests pass (syntax, help, metadata).

---

## Phase 2: Implement the install logic — DONE

### Tasks

- [x] 2.1 Add check: skip if Rancher Desktop is already installed in `/Applications/Rancher Desktop.app`
- [x] 2.2 Download the `.dmg` for Apple Silicon:
  - URL pattern: `https://github.com/rancher-sandbox/rancher-desktop/releases/download/v<VER>/Rancher.Desktop-<VER>.aarch64.dmg`
  - Download to a temp location
  - Verify download succeeded
- [x] 2.3 Mount the `.dmg`, copy `Rancher Desktop.app` to `/Applications/`, unmount
- [x] 2.4 Clear Gatekeeper quarantine: `xattr -cr /Applications/Rancher\ Desktop.app`
- [x] 2.5 Clean up temp files (downloaded `.dmg`)
- [x] 2.6 Run tests: `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop`

### Validation

User confirms install logic looks correct.

---

## Phase 3: Implement the deployment profile — DONE

### Tasks

- [x] 3.1 Auto-detect host resources:

  ```bash
  total_ram_gb=$(sysctl -n hw.memsize | awk '{printf "%d", $1/1024/1024/1024}')
  total_cpus=$(sysctl -n hw.ncpu)
  default_ram=$((total_ram_gb / 4))
  default_cpus=$((total_cpus / 2))
  ```

- [x] 3.2 Apply `--memory`, `--cpus`, `--kubernetes`/`--no-kubernetes` overrides if provided
- [x] 3.3 Generate the defaults plist with:
  - Container engine: moby (Docker)
  - Kubernetes: enabled or disabled per flag
  - RAM: auto-detected or overridden
  - CPUs: auto-detected or overridden
- [x] 3.4 Write plist to `/Library/Managed Preferences/io.rancherdesktop.profile.defaults.plist`
- [x] 3.5 Run tests: `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop`

### Validation

User confirms deployment profile logic is correct.

---

## Phase 4: Final validation — DONE

### Tasks

- [x] 4.1 Run full test suite: `bash docs/ai-developer/tools/validate-scripts.sh` — all 4 scripts pass
- [x] 4.2 Review the complete script for edge cases:
  - Download failure: curl errors are caught, temp files cleaned up
  - Already installed: skips install, updates deployment profile only
  - Plist directory missing: created with `mkdir -p`
- [x] 4.3 Add a README.md to `scripts/rancher-desktop/`

### Validation

All tests pass. User confirms script is ready.

---

## Acceptance Criteria

- [ ] Tests pass: `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop`
- [ ] All 5 metadata fields present
- [ ] Help output follows standard format and documents all custom flags
- [ ] No shellcheck errors
- [ ] Script installs Rancher Desktop from `.dmg` to `/Applications/`
- [ ] Deployment profile sets Docker (moby), Kubernetes off, and auto-detected resources
- [ ] Script is idempotent (safe to run twice — skips if already installed)

---

## Files to Create

- `scripts/rancher-desktop/rancher-desktop-install.sh`
- `scripts/rancher-desktop/README.md`

