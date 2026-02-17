# devcontainer-toolbox

The devcontainer toolbox provides a standardized development environment using Docker containers via VS Code's Dev Containers extension. It ensures consistent developer experience across team members with all required tools, dependencies, and configurations pre-configured in a containerized environment.

This folder contains the scripts needed for installing and setting up the DevContainer-Toolbox using Jamf.

It streamlines the process of getting developers productive in isolated, reproducible development environments.

For more info see [https://dct.sovereignsky.no](https://dct.sovereignsky.no)

## Overview

The toolbox consists of three main components:

- **devcontainer-pull.sh**: Pulls the Docker image to the users Mac machine
- **devcontainer-init-install.sh**: Installs the `devcontainer-init` command system-wide
- **devcontainer-init.sh**: Initializes a project folder to use the devcontainer-toolbox.

## Prerequisites

- **Docker**: A Docker-compatible system must be installed and running
  - We standardize on **Rancher Desktop** (free for all use cases) or **Docker Desktop**
  - See `rancher-desktop` folder for installation instructions

## Installation & Setup

### Step 1: Pull the Docker Image

Run the pull script to download the latest devcontainer image to the users Mac machine:

```bash
./devcontainer-pull.sh
```

**What it does:**
- Verifies Docker is installed
- Verifies Docker daemon is running
- Pulls the latest `devcontainer-toolbox:latest` image

**For help:**
```bash
./devcontainer-pull.sh -h
```

---

### Step 2: Install the devcontainer-init Command

Install the `devcontainer-init` command to the users Mac machine so the user can use it from any directory:

```bash
./devcontainer-init-install.sh
```

**What it does:**
- Locates the `devcontainer-init.sh` script
- Copies it to `/usr/local/bin/devcontainer-init`
- Makes it executable
- Verifies the installation

**Note:** May require `sudo` depending on system permissions <Thomas: does Jamf run as sudo on the users Mac?>.

**For help:**
```bash
./devcontainer-init-install.sh -h
```

---

### Step 3: Initialize a Project

Once installed, initialize any project folder to use the devcontainer:

```bash
cd /path/to/your/project
devcontainer-init
```

Or initialize a specific folder:

```bash
devcontainer-init /path/to/your/project
```

To run non-interactively (useful for scripts/automation):

```bash
devcontainer-init -y
devcontainer-init /path/to/your/project -y
```

**What it does:**
- Verifies Docker is installed and running
- Backs up any existing `.devcontainer/` folder (to `.devcontainer.backup/`)
- Downloads `devcontainer.json` from the repository
- Creates the `.devcontainer/` configuration folder

**For help:**
```bash
devcontainer-init -h
```

---

## Quick Start for Developers

1. **Initial Setup** (once per machine):
   ```bash
   ./devcontainer-pull.sh
   ./devcontainer-init-install.sh
   ```

2. **Initialize a Project**:
   ```bash
   cd my-project
   devcontainer-init
   ```

3. **Open in VS Code**:
   ```bash
   code .
   ```

4. **Reopen in Container**:
   - VS Code will prompt you to "Reopen in Container"
   - Click the button, or use: `Cmd/Ctrl+Shift+P` → "Dev Containers: Reopen in Container"

5. **Verify You're in the Container**:
   ```bash
   dev-help
   ```

---

## Workflow

```
┌─────────────────────────────────────────┐
│ 1. Install (via devcontainer-pull.sh)   │
│    - Pull Docker image                  │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 2. Setup Command (devcontainer-init-    │
│    install.sh)                          │
│    - Install devcontainer-init globally │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 3. For Each Project                     │
│    - devcontainer-init                  │
│    - code . (open in VS Code)           │
│    - Reopen in Container                │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│ 4. Develop Inside Container             │
│    - All tools pre-configured           │
│    - Consistent environment             │
└─────────────────────────────────────────┘
```

---

## Troubleshooting

### Docker is not installed

**Error:** `Docker is not installed`

**Solution:**
- macOS: Install [Rancher Desktop](https://rancherdesktop.io/) or [Docker Desktop](https://www.docker.com/products/docker-desktop)
- Linux: `sudo apt-get install docker.io`

### Docker daemon is not running

**Error:** `Docker daemon is not running`

**Solution:**
- macOS: Open Rancher Desktop or Docker Desktop
- Linux: `sudo systemctl start docker`

### Backup already exists

**Error:** `Backup already exists at .devcontainer.backup/`

**Solution:**
- Remove `.devcontainer.backup/` if no longer needed: `rm -rf .devcontainer.backup/`
- Or rename it: `mv .devcontainer.backup/ .devcontainer.backup.old/`
- Then run `devcontainer-init` again

### devcontainer-init command not found

**Solution:**
- Run the installer: `./devcontainer-init-install.sh`
- Ensure `/usr/local/bin` is in your `$PATH`: `echo $PATH`

---

## Script Details

See individual scripts for comprehensive documentation:

- [devcontainer-pull.sh](devcontainer-pull.sh) - Docker image pull & validation
- [devcontainer-init-install.sh](devcontainer-init-install.sh) - System-wide command installation
- [devcontainer-init.sh](devcontainer-init.sh) - Project initialization

Each script supports `-h` or `--help` for detailed usage information.

---

## Architecture

```
User Machine
├── Docker Desktop / Rancher Desktop
│   └── xxx/devcontainer-toolbox:latest
│
├── /usr/local/bin/devcontainer-init (symlink/copy of devcontainer-init.sh)
│
└── Project Folders
    ├── .devcontainer/
    │   └── devcontainer.json (downloaded from repository)
    └── [project files]
```

---

## For Maintainers

See [devcontainer.json](../.devcontainer/devcontainer.json) for the container configuration and image details.

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review script help: `<script-name> -h`