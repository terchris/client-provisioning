# Client Provisioning

Deployment scripts for setting up developer machines with a complete container-based development environment. Supports Windows (via Intune) and macOS (via Jamf).

**Who this is for:** Enterprise ops teams responsible for software rollout on Windows and Mac machines. The scripts are designed for MDM deployment (Intune/Jamf), but can also be tested manually using a USB stick -- no MDM infrastructure required.

The goal: a developer gets a new machine, the scripts install everything, and they can open any project in a fully configured devcontainer within minutes.

**Full documentation:** [docs/README.md](docs/README.md) -- systems overview, script packages, folder structure, and ops guide.

## What gets installed

The scripts install a container runtime and the [Devcontainer Toolbox](https://dct.sovereignsky.no/) -- a command-line tool that gives developers a complete, ready-to-use development environment with 20+ pre-configured tools (Python, Go, TypeScript, Azure CLI, Kubernetes, and more).

| | macOS | Windows |
|-|-------|---------|
| **Step 1** | Rancher Desktop | WSL2 (Windows features) |
| **Step 2** | Devcontainer Toolbox | Rancher Desktop |
| **Step 3** | | Devcontainer Toolbox |
| **Reboot needed** | No | Yes (after WSL2) |
| **Managed via** | Jamf | Intune |

Windows requires an extra step because WSL2 must be enabled before Rancher Desktop can run.

## Repo structure

```
scripts-mac/                    macOS scripts (bash), deployed via Jamf
  rancher-desktop/              install, uninstall, configuration
  devcontainer-toolbox/         devcontainer setup scripts

scripts-win/                    Windows scripts (PowerShell), deployed via Intune
  wsl2/                         WSL2 install and detection
  rancher-desktop/              install, uninstall, detection
  devcontainer-toolbox/         Docker image pull and init tool
  diagnostics/                  environment diagnostic

docs/                           documentation, guides, plans
```

Each script package contains `install.ps1`, `detect.ps1`, `uninstall.ps1` (Windows) or equivalent bash scripts (Mac), plus `README.md`, `TESTING.md`, and automated tests.

## Script standards

Every script follows a strict standard enforced by validation tools:

- Version number, unique ID, numbered error codes (ERR001, etc.)
- `--help` / `-Help` flag with consistent format
- Structured logging (`log_info`, `log_error`, `log_success`)
- Automatic patch version bumping via pre-commit hook

```bash
# Validate all scripts
bash docs/ai-developer/tools/validate-bash.sh
bash docs/ai-developer/tools/validate-powershell.sh
```

See [docs/SCRIPT-STANDARDS.md](docs/SCRIPT-STANDARDS.md) for details.

## CI/CD

Windows `.intunewin` packages are built automatically by Azure Pipelines when changes are pushed to `main`. Mac scripts are validated on push. See [docs/CICD.md](docs/CICD.md).

## USB testing

Scripts can be copied to a USB stick for manual testing on Windows PCs. See [docs/MANUAL-TEST-WINDOWS-REINSTALL.md](docs/MANUAL-TEST-WINDOWS-REINSTALL.md) for the full end-to-end test procedure.

## Getting started

See [docs/QUICK-START.md](docs/QUICK-START.md) for the step-by-step setup guide (clone, open in VS Code, devcontainer starts automatically).

## AI-supported development

This repo uses Claude Code for plan-based development. Plans and investigations live in `docs/ai-developer/plans/`. See [docs/AI-SUPPORTED-DEVELOPMENT.md](docs/AI-SUPPORTED-DEVELOPMENT.md) for the workflow.

## License

[MIT](LICENSE)
