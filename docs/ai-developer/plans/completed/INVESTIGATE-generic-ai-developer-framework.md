# Investigate: Make docs/ai-developer a Generic Framework

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Completed**: 2026-02-08

**Goal**: Restructure `docs/ai-developer/` so it works as a generic framework for any project — not just bash scripts for Jamf/macOS. PowerShell for Windows is the next language coming.

**Last Updated**: 2026-02-08

---

## Questions to Answer

1. Are WORKFLOW.md and PLANS.md already generic enough?
2. How should language-specific rules (bash, PowerShell) be organized?
3. How should validation and testing generalize across languages?
4. What stays in the framework vs what's project-specific?
5. How should the repo organize scripts for different platforms?

---

## Decisions Made

### Platform separation: `scripts-mac/` and `scripts-windows/`

The ops team is mostly Windows techs. Symmetric naming makes it clear what's what.

- `scripts/` → renamed to `scripts-mac/` (bash scripts for macOS via Jamf)
- `scripts-windows/` → new folder (PowerShell scripts for Windows)

Each platform folder has the same package structure:
```
scripts-mac/
  rancher-desktop/
  devcontainer-toolbox/

scripts-windows/
  rancher-desktop/       (future — same software, different platform)
  some-windows-thing/    (future — Windows-only)
```

Some packages exist on both platforms (e.g. Rancher Desktop), some are platform-specific. Each package is self-contained with its own README and tests.

### Why not nested? (scripts/mac/, scripts/windows/)

Flat top-level folders are simpler to navigate, reference in docs, and work with in CI. No deep nesting needed.

---

## Analysis

### 1. WORKFLOW.md — Almost generic

**What's generic (works for any project):**
- The plan-based flow (backlog → active → completed)
- User describes work → Claude creates plan → user reviews → Claude implements
- Phase-by-phase implementation with user confirmation
- Feature branch workflow
- The quick reference table and example session

**What's project-specific (needs changing):**
- Step 5 mentions `validate-scripts.sh` and `shellcheck` — bash-specific
- Step 6 mentions `set-version.sh` and `SCRIPT_VER` — bash-specific
- Version Management section is entirely about `SCRIPT_VER` and `set-version.sh`
- Example session uses "Rancher Desktop install script"

**Verdict:** ~90% generic. Replace specific tool references with "run the project's validation" and "check the language rules file". Version management can stay as a generic concept (every project has versions) but should reference the language rules file for the specific command.

---

### 2. PLANS.md — Almost generic

**What's generic:**
- Plan structure (header, phases, tasks, acceptance criteria)
- File types (PLAN vs INVESTIGATE)
- Status values and transitions
- Naming conventions (PLAN-nnn-*)
- Templates for bug fix, feature, investigation
- Best practices

**What's project-specific:**
- Acceptance criteria template mentions `validate-scripts.sh`, `SCRIPT_ID`, `SCRIPT_NAME`, etc.
- Phase 2 validation example uses `validate-scripts.sh <folder-name>`
- "All 5 metadata fields present" is bash-specific

**Verdict:** ~95% generic. Replace bash-specific acceptance criteria examples with neutral ones. Use "run validation (see language rules)" instead of specific commands.

---

### 3. CREATING-SCRIPTS.md — Becomes rules/bash.md

100% bash-specific. This IS the language-specific rules file. Rename to `rules/bash.md` and keep all content. When PowerShell comes, create `rules/powershell.md` with equivalent standards adapted for PowerShell.

Each rules file defines:
1. **Code standard** — what every file of that language must follow
2. **Validation command** — how to check code meets the standard
3. **Template** — starting point for new files
4. **Platform gotchas** — language/platform-specific pitfalls (macOS bash 3.2, Windows path handling, etc.)

---

### 4. validate-scripts.sh — Bash-specific tool

The validation tool validates bash scripts. PowerShell would need its own validator (PSScriptAnalyzer, metadata checks, help format checks).

**Decision:** Keep language-specific validation tools. Rename to make the language clear:
- `validate-bash.sh` — validates bash scripts in `scripts-mac/`
- `validate-powershell.ps1` (future) — validates PowerShell scripts in `scripts-windows/`

Same for set-version:
- `set-version-bash.sh` — bumps SCRIPT_VER in bash scripts
- `set-version-powershell.ps1` (future) — bumps version in PowerShell scripts

---

### 5. README.md — Split generic and project-specific

The README needs two sections:
1. **Framework** — how the ai-developer workflow works (generic)
2. **This project** — what packages exist, platform-specific commands (project-specific)

---

## Proposed Structure

