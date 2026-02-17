# Deployment Scripts

Automated installation scripts for deploying systems to managed machines. Mac machines are managed via Jamf, Windows machines via Intune.

Each system may require multiple installation steps and prerequisites that vary by OS. The scripts in this repo handle the full chain -- from enabling OS features to installing the final application.

**New here?** See the [Quick Start Guide](QUICK-START.md) to get set up and start editing scripts.

## How this repo is organised and how to use it

This repo contains deployment scripts for various systems. It is made for the Operations teams to simplify creation, testing and version control of deployment scripts.

### Script Standards make support simpler

Consistency is important for maintaining and supporting deployment scripts. The repo has rules that are enforced by validation tests. This ensures that every script has a version number, unique id, unique numbered error messages, support a --help flag, and so on. Changes to a script automatically bump its version number. So there is never a doubt on what script version that is used.
See [SCRIPT-STANDARDS.md](SCRIPT-STANDARDS.md) for the full details.

### Automated builds the CI/CD Pipeline

Scripts are automatically built and verified when pushing to `main`.

* The Windows Intune packages (`.intunewin`) are built automatically by Azure Pipelines when there are changes to `scripts-win/`.
* Mac scripts are validated automatically by Azure Pipelines when there are changes to `scripts-mac/`.
See [CICD.md](CICD.md) for details.

> **Download built packages:** Azure DevOps > Pipelines > Runs > select the latest run > Artifacts. Each package is a separate artifact (`wsl2`, `rancher-desktop`, `devcontainer-toolbox`) containing the `.intunewin` file ready to upload to the Intune portal.

### Ops Guide — Deployment Scripts

This guide describes the day-to-day workflow for editing, testing, and deploying scripts. Mac scripts are deployed via Jamf, Windows scripts via Intune. See [OPS.md](OPS.md) for details.

### AI-Supported Development

This repo uses Claude Code for plan-based development. See [AI-SUPPORTED-DEVELOPMENT.md](AI-SUPPORTED-DEVELOPMENT.md) for the workflow, completed plans, and the AI developer guide.

---

## Systems

### Devcontainer Toolbox

The Devcontainer Toolbox is a command-line tool that gives developers a complete, ready-to-use development environment with one command. It includes 20+ pre-configured tools (Python, Go, TypeScript, Azure CLI, Kubernetes, and more) that run inside a container.

The biggest benefit is for maintenance and support of the systems we run in Azure. Developers check in not only the code, but also the full development environment. When the maintenance team needs to fix a bug, they check out the repo and get the exact same environment the original developer used -- same tools, same versions, same configuration. No guessing, no "works on my machine" problems. Onboarding a new developer takes minutes, not days.

For more details, see the [Devcontainer Toolbox website](https://dct.sovereignsky.no/) and [DEVCONTAINER-TOOLBOX.md](ai-developer/DEVCONTAINER-TOOLBOX.md).

**What needs to be installed:**

The Devcontainer Toolbox runs inside a container, so each machine needs a container runtime and its prerequisites before the toolbox itself can be installed.

| | macOS | Windows |
|-|-------|---------|
| **Step 1** | Rancher Desktop | WSL2 (Windows features via DISM) |
| **Step 2** | Devcontainer Toolbox | Rancher Desktop |
| **Step 3** | | Devcontainer Toolbox |
| **Reboot needed** | No | Yes (after WSL2 features) |
| **Managed via** | Jamf | Intune |

Windows requires an extra step because WSL2 must be enabled before Rancher Desktop can run. See [wsl-install-challenge.md](wsl-install-challenge.md) for details on the WSL2 deployment challenge.

---

#### Script Packages

##### macOS (Jamf)

| Package | Description | Docs |
|---------|-------------|------|
| `scripts-mac/rancher-desktop/` | Rancher Desktop install, uninstall, and configuration | [README](../scripts-mac/rancher-desktop/README.md), [TESTING](../scripts-mac/rancher-desktop/TESTING.md) |
| `scripts-mac/devcontainer-toolbox/` | Install and configure the devcontainer toolbox on Mac machines | [README](../scripts-mac/devcontainer-toolbox/README.md) |
| `scripts-mac/urbalurba-infrastructure-stack/` | Infrastructure stack setup (planned) | — |

##### Windows (Intune)

Packages must be deployed in this order. Each package depends on the ones above it.

| Order | Package | Description | Docs |
|:-----:|---------|-------------|------|
| 1 | `scripts-win/wsl2/` | WSL2 install and detection | [README](../scripts-win/wsl2/README.md), [TESTING](../scripts-win/wsl2/TESTING.md), [INTUNE](../scripts-win/wsl2/INTUNE.md) |
| 2 | `scripts-win/rancher-desktop/` | Rancher Desktop install, uninstall, and detection (requires WSL2) | [README](../scripts-win/rancher-desktop/README.md), [TESTING](../scripts-win/rancher-desktop/TESTING.md), [INTUNE](../scripts-win/rancher-desktop/INTUNE.md) |
| 3 | `scripts-win/devcontainer-toolbox/` | Devcontainer toolbox image pull and init command (requires Rancher Desktop) | [README](../scripts-win/devcontainer-toolbox/README.md), [TESTING](../scripts-win/devcontainer-toolbox/TESTING.md), [INTUNE](../scripts-win/devcontainer-toolbox/INTUNE.md) |

Intune enforces this order via package dependencies. For USB testing, run in the same order.

---

## Script Folder Structure

```text
scripts-mac/
  rancher-desktop/
    rancher-desktop-install.sh      ← install Rancher Desktop
    rancher-desktop-uninstall.sh    ← uninstall with data preservation options
    rancher-desktop-config.sh       ← VM and container runtime configuration
    rancher-desktop-k8s.sh          ← Kubernetes toggle and settings
    tests/                          ← automated test suite (14 test scripts)
  devcontainer-toolbox/
    devcontainer-init.sh            ← initialize devcontainer on Mac
    devcontainer-init-install.sh    ← install devcontainer toolbox
    devcontainer-pull.sh            ← pull latest devcontainer image
  urbalurba-infrastructure-stack/   ← planned, not started

scripts-win/
  rancher-desktop/
    install.ps1                     ← install Rancher Desktop
    uninstall.ps1                   ← uninstall Rancher Desktop
    detect.ps1                      ← Intune detection script
    build.ps1                       ← build .intunewin package
    tests/                          ← build and install test suites
  wsl2/
    install.ps1                     ← install WSL2
    detect.ps1                      ← Intune detection script
    build.ps1                       ← build .intunewin package
    tests/                          ← install test suite
  devcontainer-toolbox/
    install.ps1                     ← pull Docker image, install init tool, add to PATH
    uninstall.ps1                   ← remove init tool and PATH entry
    detect.ps1                      ← Intune detection script
    build.ps1                       ← build .intunewin package
    devcontainer-init.ps1           ← user-facing init tool (installed to Program Files)
    devcontainer-init.cmd           ← .cmd shim so users type devcontainer-init
    tests/                          ← build, install, init, and uninstall test suites
  diagnostics/
    check-environment.ps1           ← Windows environment diagnostic
```
