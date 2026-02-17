# Investigate: Rancher Desktop Installation via Jamf on Mac

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Complete

**Goal**: Determine the best approach for deploying Rancher Desktop to Mac machines via Jamf.

**Last Updated**: 2026-02-06

---

## Questions to Answer

### Installation

1. Does Rancher Desktop provide a `.pkg` installer suitable for Jamf deployment, or only `.dmg`?
2. Is there a silent/unattended install method for macOS?
3. Are there any official docs or community guides for Jamf/MDM deployment of Rancher Desktop?
4. What prerequisites are needed on the Mac (e.g., macOS version, Rosetta 2 for Apple Silicon)?
5. Are there any known issues with enterprise/MDM deployment?

### Configuration

1. Does k3s (Kubernetes) come enabled by default? Can it be disabled at install time or via config?
2. Can we make Kubernetes on/off a script parameter (e.g. `--no-kubernetes`)?
3. How does Rancher Desktop allocate RAM and CPUs on macOS? Is there a config file or CLI to set this?
4. Can we auto-detect available RAM/CPUs and set sensible defaults (e.g. 25% of RAM, half of cores)?
5. Where does Rancher Desktop store its configuration on macOS — can we pre-seed it before first launch?

### Updates

1. How do we handle updates — does Rancher Desktop auto-update, or do we manage that via Jamf?

---

## Current State

- The `scripts/rancher-desktop/` folder exists but is empty (only `.gitkeep`)
- No scripts or documentation exist yet for this deployment
- The team uses Jamf to deploy software to Mac machines
- Cannot rely on Homebrew — not all target machines have it installed

---

## Research Findings

### Installation: .dmg only, no .pkg

Rancher Desktop v1.22.0 (latest, Jan 2026) ships **only `.dmg` files** for macOS:

- `Rancher.Desktop-1.22.0.aarch64.dmg` (Apple Silicon — our target)

No `.pkg` installer is provided. The community has requested one for enterprise deployment, but it doesn't exist yet.

**Install approach:** Script must download the `.dmg`, mount it, copy `Rancher Desktop.app` to `/Applications`, and unmount. This is the standard pattern for Jamf deployment of `.dmg`-only apps.

### MDM / Deployment Profiles (official support)

Rancher Desktop has official MDM support via **deployment profiles**. These are plist files that pre-configure settings before first launch.

**System profile locations (Jamf-compatible):**

- `/Library/Managed Preferences/io.rancherdesktop.profile.defaults.plist` — default settings, user can change
- `/Library/Managed Preferences/io.rancherdesktop.profile.locked.plist` — locked settings, user cannot change

**Fallback locations (pre-v1.19):**

- `/Library/Preferences/io.rancherdesktop.profile.defaults.plist`
- `/Library/Preferences/io.rancherdesktop.profile.locked.plist`

**Key facts:**

- Profiles are plist XML files
- Rancher Desktop reads them on startup and applies them
- Profiles survive factory reset and uninstall
- Rancher Desktop refuses to start if a profile exists but can't be parsed
- System profiles take precedence over user profiles

### Kubernetes: enabled by default, configurable

Kubernetes (k3s) is **enabled by default**. It can be disabled via:

1. **Deployment profile** (before first launch): Set `kubernetes.enabled = false` in the defaults plist
2. **rdctl CLI** (after install): `rdctl set --kubernetes-enabled=false`
3. **GUI**: Preferences > Kubernetes

### RAM and CPU: configurable, defaults are 2 CPU / 6 GB RAM

Defaults: **2 CPUs, 6 GB RAM**. Configurable via:

1. **Deployment profile**: Set `virtualMachine.memoryInGB` and `virtualMachine.numberCPUs` in the defaults plist
2. **rdctl CLI**: `rdctl set --virtual-machine.memory-in-gb 4 --virtual-machine.number-cpus 2`
3. **GUI**: Preferences > Virtual Machine > Hardware

The selectable range is based on the host system. There's a visual "red zone" warning when allocation may affect system stability.

### rdctl CLI tool

`rdctl` is Rancher Desktop's CLI for scripted configuration. Key commands:

| Command | Purpose |
| ------- | ------- |
| `rdctl list-settings` | Dump current config as JSON |
| `rdctl set --kubernetes-enabled=false` | Disable Kubernetes |
| `rdctl set --virtual-machine.memory-in-gb 4` | Set RAM |
| `rdctl set --virtual-machine.number-cpus 2` | Set CPUs |
| `rdctl set --container-engine.name moby` | Set Docker (moby) as engine |
| `rdctl create-profile --output plist` | Generate a deployment plist from JSON |
| `rdctl shutdown` | Gracefully stop Rancher Desktop |

**Note:** `rdctl` requires Rancher Desktop to be running. For pre-first-launch config, use deployment profiles instead.

### Generating a deployment profile

```bash
# 1. Dump current settings to JSON
rdctl list-settings | jq . > settings.json

# 2. Edit settings.json — keep only the keys you want to set

# 3. Convert to macOS plist
rdctl create-profile --output plist --input settings.json \
  > io.rancherdesktop.profile.defaults.plist

# 4. Deploy to target machine
sudo cp io.rancherdesktop.profile.defaults.plist \
  /Library/Managed\ Preferences/
```

