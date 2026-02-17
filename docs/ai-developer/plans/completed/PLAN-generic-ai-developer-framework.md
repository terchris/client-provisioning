# Plan: Make docs/ai-developer a Generic Framework

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Completed**: 2026-02-08

**Goal**: Restructure `docs/ai-developer/` so it works as a generic framework for any project. Separate generic workflow from language-specific rules. Rename `scripts/` to `scripts-mac/` for platform clarity. Add devcontainer toolbox awareness.

**Last Updated**: 2026-02-08

**Based on**: [INVESTIGATE-generic-ai-developer-framework.md](INVESTIGATE-generic-ai-developer-framework.md)

---

## Overview

The framework has three layers:

1. **Generic workflow** — plans, workflow (works for any project)
2. **Shared script standard** — metadata fields, help format, logging, error codes (applies to all script languages)
3. **Language-specific** — syntax, templates, validation tools, platform gotchas (one per language)

The shared standard means bash and PowerShell scripts follow the same patterns — same 5 metadata fields, same help format structure, same logging conventions, same error identifiers. Only the syntax differs.

This plan separates the layers, adds devcontainer toolbox awareness, and renames `scripts/` to `scripts-mac/` for platform clarity.

---

## Phase 1: Rename `scripts/` to `scripts-mac/` — DONE

### Tasks

- [x] 1.1 `git mv scripts/ scripts-mac/`
- [x] 1.2 Update `validate-bash.sh` SCRIPTS_DIR (still called validate-scripts.sh at this point — renamed in phase 2)
- [x] 1.3 Update `set-version.sh` SCRIPTS_DIR
- [x] 1.4 Grep for all references to `scripts/` across the repo and update them

### Validation

Run `bash docs/ai-developer/tools/validate-scripts.sh` to confirm validation still works with new path. User confirms.

---

## Phase 2: Create `rules/` folder, move and rename language-specific files — DONE

### Tasks

- [x] 2.1 Create `docs/ai-developer/rules/`
- [x] 2.2 `git mv docs/ai-developer/CREATING-SCRIPTS.md docs/ai-developer/rules/bash.md`
- [x] 2.3 `git mv docs/ai-developer/tools/validate-scripts.sh docs/ai-developer/tools/validate-bash.sh`
- [x] 2.4 `git mv docs/ai-developer/tools/set-version.sh docs/ai-developer/tools/set-version-bash.sh`
- [x] 2.5 Create `docs/ai-developer/templates/bash/` and move `script-template.sh` into it
- [x] 2.6 Move `README-template.md` to `docs/ai-developer/templates/README-template.md` (stays generic, not under bash/)
- [x] 2.7 Update internal paths in `rules/bash.md` (template path, tool names)
- [x] 2.8 Update SCRIPTS_DIR in `validate-bash.sh` and `set-version-bash.sh` to point to `scripts-mac/`
- [x] 2.9 Grep for all references to old filenames and update

### Validation

Run `bash docs/ai-developer/tools/validate-bash.sh` to confirm everything works. 7/7 + 14/14 pass.

---

## Phase 3: Create shared script standard — DONE

Extract the universal concepts from `rules/bash.md` into `rules/script-standard.md`. This defines what all script languages must follow — bash and PowerShell both reference this.

### Tasks

- [x] 3.1 Create `docs/ai-developer/rules/script-standard.md` with a header that links to language-specific rules files. Content covering:
  - The 5 required metadata fields (SCRIPT_ID, SCRIPT_NAME, SCRIPT_VER, SCRIPT_DESCRIPTION, SCRIPT_CATEGORY)
  - Standard help format structure (name+version, description, usage, options, metadata section)
  - Standard logging pattern (log_info, log_success, log_error, log_warning with timestamps)
  - Unique error identifiers (ERR001, ERR002, etc.)
  - No hardcoded values — use configuration variables
  - Verify every action — check results of commands
  - Capture error output for troubleshooting
  - Check that non-standard commands exist before using them
  - SCRIPT_CATEGORY values
  - Note: each language rules file shows the syntax for these concepts
