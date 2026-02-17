# Plan: Create rancher-desktop-k8s.sh and rancher-desktop-config.sh

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Complete

**Goal**: Create two scripts for managing Rancher Desktop settings via deployment profiles (plist).

**Last Updated**: 2026-02-07

---

## Context

The install and uninstall scripts are done. Two more scripts are needed before USB testing on a private Mac:

1. **rancher-desktop-k8s.sh** — toggle Kubernetes on/off
2. **rancher-desktop-config.sh** — change RAM and CPU allocation

Rancher Desktop is likely NOT running on the user's machine, so we use the **deployment profile (plist) approach** — not rdctl. By default we write a **defaults** plist (user can change later). With `--lock` we write a **locked** plist (user cannot change).

Research is done in `docs/ai-developer/plans/backlog/INVESTIGATE-rancher-desktop-install.md`.

---

## Plist merge strategy: PlistBuddy

### Problem

Multiple scripts write to the same plist file. If a script overwrites the entire file (e.g. `cat > file.plist`), it destroys keys set by other scripts. For example, the install script sets `containerEngine`, `kubernetes`, and `virtualMachine`. If the k8s script then overwrites the file with only `kubernetes.enabled`, the other settings are lost.

### Solution: PlistBuddy

macOS ships with `/usr/libexec/PlistBuddy` — a tool that reads and writes **individual keys** in a plist without touching the rest of the file. It's built into every macOS version, no install needed. Since we target Apple Silicon (ARM), the minimum macOS is 11+, so PlistBuddy is always available.

### How it works

```bash
PLISTBUDDY="/usr/libexec/PlistBuddy"

# Create a new plist with a key
$PLISTBUDDY -c "Add :version integer 10" file.plist

# Set an existing key (fails if key doesn't exist)
$PLISTBUDDY -c "Set :kubernetes:enabled true" file.plist

# Add a new key (fails if key already exists)
$PLISTBUDDY -c "Add :kubernetes:enabled bool true" file.plist
```

The standard pattern to handle both cases (key may or may not exist):

```bash
plist_set() {
    local file="$1" key="$2" type="$3" value="$4"
    $PLISTBUDDY -c "Set ${key} ${type} ${value}" "$file" 2>/dev/null \
        || $PLISTBUDDY -c "Add ${key} ${type} ${value}" "$file"
}
```

For nested dicts like `:kubernetes:enabled`, the parent dict (`:kubernetes`) must exist first. So we use a helper that ensures the parent dict exists before setting the key.

### Bootstrap

If the plist file doesn't exist yet, PlistBuddy creates it automatically on the first `Add` command. We ensure the `version` key is always set, then add/update only the keys the script manages.

---

## Script 1: rancher-desktop-k8s.sh

### What it does

Sets `kubernetes.enabled` to true or false in the deployment profile. Preserves all other keys in the file (containerEngine, virtualMachine, etc.).

### Parameters

- `--enable` — enable Kubernetes (k3s)
- `--disable` — disable Kubernetes (k3s)
- `--lock` — write to locked plist (user cannot change setting)
- `-h, --help` — show help

One of `--enable` or `--disable` is required.

### Implementation

1. Metadata: `SCRIPT_ID="rancher-desktop-k8s"`, `SCRIPT_NAME="Rancher Desktop Kubernetes"`, `SCRIPT_CATEGORY="DEVOPS"`
2. Configuration section:
   - `PLISTBUDDY="/usr/libexec/PlistBuddy"`
   - `RANCHER_PROFILE_DIR="/Library/Managed Preferences"`
   - `PROFILE_DEFAULTS="io.rancherdesktop.profile.defaults.plist"`
   - `PROFILE_LOCKED="io.rancherdesktop.profile.locked.plist"`
3. Argument parsing: require `--enable` or `--disable`, optional `--lock`
4. Use PlistBuddy to set `:version` and `:kubernetes:enabled` — preserves other keys
5. Default: write to defaults plist. With `--lock`: write to locked plist
6. Verify file exists after writing
7. Log what was done and remind user to restart Rancher Desktop

### Keys written

| Key | Type | Value |
|-----|------|-------|
| `:version` | integer | `10` |
| `:kubernetes:enabled` | bool | `true` or `false` |

---

## Script 2: rancher-desktop-config.sh

### What it does

