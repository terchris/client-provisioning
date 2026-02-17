# Feature: Rancher Desktop Uninstall Script

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Complete

**Goal**: Create a Jamf-deployable script that cleanly uninstalls Rancher Desktop and removes deployment profiles from Apple Silicon Macs.

**Last Updated**: 2026-02-06

**Related**: [PLAN-rancher-desktop-install.md](../active/PLAN-rancher-desktop-install.md)

---

## Overview

Remove Rancher Desktop and all associated configuration. This script is needed before testing the install script on a Mac that already has Rancher Desktop.

---

## Research needed

1. What does Rancher Desktop leave behind on macOS?
   - `/Applications/Rancher Desktop.app`
   - Deployment profiles in `/Library/Managed Preferences/io.rancherdesktop.profile.*`
   - User config in `~/Library/Application Support/rancher-desktop/`
   - VM data and container images
   - Socket files, CLI symlinks (`rdctl`, `docker`, `kubectl`, `nerdctl`)
2. Does Rancher Desktop have a built-in uninstall or factory reset?
3. What needs root vs user-level access?

---

## Phase 1: Create the uninstall script from template

### Tasks

- [x] 1.1 Copy `docs/ai-developer/templates/script-template.sh` to `scripts/rancher-desktop/rancher-desktop-uninstall.sh`
- [x] 1.2 Fill in metadata:
  - `SCRIPT_ID="rancher-desktop-uninstall"`
  - `SCRIPT_NAME="Rancher Desktop Uninstall"`
  - `SCRIPT_VER="0.1.0"`
  - `SCRIPT_DESCRIPTION="Uninstall Rancher Desktop and remove deployment profiles"`
  - `SCRIPT_CATEGORY="DEVOPS"`
- [x] 1.3 Add custom flags:
  - `--keep-profile` — keep the deployment profile (default: remove it)
- [x] 1.4 Run tests: `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop`

### Validation

Tests pass (syntax, help, metadata).

---

## Phase 2: Implement the uninstall logic

### Tasks

- [x] 2.1 Quit Rancher Desktop if running (`osascript -e 'quit app "Rancher Desktop"'` or `rdctl shutdown`)
- [x] 2.2 Remove `/Applications/Rancher Desktop.app`
- [x] 2.3 Remove deployment profiles from `/Library/Managed Preferences/io.rancherdesktop.profile.*`  (unless `--keep-profile`)
- [x] 2.4 Remove user config: `~/Library/Application Support/rancher-desktop/`
- [x] 2.5 Remove any CLI symlinks left behind (`rdctl`, `docker`, `kubectl`, `nerdctl` in `/usr/local/bin/` or `~/.rd/bin/`)
- [x] 2.6 Clean up VM data and caches (identify paths during research)
- [x] 2.7 Handle "not installed" gracefully — log and exit 0
- [x] 2.8 Run tests: `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop`

### Validation

User confirms uninstall logic looks correct.

---

## Phase 3: Final validation

### Tasks

- [x] 3.1 Run full test suite: `bash docs/ai-developer/tools/validate-scripts.sh`
- [x] 3.2 Update `scripts/rancher-desktop/README.md` to document the uninstall script

### Validation

All tests pass. User confirms script is ready for manual testing.

---

## Acceptance Criteria

- [x] Tests pass: `bash docs/ai-developer/tools/validate-scripts.sh`
- [x] All 5 metadata fields present
- [x] Help output follows standard format
- [x] No shellcheck errors
- [x] Script removes app, profiles, user config, and CLI symlinks
- [x] Script handles "not installed" gracefully
- [x] Script is idempotent (safe to run twice)
- [x] README updated

---

## Files to Create/Modify

- `scripts/rancher-desktop/rancher-desktop-uninstall.sh` (new)
- `scripts/rancher-desktop/README.md` (update)
