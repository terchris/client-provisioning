# Investigate: Script Package Standard

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Complete

**Goal**: Define a standard structure and terminology for script packages, consolidate developer tooling under `docs/ai-developer/`, and resolve the `tests/` naming conflict.

**Last Updated**: 2026-02-08

---

## Questions to Answer

1. What should every script folder ("package") contain?
2. What's the right terminology for root-level validation vs per-package functional tests?
3. Where should developer tools live? (`set-version.sh`, `run-tests.sh`, `script-template.sh`)
4. What rules should be enforced vs recommended?
5. Where should these rules be documented?

---

## Decisions Made

### Root folder rename: `tests/` → move into `docs/ai-developer/tools/`

The root `tests/` folder does **validation** (format checks), not functional testing. To avoid confusion with per-package `tests/` folders (functional tests), and to consolidate all developer tooling, the validation script moves into `docs/ai-developer/tools/`.

### Developer tooling consolidation: everything under `docs/ai-developer/`

All developer tools, templates, and docs live in one tree. The only root-level file is `CLAUDE.md` (required by Claude Code).

**Before (scattered across root):**
```
CLAUDE.md
set-version.sh
tests/run-tests.sh
templates/script-template.sh
docs/ai-developer/
  WORKFLOW.md, PLANS.md, CREATING-SCRIPTS.md
  plans/
```

**After (consolidated):**
```
CLAUDE.md                           ← stays at root (Claude Code requires it)

docs/ai-developer/
  WORKFLOW.md                       ← existing
  PLANS.md                          ← existing
  CREATING-SCRIPTS.md               ← existing (expand to cover packages)
  plans/                            ← existing
  tools/
    validate-scripts.sh             ← moved from tests/run-tests.sh
    set-version.sh                  ← moved from root
  templates/
    script-template.sh              ← moved from templates/
```

**Benefits:**
- One folder to copy to set up a new repo
- Root is clean — no loose scripts
- Clear what's "our stuff" vs "the project"
- Terminology is resolved: "validation" = format checks (in tools/), "tests" = functional tests (in each package)

### Terminology

| Term | Meaning | Location |
|------|---------|----------|
| **Validation** | Checks that scripts follow the standard template (syntax, help, metadata, shellcheck) | `docs/ai-developer/tools/validate-scripts.sh` |
| **Tests** | Functional tests that verify scripts actually work on a target machine | `scripts/<package>/tests/` |
| **Package** | A script folder under `scripts/` with its scripts, docs, and tests | `scripts/<name>/` |

---

## Current State

### Repo structure today

```
CLAUDE.md
set-version.sh                      ← loose in root
tests/                              ← confusing name
  run-tests.sh
templates/                          ← loose in root
  script-template.sh

docs/ai-developer/
  WORKFLOW.md, PLANS.md, CREATING-SCRIPTS.md
  plans/

scripts/
  devcontainer-toolbox/             ← has README, no tests, no TESTING.md
    README.md
    devcontainer-init.sh
    devcontainer-init-install.sh
    devcontainer-pull.sh

  rancher-desktop/                  ← has README + TESTING.md + tests/
    README.md
    TESTING.md
    rancher-desktop-install.sh
    rancher-desktop-uninstall.sh
    rancher-desktop-k8s.sh
    rancher-desktop-config.sh
    tests/
      test-helpers.sh
      test-1-install.sh
      ...
      run-all-tests.sh

  urbalurba-infrastructure-stack/   ← empty
```

### Issues with set-version.sh

The current `set-version.sh` does NOT follow the script standard:
- No metadata fields (SCRIPT_ID, SCRIPT_NAME, etc.)
- No standard logging functions
- No standard help format
- Uses `grep -oP` (Perl regex) which is not available on macOS
- Lives loose in the repo root with no clear home

It needs to be fixed when it moves to `docs/ai-developer/tools/`.

---

## Open Questions

### 1. Should functional tests be required for every package?

Options:
- **Required**: Every package must have `tests/` and `TESTING.md`. Ensures nothing ships untested.
- **Recommended**: Packages should have tests, but simple packages can skip them. Validation still runs for all.
- **Tiered**: Require `TESTING.md` (even if it just says "run the script and verify manually"), make `tests/` optional.

### 2. Should README.md follow a standard template?

rancher-desktop has a detailed README. devcontainer-toolbox has a basic one. Should we define minimum sections?

Possible minimum:
```markdown
# Package Name
One-line description.

## Scripts
| Script | Purpose |
...

## Usage
How to run the scripts.
```

### 3. Should we create a package scaffold tool?

A script that creates the whole folder structure:
```bash
bash docs/ai-developer/tools/new-package.sh my-new-package
# Creates:
#   scripts/my-new-package/
#   scripts/my-new-package/README.md (from template)
#   scripts/my-new-package/TESTING.md (from template)
#   scripts/my-new-package/tests/ (empty)
```

### 4. Should validate-scripts.sh warn about missing package files?

Could add checks like:
```
WARNING: scripts/devcontainer-toolbox/ has no TESTING.md
WARNING: scripts/devcontainer-toolbox/ has no tests/ folder
```
Not a failure — just a reminder.

### 5. Should the tools themselves follow the script standard?

`validate-scripts.sh` and `set-version.sh` are developer tools, not deployment scripts. Should they have the full template (metadata, logging, help format)? Or is that overkill for tools that never get deployed to Macs via Jamf?

Arguments for: consistency, the validation script can validate itself.
Arguments against: these aren't Jamf scripts, the standard was designed for deployment scripts.

---

## Proposed Package Standard

Every script folder under `scripts/` is a **package**.

### Required

| Item | Purpose |
|------|---------|
| `README.md` | What the package does, how to use it |
| At least one `.sh` script | The deployment script(s) |

### Recommended

| Item | Purpose |
|------|---------|
| `TESTING.md` | How to test on a real Mac (or target machine) |
| `tests/` folder | Functional test scripts |

### Target structure

```
scripts/my-package/
  README.md
  TESTING.md
  my-script.sh
  my-other-script.sh
  tests/
    test-helpers.sh
    test-1-something.sh
    test-2-something.sh
    run-all-tests.sh
```

---

## Commands after consolidation

```bash
# Validate script format (replaces: bash tests/run-tests.sh)
bash docs/ai-developer/tools/validate-scripts.sh

# Validate one package
bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop

# Validate package tests
bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop/tests

# Bump versions
bash docs/ai-developer/tools/set-version.sh devcontainer-toolbox
```

---

## Next Steps

- [ ] Resolve open questions with user
- [ ] Create PLAN with the implementation steps (move files, update references, fix set-version.sh)
