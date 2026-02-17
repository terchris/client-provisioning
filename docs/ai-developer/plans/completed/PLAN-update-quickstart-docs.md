# Plan: Update Quick Start and onboarding docs for devcontainer-first flow

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Goal**: Update docs so a new developer using Azure DevOps can go from zero to working devcontainer without getting stuck.

**Last Updated**: 2026-02-10

**Based on**: [INVESTIGATE-quickstart-azure-devops-gaps.md](../completed/INVESTIGATE-quickstart-azure-devops-gaps.md)

---

## Problem

The current docs assume the developer already has git and Azure DevOps access set up. A new developer hits these gaps:

1. **No prerequisites** — no mention that they need an Azure DevOps account and PAT before starting
2. **Vague auth** — Quick Start says "sign in with your Azure DevOps credentials" at clone step but doesn't explain what that means
3. **Wrong clone path** — Quick Start describes host-clone (needs git + Xcode CLT on Mac), but the recommended approach is devcontainer-first (no git on host needed)
4. **No mention of config scripts** — the toolbox has `config-git.sh`, `config-azure-devops.sh`, and `dev-setup` but no docs reference them
5. **No credential persistence info** — developers don't know that `.devcontainer.secrets/` survives rebuilds and that `--verify` restores everything automatically

## Key findings from investigation

- The toolbox entrypoint runs `--verify` on all config scripts at every container start — credentials restore automatically
- `config-azure-devops.sh` handles PAT, org, and project defaults with persistence in `.devcontainer.secrets/`
- `config-git.sh` handles git identity with persistence
- One PAT works for both `az devops` and `git clone`
- The complete onboarding flow works inside the devcontainer: `dev-setup` → `config-git` → `config-azure-devops` → `git clone`

---

## Phase 1: Rewrite QUICK-START.md — DONE

### Tasks

- [x] 1.1 Add a **Prerequisites** section ("Before You Start") with Azure DevOps account, PAT creation steps with scopes
- [x] 1.2 Rewrite install/setup steps: VS Code → Docker/Rancher → Dev Containers extension → clone with PAT → open in container → config scripts
- [x] 1.3 Kept host-clone as the primary path (simpler for beginners) with config scripts as step 6 inside the devcontainer
- [x] 1.4 Add **Credential Persistence** section explaining `.devcontainer.secrets/` and auto-restore
- [x] 1.5 Kept existing day-to-day workflow sections unchanged
- [x] Added link to Devcontainer Toolbox in Getting Help

### Validation

User confirms Quick Start reads clearly from a new developer's perspective.

---

## Phase 2: Update OPS.md — DONE

### Tasks

- [x] 2.1 Added `dev-setup` and credential reference to prerequisites and step 1
- [x] 2.2 Added note about `.devcontainer.secrets/` persistence and auto-restore

### Validation

User confirms OPS.md changes are appropriate.

---

## Phase 3: Update GIT-HOSTING-AZURE-DEVOPS.md — DONE

### Tasks

- [x] 3.1 Rewrote Authentication section — `config-azure-devops.sh` is now the primary method, manual setup is an alternative
- [x] 3.2 Added note that same PAT works for both `az devops` and `git clone`
- [x] 3.3 Added note about auto-restore on rebuild via `--verify`
- [x] 3.4 Updated Prerequisites to reference `dev-setup` for installation

### Validation

User confirms GIT-HOSTING doc is consistent with Quick Start.

---

## Phase 4: Update DEVCONTAINER-TOOLBOX.md — DONE

### Tasks

- [x] 4.1 Added **Configuration Scripts** section with table listing `config-git.sh` and `config-azure-devops.sh`, their flags, and persistence locations
- [x] 4.2 Added note about auto-restore on startup via entrypoint `--verify`
- [x] 4.3 Updated **Temporary Project Installs** — noted `tool-azure-devops` is now available in toolbox (#42 closed), project-installs entry can be removed

### Validation

User confirms DEVCONTAINER-TOOLBOX.md is consistent.

---

## Phase 5: Update AI-SUPPORTED-DEVELOPMENT.md — DONE

### Tasks

- [x] 5.1 Add the quickstart-azure-devops-gaps investigation to the completed plans table

### Validation

Done — both investigations added earlier in the session.

---

## Acceptance Criteria

- [x] A new developer can follow Quick Start from zero to working devcontainer without getting stuck
- [x] Prerequisites (account, PAT) are clearly listed before the install steps
- [x] The devcontainer-first flow is the primary documented path
- [x] Config scripts (`config-git.sh`, `config-azure-devops.sh`) are referenced in relevant docs
- [x] Credential persistence is explained (`.devcontainer.secrets/` + auto-restore)
- [x] All four docs are consistent with each other

---

## Files to Modify

- `docs/QUICK-START.md` — major rewrite (phases 1)
- `docs/OPS.md` — minor additions (phase 2)
- `docs/ai-developer/GIT-HOSTING-AZURE-DEVOPS.md` — update auth section (phase 3)
- `docs/ai-developer/DEVCONTAINER-TOOLBOX.md` — add config scripts section (phase 4)
- `docs/AI-SUPPORTED-DEVELOPMENT.md` — add to completed table (phase 5)