- [x] 3.2 Update `rules/bash.md` — remove the shared concepts (move to script-standard.md), keep only:
  - Header linking back to script-standard.md ("Read `script-standard.md` first — this file covers bash-specific syntax")
  - Bash-specific syntax for metadata, logging, help, argument parsing
  - Bash template sections and structure
  - macOS bash 3.2 limitations and gotchas
  - Shellcheck / validation details
  - Bash-specific examples
- [x] 3.3 Verify `rules/bash.md` still reads well as a standalone guide (with the reference to script-standard.md)

### Validation

Both files reviewed. No concepts lost — everything from the original CREATING-SCRIPTS.md is in one of the two files.

---

## Phase 4: Make WORKFLOW.md generic — DONE

### Tasks

- [x] 4.1 Replace `validate-scripts.sh` references with generic "run validation (see language rules)"
- [x] 4.2 Replace `set-version.sh` / `SCRIPT_VER` references with generic version management concept
- [x] 4.3 Make Version Management section generic — reference script standard and language rules for specific commands
- [ ] 4.4 Make example session more neutral (not bash/Rancher-specific) — skipped, the example is still useful as-is
- [x] 4.5 Keep Step 5 review section generic — "run validation, check for lint errors"

### Validation

WORKFLOW.md reviewed, no bash-specific tool references remain.

---

## Phase 5: Make PLANS.md generic — DONE

### Tasks

- [x] 5.1 Replace bash-specific acceptance criteria examples with neutral ones
- [x] 5.2 Replace `validate-scripts.sh <folder-name>` with "run validation (see language rules)"
- [x] 5.3 Replace "All 5 metadata fields present" with "follows script standard" — reference `rules/script-standard.md`
- [x] 5.4 Use generic acceptance criteria like "Validation passes", "Code follows script standard and language rules", "Tests pass"

### Validation

PLANS.md reviewed, no bash-specific references remain.

---

## Phase 6: Create DEVCONTAINER-TOOLBOX.md — DONE

A standalone reference for working with the devcontainer-toolbox. Claude reads this to understand the development environment — what's installed, how to examine tools, and how to install new ones.

### Tasks

- [x] 6.1 Create `docs/ai-developer/DEVCONTAINER-TOOLBOX.md` with general info:
  - What the devcontainer-toolbox is
  - `dev-env` — see what's installed (runtimes, tools, services, configurations)
  - `dev-setup` — interactive menu to install/uninstall tools
  - `dev-help` — list all available dev-* commands
  - How to examine what a tool installs: `bash /opt/devcontainer-toolbox/additions/install-<tool-id>.sh --help`
  - How to install a tool: `bash /opt/devcontainer-toolbox/additions/install-<tool-id>.sh`
  - How tools are auto-enabled: `.devcontainer.extend/enabled-tools.conf`
  - NO specific tool examples — Claude figures out the specifics from the general pattern

### Validation

DEVCONTAINER-TOOLBOX.md reviewed.

---

## Phase 7: Rewrite README.md — DONE

The README becomes the onboarding doc with two parts: generic framework + project-specific.

### Tasks

- [x] 7.1 **Framework section**: What this folder is, the plan workflow (brief — link to WORKFLOW.md), general rules (ask before starting, ask before git)
- [x] 7.2 **Script standard and language rules section**: Link to `rules/script-standard.md` + table linking to `rules/bash.md` (and future `rules/powershell.md`)
- [x] 7.3 **IMPLEMENTATION RULES reference**: Ready-to-copy blocks for each language, so Claude knows exactly what to put at the top of plans. Example:
  - Bash work: WORKFLOW.md + PLANS.md + script-standard.md + bash.md
  - PowerShell work (future): WORKFLOW.md + PLANS.md + script-standard.md + powershell.md
