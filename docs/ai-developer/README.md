# AI Developer Guide

Read this first when starting a new session. This folder contains everything an AI coding assistant needs to work on this repo.

---

## Framework

This folder provides a plan-based development workflow with a shared script standard across languages.

### Three layers

1. **Generic workflow** — How to plan and implement work. Works for any project.
   - [WORKFLOW.md](WORKFLOW.md) — Plan-to-implementation flow
   - [PLANS.md](PLANS.md) — Plan structure and templates

2. **Shared script standard** — Metadata, help format, logging, error codes. Applies to all script languages.
   - [rules/script-standard.md](rules/script-standard.md)

3. **Language-specific rules** — Syntax, templates, validation tools, platform gotchas. One per language.
   - [rules/bash.md](rules/bash.md) — Bash scripts for macOS

### Devcontainer toolbox

This repo's devcontainer has installable tools, runtimes, and services. See [DEVCONTAINER-TOOLBOX.md](DEVCONTAINER-TOOLBOX.md) for how to discover, examine, and install tools.

---

## Key Rules

1. **Always ask before starting** — ask whether to create a `PLAN-*.md` or `INVESTIGATE-*.md` before doing anything. Never jump straight into implementation.
2. **Ask before git commands** — always confirm before git add, commit, push, branch, or merge.
3. **Every script must follow the standard** — no exceptions. This includes test scripts, helpers, and library scripts. See [rules/script-standard.md](rules/script-standard.md) and the language rules file.
4. **Validate before committing** — run the language-specific validation tool (see language rules).

---

## IMPLEMENTATION RULES

Copy the appropriate block into the top of every plan or investigation file. This prevents drift — Claude reads the right rules files before starting work.

### For bash work

```markdown
> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
> - [rules/script-standard.md](../../rules/script-standard.md) — Shared script standard
> - [rules/bash.md](../../rules/bash.md) — Bash-specific rules
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.
```

### For non-script work (docs, plans, config)

```markdown
> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.
```

---

## This Project

Bash scripts for deploying software to Mac machines via Jamf MDM. The ops team edits scripts in a devcontainer, validates them, and copies them into Jamf. Target machines run **macOS with bash 3.2** (Apple Silicon).

### Platform folders

| Folder | Language | Target |
|--------|----------|--------|
| `scripts-mac/` | Bash | macOS via Jamf |

### Current packages

Each folder under `scripts-mac/` is a **package** — a group of related deployment scripts with docs and tests.

| Package | Scripts | Tests | Description |
|---------|---------|-------|-------------|
| `rancher-desktop/` | 4 scripts | 14 test scripts in `tests/` | Install, uninstall, Kubernetes toggle, VM config |
| `devcontainer-toolbox/` | 3 scripts | none | Devcontainer init and image pull |
| `urbalurba-infrastructure-stack/` | — | — | Planned, not started |

### Validation commands (bash)

```bash
# Validate all script packages
bash docs/ai-developer/tools/validate-bash.sh

# Validate one package
bash docs/ai-developer/tools/validate-bash.sh rancher-desktop

# Validate scripts in a subfolder (e.g. test scripts)
bash docs/ai-developer/tools/validate-bash.sh rancher-desktop/tests

# Bump version across a package
bash docs/ai-developer/tools/set-version-bash.sh rancher-desktop
```

### Templates

| Template | Use |
|----------|-----|
| `templates/bash/script-template.sh` | Starting point for any new `.sh` file |
| `templates/README-template.md` | Starting point for a new package README |

---

## Detailed Docs

| Document | Read when |
|----------|-----------|
| [WORKFLOW.md](WORKFLOW.md) | You need to understand the plan-based workflow |
| [PLANS.md](PLANS.md) | You need to create or manage plans |
| [rules/script-standard.md](rules/script-standard.md) | You need to understand the shared script standard |
| [rules/bash.md](rules/bash.md) | You need to create or modify bash scripts |
| [GIT-HOSTING-AZURE-DEVOPS.md](GIT-HOSTING-AZURE-DEVOPS.md) | You need to create PRs, merge, or manage work items |
| [DEVCONTAINER-TOOLBOX.md](DEVCONTAINER-TOOLBOX.md) | You need to install tools in the devcontainer |
| [OPS.md](../OPS.md) | You need to understand the ops team's day-to-day |

---

## Folder Structure

```
docs/ai-developer/
  README.md                  <- you are here
  WORKFLOW.md                <- plan-to-implementation flow
  PLANS.md                   <- plan structure and templates
  GIT-HOSTING-AZURE-DEVOPS.md <- PRs, merge, work items (Azure DevOps)
  DEVCONTAINER-TOOLBOX.md    <- devcontainer tool discovery and install
  rules/
    script-standard.md       <- shared standard (metadata, help, logging, errors)
    bash.md                  <- bash-specific rules
  tools/
    validate-bash.sh         <- validation (syntax, help, metadata, shellcheck)
    set-version-bash.sh      <- bump SCRIPT_VER across a package
  templates/
    bash/
      script-template.sh     <- copy to start any new bash script
    README-template.md       <- copy to start a new package README
  plans/
    active/                  <- plans currently being worked on
    backlog/                 <- plans waiting for implementation
    completed/               <- done, kept for reference
```
