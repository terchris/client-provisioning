# Need config-azure-devops.sh addition for Azure DevOps authentication

## Problem

There is no devcontainer-toolbox addition for configuring Azure DevOps authentication. Developers working with Azure DevOps repos need to manually set up a Personal Access Token (PAT) and configure `az devops` defaults every time they create a new container.

The toolbox already has `config-git.sh` for git identity (name/email) with persistent storage in `.devcontainer.secrets/`. A similar script is needed for Azure DevOps authentication.

## What is needed

A new addition script `config-azure-devops.sh` that follows the same pattern as `config-git.sh`:

### Interactive mode (no flags)

1. Prompt for Azure DevOps organization URL (e.g. `https://dev.azure.com/MyOrg`)
2. Prompt for project name
3. Prompt for Personal Access Token (PAT)
4. Configure `az devops` defaults
5. Export `AZURE_DEVOPS_EXT_PAT` to the environment
6. Save all values to `.devcontainer.secrets/env-vars/` for persistence across container rebuilds

### Flags

- `--show` — display current Azure DevOps configuration (org, project, PAT status)
- `--verify` — non-interactive restore from `.devcontainer.secrets/` (for container startup)
- `--help` — usage information

### Integration

- `dev-setup.sh` menu integration via `SCRIPT_COMMANDS`
- `SCRIPT_CHECK_COMMAND` to detect if already configured
- Persistent storage in `.devcontainer.secrets/env-vars/` (survives container rebuild)

### Prerequisite

Requires `az` CLI with the `azure-devops` extension. This could either:
- Check if `az` is installed and prompt the user to install `tool-azure-devops` first (see [ISSUE-azure-devops-cli.md](ISSUE-azure-devops-cli.md))
- Or be bundled together with the CLI install in a single tool

## Persistent storage

Following the `config-git.sh` pattern, credentials should be stored in:

```text
.devcontainer.secrets/env-vars/
  azure-devops-pat          ← PAT token
  .azure-devops-config      ← org URL, project name
```

The `--verify` flag should restore these on container start (via `postStartCommand`).

## Use case

In the `client-provisioning` repo (Azure DevOps), new developers need to:
1. Run `config-git.sh` to set their identity
2. Run `config-azure-devops.sh` to set their PAT and org/project defaults
3. Start working — `az repos pr create`, `git push`, etc. all work

Without this, each developer must manually run `az devops configure`, create PAT files, and add environment variables to `.bashrc`. This is error-prone and undocumented.

## Suggested metadata

```bash
SCRIPT_ID="config-azure-devops"
SCRIPT_NAME="Azure DevOps Identity"
SCRIPT_DESCRIPTION="Configure Azure DevOps authentication (PAT) and project defaults"
SCRIPT_CATEGORY="INFRA_CONFIG"
SCRIPT_TAGS="azure devops pat authentication identity config"
SCRIPT_RELATED="config-git tool-azure-devops"
```
