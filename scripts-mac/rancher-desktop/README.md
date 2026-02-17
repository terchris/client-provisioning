# Rancher Desktop

Scripts for deploying and managing Rancher Desktop on Apple Silicon Macs via Jamf.

## Deployment profiles: defaults vs locked

All scripts write settings via macOS deployment profiles (plist files). Understanding the two profile types is essential:

| Profile | File | When it applies | User can change? |
| ------- | ---- | --------------- | ---------------- |
| **defaults** | `io.rancherdesktop.profile.defaults.plist` | First launch only (or after factory reset) | Yes |
| **locked** | `io.rancherdesktop.profile.locked.plist` | Every launch — overrides user settings | No |

**Key behavior:**

- Rancher Desktop reads profiles at **startup only** — changes while the app is running take effect on next restart.
- The **defaults** profile sets initial values. Once the user (or the app on first launch) saves a preference, the default is ignored on subsequent launches.
- The **locked** profile always wins. Use `--lock` when you need to enforce a setting on machines where Rancher Desktop has already been launched.
- Both profiles live in `/Library/Managed Preferences/` and require root (sudo) to write.
- Scripts use PlistBuddy to merge keys into the profile — running one script does not destroy settings written by another.

**When to use which:**

- **Fresh install** (install script) — defaults is fine, the app hasn't launched yet.
- **Change a setting on a machine that's already in use** — use `--lock` to guarantee the change takes effect.
- **Set an org-wide policy** (e.g. "Kubernetes must be off") — use `--lock` to prevent users from changing it.

