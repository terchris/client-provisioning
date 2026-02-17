# Plan: Consolidate AI Developer Tooling

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Complete

**Goal**: Move all developer tools, templates, and validation into `docs/ai-developer/` so the repo root is clean and the entire setup is portable to any repo.

**Last Updated**: 2026-02-08

**Background**: [INVESTIGATE-script-package-standard.md](INVESTIGATE-script-package-standard.md)

---

## Problem

Developer tooling is scattered across 4 root-level locations:

```
tests/run-tests.sh              ← validation
set-version.sh                  ← version management
templates/script-template.sh    ← scaffolding
docs/ai-developer/              ← docs + plans
```

This clutters the root, makes setup on new repos harder, and creates a naming conflict between the root `tests/` (validation) and per-package `tests/` (functional tests).

Additionally, both `run-tests.sh` and `set-version.sh` use `grep -oP` (Perl regex) which is not available on stock macOS.

---

## Target State

```
CLAUDE.md                                   ← stays (Claude Code requires root)

docs/ai-developer/
  WORKFLOW.md                               ← existing
  PLANS.md                                  ← existing
  CREATING-SCRIPTS.md                       ← existing (expanded for packages)
  README.md                                 ← existing
  plans/                                    ← existing
  tools/
    validate-scripts.sh                     ← moved from tests/run-tests.sh
    set-version.sh                          ← moved from set-version.sh
  templates/
    script-template.sh                      ← moved from templates/script-template.sh
    README-template.md                      ← NEW: package README template
```

Old folders (`tests/`, `templates/`) and root `set-version.sh` are removed.

### New command paths

```bash
# Validate (was: bash tests/run-tests.sh)
bash docs/ai-developer/tools/validate-scripts.sh
bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop
bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop/tests

# Version bump (was: bash set-version.sh)
bash docs/ai-developer/tools/set-version.sh devcontainer-toolbox

# Copy template (was: cp templates/script-template.sh ...)
cp docs/ai-developer/templates/script-template.sh scripts/my-package/my-script.sh
```

---

## Phase 1: Move files

### Tasks

- [ ] 1.1 Create `docs/ai-developer/tools/` and `docs/ai-developer/templates/`
- [ ] 1.2 `git mv tests/run-tests.sh docs/ai-developer/tools/validate-scripts.sh`
- [ ] 1.3 `git mv set-version.sh docs/ai-developer/tools/set-version.sh`
- [ ] 1.4 `git mv templates/script-template.sh docs/ai-developer/templates/script-template.sh`
- [ ] 1.5 Remove empty folders: `tests/`, `templates/`

### Validation

Files are in new locations, git history preserved via `git mv`.

---

## Phase 2: Fix validate-scripts.sh

The script needs 3 fixes:
1. Follow the script standard (metadata, logging, help, argument parsing)
2. Resolve `scripts/` path from repo root regardless of CWD
3. Replace `grep -oP` with macOS-compatible alternative

### Tasks

- [ ] 2.1 Add script standard sections (metadata, logging, help, argument parsing)
- [ ] 2.2 Resolve repo root from script location: `REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"` and use `SCRIPTS_DIR="${REPO_ROOT}/scripts"`
- [ ] 2.3 Replace all `grep -oP '^FIELD="\K[^"]+'` with `grep '^FIELD=' | head -1 | sed 's/^FIELD="//' | sed 's/".*//'` (or equivalent macOS-safe pattern)
- [ ] 2.4 Update internal usage comments to show new path
- [ ] 2.5 Test: `bash docs/ai-developer/tools/validate-scripts.sh` (all packages)
- [ ] 2.6 Test: `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop/tests`

### Validation

Validation passes for all packages and subfolders.

---

## Phase 3: Fix set-version.sh

Same 3 fixes as validate-scripts.sh.

### Tasks

- [ ] 3.1 Add script standard sections (metadata, logging, help, argument parsing)
- [ ] 3.2 Resolve repo root from script location (same pattern as validate-scripts.sh)
- [ ] 3.3 Replace `grep -oP` with macOS-safe alternative
- [ ] 3.4 Update internal usage comments to show new path
- [ ] 3.5 Test: `bash docs/ai-developer/tools/set-version.sh -h` (help works)

### Validation

set-version.sh passes validation: `bash docs/ai-developer/tools/validate-scripts.sh docs/ai-developer/tools`

Note: validate-scripts.sh currently only scans `scripts/`. To validate the tools themselves, pass the tools folder explicitly. This works because the script takes a folder path relative to `scripts/` OR validates any folder containing `.sh` files. If it doesn't support this yet, add support.

---

## Phase 4: Create README template

### Tasks

- [ ] 4.1 Create `docs/ai-developer/templates/README-template.md` with minimum sections:
  - Package title + one-line description
  - Scripts table (script name + purpose)
  - Usage section
  - Placeholder for additional sections (flags, prerequisites, etc.)
