# Ops Guide — Deployment Scripts

This guide describes the day-to-day workflow for editing, testing, and deploying scripts. Mac scripts are deployed via Jamf, Windows scripts via Intune.

## Prerequisites

- VS Code (installed from Intune Company Portal or Jamf Self Service)
- Rancher Desktop running (installed via Intune or Jamf)
- Access to this repository (clone or open in VS Code)
- Access to Jamf (for Mac scripts) and/or Intune (for Windows scripts)
- Git identity and Azure DevOps credentials configured inside the devcontainer (see [Quick Start](QUICK-START.md))

The Dev Containers extension is installed automatically when you first open a project that has `.vscode/extensions.json` -- see "How the devcontainer bootstrap works" below.

## Workflow

```text
Open in VS Code → devcontainer starts
        ↓
Edit scripts in scripts-mac/ or scripts-win/
        ↓
Validate:
  bash docs/ai-developer/tools/validate-bash.sh          ← Mac scripts
  bash docs/ai-developer/tools/validate-powershell.sh     ← Windows scripts
        ↓
Bump version (if releasing):
  bash docs/ai-developer/tools/set-version-bash.sh <name>
  bash docs/ai-developer/tools/set-version-powershell.sh <name>
        ↓
Deploy:
  Mac: copy scripts to Jamf
  Windows: push to main → CI/CD builds .intunewin → upload to Intune
        ↓
git add -A && git commit -m "message" && git push
```

## Step-by-step

### 1. Open the repo in VS Code

Clone or open the repo folder in VS Code. It will detect the devcontainer and ask to "Reopen in Container" — click yes. The devcontainer gives you a consistent environment with all tools installed.

To install additional tools or configure credentials, run `dev-setup` in the terminal. Your credentials (git identity, Azure DevOps PAT) are saved in `.devcontainer.secrets/` and restored automatically after container rebuilds.

#### How the devcontainer bootstrap works

On a fresh machine, VS Code does not know what a devcontainer is. It needs the **Dev Containers** extension (`ms-vscode-remote.remote-containers`) installed on the host before it can detect `.devcontainer/devcontainer.json` and offer to reopen in a container.

This is a chicken-and-egg problem: the extensions listed inside `devcontainer.json` (markdownlint, shellcheck, etc.) are installed **inside** the container after it starts. They cannot help with the initial bootstrap. The Dev Containers extension must be on the **host** VS Code first.

The bootstrap chain that solves this:

```text
Intune/Jamf deploys:
  WSL2 (Windows only) → Rancher Desktop → devcontainer-toolbox

devcontainer-toolbox install creates:
  devcontainer-init command (added to PATH)

User runs:
  devcontainer-init ~/projects/my-repo
    → Creates .devcontainer/devcontainer.json
    → Creates .vscode/extensions.json          ← THIS IS THE KEY STEP

User opens folder in VS Code:
  1. VS Code reads .vscode/extensions.json
  2. Prompts: "This workspace has extension recommendations" → Install All
  3. Dev Containers extension is installed on the host
  4. Extension detects .devcontainer/devcontainer.json
  5. Prompts: "Reopen in Container" → user clicks yes
  6. Container starts, in-container extensions install automatically
```

The `.vscode/extensions.json` file is what bridges the gap. Without it, VS Code would open the repo as a plain folder with no prompt. This file is created in three places:

- **This repo** already has `.vscode/extensions.json` checked in
- **`devcontainer-init`** creates it alongside `devcontainer.json` for every new project
- **The devcontainer-toolbox entrypoint** will backfill it for existing projects on container startup

### 2. Edit scripts

Deployment scripts are organized by platform:

| Folder           | Language   | Target             |
|------------------|------------|--------------------|
| `scripts-mac/`   | Bash       | macOS via Jamf     |
| `scripts-win/`   | PowerShell | Windows via Intune  |

Each subfolder is one "package" of related scripts:

```text
scripts-mac/
  devcontainer-toolbox/
  rancher-desktop/
  urbalurba-infrastructure-stack/

scripts-win/
  wsl2/
  rancher-desktop/
  devcontainer-toolbox/
  diagnostics/
```

Edit files directly in the package folder. Git tracks all your changes automatically.

### 3. Test your changes

Run the validation tools from the repo root:

```bash
# Validate all Mac (bash) scripts
bash docs/ai-developer/tools/validate-bash.sh

# Validate all Windows (PowerShell) scripts
bash docs/ai-developer/tools/validate-powershell.sh

# Validate one specific folder
bash docs/ai-developer/tools/validate-bash.sh devcontainer-toolbox
bash docs/ai-developer/tools/validate-powershell.sh rancher-desktop
```

The validators check every script for:

