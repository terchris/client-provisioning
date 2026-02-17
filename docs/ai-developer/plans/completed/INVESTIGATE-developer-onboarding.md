# Investigate: Developer Onboarding via Jamf

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Goal**: Determine how to onboard a new developer on a fresh Mac using Jamf, so they can edit, test, and deploy scripts from this repo.

**Completed**: 2026-02-10
**Last Updated**: 2026-02-10

---

## Context

A new developer gets a Mac with nothing installed. They need to be able to:

1. Clone this repo
2. Open it in VS Code with the devcontainer
3. Edit, test, and commit scripts
4. Push changes to Azure DevOps

Currently this requires manual installation of multiple tools and manual configuration. We want to automate as much as possible via Jamf, since we already use it for Mac deployment (see `scripts-mac/rancher-desktop/` for an example).

**Already automated via Jamf:**

- **Rancher Desktop** — `scripts-mac/rancher-desktop/` (install, config, uninstall, K8s toggle)
- **Devcontainer toolbox** — `scripts-mac/devcontainer-toolbox/` (pull image, install `devcontainer-init` command, initialize projects)

**Not yet automated — this is what we need to investigate:**

- VS Code installation
- Git installation (Xcode Command Line Tools)
- Git configuration (user.name, user.email)
- Azure DevOps authentication (PAT or Git Credential Manager)
- Cloning the repo
- Training flow using the AId project (`https://dev.azure.com/YOUR-ORG/AId`)

---

## Questions to Answer

### VS Code

1. Can VS Code be deployed via Jamf as a .pkg or .dmg? Is there an official pkg installer?
2. Can VS Code settings (e.g. default terminal, font size) be pre-configured via a settings.json deployed by Jamf?

Note: VS Code extensions are handled by the devcontainer toolbox — they get installed automatically when the repo is opened in the devcontainer.

### Git

3. What is the best way to install git on a Mac without Homebrew?
4. `xcode-select --install` triggers a UI dialog — can Jamf install the Command Line Tools package silently? (The CLT is ~500MB, includes git, make, clang — no full Xcode needed)
5. Is there a standalone git .pkg that can be deployed via Jamf?
6. The onboarding script should detect if git is already installed (`/usr/bin/git` via CLT) and skip if so
7. Can a Jamf script set `git config --global user.name` and `user.email` for the logged-in user? What are the gotchas when the script runs as root?

### Azure DevOps Authentication

9. What is Git Credential Manager (GCM)? Can it be deployed via Jamf?
10. Does GCM handle Azure DevOps authentication automatically (browser-based login)?
11. Or is a Personal Access Token (PAT) the simpler approach for our use case?
12. Can any part of PAT creation be automated, or must the user always create it manually in the Azure DevOps web UI?
13. Can Jamf pre-configure the git credential helper so the user only needs to authenticate once?

### Repo Clone

14. Can a Jamf script clone the repo into the user's home directory?
15. What are the permission issues when cloning as root vs as the logged-in user?
16. Should cloning be automated, or is it better as a manual step the user does after auth is set up?

### Training Environment

17. There is a dedicated training project at `https://dev.azure.com/YOUR-ORG/AId` that all developers can use to learn Azure DevOps. How should this be integrated into the onboarding flow?
18. Should the onboarding script clone a training repo from AId first, so the developer can practice git/Azure DevOps before working on real projects?
19. What training repos and exercises should exist in AId?

---

## Current State

| Component | Status | How |
|-----------|--------|-----|
| Rancher Desktop | Automated | `scripts-mac/rancher-desktop/` via Jamf |
| Devcontainer toolbox | Automated | `scripts-mac/devcontainer-toolbox/` via Jamf |
| VS Code | Manual | User downloads and installs |
| Git | Manual | User runs `xcode-select --install` |
| Git config | Manual | User runs `git config` commands |
| Azure DevOps auth | Manual | User creates PAT in web UI |
| Repo clone | Manual | User runs `git clone` |
| VS Code extensions | Semi-auto | Dev Containers extension installed by devcontainer, but only after repo is opened |

---

## Options

### Option A: Do everything on the Mac

Install git, VS Code, GCM on the Mac via Jamf. User clones the repo on the Mac, then opens in devcontainer.

**Pros:**

- Standard git workflow — clone first, then develop
- Git works outside the devcontainer too

**Cons:**

- Need Xcode CLT on every Mac (~500MB download)
- Azure DevOps auth on the Mac is complex (PAT or GCM)
- Running Jamf scripts as root complicates user-level git config

### Option B: Bootstrap via devcontainer — skip git on the Mac

The devcontainer already has git, az CLI, and the azure-devops extension. The idea: avoid installing git on the Mac entirely by doing everything inside the devcontainer.

**Flow:**

1. Jamf installs only **Rancher Desktop** + **VS Code** (both already have Jamf scripts)
2. User runs `devcontainer-init ~/projects/client-provisioning` — creates devcontainer config (no git needed)
3. User opens the folder in VS Code — devcontainer starts
4. Inside the devcontainer, a setup script runs that:
   - Prompts for Azure DevOps PAT
   - Configures git identity (user.name, user.email)
   - Clones the repo into the workspace
   - Configures az devops defaults

**Key insight:** `devcontainer-init.sh` downloads devcontainer.json from a URL — it doesn't need git. So the devcontainer can bootstrap itself, then handle cloning from inside where all tools exist.

**What already works inside the devcontainer:**

- git (pre-installed in the container image)
- az CLI + azure-devops extension (via `project-installs.sh`)
- VS Code extensions (via `devcontainer.json` customizations)
- `initializeCommand` in devcontainer.json captures host git identity into `.devcontainer.secrets/`