```
docs/ai-developer/
  README.md                    ← framework overview + project-specific section
  WORKFLOW.md                  ← generic plan-based workflow
  PLANS.md                     ← generic plan structure and templates
  rules/
    bash.md                    ← bash script standards (current CREATING-SCRIPTS.md)
    powershell.md              ← (future) PowerShell script standards
  tools/
    validate-bash.sh           ← renamed from validate-scripts.sh
    set-version-bash.sh        ← renamed from set-version.sh
    validate-powershell.ps1    ← (future)
    set-version-powershell.ps1 ← (future)
  templates/
    bash/
      script-template.sh       ← moved from templates/
      README-template.md        ← moved from templates/
    powershell/                 ← (future)
      script-template.ps1
      README-template.md
  plans/
    active/
    backlog/
    completed/
```

### Repo root after changes

```
CLAUDE.md                      ← entry point for Claude Code
OPS.md                         ← ops workflow
README.md                      ← repo overview
scripts-mac/                   ← renamed from scripts/
  rancher-desktop/
  devcontainer-toolbox/
  urbalurba-infrastructure-stack/
scripts-windows/               ← (created when PowerShell work starts)
docs/ai-developer/             ← the framework
```

---

## What Changes

### Files to rename/move

| From | To |
|------|----|
| `scripts/` | `scripts-mac/` |
| `CREATING-SCRIPTS.md` | `rules/bash.md` |
| `tools/validate-scripts.sh` | `tools/validate-bash.sh` |
| `tools/set-version.sh` | `tools/set-version-bash.sh` |
| `templates/script-template.sh` | `templates/bash/script-template.sh` |
| `templates/README-template.md` | `templates/bash/README-template.md` |

### Files to edit (make generic)

| File | What changes |
|------|-------------|
| `WORKFLOW.md` | Replace bash-specific commands with generic references to language rules |
| `PLANS.md` | Replace bash-specific acceptance criteria examples with neutral ones |
| `README.md` | Split into framework section + project section, update all paths |
| `CLAUDE.md` | Update paths |
| `OPS.md` | Update paths, add note about platform folders |
| `rules/bash.md` | Update internal paths (templates/, tools/) |

### References to update

Every file that mentions `scripts/`, `validate-scripts.sh`, `set-version.sh`, `CREATING-SCRIPTS.md`, or template paths needs updating. This is the same kind of bulk reference update we did in the last consolidation.

---

## Resolved Questions

1. **README-template.md** — **Generic.** One template at `templates/README-template.md`. Only code templates go in language subfolders (`templates/bash/`, `templates/powershell/`).

2. **OPS.md** — **One file with sections.** When Windows comes, add a Windows section to the same OPS.md.

3. **Tool naming** — **By language.** `validate-bash.sh`, `validate-powershell.ps1`, `set-version-bash.sh`, `set-version-powershell.ps1`. Tools validate the language, not the platform.

---

## Final Structure

```
docs/ai-developer/
  README.md                    ← framework overview + project-specific section
  WORKFLOW.md                  ← generic plan-based workflow
  PLANS.md                     ← generic plan structure and templates
  DEVCONTAINER-TOOLBOX.md      ← how to discover, examine, and install tools
  rules/
    script-standard.md         ← shared standard (metadata, help, logging, error codes)
    bash.md                    ← bash-specific syntax and gotchas (references script-standard.md)
    powershell.md              ← (future) PowerShell-specific syntax and gotchas
  tools/
    validate-bash.sh           ← renamed from validate-scripts.sh
    set-version-bash.sh        ← renamed from set-version.sh
    validate-powershell.ps1    ← (future)
    set-version-powershell.ps1 ← (future)
  templates/
    README-template.md         ← generic (shared across languages)
    bash/
      script-template.sh
    powershell/                ← (future)
      script-template.ps1
  plans/
    active/
    backlog/
    completed/
```

---

## Devcontainer Toolbox Awareness

This repo runs inside the **devcontainer-toolbox** — a devcontainer with many development tools available. The README should tell Claude how to discover the environment:

| Command | Purpose |
|---------|---------|
| `dev-env` | Show installed tools, runtimes, services, and configurations |
| `dev-setup` | Interactive menu to install additional tools |
| `dev-help` | List all available dev-* commands |

Currently installed: Bash Development Tools, C/C++ Development Tools, Claude Code. Available but not installed: Python, TypeScript, Go, Rust, Java, Kubernetes, Azure, and more.

A fresh Claude session should run `dev-env` to understand what's available before suggesting tool-dependent solutions.

---

## Next Steps

- [x] Resolve open questions with user
- [ ] Create PLAN with implementation phases