- Syntax errors (`bash -n` for bash, AST parser for PowerShell)
- Help output follows the standard format (`-h`/`--help` for bash, `-Help` for PowerShell)
- Required metadata fields present (`SCRIPT_ID`, `SCRIPT_NAME`, `SCRIPT_VER`, `SCRIPT_DESCRIPTION`, `SCRIPT_CATEGORY`)
- Startup message (`log_start` function)
- Lint (shellcheck for bash, PSScriptAnalyzer for PowerShell)

Fix any failures before continuing.

Some packages also have their own test suites. See [Rancher Desktop TESTING.md](../scripts-mac/rancher-desktop/TESTING.md) for Mac testing or [WSL2 TESTING.md](../scripts-win/wsl2/TESTING.md) for Windows USB testing.

### 4. Set the version (if releasing a new version)

Patch versions bump automatically on every commit (via a git pre-commit hook). You only need to set the version manually for minor or major releases:

```bash
# Mac scripts
bash docs/ai-developer/tools/set-version-bash.sh devcontainer-toolbox

# Windows scripts
bash docs/ai-developer/tools/set-version-powershell.sh rancher-desktop
```

This will:

- Show the current `SCRIPT_VER` in each script file
- Ask you to type the new version (e.g. `0.2.0`)
- Update all script files in that folder

See [SCRIPT-STANDARDS.md](SCRIPT-STANDARDS.md) for the full versioning guide.

### 5. Deploy

#### Mac (Jamf)

Manually copy the script contents into Jamf:

1. Open the script file (e.g. `scripts-mac/devcontainer-toolbox/devcontainer-init.sh`)
2. Copy the full contents
3. In Jamf, go to **Settings > Computer Management > Scripts**
4. Create a new script (or edit an existing one)
5. Paste the script contents
6. Set appropriate execution settings (run as root if needed)
7. Assign the script to a policy that targets the right machines

#### Windows (Intune)

Windows packages are built automatically by CI/CD:

1. Push your changes to `main`
2. Azure Pipelines builds the `.intunewin` packages automatically (see [CICD.md](CICD.md))
3. Download the built package: Azure DevOps > Pipelines > Runs > latest run > Artifacts
4. Upload the `.intunewin` file to the Intune portal
5. Configure the Intune app settings (install command, detection rule, dependencies) — see the package's `INTUNE.md` for details

### 6. Save your work to git

After making changes, save to git:

```bash
git add -A && git commit -m "describe what you changed" && git push
```

For example:

```bash
git add -A && git commit -m "update devcontainer-init to v0.2.0" && git push
```

Note: the pre-commit hook will automatically bump patch versions on any changed scripts.

## Creating a new script folder

### Mac (bash)

1. Create the folder under `scripts-mac/`:

   ```bash
   mkdir scripts-mac/my-new-scripts
   ```

2. Copy the template as your starting point:

   ```bash
   cp docs/ai-developer/templates/bash/script-template.sh scripts-mac/my-new-scripts/my-script.sh
   ```

3. Edit the metadata at the top of the file — fill in `SCRIPT_ID`, `SCRIPT_NAME`, `SCRIPT_VER`, `SCRIPT_DESCRIPTION`, and `SCRIPT_CATEGORY`. Add your logic to `main()`.

4. Test it:

   ```bash
   bash docs/ai-developer/tools/validate-bash.sh my-new-scripts
   ```

5. Commit and push.

### Windows (PowerShell)

1. Create the folder under `scripts-win/`:

   ```bash
   mkdir scripts-win/my-new-scripts
   ```

2. Copy the template as your starting point:

   ```bash
   cp docs/ai-developer/templates/powershell/script-template.ps1 scripts-win/my-new-scripts/my-script.ps1
   ```

3. Edit the metadata at the top of the file — fill in `$SCRIPT_ID`, `$SCRIPT_NAME`, `$SCRIPT_VER`, `$SCRIPT_DESCRIPTION`, and `$SCRIPT_CATEGORY`. Add your logic to the main section.

4. Test it:

   ```bash
   bash docs/ai-developer/tools/validate-powershell.sh my-new-scripts
   ```

5. Commit and push.

## Script Standards

Every script must follow the [script standard](ai-developer/rules/script-standard.md) (metadata, help format, logging, error handling). The validation tools enforce these rules.

- For bash-specific syntax, see [bash rules](ai-developer/rules/bash.md).
- For PowerShell-specific syntax, see [PowerShell rules](ai-developer/rules/powershell.md).
- For ready-to-copy starting points, see `docs/ai-developer/templates/`.

## Rollback

Git makes rollback straightforward:

- **See what changed:**

  ```bash
  git log --oneline
  ```

- **View a specific commit:**

  ```bash
  git show <commit-hash>
  ```

- **Restore a file to a previous version:**

  ```bash
  git checkout <commit-hash> -- scripts-mac/devcontainer-toolbox/devcontainer-init.sh
  ```

- **In Jamf:** paste the old version of the script back into the Jamf script editor.
- **In Intune:** rebuild the package from the restored file, then re-upload to Intune.