**What needs to be built:**

- A setup script that runs inside the devcontainer on first use
- It prompts for PAT and git identity (unless already captured from host)
- It clones the repo and configures az devops defaults

**Pros:**

- Only two things to install on the Mac (Rancher Desktop + VS Code)
- No git, no CLT, no GCM, no PAT management on the Mac
- All dev tooling lives in the devcontainer — consistent across everyone
- Extends existing `scripts-mac/devcontainer-toolbox/` rather than creating a new package

**Cons:**

- Git only works inside the devcontainer, not on the Mac
- First-time setup requires opening a "bootstrap" devcontainer before the repo is cloned
- Need to solve: how does the workspace bind-mount work if the repo isn't cloned yet?

### Option C: Hybrid — git on Mac for clone only, everything else in devcontainer

Minimal Mac setup: just enough to clone. Everything else in the devcontainer.

**Flow:**

1. Jamf installs Rancher Desktop + VS Code + Xcode CLT (for git)
2. User creates a PAT in Azure DevOps web UI
3. User clones: `git clone https://dev.azure.com/...` (uses PAT as password)
4. User opens in VS Code — devcontainer handles everything else

**Pros:**

- Standard clone workflow (familiar to anyone who's used git)
- Devcontainer handles the complex tooling (az CLI, extensions, etc.)
- Mac setup is simple — just packages, no config

**Cons:**

- Still need CLT on the Mac for the initial clone
- User must create PAT manually before cloning

---

## Recommendation

**Option B (bootstrap via devcontainer)** combined with a new `config-azure-devops.sh` addition for the devcontainer-toolbox.

### Why

**Cross-platform by default.** The devcontainer runs on Mac, Windows, and Linux — the same setup flow works everywhere. By using git inside the devcontainer, we avoid platform-specific git installation entirely (no Xcode CLT on Mac, no Git for Windows, no package manager differences on Linux). The devcontainer is the single environment where all development happens, regardless of the host OS.

The devcontainer-toolbox already has `config-git.sh` that handles git identity inside the devcontainer — interactive setup, persistent storage in `.devcontainer.secrets/`, `dev-setup.sh` menu integration. A `config-azure-devops.sh` script following the same pattern would handle:

- Prompt for Azure DevOps PAT (or read from `.devcontainer.secrets/env-vars/azure-devops-pat`)
- Configure `az devops` defaults (organization, project)
- Export `AZURE_DEVOPS_EXT_PAT` to the environment
- Persist across container rebuilds via `.devcontainer.secrets/`
- Support `--show`, `--verify` (non-interactive restore), and interactive mode
- Integrate with the `dev-setup.sh` menu

This belongs in the **devcontainer-toolbox** (not project-specific) because Azure DevOps is used across multiple repos in the organization.

### Full onboarding flow with this approach

1. **Install prerequisites** (once per machine):
   - Docker/Rancher Desktop (Mac: via Jamf `scripts-mac/rancher-desktop/`, Windows/Linux: manual or org tooling)
   - VS Code (Mac: via Jamf or manual, Windows/Linux: download from code.visualstudio.com)
   - Devcontainer toolbox (Mac: via Jamf `scripts-mac/devcontainer-toolbox/`, Windows/Linux: manual setup)

2. **User runs** (one-time, on any OS):
   - `devcontainer-init ~/projects/client-provisioning` — creates devcontainer config (no git needed)
   - Opens folder in VS Code — devcontainer starts

3. **Inside the devcontainer** (guided by `dev-setup.sh` menu):
   - `config-git.sh` — set git identity
   - `config-azure-devops.sh` — set PAT and org/project defaults
   - Clone the repo: `git clone https://dev.azure.com/...`

4. **Training** (optional):
   - New developers can first clone the training repo from `https://dev.azure.com/YOUR-ORG/AId` to practice

### Toolbox issues

Toolbox issues were filed and resolved:

| Local issue file | GitHub issue | Status |
|---|---|---|
| [ISSUE-azure-devops-cli.md](../../devcontainer-toolbox-issues/ISSUE-azure-devops-cli.md) | [#42](https://github.com/terchris/devcontainer-toolbox/issues/42) — Need lightweight Azure DevOps tool | **Closed** |
| [ISSUE-config-azure-devops.md](../../devcontainer-toolbox-issues/ISSUE-config-azure-devops.md) | [#44](https://github.com/terchris/devcontainer-toolbox/issues/44) — Need config-azure-devops.sh addition | **Closed** |
| [ISSUE-machine-readable-tool-inventory.md](../../devcontainer-toolbox-issues/ISSUE-machine-readable-tool-inventory.md) | [#43](https://github.com/terchris/devcontainer-toolbox/issues/43) — Ship machine-readable tool inventory | **Closed** |
| [ISSUE-persist-claude-credentials.md](../../devcontainer-toolbox-issues/ISSUE-persist-claude-credentials.md) | [#46](https://github.com/terchris/devcontainer-toolbox/issues/46) — Persist Claude Code credentials | **Open** |

---

## Next Steps

- [x] Submit toolbox issue for `config-azure-devops.sh` — resolved in toolbox ([#44](https://github.com/terchris/devcontainer-toolbox/issues/44))
- [ ] Research VS Code deployment via Jamf (.pkg availability)
- [ ] Test the bootstrap flow: `devcontainer-init` → open in VS Code → clone from inside
- [ ] Create training repo in AId project
- [ ] Create PLAN-developer-onboarding.md with the chosen approach
