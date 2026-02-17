# Need lightweight PowerShell tool for Intune script development

## Problem

The only way to get PowerShell (`pwsh`) in the devcontainer is through `tool-azure-ops`, which bundles a lot of heavy extras not needed for PowerShell scripting:

- **Azure CLI** (`az`)
- **Az PowerShell modules** (Az.Accounts, Az.Resources, Az.Storage, Az.KeyVault)
- **Microsoft.Graph module**
- **ExchangeOnlineManagement module**
- **7 VS Code extensions** (Azure Account, Resources, Storage, Functions, Databases, Pipelines, Terraform)

All of this is unnecessary when the goal is simply writing and validating PowerShell scripts for Intune deployment.

## ARM64 support required

Microsoft's APT repository only ships PowerShell for **amd64**. There is no `powershell` package for arm64. The install script must handle both architectures by downloading the `.tar.gz` from GitHub releases instead of using APT:

- amd64: `powershell-<version>-linux-x64.tar.gz`
- arm64: `powershell-<version>-linux-arm64.tar.gz`

Releases: `https://github.com/PowerShell/PowerShell/releases`

We verified this on a Debian 12 (bookworm) arm64 devcontainer — APT install fails, tar.gz works.

## What is needed

A lightweight install script (e.g. `install-tool-powershell.sh`) that installs **only**:

1. **PowerShell 7** (`pwsh`) — via GitHub release tar.gz (not APT — see ARM64 note above)
2. **PSScriptAnalyzer module** — PowerShell linter (`Install-Module PSScriptAnalyzer`)
3. **VS Code PowerShell extension** (`ms-vscode.powershell`)

This enables:

- Writing `.ps1` scripts with syntax highlighting and IntelliSense
- Linting with `Invoke-ScriptAnalyzer` to catch errors before deployment
- Running PowerShell scripts locally for syntax validation
- Testing script logic that does not depend on Windows-specific APIs

No Azure CLI, no Az modules, no Graph/Exchange modules, no Azure VS Code extensions.

## Use case

The `client-provisioning` repo is expanding to include Intune deployment scripts for Windows. These scripts are written in PowerShell and deployed via Microsoft Intune. Developers need `pwsh` in the devcontainer to write and lint these scripts, but installing the full `tool-azure-ops` suite adds unnecessary bloat and complexity.

PowerShell on Linux can validate ~60-70% of script quality (syntax, style, logic, parameter handling). Windows-specific operations (registry, MSI, services) cannot be tested on Linux, but catching syntax and style issues early is still valuable.

## Suggested metadata

```bash
SCRIPT_ID="tool-powershell"
SCRIPT_NAME="PowerShell"
SCRIPT_DESCRIPTION="Installs PowerShell 7 with PSScriptAnalyzer for script development and linting"
SCRIPT_CATEGORY="DEV_TOOLS"
SCRIPT_TAGS="powershell pwsh intune linting scripting"
SCRIPT_RELATED="tool-azure-ops"
```