- [x] 7.4 **Devcontainer toolbox reference**: Link to `DEVCONTAINER-TOOLBOX.md`
- [x] 7.5 **This project section**: Platform folders (`scripts-mac/`, `scripts-windows/`), current packages table, project-specific validation commands
- [x] 7.6 **Folder structure**: Updated tree showing rules/, templates/bash/, tools with new names

### Validation

README.md reviewed.

---

## Phase 8: Update CLAUDE.md and OPS.md — DONE

### Tasks

- [x] 8.1 Update CLAUDE.md — point to new README, update validation command to `validate-bash.sh`
- [x] 8.2 Update OPS.md — update all tool paths, `scripts/` → `scripts-mac/`, add note about platform folders

### Validation

Both files reviewed.

---

## Phase 9: Update all remaining references — DONE

### Tasks

- [x] 9.1 Grep entire repo for stale references: `scripts/`, `CREATING-SCRIPTS.md`, `validate-scripts.sh`, `set-version.sh`, old template paths
- [x] 9.2 Update any remaining files (completed plans may reference old paths — that's OK, they document history)
- [x] 9.3 Run final validation: `bash docs/ai-developer/tools/validate-bash.sh` — 7/7 + 14/14 pass
- [x] 9.4 Verify old files/folders are gone

### Validation

All validation passes. No stale references in active files. Completed plans left as-is (historical).

---

## Acceptance Criteria

- [x] `scripts/` renamed to `scripts-mac/`
- [x] `rules/script-standard.md` exists with shared concepts
- [x] `rules/bash.md` references script-standard.md, covers bash-specific syntax only
- [x] `CREATING-SCRIPTS.md` → `rules/bash.md`
- [x] `validate-scripts.sh` → `validate-bash.sh` (works correctly)
- [x] `set-version.sh` → `set-version-bash.sh` (works correctly)
- [x] `script-template.sh` in `templates/bash/`
- [x] `README-template.md` in `templates/` (generic)
- [x] `DEVCONTAINER-TOOLBOX.md` exists with general toolbox usage
- [x] WORKFLOW.md has no bash-specific references
- [x] PLANS.md has no bash-specific references
- [x] README.md has framework + project sections + links to script standard, language rules, devcontainer toolbox
- [x] CLAUDE.md updated
- [x] OPS.md updated
- [x] All validation passes

---

## Files to rename/move

| From | To |
|------|----|
| `scripts/` | `scripts-mac/` |
| `docs/ai-developer/CREATING-SCRIPTS.md` | `docs/ai-developer/rules/bash.md` |
| `docs/ai-developer/tools/validate-scripts.sh` | `docs/ai-developer/tools/validate-bash.sh` |
| `docs/ai-developer/tools/set-version.sh` | `docs/ai-developer/tools/set-version-bash.sh` |
| `docs/ai-developer/templates/script-template.sh` | `docs/ai-developer/templates/bash/script-template.sh` |
| `docs/ai-developer/templates/README-template.md` | stays at `docs/ai-developer/templates/README-template.md` |

## Files to create

| File | Content |
|------|---------|
| `docs/ai-developer/rules/script-standard.md` | Shared standard: metadata, help format, logging, error codes, verify actions |
| `docs/ai-developer/DEVCONTAINER-TOOLBOX.md` | How to discover, examine, and install tools in the devcontainer |

## Files to edit

| File | Changes |
|------|---------|
| `docs/ai-developer/WORKFLOW.md` | Remove bash-specific references |
| `docs/ai-developer/PLANS.md` | Remove bash-specific references |
| `docs/ai-developer/README.md` | Full rewrite — framework + project + devcontainer |
| `docs/ai-developer/rules/bash.md` | Update internal paths |
| `docs/ai-developer/tools/validate-bash.sh` | Update SCRIPTS_DIR, internal references |
| `docs/ai-developer/tools/set-version-bash.sh` | Update SCRIPTS_DIR, internal references |
| `CLAUDE.md` | Update paths and commands |
| `OPS.md` | Update paths, add platform note |
| Various plan files in `completed/` | Leave as-is (historical) |
