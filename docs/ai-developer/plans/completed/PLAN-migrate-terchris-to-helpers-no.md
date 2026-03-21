# Plan: Migrate terchris references to helpers-no

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Goal**: Replace all `terchris` GitHub/GHCR references with `helpers-no` across the repository, excluding Windows usernames, file paths in example logs, and Author comments in script headers.

**Last Updated**: 2026-03-21
**Completed**: 2026-03-21

---

## Problem

The repository still references the old `terchris` GitHub account in GitHub URLs, GHCR container image names, REPO variables in scripts, and the LICENSE copyright. This needs to be updated to reflect the new `helpers-no` organisation.

## What to change vs. keep

### Change
- GitHub URLs: `github.com/terchris/` → `github.com/helpers-no/`
- GHCR image refs: `ghcr.io/terchris/` → `ghcr.io/helpers-no/`
- REPO variables in scripts: `terchris/devcontainer-toolbox` → `helpers-no/devcontainer-toolbox`
- LICENSE copyright: `Copyright (c) 2026 terchris` → `Copyright (c) 2026 helpers-no`

### Keep as-is
- `.gitignore` entry `terchris/` and comment `# terchris temp folder` (personal temp folder exclusion)
- `Author: terchris` comments in bash script headers
- Windows usernames in example log files: `AzureAD\terchris`, `C:\Users\terchris\...`

---

## Phase 1: Update GitHub URLs in documentation — DONE

### Tasks

- [x] 1.1 Update `.devcontainer/devcontainer.json` — comment URL and image reference
- [x] 1.2 Update `docs/ai-developer/DEVCONTAINER-TOOLBOX.md` — GitHub URL and `gh issue create` command
- [x] 1.3 Update `docs/ai-developer/devcontainer-toolbox-issues/ISSUE-cmd-publish-github.md` — GitHub URLs
- [x] 1.4 Update `docs/ai-developer/devcontainer-toolbox-issues/README.md` — GitHub issue links
- [x] 1.5 Update `docs/ai-developer/devcontainer-toolbox-issues/ISSUE-update-upgrade-mechanism.md` — GitHub release URL
- [x] 1.6 Update `docs/AI-SUPPORTED-DEVELOPMENT.md` — GitHub reference
- [x] 1.7 Update completed plan files that reference `github.com/terchris/` or `githubusercontent.com/terchris/`

### Validation

```bash
grep -r "github\.com/terchris" docs/ .devcontainer/
grep -r "githubusercontent\.com/terchris" docs/ .devcontainer/
```

No matches expected (excluding .gitignore content).

---

## Phase 2: Update scripts — Mac (bash) and Windows (PowerShell) — DONE

### Tasks

- [x] 2.1 Update `scripts-mac/devcontainer-toolbox/devcontainer-pull.sh` — IMAGE_NAME variable
- [x] 2.2 Update `scripts-mac/devcontainer-toolbox/devcontainer-init.sh` — REPO variable
- [x] 2.3 Update `scripts-mac/devcontainer-toolbox/tests/test-1-pull.sh` — IMAGE_NAME variable
- [x] 2.4 Update `scripts-win/devcontainer-toolbox/install.ps1` — CONTAINER_IMAGE variable
- [x] 2.5 Update `scripts-win/devcontainer-toolbox/uninstall.ps1` — CONTAINER_IMAGE variable
- [x] 2.6 Update `scripts-win/devcontainer-toolbox/devcontainer-init.ps1` — REPO variable
- [x] 2.7 Update `scripts-win/devcontainer-toolbox/README.md` — Docker image reference
- [x] 2.8 Update `scripts-win/devcontainer-toolbox/INTUNE.md` — Docker image reference

### Validation

```bash
grep -r "ghcr\.io/terchris" scripts-mac/ scripts-win/
grep -r '"terchris/' scripts-mac/ scripts-win/
grep -r "'terchris/" scripts-mac/ scripts-win/
bash docs/ai-developer/tools/validate-bash.sh devcontainer-toolbox
```

No `terchris` matches expected (Author comments are excluded from the grep targets above).

---

## Phase 3: Update example log files — Docker image references only — DONE

### Tasks

