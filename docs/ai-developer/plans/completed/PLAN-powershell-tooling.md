# Plan: PowerShell tooling for the devcontainer

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Complete

**Goal**: Create the PowerShell script template, validation tool, and version bump tool — mirroring the existing bash tooling — so we can develop and validate Windows deployment scripts from the devcontainer.

**Last Updated**: 2026-02-11

**Based on**: [INVESTIGATE-intune-windows-deployment.md](../backlog/INVESTIGATE-intune-windows-deployment.md) (see "PowerShell tooling for the devcontainer" and "Suggested starting order")

---

## Problem

We have bash tooling for Mac scripts: a script template, `validate-bash.sh`, and `set-version-bash.sh`. We need the PowerShell equivalents before we can write any Windows deployment scripts. Without these, there's no way to ensure scripts follow the standard and no template to start from.

We also need `SvRooij.ContentPrep.Cmdlet` installed in the devcontainer so we can build `.intunewin` packages.

---

## Phase 1: Install SvRooij.ContentPrep.Cmdlet — DONE

### Tasks

- [x] 1.1 Add `Install-Module SvRooij.ContentPrep.Cmdlet -Force -Scope AllUsers` to `.devcontainer.extend/project-installs.sh` (after the existing PSScriptAnalyzer install)
- [x] 1.2 Rebuild devcontainer and verify the module is available: `pwsh -Command "Get-Module -ListAvailable SvRooij.ContentPrep.Cmdlet"` — v0.4.0 installed

### Validation

`New-IntuneWinPackage` command is available in pwsh.

---

## Phase 2: Create PowerShell script template — DONE

Mirror `docs/ai-developer/templates/bash/script-template.sh` for PowerShell.

### Tasks

- [x] 2.1 Create `docs/ai-developer/templates/powershell/script-template.ps1`
- [x] 2.2 Template passes syntax check
- [x] 2.3 Template passes PSScriptAnalyzer with no errors (Write-Host warnings only)
- [x] 2.4 Template `-Help` output matches the standard format

### Validation

Template parses, lints clean, and help output matches the standard.

---

## Phase 3: Create validate-powershell.sh — DONE

Mirror `docs/ai-developer/tools/validate-bash.sh`. This is a **bash script** that calls `pwsh` for PowerShell-specific checks.

### Tasks

- [x] 3.1 Create `docs/ai-developer/tools/validate-powershell.sh` with 4 checks: syntax, help, metadata, lint
- [x] 3.2 Script structure mirrors `validate-bash.sh`
- [x] 3.3 Accepts optional folder argument
- [x] 3.4 Validates `scripts-win/diagnostics/` (check-environment.ps1)
- [x] 3.5 Output format matches validate-bash.sh
- [x] 3.6 Script passes bash syntax, shellcheck, help format checks
- [x] 3.7 `check-environment.ps1` passes all 4 checks

### Implementation notes

- The `extract_meta` function needs to match PowerShell variable syntax: `$SCRIPT_ID = "value"` (with `$` prefix and variable spaces around `=`)
- Grep pattern for metadata presence: `^\$FIELD` (escaped `$` in bash)
- Extract pattern for values: `\$FIELD *= *"([^"]*)"` — must handle aligned whitespace (e.g. `$SCRIPT_ID          = "check-environment"`)
- Help output comes from stdout (PowerShell `Write-Host` goes to stdout when run from bash)
- The script is bash because it runs in the devcontainer (Linux) and follows our bash script standard

### Pre-checked: check-environment.ps1 compatibility

Verified that `scripts-win/diagnostics/check-environment.ps1` already passes all 4 checks:
- Syntax: pwsh parser passes
- Help: first line `Windows Environment Diagnostic (v0.1.0)`, description present, `Metadata:` with ID and Category
- Metadata: all 5 `$SCRIPT_*` fields on lines starting with `$` at column 1
- Lint: PSScriptAnalyzer has no errors (only expected Write-Host warnings)

No changes needed to the diagnostic script.

### Validation

`validate-powershell.sh` passes `validate-bash.sh`, and `check-environment.ps1` passes all 4 checks.

---

## Phase 4: Create set-version-powershell.sh — DONE

Mirror `docs/ai-developer/tools/set-version-bash.sh`.

### Tasks

- [x] 4.1 Create `docs/ai-developer/tools/set-version-powershell.sh`
- [x] 4.2 Script structure follows bash standard
- [x] 4.3 Script passes bash syntax, shellcheck, help format checks
- [x] 4.4 Sed pattern preserves whitespace alignment (verified)

### Implementation notes

- Grep/sed for PowerShell variables needs careful escaping: `\$SCRIPT_VER` (literal `$` in bash)
- The assignment format in PowerShell uses spaces: `$SCRIPT_VER = "0.1.0"` (not `$SCRIPT_VER="0.1.0"`)
- Preserve the exact whitespace from the template (aligned `=` signs in the metadata block)

### Validation

`set-version-powershell.sh` passes `validate-bash.sh`.

---

## Phase 5: Update documentation — DONE

### Tasks

- [x] 5.1 Update `rules/powershell.md` — Validation section already existed (added during rules creation)
- [x] 5.2 Update `rules/powershell.md` — added "Version Bumping" section
- [x] 5.3 Update investigation's "PowerShell tooling" section — all items marked done

### Validation

User confirms documentation is correct.

---

## Acceptance Criteria

- [x] `SvRooij.ContentPrep.Cmdlet` is installed in devcontainer and `New-IntuneWinPackage` is available (v0.4.0)
- [x] PowerShell template exists at `docs/ai-developer/templates/powershell/script-template.ps1`
- [x] Template passes syntax, lint, help, and metadata checks
- [x] `validate-powershell.sh` validates all `.ps1` files under `scripts-win/`
- [x] `validate-powershell.sh` itself passes syntax, shellcheck, help format
- [x] `set-version-powershell.sh` updates `$SCRIPT_VER` in PowerShell scripts (whitespace preserved)
- [x] `set-version-powershell.sh` itself passes syntax, shellcheck, help format
- [x] Existing `scripts-win/diagnostics/check-environment.ps1` passes validation
- [x] Documentation updated

---

## Files

### New

- `docs/ai-developer/templates/powershell/script-template.ps1`
- `docs/ai-developer/tools/validate-powershell.sh`
- `docs/ai-developer/tools/set-version-powershell.sh`

### Modified

- `.devcontainer.extend/project-installs.sh` (add SvRooij.ContentPrep.Cmdlet install)
- `docs/ai-developer/rules/powershell.md` (add validation and version bumping sections)
- `docs/ai-developer/plans/backlog/INVESTIGATE-intune-windows-deployment.md` (update next steps)
