# Azure DevOps PAT not exported as environment variable

## Problem

The Azure DevOps PAT is stored at `.devcontainer.secrets/env-vars/azure-devops-pat` but is never exported as the `AZURE_DEVOPS_EXT_PAT` environment variable. This means `az devops` commands fail with an authentication error until the user manually exports it.

The entrypoint (`/opt/devcontainer-toolbox/entrypoint.sh`) reads the PAT file only to check if Azure DevOps is configured (for the welcome message). It does not export it into the shell environment.

## Expected behavior

When `.devcontainer.secrets/env-vars/azure-devops-pat` exists, the `AZURE_DEVOPS_EXT_PAT` environment variable should be set automatically in every shell session. This is how the `az devops` CLI picks up authentication without requiring `az devops login`.

## Current workaround

Users must manually export the variable each time:

```bash
export AZURE_DEVOPS_EXT_PAT="$(cat /workspace/.devcontainer.secrets/env-vars/azure-devops-pat)"
```

Or add it to `~/.bashrc` via `project-installs.sh`.

## Suggested fix

In the entrypoint or in the Azure DevOps config script (`config-azure-devops.sh`), add the PAT to the shell profile so it is available in all terminal sessions:

```bash
PAT_FILE="$DCT_WORKSPACE/.devcontainer.secrets/env-vars/azure-devops-pat"
if [ -f "$PAT_FILE" ]; then
    echo "export AZURE_DEVOPS_EXT_PAT=\"\$(cat $PAT_FILE 2>/dev/null)\"" >> ~/.bashrc
fi
```

This follows the same pattern as how git identity is restored from `.devcontainer.secrets/env-vars/.git-host-name` and `.git-host-email`.

## Discovered

Found while trying to run `az pipelines runs list` from Claude Code in the `client-provisioning` repo. The PAT file existed but `az` could not authenticate because the env var was not set.
