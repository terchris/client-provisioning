# Ship machine-readable tool inventory with the container

## Problem

The devcontainer-toolbox has no machine-readable way to discover available tools. The current options are:

- **`dev-env`** — human-formatted output with box drawing and checkmarks, hard to parse
- **`dev-docs`** — generates a `tools.json` with high-level metadata, but it's a contributor tool that writes to `website/` for the documentation site, and it does not include package details
- **`install-*.sh --help`** — full details per script (APT packages, Node packages, VS Code extensions, etc.), but requires running each script individually (21 scripts currently)

AI coding assistants (Claude Code, Copilot, etc.) and humans both need to quickly understand what tools are available, what each one installs in detail, and whether it's already installed. Right now the only way to get full details is to run `--help` on each install script one at a time.

## What is needed

### 1. A complete `tools.json` generated at build time

The CI/CD process that builds the devcontainer-toolbox should generate a `tools.json` that combines:

- The high-level metadata that `dev-docs` already extracts (id, name, description, category, tags, etc.)
- The detailed package lists from each install script (`PACKAGES_SYSTEM`, `PACKAGES_NODE`, `EXTENSIONS`, `PACKAGES_POWERSHELL`, etc.)

Example of what a complete tool entry should look like:

```json
{
  "id": "tool-azure-dev",
  "type": "install",
  "name": "Azure Application Development",
  "description": "Installs Azure CLI, Functions Core Tools, Azurite, and VS Code extensions...",
  "category": "CLOUD_TOOLS",
  "tags": ["azure", "microsoft", "cloud", "functions", "azurite"],
  "abstract": "Azure application development with CLI, Functions, Azurite emulator...",
  "website": "https://azure.microsoft.com",
  "summary": "Complete Azure development toolkit including...",
  "related": ["tool-azure-ops", "tool-kubernetes", "tool-iac"],
  "packages": {
    "system": ["azure-cli"],
    "node": ["azure-functions-core-tools@4", "azurite"],
    "powershell": [],
    "pip": []
  },
  "extensions": [
    "ms-vscode.azure-account",
    "ms-azuretools.vscode-azureresourcegroups",
    "ms-azuretools.vscode-azureappservice",
    "ms-azuretools.vscode-azurefunctions",
    "ms-azuretools.vscode-azurestorage",
    "digital-molecules.service-bus-explorer",
    "ms-azuretools.vscode-cosmosdb",
    "ms-azuretools.vscode-bicep"
  ]
}
```

This file should be stored at a known path inside the container image, e.g.:

```text
/opt/devcontainer-toolbox/manage/tools.json
```

### 2. A `dev-tools` command that outputs the JSON

A new command (e.g. `dev-tools`) that outputs the JSON to stdout:

```bash
# Full inventory — humans pipe to jq, Claude reads directly
dev-tools

# Example: find tools that install azure-cli
dev-tools | jq '.tools[] | select(.packages.system[] == "azure-cli") | .id'
```

The command just reads and outputs the pre-generated `tools.json` — no computation at runtime. This makes it fast and usable by both humans and AI assistants.

## Use case

In the `client-provisioning` repo, Claude Code needed to find out if there was a lightweight Azure CLI tool available. This required:

1. Listing all install scripts (`ls /opt/devcontainer-toolbox/additions/install-*.sh`)
2. Running `--help` on two candidate scripts to compare what they install
3. Concluding neither was a good fit

With `dev-tools`, this would be a single command — all tool names, descriptions, packages, and tags in one read. Both Claude and a human running `dev-tools | jq` would get the same complete answer instantly.
