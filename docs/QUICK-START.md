# Quick Start Guide

A step-by-step guide for maintainers of the deployment scripts. No prior experience with git, VS Code, or Azure DevOps required.

---

## Before You Start

You need these before following the steps below. Ask your team lead or IT admin if you don't have them.

1. **Azure DevOps account** with access to the project 
2. **Personal Access Token (PAT)** — this is your password for git and the Azure DevOps CLI

### What is a PAT?

A Personal Access Token is a long random string (like `ghp3x7kA9...`) that works as a password when connecting to Azure DevOps from your machine. It is tied to your account and has an expiration date. You can create multiple PATs and revoke them at any time.

### How to create a PAT

1. Go to `https://dev.azure.com/YOUR-ORG/_usersSettings/tokens`
2. Click **New Token**
3. Give it a name (e.g. "devcontainer")
4. Set expiration (e.g. 90 days)
5. Under **Scopes**, select **Full access** (or at minimum: Code Read & Write, Work Items Read)
6. Click **Create** and **copy the token immediately** — you won't see it again

Keep the token somewhere safe. You'll paste it during setup inside the devcontainer.

---

## First-Time Setup

The deployment scripts in this repo (`scripts-mac/` and `scripts-win/`) handle installing Rancher Desktop, WSL2, and all other prerequisites on managed machines. You do not need to install those manually.

To work on the scripts themselves, you only need VS Code. Follow these steps in order — you only need to do this once.

### 1. Install VS Code

VS Code is available from the self-service portals:

- **Mac:** Install from **Jamf Self Service**
- **Windows:** Install from **Intune Company Portal**

### 2. Clone the repo and open it