- [x] 3.1 Update `scripts-win/devcontainer-toolbox/tests/example-init.log` — `ghcr.io/terchris/` references (keep `AzureAD\terchris` and `C:\Users\terchris` intact)
- [x] 3.2 Update `scripts-win/devcontainer-toolbox/tests/example-install.log` — `ghcr.io/terchris/` references (keep Windows username paths intact)
- [x] 3.3 Update `scripts-win/devcontainer-toolbox/tests/example-uninstall.log` — `ghcr.io/terchris/` references (keep Windows username paths intact)
- [x] 3.4 Update completed plan docs with `ghcr.io/terchris/` or `docker pull terchris/` references (already done in Phase 1)

### Validation

```bash
grep -r "ghcr\.io/terchris" scripts-win/
grep -r "docker pull terchris/" docs/
```

No matches expected.

---

## Phase 4: Update LICENSE copyright — DONE

### Tasks

- [x] 4.1 Update `LICENSE` — `Copyright (c) 2026 terchris` → `Copyright (c) 2026 helpers-no`
- [x] 4.2 `.gitignore` entry `terchris/` — **keep as-is** (personal temp folder, no change needed)
- [x] 4.3 `Author: terchris` in script headers — **keep as-is** (attribution, no change needed)

### Validation

```bash
grep "terchris" LICENSE
```

No matches expected.

Final check — remaining `terchris` occurrences should only be in:
- `.gitignore` (personal temp folder entry)
- Script `Author:` headers
- Windows username paths in example log files

```bash
grep -rn "terchris" . \
  --exclude-dir=".git" \
  --exclude-dir=".claude"
```

---

## Acceptance Criteria

- [x] All `github.com/terchris/` and `ghcr.io/terchris/` references updated to `helpers-no`
- [x] LICENSE copyright updated
- [x] `.gitignore` terchris/ entry preserved
- [x] `Author: terchris` headers preserved
- [x] Windows username paths in example logs preserved
- [x] `bash docs/ai-developer/tools/validate-bash.sh devcontainer-toolbox` passes

---

## Files to Modify

**Documentation:**
- `.devcontainer/devcontainer.json`
- `docs/AI-SUPPORTED-DEVELOPMENT.md`
- `docs/ai-developer/DEVCONTAINER-TOOLBOX.md`
- `docs/ai-developer/devcontainer-toolbox-issues/ISSUE-cmd-publish-github.md`
- `docs/ai-developer/devcontainer-toolbox-issues/README.md`
- `docs/ai-developer/devcontainer-toolbox-issues/ISSUE-update-upgrade-mechanism.md`
- `docs/ai-developer/plans/completed/INVESTIGATE-devcontainer-json-download-url.md`
- `docs/ai-developer/plans/completed/INVESTIGATE-quickstart-azure-devops-gaps.md`
- `docs/ai-developer/plans/completed/INVESTIGATE-developer-onboarding.md`
- `docs/ai-developer/plans/completed/INVESTIGATE-devcontainer-first-open.md`
- `docs/ai-developer/plans/completed/INVESTIGATE-devcontainer-toolbox-testing.md`
- `docs/ai-developer/plans/completed/INVESTIGATE-windows-devcontainer-toolbox.md`
- `docs/ai-developer/plans/completed/PLAN-windows-devcontainer-toolbox.md`

**Mac scripts:**
- `scripts-mac/devcontainer-toolbox/devcontainer-pull.sh`
- `scripts-mac/devcontainer-toolbox/devcontainer-init.sh`
- `scripts-mac/devcontainer-toolbox/tests/test-1-pull.sh`

**Windows scripts:**
- `scripts-win/devcontainer-toolbox/install.ps1`
- `scripts-win/devcontainer-toolbox/uninstall.ps1`
- `scripts-win/devcontainer-toolbox/devcontainer-init.ps1`
- `scripts-win/devcontainer-toolbox/README.md`
- `scripts-win/devcontainer-toolbox/INTUNE.md`

**Example logs:**
- `scripts-win/devcontainer-toolbox/tests/example-init.log`
- `scripts-win/devcontainer-toolbox/tests/example-install.log`
- `scripts-win/devcontainer-toolbox/tests/example-uninstall.log`

**Other:**
- `LICENSE`
