# Fix: Temporary Azure DevOps CLI install until toolbox adds it

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Goal**: Install Azure CLI + azure-devops extension via `project-installs.sh` so we can manage Azure DevOps from the CLI.

**Last Updated**: 2026-02-08

---

## Problem

This repo is hosted on Azure DevOps, not GitHub. The `gh` CLI only works with GitHub. Without the `az` CLI and its `azure-devops` extension, we have to use the web UI for everything — PRs, work items, pipelines, wiki.

A proper toolbox install script has been requested ([ISSUE-azure-devops-cli.md](../devcontainer-toolbox-issues/ISSUE-azure-devops-cli.md)), but until the devcontainer-toolbox maintainer implements it, we need a temporary workaround.

## What the azure-devops extension enables

| Command group | What it does | Examples |
|---------------|-------------|----------|
| `az repos` | PRs, branches, policies, merge | `az repos pr create`, `az repos pr list` |
| `az boards` | Work items, queries, iterations, areas | `az boards work-item create`, `az boards query` |
| `az pipelines` | Build/release pipelines, runs, variables | `az pipelines run list`, `az pipelines show` |
| `az artifacts` | Package feeds | `az artifacts feed list` |
| `az devops wiki` | Wiki pages | `az devops wiki page show` |
| `az devops` | Projects, extensions, service endpoints | `az devops project list` |

## Solution

Use `.devcontainer.extend/project-installs.sh` — the project-specific hook that runs after standard tools are installed. This persists across container rebuilds and is the intended place for project-specific packages.

---

## Phase 1: Install Azure CLI + azure-devops extension — DONE

### Tasks

- [x] 1.1 Add Azure CLI install and azure-devops extension to `project-installs.sh`
- [x] 1.2 Add a comment noting this is temporary until `tool-azure-devops` exists in the toolbox

### Validation

Rebuild the container (or run `project-installs.sh` manually) and verify:

```bash
az --version
az extension show --name azure-devops
```

User confirms both commands succeed.

---

## Phase 2: Document in DEVCONTAINER-TOOLBOX.md — DONE

### Tasks

- [x] 2.1 Add a "Temporary Project Installs" section documenting the az install and linking to the issue

### Validation

User confirms the note is clear.

---

## Acceptance Criteria

- [x] `az` CLI is installed — v2.83.0
- [x] `az extension show --name azure-devops` succeeds — v1.0.2
- [x] VS Code extension `ankitbko.vscode-pull-request-azdo` installed
- [x] Install is in `project-installs.sh` (not a custom Dockerfile or manual step)
- [x] Comment in `project-installs.sh` marks this as temporary
- [x] Idempotent — re-runs skip already installed components

---

## Files to Modify

- `.devcontainer.extend/project-installs.sh` — add az CLI + extension install
- `docs/ai-developer/DEVCONTAINER-TOOLBOX.md` — add note about temporary workaround
