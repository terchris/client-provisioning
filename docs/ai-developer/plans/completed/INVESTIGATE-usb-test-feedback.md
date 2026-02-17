# Investigate: USB Test Feedback

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices
> - [rules/script-standard.md](../../rules/script-standard.md) - Shared script standard
> - [rules/powershell.md](../../rules/powershell.md) - PowerShell-specific rules
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Goal**: Collect all feedback from the full Windows reinstall USB test and produce a PLAN with fixes.

**Last Updated**: 2026-02-17

---

## Context

Running a clean end-to-end test of the Windows install pipeline on a real Windows PC using a USB stick. WSL2 is already installed. Testing the full cycle: diagnose, uninstall, reinstall, verify.

Test procedure: [docs/MANUAL-TEST-WINDOWS-REINSTALL.md](../../../MANUAL-TEST-WINDOWS-REINSTALL.md)

---

## Feedback Collected

### 1. detect.ps1 scripts show no output when component is not installed

**Found during:** Phase 1 -- Diagnose current state

**Problem:** All three detect scripts (`wsl2`, `rancher-desktop`, `devcontainer-toolbox`) follow the Intune convention where no stdout = not detected. When running manually, the user sees only the `INFO: Starting...` line and then nothing. This is confusing -- it looks like the script silently failed.

**Proposed fix:** Add a `Write-Host` message (e.g. "Rancher Desktop is not installed") in the "not detected" path. `Write-Host` goes to the console for human feedback but does NOT produce stdout, so the Intune convention (no stdout = not detected) is preserved.

**Affected files:**
- `scripts-win/wsl2/detect.ps1`
- `scripts-win/rancher-desktop/detect.ps1`
- `scripts-win/devcontainer-toolbox/detect.ps1`

---

No other issues found. Full reinstall test passed.

---

## Next Steps

- [x] Complete USB test (all 4 phases)
- [x] Create PLAN with all fixes from this investigation -- see PLAN-detect-not-installed-message.md
