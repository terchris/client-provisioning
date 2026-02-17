# AI-Supported Development

This repo uses [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic's CLI coding assistant) for plan-based development. Claude reads `CLAUDE.md` in the repo root automatically and follows the workflow described here.

---

## Setting Up Claude Code

Claude Code was installed using `dev-setup` (see [Devcontainer Toolbox](ai-developer/DEVCONTAINER-TOOLBOX.md) for how to install and manage tools). It is listed in `enabled-tools.conf` so it auto-installs on every container rebuild. You just need to authenticate.

### First-time setup

1. Open a terminal in VS Code (Terminal > New Terminal)
2. Run `claude` — this starts the OAuth flow and opens a browser window
3. Log in with your Anthropic account and authorize the CLI
4. You're ready — Claude Code is now authenticated

### Saving credentials for container rebuilds

Claude Code stores its OAuth tokens in `~/.claude/.credentials.json` inside the container. This file is lost on every container rebuild. To persist it:

**After first-time auth (save):**

```bash
cp ~/.claude/.credentials.json .devcontainer.secrets/claude-credentials.json
```

**After a container rebuild (restore):**

```bash
mkdir -p ~/.claude
cp .devcontainer.secrets/claude-credentials.json ~/.claude/.credentials.json
chmod 600 ~/.claude/.credentials.json
```

This is a manual workaround until the devcontainer-toolbox adds automatic credential persistence. See [issue #46](https://github.com/terchris/devcontainer-toolbox/issues/46).

### Verify installation

```bash
# Check Claude Code is installed
claude --version

# Check available devcontainer tools
dev-env
```

---

## Getting Started

Open this repo in the devcontainer and run `claude` in the terminal. Claude reads `CLAUDE.md` in the repo root automatically and knows the script standards, validation tools, and workflow.

**How it works:**

1. Tell Claude what you want: *"Add a Rancher Desktop install script"*
2. Claude creates a plan file for you to review
3. You approve, Claude implements phase by phase
4. Claude asks before every git command

---

## Plan-Based Workflow

All work follows a plan-based workflow. Nothing gets implemented without a plan that's been reviewed and approved first.

**The flow:**

1. **Investigate** — if the problem is unclear, create an `INVESTIGATE-*.md` to research it
2. **Plan** — create a `PLAN-*.md` with phases, tasks, and validation steps
3. **Review** — the plan is reviewed and approved before any code is written
4. **Implement** — work through the plan phase by phase, committing after each
5. **Complete** — move the plan to `completed/` when done

Plans live in `docs/ai-developer/plans/` and move through folders as they progress:

```text
plans/
  backlog/      ← waiting for implementation
  active/       ← currently being worked on
  completed/    ← done, kept as examples
```

**See a full example:** [AI-EXAMPLE-WORKFLOW.md](AI-EXAMPLE-WORKFLOW.md) — a walkthrough showing the user and Claude working through investigate, plan, implement, and merge.

---

## Completed Plans and Investigations

See how previous work was planned and executed:

| Plan | What it did |
|------|-------------|
| [PLAN-rancher-desktop-install](ai-developer/plans/completed/PLAN-rancher-desktop-install.md) | Install and configure Rancher Desktop via Jamf |
| [PLAN-rancher-desktop-k8s-config](ai-developer/plans/completed/PLAN-rancher-desktop-k8s-config.md) | Kubernetes toggle and VM configuration |
| [PLAN-rancher-desktop-uninstall](ai-developer/plans/completed/PLAN-rancher-desktop-uninstall.md) | Safe uninstall with data preservation options |
| [PLAN-automate-test-runner](ai-developer/plans/completed/PLAN-automate-test-runner.md) | Automated test framework for deployment scripts |
| [PLAN-fix-test-verification](ai-developer/plans/completed/PLAN-fix-test-verification.md) | Fix grep/pipefail false failures in tests |
| [PLAN-install-az-devops-cli](ai-developer/plans/completed/PLAN-install-az-devops-cli.md) | Temporary Azure DevOps CLI install |
| [PLAN-consolidate-ai-developer-tooling](ai-developer/plans/completed/PLAN-consolidate-ai-developer-tooling.md) | Consolidate developer tooling under docs/ |
| [PLAN-generic-ai-developer-framework](ai-developer/plans/completed/PLAN-generic-ai-developer-framework.md) | Make ai-developer framework reusable across repos |
| [INVESTIGATE-rancher-desktop-install](ai-developer/plans/completed/INVESTIGATE-rancher-desktop-install.md) | Research Rancher Desktop deployment on macOS |
| [INVESTIGATE-generic-ai-developer-framework](ai-developer/plans/completed/INVESTIGATE-generic-ai-developer-framework.md) | Research making the framework language-agnostic |
| [INVESTIGATE-script-package-standard](ai-developer/plans/completed/INVESTIGATE-script-package-standard.md) | Research script packaging and metadata standards |
| [INVESTIGATE-developer-onboarding](ai-developer/plans/completed/INVESTIGATE-developer-onboarding.md) | Determine onboarding flow for new developers via Jamf — recommended devcontainer-first approach |
| [INVESTIGATE-quickstart-azure-devops-gaps](ai-developer/plans/completed/INVESTIGATE-quickstart-azure-devops-gaps.md) | Audit docs for Azure DevOps onboarding gaps — found toolbox config scripts cover the flow |

---

## AI Developer Guide

Detailed docs on workflow, script standards, validation tools, and templates.

**Start here:** [ai-developer/README.md](ai-developer/README.md)

| Document | What it covers |
|----------|----------------|
| [Workflow](ai-developer/WORKFLOW.md) | Plan-to-implementation flow |
| [Plans](ai-developer/PLANS.md) | Plan structure, templates, and status tracking |
| [Script Standard](ai-developer/rules/script-standard.md) | Shared standard for all scripts (metadata, help, logging, errors) |
| [Bash Rules](ai-developer/rules/bash.md) | Bash-specific rules, conventions, and platform gotchas |

---

## DevOps and Infrastructure

| Document | What it covers |
|----------|----------------|
| [Git Hosting: Azure DevOps](ai-developer/GIT-HOSTING-AZURE-DEVOPS.md) | PRs, merging, wiki, work items — az CLI commands |
| [Devcontainer Toolbox](ai-developer/DEVCONTAINER-TOOLBOX.md) | Discover, install, and manage devcontainer tools |

---

## Repo Structure

```text
scripts-mac/              ← macOS deployment scripts (bash)
scripts-win/              ← Windows deployment scripts (PowerShell)
docs/                     ← all documentation (published as wiki)
  ai-developer/           ← AI developer guide, workflow, plans, tools, templates
    rules/                ← script-standard.md, bash.md
    tools/                ← validate-bash.sh, set-version-bash.sh
    templates/            ← bash/script-template.sh, README-template.md
    plans/                ← backlog/, active/, completed/
  OPS.md                  ← ops workflow guide
  AI-SUPPORTED-DEVELOPMENT.md ← this file
  AI-EXAMPLE-WORKFLOW.md  ← full example of the plan-based workflow
CLAUDE.md                 ← entry point for Claude Code
```