---

## Options

### Option A: Script-based install from .dmg + deployment profile

Download `.dmg`, mount, copy `.app` to `/Applications`, unmount. Deploy a pre-built defaults plist to `/Library/Managed Preferences/` to pre-configure Kubernetes and resources.

**Pros:**

- Only viable approach (no `.pkg` exists)
- Deployment profiles are officially supported for MDM
- Can pre-configure Kubernetes on/off, RAM, CPUs before first launch
- Script parameters can control which profile to deploy

**Cons:**

- Must handle Gatekeeper (`xattr -cr` on the app)
- Two-part deploy: app install + config profile

### ~~Option B: Package-based install (.pkg)~~

Not available. Rancher Desktop only ships `.dmg`.

---

## Research Tasks

- [x] Check Rancher Desktop releases page for `.pkg` availability — **no .pkg, only .dmg**
- [x] Check official Rancher Desktop docs for enterprise/MDM deployment guidance — **deployment profiles supported**
- [x] Search for community guides on Jamf + Rancher Desktop — **community requesting .pkg, not yet available**
- [x] Find where Rancher Desktop stores config on macOS — **plist in /Library/Managed Preferences/**
- [x] Determine how to pre-configure Kubernetes on/off and resource limits — **deployment profiles + rdctl**
- [ ] Test which install method works in the Jamf execution context (root, no GUI)
- [ ] Identify required prerequisites (macOS version, Rosetta 2, etc.)

---

## Recommendation

**Use Option A: Script-based .dmg install + deployment profile.**

The script should:

1. Download the Apple Silicon `.dmg` from the Rancher Desktop releases
2. Mount, copy `Rancher Desktop.app` to `/Applications`, unmount
3. Clear Gatekeeper quarantine (`xattr -cr`)
4. Deploy a defaults plist to `/Library/Managed Preferences/` with:
   - Container engine set to Docker (moby)
   - Kubernetes enabled or disabled (script parameter, default: disabled)
   - RAM and CPU set to sensible defaults based on host hardware (e.g. 25% RAM, half cores)

Script parameters:

- `--kubernetes` / `--no-kubernetes` — enable/disable k3s (default: disabled)
- `--memory <GB>` — override RAM allocation (default: auto-detect)
- `--cpus <N>` — override CPU allocation (default: auto-detect)

Auto-detection for resources:

```bash
total_ram_gb=$(sysctl -n hw.memsize | awk '{printf "%d", $1/1024/1024/1024}')
total_cpus=$(sysctl -n hw.ncpu)
default_ram=$((total_ram_gb / 4))      # 25% of total
default_cpus=$((total_cpus / 2))       # 50% of cores
```

---

## Future Scripts

The install and uninstall scripts are done. The following scripts are needed next.

### 1. rancher-desktop-k8s.sh — Enable/disable Kubernetes

**Purpose:** Toggle Kubernetes (k3s) on an existing Rancher Desktop installation.

**Two approaches:**

1. **`rdctl set --kubernetes-enabled=false`** — runs as logged-in user (not root), requires app running, immediate effect (backend auto-restarts)
2. **Locked plist + app restart** — runs as root (Jamf-compatible), no app needed, applied on next app launch

**rdctl approach** (requires running as user):

```bash
CURRENT_USER=$(stat -f%Su /dev/console)
sudo -u "$CURRENT_USER" rdctl set --kubernetes-enabled=false
```

- Uses equals sign syntax (`--kubernetes-enabled=false`), not space-separated
- `rdctl` talks to a per-user API server on `localhost:6107`
- Backend restarts automatically after the change

**Locked plist approach** (Jamf-compatible, runs as root):

```bash
LOCKED="/Library/Managed Preferences/io.rancherdesktop.profile.locked.plist"
# Write locked plist with kubernetes.enabled = false
# Then restart Rancher Desktop
```

- Locked profiles override user settings — user cannot change the value
- Defaults profiles only apply on first run or after factory reset

**Resource impact:** Disabling k3s reduces idle CPU from ~20% to ~5% on Apple Silicon. Existing Kubernetes resources are preserved and available again when re-enabled.

**Script parameters:**

- `--enable` / `--disable` — toggle Kubernetes
- `--lock` — use locked profile (prevents user from changing)

---

### 2. rancher-desktop-config.sh — Change RAM and CPU

**Purpose:** Modify VM resource allocation on an existing installation. Container engine is always moby (Docker) — we do not support switching engines.

**Same two approaches as k8s script:**

**rdctl approach** (must run as user, app must be running):

```bash
CURRENT_USER=$(stat -f%Su /dev/console)
sudo -u "$CURRENT_USER" rdctl set \
  --virtual-machine.memory-in-gb=8 \
  --virtual-machine.number-cpus=4
```

- Multiple settings can be combined in one call
- VM restarts automatically (all running containers are stopped)
- `rdctl set` validates, saves, and triggers restart in one operation

**Locked plist approach** (Jamf-compatible):

- Write locked plist with desired values, restart app

**Important warnings:**

- Changing RAM/CPU restarts the VM, stopping all running containers
- Named volumes persist across VM restarts

**Script parameters:**

- `--memory <GB>` — RAM allocation
- `--cpus <N>` — CPU allocation
- `--lock` — use locked profile

---

### ~~3. rancher-desktop-update.sh~~ — Not needed

**Conclusion:** No update script needed. Users manage their own updates.

**Decision:** Auto-update is ON by default in Rancher Desktop, and we do not change or lock this setting. Users decide when to update. This keeps ops workload at zero for update management.

**Why this works:**

- Rancher Desktop has a built-in "Check for updates automatically" checkbox in Preferences > Application > General
- When an update is available, the user sees it in the UI and chooses when to restart
- The user controls timing, so they won't lose running containers unexpectedly
- No ops effort needed to track releases or push updates

**Known risks (acceptable):**

- Version drift across the fleet — different users will be on different versions. Acceptable for our use case since Rancher Desktop is a local dev tool, not a shared service.
- The auto-updater has had reliability issues historically (Issues #932, #5184, #3347) but these were fixed in older releases.
- If the app is installed to `/Applications/` as root, auto-update may need the user to have write access to the `.app` bundle. If this becomes a problem, we can adjust permissions during install.

**No changes needed to install script.** Auto-update is already ON by default. Our deployment profile does not need to set `application.updater.enabled` at all.

**Sources (if ops wants to revisit this decision later):**

- [Auto-update crash on macOS — Issue #932](https://github.com/rancher-sandbox/rancher-desktop/issues/932)
- [Auto-update detects wrong version — Issue #5184](https://github.com/rancher-sandbox/rancher-desktop/issues/5184)
- [Auto-update toggle not working — Issue #3347](https://github.com/rancher-sandbox/rancher-desktop/issues/3347)
- [Launch failure after upgrade with deployment profile — Issue #6292](https://github.com/rancher-sandbox/rancher-desktop/issues/6292)
- [No "Check for Updates" button — Issue #6820](https://github.com/rancher-sandbox/rancher-desktop/issues/6820)
- [MDM support in macOS — Issue #9044](https://github.com/rancher-sandbox/rancher-desktop/issues/9044) (shipped in v1.20)
- [Jamf Community — Best Practice: Auto Updates vs Patch Management](https://community.jamf.com/general-discussions-2/best-practice-automatic-updates-or-patch-management-34935)

---

### Decision needed: rdctl vs locked plist

For the k8s and config scripts, there are two approaches:

1. **rdctl** — more powerful, immediate effect, but must run as the logged-in user (not root). Requires Rancher Desktop to be running.
2. **Locked plist** — works as root (Jamf-compatible), but requires app restart and prevents user from changing the setting.

A hybrid approach may be best:

- Use **locked plist** for organization-wide policies deployed via Jamf (e.g. "Kubernetes must be disabled")
- Use **rdctl** for user-initiated changes or one-off adjustments

---

### Research tasks for future scripts

- [ ] Test `rdctl set` via `sudo -u $CURRENT_USER` in Jamf context
- [ ] Test locked plist approach — does changing a locked plist take effect on next app launch without factory reset?
- [ ] Test `rdctl shutdown` reliability — does it block until complete?
- [x] ~~Check if auto-update should be disabled via locked profile for Jamf-managed machines~~ — **no, leave auto-update ON.** Users decide when to update. Zero ops overhead.

---

## Next Steps

- [x] Create PLAN-rancher-desktop-install.md with the approach above
- [x] Create PLAN-rancher-desktop-uninstall.md
- [x] Create PLAN-rancher-desktop-k8s-config.md (combined plan for both scripts)
- [x] ~~Create PLAN-rancher-desktop-update.md~~ — not needed, handled by install script

---

## Sources

- [Rancher Desktop Deployment Profiles](https://docs.rancherdesktop.io/getting-started/deployment/)
- [Generating Deployment Profiles](https://docs.rancherdesktop.io/how-to-guides/generating-deployment-profiles/)
- [rdctl Command Reference](https://docs.rancherdesktop.io/references/rdctl-command-reference/)
- [VM Hardware Settings](https://docs.rancherdesktop.io/ui/preferences/virtual-machine/hardware/)
- [Rancher Desktop Releases](https://github.com/rancher-sandbox/rancher-desktop/releases)
- [Kubernetes Preferences](https://docs.rancherdesktop.io/ui/preferences/kubernetes/)
- [Container Engine General](https://docs.rancherdesktop.io/ui/preferences/container-engine/general/)
- [Application General Preferences](https://docs.rancherdesktop.io/ui/preferences/application/general/)
- [High CPU on Apple Silicon — Issue #7087](https://github.com/rancher-sandbox/rancher-desktop/issues/7087)
- [rdctl start does not wait — Issue #6915](https://github.com/rancher-sandbox/rancher-desktop/issues/6915)