- [ ] 4.2 Verify it works as a starting point (copy, fill in, makes sense)

### Validation

Template exists and is usable.

---

## Phase 5: Expand CREATING-SCRIPTS.md for packages

CREATING-SCRIPTS.md currently covers individual scripts. Expand it to cover the full package structure.

### Tasks

- [ ] 5.1 Add "Package Structure" section defining what a package is and what it contains:
  - Required: `README.md`, at least one `.sh` script
  - Recommended: `TESTING.md`, `tests/` folder
- [ ] 5.2 Add "Creating a New Package" section with step-by-step:
  1. Create folder under `scripts/`
  2. Copy README template
  3. Copy script template
  4. Fill in metadata
  5. Run validation
- [ ] 5.3 Update all command paths from `tests/run-tests.sh` to `docs/ai-developer/tools/validate-scripts.sh`
- [ ] 5.4 Update template path from `templates/script-template.sh` to `docs/ai-developer/templates/script-template.sh`
- [ ] 5.5 Update `set-version.sh` path

### Validation

CREATING-SCRIPTS.md has correct paths and covers packages.

---

## Phase 6: Update all references

Every file that mentions the old paths needs updating. Grouped by priority.

### Active docs (critical — these are read regularly)

- [ ] 6.1 `CLAUDE.md` — update validation command, repo structure, set-version path
- [ ] 6.2 `README.md` — update validation command, repo structure
- [ ] 6.3 `OPS.md` — update all command paths (validation, set-version, template)
- [ ] 6.4 `docs/ai-developer/WORKFLOW.md` — update validation + set-version paths
- [ ] 6.5 `docs/ai-developer/PLANS.md` — update validation path in templates
- [ ] 6.6 `docs/ai-developer/README.md` — update validation + template paths
- [ ] 6.7 `scripts/rancher-desktop/README.md` — update validation path

### Plan files (low priority — historical reference, but should be accurate)

- [ ] 6.8 Update active plan files in `docs/ai-developer/plans/active/`
- [ ] 6.9 Update completed plan files in `docs/ai-developer/plans/completed/`
- [ ] 6.10 Update the investigation file

### Memory files

- [ ] 6.11 Update `/home/vscode/.claude/projects/-workspace/memory/MEMORY.md`

### Validation

`grep -r "tests/run-tests.sh\|bash set-version\|templates/script-template" .` returns no hits (excluding `.git/`).

---

## Phase 7: Final validation + cleanup

### Tasks

- [ ] 7.1 Run full validation: `bash docs/ai-developer/tools/validate-scripts.sh`
- [ ] 7.2 Run validation on test scripts: `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop/tests`
- [ ] 7.3 Run validation on tools: `bash docs/ai-developer/tools/validate-scripts.sh docs/ai-developer/tools` (if supported, otherwise validate manually)
- [ ] 7.4 Verify old folders are gone: `ls tests/ templates/` should fail
- [ ] 7.5 Grep for any remaining old paths

### Validation

All validation passes, no stale references remain.

---

## Acceptance Criteria

- [ ] All developer tools live under `docs/ai-developer/tools/`
- [ ] All templates live under `docs/ai-developer/templates/`
- [ ] Root has no loose scripts or tool folders (only `CLAUDE.md`)
- [ ] `validate-scripts.sh` and `set-version.sh` follow the script standard
- [ ] No `grep -oP` usage (macOS-compatible)
- [ ] All docs reference new paths
- [ ] Full validation passes
- [ ] README template exists

---

## Files to move

| From | To |
|------|----|
| `tests/run-tests.sh` | `docs/ai-developer/tools/validate-scripts.sh` |
| `set-version.sh` | `docs/ai-developer/tools/set-version.sh` |
| `templates/script-template.sh` | `docs/ai-developer/templates/script-template.sh` |

## Files to create

| File | Purpose |
|------|---------|
| `docs/ai-developer/templates/README-template.md` | Standard README for new packages |

## Files to modify

| File | Changes |
|------|---------|
| `docs/ai-developer/tools/validate-scripts.sh` | Script standard + path fix + grep fix |
| `docs/ai-developer/tools/set-version.sh` | Script standard + path fix + grep fix |
| `docs/ai-developer/CREATING-SCRIPTS.md` | Package structure + new paths |
| `CLAUDE.md` | New paths |
| `README.md` | New paths |
| `OPS.md` | New paths |
| `docs/ai-developer/WORKFLOW.md` | New paths |
| `docs/ai-developer/PLANS.md` | New paths |
| `docs/ai-developer/README.md` | New paths |
| `scripts/rancher-desktop/README.md` | New paths |
| Multiple plan files | New paths |

## Files/folders to remove

| Item | Reason |
|------|--------|
| `tests/` (root folder) | Empty after move |
| `templates/` (root folder) | Empty after move |