Sets `virtualMachine.memoryInGB` and/or `virtualMachine.numberCPUs` in the deployment profile. Only the provided settings are written — if you only pass `--memory`, CPUs are not touched. Preserves all other keys in the file.

### Parameters

- `--memory <GB>` — RAM allocation in GB
- `--cpus <N>` — CPU count
- `--lock` — write to locked plist (user cannot change setting)
- `-h, --help` — show help

At least one of `--memory` or `--cpus` is required.

### Implementation

1. Metadata: `SCRIPT_ID="rancher-desktop-config"`, `SCRIPT_NAME="Rancher Desktop Config"`, `SCRIPT_CATEGORY="DEVOPS"`
2. Same configuration section as k8s script
3. Argument parsing: validate `--memory` and `--cpus` are positive integers
4. Use PlistBuddy to set `:version` and only the provided keys under `:virtualMachine:`
5. Default: write to defaults plist. With `--lock`: write to locked plist
6. Verify file exists after writing
7. Log what was done, warn that VM will restart (containers stopped) on next launch

### Keys written

| Key | Type | Condition |
|-----|------|-----------|
| `:version` | integer | always |
| `:virtualMachine:memoryInGB` | integer | only if `--memory` provided |
| `:virtualMachine:numberCPUs` | integer | only if `--cpus` provided |

---

## Shared patterns (both scripts)

### Shared helper: plist_set

Both scripts use the same helper to set a key, handling the "key exists" vs "key doesn't exist" case:

```bash
plist_set() {
    local file="$1" key="$2" type="$3" value="$4"
    "$PLISTBUDDY" -c "Set ${key} ${value}" "$file" 2>/dev/null \
        || "$PLISTBUDDY" -c "Add ${key} ${type} ${value}" "$file"
}
```

### Shared helper: plist_ensure_dict

Parent dicts must exist before setting nested keys. This helper creates a dict if it doesn't exist:

```bash
plist_ensure_dict() {
    local file="$1" key="$2"
    "$PLISTBUDDY" -c "Print ${key}" "$file" 2>/dev/null \
        || "$PLISTBUDDY" -c "Add ${key} dict" "$file"
}
```

### Other shared patterns

- **Profile dir**: `/Library/Managed Preferences/` (same as install script)
- **Profile version**: `10` (current Rancher Desktop profile format version)
- **Write permission check**: check write access and suggest sudo if needed
- **Error codes**: sequential per script, `ERR001`, `ERR002`, etc.
- **Verify every action**: check plist was written, check directory exists
- **Idempotent**: safe to run multiple times — PlistBuddy updates in place
- **No rdctl dependency**: works without app running

---

## Phases

### Phase 1: Create rancher-desktop-k8s.sh

- [x] 1.1 Copy template, fill metadata
- [x] 1.2 Add help, argument parsing (`--enable`, `--disable`, `--lock`)
- [x] 1.3 Implement plist writing with PlistBuddy (version + kubernetes.enabled)
- [x] 1.4 Run tests: `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop`

### Phase 2: Create rancher-desktop-config.sh

- [x] 2.1 Copy template, fill metadata
- [x] 2.2 Add help, argument parsing (`--memory`, `--cpus`, `--lock`)
- [x] 2.3 Implement plist writing with PlistBuddy (version + virtualMachine keys)
- [x] 2.4 Run tests: `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop`

### Phase 3: Update docs and README

- [x] 3.1 Update `scripts/rancher-desktop/README.md` with k8s and config script docs
- [x] 3.2 Update investigate file: mark k8s and config plans as created
- [x] 3.3 Run full test suite: `bash docs/ai-developer/tools/validate-scripts.sh`

---

## Files created/modified

- `scripts/rancher-desktop/rancher-desktop-k8s.sh` (new)
- `scripts/rancher-desktop/rancher-desktop-config.sh` (new)
- `scripts/rancher-desktop/README.md` (updated)
- `docs/ai-developer/plans/backlog/INVESTIGATE-rancher-desktop-install.md` (updated next steps)

## Verification

- All tests pass: `bash docs/ai-developer/tools/validate-scripts.sh`
- Both scripts show correct help with `-h`
- Both scripts have all 5 metadata fields
- No shellcheck errors
- On Mac: verify with `plutil -lint` that output plist is valid
- On Mac: verify running k8s script does NOT destroy keys set by install script