See [Rancher Desktop Deployment Profiles](https://docs.rancherdesktop.io/getting-started/deployment/) for details.

## Testing

```bash
# Test all rancher-desktop scripts
bash docs/ai-developer/tools/validate-bash.sh rancher-desktop

# Test everything
bash docs/ai-developer/tools/validate-bash.sh
```

---

# Rancher Desktop Install

Install Rancher Desktop on Apple Silicon Macs.

## What it does

1. Downloads the Rancher Desktop `.dmg` for Apple Silicon
2. Mounts, copies `Rancher Desktop.app` to `/Applications/`, unmounts
3. Clears Gatekeeper quarantine
4. Creates a **defaults** deployment profile with:
   - Container engine: Docker (moby)
   - Kubernetes: disabled (default) or enabled via flag
   - RAM and CPU: auto-detected from host hardware or overridden via flags

If Rancher Desktop is already installed, the script skips the install and updates the deployment profile only.

## Usage

```bash
# Basic install (Kubernetes off, auto-detected resources)
sudo bash scripts-mac/rancher-desktop/rancher-desktop-install.sh

# Install with Kubernetes enabled
sudo bash scripts-mac/rancher-desktop/rancher-desktop-install.sh --kubernetes

# Install with custom resources
sudo bash scripts-mac/rancher-desktop/rancher-desktop-install.sh --memory 8 --cpus 4

# Install a specific version
sudo bash scripts-mac/rancher-desktop/rancher-desktop-install.sh --version 1.22.0
```

## Options

| Flag | Description | Default |
| ---- | ----------- | ------- |
| `--kubernetes` | Enable Kubernetes (k3s) | disabled |
| `--no-kubernetes` | Disable Kubernetes (k3s) | default |
| `--memory <GB>` | RAM allocation in GB | 25% of host RAM |
| `--cpus <N>` | CPU allocation | 50% of host cores |
| `--version <VER>` | Rancher Desktop version | `1.22.0` |

## Resource auto-detection

When `--memory` and `--cpus` are not specified, the script detects host hardware and allocates:

- **RAM**: 25% of total (minimum 2 GB)
- **CPUs**: 50% of total (minimum 1)

---

# Rancher Desktop Uninstall

Cleanly remove Rancher Desktop and all associated configuration from a Mac.

**This script requires `--confirm` to run.** It will not execute without it — this prevents accidental data loss.

## Data loss warning

This script **permanently destroys** all container data stored in the Rancher Desktop VM:

- All Docker images (pulled and built)
- All Docker containers (running and stopped)
- All Docker volumes (named and anonymous)
- All Kubernetes resources (if k3s was enabled)

Files bind-mounted from the host filesystem (e.g. `-v /Users/me/project:/app`) are **not affected** — those live on the host, not inside the VM.

There is no recovery. Back up any important data before running this script.

## What it does

1. Quits Rancher Desktop if running (graceful quit, then force kill)
2. Removes `/Applications/Rancher Desktop.app`
3. Removes deployment profiles from `/Library/Managed Preferences/io.rancherdesktop.profile.*`
4. Removes user-level data directories (caches, logs, preferences, `~/.rd`) — **this is where the VM disk lives**
5. Removes CLI symlinks (`rdctl`, `docker`, `kubectl`, `nerdctl`, `helm`) that point to Rancher Desktop
6. Removes `/opt/rancher-desktop/`

The script handles "not installed" gracefully — if a file or directory doesn't exist, it skips it.

## Usage

```bash
# Full uninstall (--confirm is required)
sudo bash scripts-mac/rancher-desktop/rancher-desktop-uninstall.sh --confirm

# Uninstall but keep the deployment profile
sudo bash scripts-mac/rancher-desktop/rancher-desktop-uninstall.sh --confirm --keep-profile
```

## Options

| Flag | Description | Default |
| ---- | ----------- | ------- |
| `--confirm` | Required. Confirms you understand this destroys all data | - |
| `--keep-profile` | Keep deployment profiles in `/Library/Managed Preferences` | remove them |

---

# Rancher Desktop Kubernetes

Enable or disable Kubernetes (k3s) in Rancher Desktop via deployment profile.

## What it does

Sets `kubernetes.enabled` in the deployment profile using PlistBuddy. Other settings in the profile (containerEngine, virtualMachine, etc.) are preserved.

## Usage

```bash
# Disable Kubernetes (defaults profile — first launch only)
sudo bash scripts-mac/rancher-desktop/rancher-desktop-k8s.sh --disable

# Enable Kubernetes (defaults profile — first launch only)
sudo bash scripts-mac/rancher-desktop/rancher-desktop-k8s.sh --enable

# Disable Kubernetes and lock the setting (enforced on every launch)
sudo bash scripts-mac/rancher-desktop/rancher-desktop-k8s.sh --disable --lock
```

**Important:** Without `--lock`, the setting only applies on first launch or after factory reset. If Rancher Desktop has already been launched on this machine, use `--lock` to enforce the change.

## Options

| Flag | Description |
| ---- | ----------- |
| `--enable` | Enable Kubernetes (k3s) |
| `--disable` | Disable Kubernetes (k3s) |
| `--lock` | Write to locked profile (enforced on every launch, user cannot change) |

One of `--enable` or `--disable` is required.

---

# Rancher Desktop Config

Configure Rancher Desktop VM resources (RAM and CPU) via deployment profile.

## What it does

Sets `virtualMachine.memoryInGB` and/or `virtualMachine.numberCPUs` in the deployment profile using PlistBuddy. Only the provided settings are written — if you only pass `--memory`, CPUs are not touched. Other settings in the profile are preserved.

**Warning:** Changing RAM or CPU will restart the VM on next Rancher Desktop launch. All running containers will be stopped (named volumes persist).

## Usage

```bash
# Set RAM to 8 GB (defaults profile — first launch only)
sudo bash scripts-mac/rancher-desktop/rancher-desktop-config.sh --memory 8

# Set CPU count to 4
sudo bash scripts-mac/rancher-desktop/rancher-desktop-config.sh --cpus 4

# Set both RAM and CPU
sudo bash scripts-mac/rancher-desktop/rancher-desktop-config.sh --memory 8 --cpus 4

# Set RAM and lock the setting (enforced on every launch)
sudo bash scripts-mac/rancher-desktop/rancher-desktop-config.sh --memory 8 --lock
```

**Important:** Without `--lock`, the setting only applies on first launch or after factory reset. If Rancher Desktop has already been launched on this machine, use `--lock` to enforce the change.

## Options

| Flag | Description |
| ---- | ----------- |
| `--memory <GB>` | RAM allocation in GB |
| `--cpus <N>` | CPU allocation |
| `--lock` | Write to locked profile (enforced on every launch, user cannot change) |

At least one of `--memory` or `--cpus` is required.