1. Go to the repo in Azure DevOps: `https://dev.azure.com/YOUR-ORG/Azure/_git/client-provisioning`
2. Click the **Clone** button (top right)
3. In the dialog that appears, click **Clone in VS Code** under the IDE section
4. VS Code will open and ask where to save the repo — pick a folder (e.g. your home folder)
5. When prompted for a password, **paste your PAT** (the token you created above)
6. VS Code will detect the `.devcontainer` folder and prompt you to install the **Dev Containers** extension — accept it
7. VS Code will then show a notification: **"Reopen in Container"** — click it
8. Wait for the container to build (first time takes a few minutes, after that it's fast)

You're now inside the devcontainer with all tools ready.

### 3. Set up your identity and credentials

Open a terminal inside VS Code: go to **Terminal > New Terminal** (or press `` Ctrl+` ``). This terminal runs inside the devcontainer.

Type this command and press Enter:

```bash
dev-setup
```

This opens an interactive menu where you can configure your git identity (name and email) and Azure DevOps authentication (paste your PAT when prompted).

Your settings are saved to `.devcontainer.secrets/` and survive container rebuilds automatically. You only need to do this once. If something stops working after a rebuild, run `dev-setup` again to reconfigure.

---

## Daily Workflow

### Pull the latest changes

Before you start editing, always pull the latest changes:

```bash
git pull
```

### Edit scripts

Scripts are organized by platform:

```text
scripts-mac/                          ← macOS scripts (bash), deployed via Jamf
  rancher-desktop/                    ← Rancher Desktop install, config, uninstall
  devcontainer-toolbox/               ← devcontainer setup scripts
  urbalurba-infrastructure-stack/     ← infrastructure stack (planned)

scripts-win/                          ← Windows scripts (PowerShell), deployed via Intune
  wsl2/                               ← WSL2 install and detection
  rancher-desktop/                    ← Rancher Desktop install and uninstall
  devcontainer-toolbox/               ← devcontainer image pull and init tool
  diagnostics/                        ← environment diagnostic
```

Open the file you want to edit in VS Code. Make your changes and save (`Ctrl+S`).

### Test your changes

Run the validation tools to check your scripts:

```bash
# Validate all Mac (bash) scripts
bash docs/ai-developer/tools/validate-bash.sh

# Validate all Windows (PowerShell) scripts
bash docs/ai-developer/tools/validate-powershell.sh

# Validate one specific folder
bash docs/ai-developer/tools/validate-bash.sh rancher-desktop
bash docs/ai-developer/tools/validate-powershell.sh wsl2
```

The tools check for:

- Syntax errors
- Help output format (`-h`/`--help` for bash, `-Help` for PowerShell)
- Required metadata fields (`SCRIPT_ID`, `SCRIPT_NAME`, `SCRIPT_VER`, `SCRIPT_DESCRIPTION`, `SCRIPT_CATEGORY`)
- Startup message (`log_start`)
- Lint (shellcheck for bash, PSScriptAnalyzer for PowerShell)

Fix any errors before continuing.

### Save your changes to git

See [QUICK-GIT.md](QUICK-GIT.md) for a quick reference of git commands. The short version:

```bash
git add -A && git commit -m "describe what you changed" && git push
```

For deployment steps (Jamf and Intune), see [OPS.md](OPS.md).

---

## Key Concepts

### What is a repository (repo)?

A repo is a folder of files with full version history. Every change is tracked — you can always see who changed what and when, and roll back if needed. This repo contains the deployment scripts for Mac (via Jamf) and Windows (via Intune).

### What is git?

Git is the tool that tracks changes in the repo. You don't need to learn git deeply — see [QUICK-GIT.md](QUICK-GIT.md) for the commands you need.

### What is Azure DevOps?

Azure DevOps is where the repo lives on the server. It provides:

- **Repos** — the code and its history
- **Wiki** — documentation (auto-generated from the `docs/` folder)
- **Boards** — work items, tasks, and planning
- **Pipelines** — automated builds and deployments

Our project URL: `https://dev.azure.com/YOUR-ORG/Azure`

### What is a devcontainer?

A devcontainer is a pre-configured development environment that runs inside a container. When you open this repo in VS Code, it automatically starts a container with all the tools you need — no manual installation required. Everyone gets the same environment.

This repo uses the [Devcontainer Toolbox](ai-developer/DEVCONTAINER-TOOLBOX.md) — run `dev-env` to see what's installed, or `dev-setup` to install additional tools.

---

## Creating a New Script

Every script must follow the [script standard](SCRIPT-STANDARDS.md) (metadata, help format, logging, error handling). The validation tools enforce these rules.

### Mac (bash)

1. Create a folder under `scripts-mac/`:

   ```bash
   mkdir scripts-mac/my-new-package
   ```

2. Copy the template:

   ```bash
   cp docs/ai-developer/templates/bash/script-template.sh scripts-mac/my-new-package/my-script.sh
   ```

3. Edit the metadata at the top of the file — fill in `SCRIPT_ID`, `SCRIPT_NAME`, `SCRIPT_VER`, `SCRIPT_DESCRIPTION`, and `SCRIPT_CATEGORY`

4. Add your logic to the `main()` function

5. Test it:

   ```bash
   bash docs/ai-developer/tools/validate-bash.sh my-new-package
   ```

### Windows (PowerShell)

1. Create a folder under `scripts-win/`:

   ```bash
   mkdir scripts-win/my-new-package
   ```

2. Copy the template:

   ```bash
   cp docs/ai-developer/templates/powershell/script-template.ps1 scripts-win/my-new-package/my-script.ps1
   ```

3. Edit the metadata at the top of the file — fill in `$SCRIPT_ID`, `$SCRIPT_NAME`, `$SCRIPT_VER`, `$SCRIPT_DESCRIPTION`, and `$SCRIPT_CATEGORY`

4. Add your logic to the main section

5. Test it:

   ```bash
   bash docs/ai-developer/tools/validate-powershell.sh my-new-package
   ```

---

## Getting Help

- **Git commands** — quick reference: [QUICK-GIT.md](QUICK-GIT.md)
- **Script standards** — every script must follow the [script standard](ai-developer/rules/script-standard.md)
- **Ops workflow** — day-to-day guide: [OPS.md](OPS.md)
- **Azure DevOps commands** — PRs, merging, work items: [Git Hosting Guide](ai-developer/GIT-HOSTING-AZURE-DEVOPS.md)
- **Devcontainer tools** — discover and install tools: [Devcontainer Toolbox](ai-developer/DEVCONTAINER-TOOLBOX.md)
