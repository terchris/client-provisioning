# Investigate: Quick Start and Azure DevOps Documentation Gaps

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Goal**: Determine what changes are needed to make the docs clear for a new developer using Azure DevOps — from zero to working devcontainer.

**Completed**: 2026-02-10
**Last Updated**: 2026-02-10

---

## Context

The docs are clear for someone who already has git and Azure DevOps access set up. The gap is the **first 15 minutes** — getting credentials, choosing between host-git vs devcontainer-bootstrap, and configuring auth inside the devcontainer.

The completed [INVESTIGATE-developer-onboarding.md](../completed/INVESTIGATE-developer-onboarding.md) recommended **Option B** (bootstrap via devcontainer — skip git on the Mac), but the current Quick Start still describes the host-clone path (Option C), which requires git + Xcode CLT on the Mac.

Additionally, three devcontainer-toolbox issues have been resolved since that investigation:

- [#42](https://github.com/terchris/devcontainer-toolbox/issues/42) — Azure DevOps CLI tool (closed)
- [#43](https://github.com/terchris/devcontainer-toolbox/issues/43) — Machine-readable tool inventory (closed)
- [#44](https://github.com/terchris/devcontainer-toolbox/issues/44) — `config-azure-devops.sh` addition (closed)

These resolved issues mean the toolbox now has capabilities that the docs don't reference yet.

---

## Findings — What the toolbox provides now

Investigated using `dev-tools` JSON inventory and `--help`/`--show` on each config script.

### Config scripts available in the toolbox

The toolbox has **7 config scripts**. The three relevant to developer onboarding are:

| Script | What it does | Persistence |
|--------|-------------|-------------|
| `config-git.sh` | Set git `user.name` and `user.email` globally | `.devcontainer.secrets/env-vars/.git-identity` |
| `config-azure-devops.sh` | Set PAT, organization, and project defaults for `az devops` | `.devcontainer.secrets/env-vars/azure-devops-pat` |
| `config-ai-claudecode.sh` | Set Claude Code auth token and LiteLLM proxy config | `~/.claude-code-env` |

All three support the same interface:

- `(no args)` — interactive setup
- `--show` — display current configuration
- `--verify` — non-interactive restore from `.devcontainer.secrets/`

### What `config-azure-devops.sh` does

Requires `tool-azure-devops` (Azure CLI + azure-devops extension) to be installed first. Then:

1. Prompts for a Personal Access Token (PAT)
2. Configures `az devops` defaults (organization, project)
3. Exports `AZURE_DEVOPS_EXT_PAT` to the environment
4. Stores PAT in `.devcontainer.secrets/env-vars/azure-devops-pat`
5. After rebuild, `--verify` restores everything non-interactively

### Current persistence status (observed)

| Config | Persists across rebuild? | Notes |
|--------|-------------------------|-------|
| Git identity | Yes | Stored in `.devcontainer.secrets/env-vars/.git-identity` |
| Azure DevOps PAT | **Partially** | `--show` reports "Not saved (won't survive container rebuild)" — needs `config-azure-devops.sh` to be run interactively to save to `.devcontainer.secrets/` |
| Claude Code credentials | **No** | OAuth tokens in `~/.claude/.credentials.json` are lost on rebuild. [Issue #46](https://github.com/terchris/devcontainer-toolbox/issues/46) is open for this |

### The onboarding flow that now works inside the devcontainer

```text
1. dev-setup → Cloud Tools → Azure DevOps CLI     (installs az + azure-devops extension)
2. config-git.sh                                    (set git name/email)
3. config-azure-devops.sh                           (set PAT + org/project defaults)
4. git clone https://dev.azure.com/...              (clone using the configured PAT)
```

This is exactly the **Option B** flow from the onboarding investigation — all done inside the devcontainer, no git needed on the host.

---

## Questions to Answer

### 1. Authentication — what does a new developer actually need?

- What Azure DevOps access must be granted before the developer starts? (org access, project permissions, PAT scopes)
- Should the docs include a checklist for the IT admin who sets up the account?
- ~~Are there two separate auth flows (git clone vs `az` CLI) or can one PAT cover both?~~ **Answered**: One PAT covers both. Azure DevOps PATs authenticate both `az devops` CLI and `git clone` (same auth system).
- ~~Does `config-azure-devops.sh` in the toolbox now handle this? What exactly does it do?~~ **Answered**: See findings above.

### 2. Quick Start — which clone path should it describe?

- The investigation recommended Option B (devcontainer-first, no git on host). Should Quick Start be rewritten to follow this path?
- Or should Quick Start keep the simple host-clone path and add a separate "Advanced: devcontainer-bootstrap" section?
- What does the `devcontainer-init` flow actually look like for a brand-new user? Is it documented anywhere?

### 3. What does `dev-setup` offer for Azure DevOps now?

- ~~The toolbox resolved issue #44 (`config-azure-devops.sh`). What commands are now available?~~ **Answered**: See findings above.
- ~~Does `dev-setup` have a menu option for Azure DevOps configuration?~~ **Answered**: Yes — `dev-setup` → Cloud Tools → Azure DevOps CLI for install, then config script runs.
- Should the Quick Start or OPS guide reference `dev-setup` for auth configuration?

### 4. Credential persistence across container rebuilds

- ~~Does `.devcontainer.secrets/` automatically persist across rebuilds? How?~~ **Answered**: Yes, it's a workspace directory that survives rebuilds. Config scripts store credentials there and restore via `--verify`.
- ~~Does the developer need to do anything after a rebuild, or is it seamless?~~ **Answered**: Seamless. The toolbox entrypoint (`/opt/devcontainer-toolbox/entrypoint.sh`) loops through all config scripts that support `--verify` and restores them automatically on every container start (lines 181-194). Git identity is also explicitly restored (line 67-68).
- ~~`AZURE_DEVOPS_EXT_PAT` — is it auto-exported on container start, or must the user re-export it?~~ **Answered**: Auto-restored. The entrypoint runs `config-azure-devops.sh --verify` automatically, which re-exports `AZURE_DEVOPS_EXT_PAT` from `.devcontainer.secrets/`. The "Not saved" warning we observed was because the PAT was set via `project-installs.sh` (bypassing the config script), not via `config-azure-devops.sh` interactively.
- Claude Code credentials ([#46](https://github.com/terchris/devcontainer-toolbox/issues/46)) — still open. `config-ai-claudecode.sh` exists but handles LiteLLM proxy tokens, not the OAuth login token stored in `~/.claude/.credentials.json`.

### 5. Which docs need updating?

- **QUICK-START.md** — rewrite clone/auth steps?
- **OPS.md** — add `dev-setup` reference?
- **GIT-HOSTING-AZURE-DEVOPS.md** — add git clone auth (not just `az` CLI auth)?
- ~~**DEVCONTAINER-TOOLBOX.md** — reference new tools?~~ **Done**: Added `dev-tools` command and tool inventory section.
- ~~**AI-SUPPORTED-DEVELOPMENT.md** — add completed investigation to the table?~~ **Done**: Added developer-onboarding investigation.
- Should there be a new "Prerequisites" or "Before You Start" doc?

---

## Current State

| Doc | What it covers | Gap |
|-----|---------------|-----|
| QUICK-START.md | Full walkthrough from install to push | No prerequisites checklist, vague auth at clone step, describes host-clone path (not recommended Option B) |
| OPS.md | Day-to-day workflow | No mention of `dev-setup` or credential configuration |
| GIT-HOSTING-AZURE-DEVOPS.md | az CLI PRs, merge, wiki, PAT auth | Covers `az` CLI auth but not `git clone` auth, doesn't mention `config-azure-devops.sh` |
| DEVCONTAINER-TOOLBOX.md | Tool discovery, install, `dev-tools` | Updated with `dev-tools` — but doesn't list the config scripts or the onboarding flow |

---

## Options

### Option A: Update existing docs in place

Add prerequisites, fix auth steps, reference `dev-setup` and config scripts — minimal structural changes.

**Pros:**

- Least disruption
- No new files to maintain

**Cons:**

- Quick Start may become too long if it covers both host-clone and devcontainer-bootstrap paths
- Auth/credential info stays scattered across multiple files

### Option B: Rewrite Quick Start around devcontainer-first flow

Rewrite Quick Start to follow the recommended devcontainer-bootstrap flow. Keep a short "Alternative: clone on host" section for those who prefer it.

**Pros:**

- Aligns docs with the recommended onboarding approach
- Simpler for new users (fewer things to install on the host)
- The toolbox now has everything needed (`config-git.sh`, `config-azure-devops.sh`, `dev-setup`)

**Cons:**

- Bigger rewrite
- Need to verify the devcontainer-bootstrap flow actually works end-to-end before documenting it

### Option C: Add a new "Before You Start" prerequisites doc

Create a prerequisites/setup doc that covers account access, PAT creation, and admin tasks. Keep Quick Start focused on the development workflow.

**Pros:**

- Separates IT admin tasks from developer tasks
- Quick Start stays clean and focused

**Cons:**

- One more doc to maintain
- New developers must find and read two docs instead of one

---

## Recommendation

**Option B** — rewrite Quick Start around the devcontainer-first flow, with a prerequisites section at the top.

### Why

The toolbox now has the complete onboarding flow built in:

1. `config-git.sh` — git identity with persistence
2. `config-azure-devops.sh` — PAT + org/project with persistence
3. `dev-setup` menu — guided install of Azure DevOps CLI
4. All config scripts support `--show` and `--verify` for transparency and rebuild recovery

This matches the Option B recommendation from the onboarding investigation. The Quick Start should describe the flow that actually works today, not the manual host-clone path.

Add a short prerequisites section at the top of Quick Start (Azure DevOps account, PAT creation) rather than a separate doc — keeps everything in one place.

---

## Next Steps

- [x] Check what `config-azure-devops.sh` actually does in the current toolbox
- [x] Verify that one PAT works for both `az devops` and `git clone` — yes, same auth system
- [x] Check if `--verify` runs automatically on container start — yes, entrypoint.sh loops all config scripts
- [ ] Create PLAN file for the doc updates — see [PLAN-update-quickstart-docs.md](../backlog/PLAN-update-quickstart-docs.md)
