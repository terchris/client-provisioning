# Fix: detect.ps1 scripts silent when component not installed

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices
> - [rules/script-standard.md](../../rules/script-standard.md) - Shared script standard
> - [rules/powershell.md](../../rules/powershell.md) - PowerShell-specific rules
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Goal**: Add human-readable "not installed" message to all detect.ps1 scripts so USB testers get clear feedback.

**Last Updated**: 2026-02-17

**Completed**: 2026-02-17

**Source**: [INVESTIGATE-usb-test-feedback.md](../completed/INVESTIGATE-usb-test-feedback.md)

---

## Problem

All three detect scripts follow the Intune convention: stdout output = detected, no stdout = not detected. When running manually from USB, the "not detected" case shows only the `INFO: Starting...` line and then nothing. This looks like the script silently failed.

## Solution

Add a `log_info` message in the "not detected" path of each detect script. The `log_info` function uses `Write-Host`, which goes to the console but NOT to stdout. Intune behavior is preserved.

---

## Phase 1: Add not-installed messages -- DONE

### Tasks

- [x] 1.1 Update `scripts-win/rancher-desktop/detect.ps1` -- add log_info before final exit 0
- [x] 1.2 Update `scripts-win/devcontainer-toolbox/detect.ps1` -- add log_info before final exit 0
- [x] 1.3 Update `scripts-win/wsl2/detect.ps1` -- add log_info before final exit 0
- [x] 1.4 Run PowerShell validation -- pwsh not available in devcontainer, verified manually

### Validation

PowerShell validation cannot run in this devcontainer (no pwsh). Changes verified by manual review -- each edit adds a single `log_info` call using `Write-Host` (no stdout impact).

---

## Acceptance Criteria

- [x] All three detect scripts show a clear message when component is not installed
- [x] Messages use `log_info` (Write-Host) so Intune convention is not broken
- [ ] PowerShell validation passes -- blocked (no pwsh in devcontainer)
