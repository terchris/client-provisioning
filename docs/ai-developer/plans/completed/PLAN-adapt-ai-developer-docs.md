# Plan: Adapt ai-developer docs for this repo

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Goal**: Rewrite the `docs/ai-developer/` files (copied from devcontainer-toolbox) to match this repo's actual structure and standards.

**Completed**: 2026-02-06

---

## Problem

The `docs/ai-developer/` files were copied from the larger devcontainer-toolbox project. They referenced patterns, paths, tools, and workflows that don't exist in this repo (Docusaurus website, CI/CD, shared libraries, extended metadata, install/uninstall patterns).

---

## Phase 1: Cleanup — DONE

### Tasks

- [x] 1.1 Delete `CREATING-TOOL-PAGES.md` (about Docusaurus pages, not relevant)
- [x] 1.2 Delete `.DS_Store` files
- [x] 1.3 Add `.DS_Store` to `.gitignore`

### Validation

Files removed, `.gitignore` updated.

---

## Phase 2: Create CLAUDE.md — DONE

### Tasks

- [x] 2.1 Create `/workspace/CLAUDE.md` as entry point for Claude Code
- [x] 2.2 Include repo description, key rules, structure, standards, links to detailed docs

### Validation

User confirms CLAUDE.md is accurate.

---

## Phase 3: Rewrite docs — DONE

### Tasks

- [x] 3.1 Rewrite `README.md` — remove devcontainer-toolbox refs, CI/CD links, Docusaurus frontmatter
- [x] 3.2 Adapt `WORKFLOW.md` — fix paths, rewrite version management to use `set-version.sh`, update examples
- [x] 3.3 Adapt `PLANS.md` — fix paths, update acceptance criteria and validation commands
- [x] 3.4 Rewrite `CREATING-SCRIPTS.md` — complete rewrite covering template workflow, 5 metadata fields, testing

### Validation

All cross-references verified. No stale references to devcontainer-toolbox patterns.

---

## Acceptance Criteria

- [x] All internal links between docs resolve correctly
- [x] No references to devcontainer-toolbox, CI/CD, Docusaurus, version.txt, shared libraries
- [x] CLAUDE.md exists and is accurate
- [x] Plan templates reference this repo's patterns
- [x] CREATING-SCRIPTS.md accurately describes `docs/ai-developer/templates/script-template.sh` and `docs/ai-developer/tools/validate-scripts.sh`

---

## Files Modified

- `.gitignore`
- `CLAUDE.md` (new)
- `docs/ai-developer/README.md`
- `docs/ai-developer/WORKFLOW.md`
- `docs/ai-developer/PLANS.md`
- `docs/ai-developer/CREATING-SCRIPTS.md`
- `docs/ai-developer/CREATING-TOOL-PAGES.md` (deleted)
