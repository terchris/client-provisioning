# Investigate: Fix devcontainer.json download URL

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Done

**Goal**: Fix `devcontainer-init.sh` and `devcontainer-init.ps1` to download the correct image-mode `devcontainer.json` instead of the build-mode file.

**Last Updated**: 2026-02-17

**Depends on**: devcontainer-toolbox repo publishing image-mode `devcontainer.json` at a stable URL — ✅ DONE (PR #57 merged)

**Implementation note**: URL fix applied directly from this investigation (no separate PLAN file — change was a single-line URL update in two files). Testing on Mac and Windows still pending.

---

## Problem

Both `devcontainer-init.sh` and `devcontainer-init.ps1` download `devcontainer.json` from:

```
https://raw.githubusercontent.com/terchris/devcontainer-toolbox/main/.devcontainer/devcontainer.json
```

**This is the wrong file.** That URL points to the **build-mode** `devcontainer.json` which contains:

```json
"build": {
    "dockerfile": "Dockerfile.base",
    ...
}
```

This file is for developing the toolbox itself. It requires the full `.devcontainer/` directory with `Dockerfile.base`, 100+ scripts, and all supporting files. When deployed to a user project, it fails immediately:

```
.devcontainer\Dockerfile.base does not exist
```

### What the scripts SHOULD download

The **image-mode** `devcontainer.json` which contains:

```json
"image": "ghcr.io/terchris/devcontainer-toolbox:latest"
```

This is a self-contained file that pulls the pre-built Docker image. No Dockerfile or scripts needed.

### Additional issue: cross-platform compatibility

The `devcontainer.json` must work on Windows, Mac, and Linux. The `initializeCommand` field is problematic because:

- On Windows, VS Code runs it via `cmd.exe`
- On Mac/Linux, VS Code runs it via `/bin/sh`
- There is no string syntax that works in both shells
- Git may not be installed on the host (tested on fresh Windows PC — git not present)

**Solution**: The image-mode `devcontainer.json` should NOT have an `initializeCommand`. The container entrypoint handles git identity configuration inside the container.

---

## Current State

### Files that need fixing

| File | Line | Current URL (wrong) |
|------|------|-------------------|
| `scripts-mac/devcontainer-toolbox/devcontainer-init.sh` | 38 | `https://raw.githubusercontent.com/$REPO/main/.devcontainer/devcontainer.json` |
| `scripts-win/devcontainer-toolbox/devcontainer-init.ps1` | 43 | `https://raw.githubusercontent.com/$REPO/main/.devcontainer/devcontainer.json` |

### Two devcontainer.json files in the toolbox repo

| File | Mode | Who uses it |
|------|------|-------------|
| `.devcontainer/devcontainer.json` | Build mode (`Dockerfile.base`) | Toolbox developers only |
| `devcontainer-user-template.json` | Image mode (pre-built image) | All user projects, this project's scripts |

The toolbox repo currently has no standalone image-mode `devcontainer.json` at a downloadable URL. The image-mode template only exists embedded inside `install.sh` and `install.ps1`.

---

## What Needs to Happen

### 1. In the devcontainer-toolbox repo (upstream dependency)

A standalone image-mode `devcontainer.json` needs to be published at a stable URL. Decided location:

```
https://raw.githubusercontent.com/terchris/devcontainer-toolbox/main/devcontainer-user-template.json
```

The file is named `devcontainer-user-template.json` (at the repo root) to make it immediately visible and clearly distinguish it from the build-mode `.devcontainer/devcontainer.json`.

This is tracked in the devcontainer-toolbox repo as: `INVESTIGATE-image-mode-devcontainer-json.md`

### 2. In this project (after upstream publishes the file)

Update the download URL in both scripts:

**`scripts-mac/devcontainer-toolbox/devcontainer-init.sh` line 38:**
```bash
# Before (wrong — downloads build-mode file)
DEVCONTAINER_JSON_URL="https://raw.githubusercontent.com/$REPO/main/.devcontainer/devcontainer.json"

# After (correct — downloads image-mode file)
DEVCONTAINER_JSON_URL="https://raw.githubusercontent.com/$REPO/main/devcontainer-user-template.json"
```

**`scripts-win/devcontainer-toolbox/devcontainer-init.ps1` line 43:**
```powershell
# Before (wrong — downloads build-mode file)
$DEVCONTAINER_JSON_URL = "https://raw.githubusercontent.com/$REPO/main/.devcontainer/devcontainer.json"

# After (correct — downloads image-mode file)
$DEVCONTAINER_JSON_URL = "https://raw.githubusercontent.com/$REPO/main/devcontainer-user-template.json"
```

### 3. Test on all platforms

- [ ] Mac: Run `devcontainer-init.sh`, verify downloaded file has `"image":` not `"build":`
- [ ] Windows: Run `devcontainer-init.ps1`, verify downloaded file has `"image":` not `"build":`
- [ ] Open the created devcontainer on Windows (no git installed) — must not fail
- [ ] Open the created devcontainer on Mac — must work

---

## Workaround (until upstream fix is ready)

If you need to deploy NOW before the toolbox repo publishes the image-mode file, embed the correct JSON directly in the scripts instead of downloading it. The correct image-mode `devcontainer.json` is:

```json
{
    "image": "ghcr.io/terchris/devcontainer-toolbox:latest",
    "overrideCommand": false,
    "runArgs": [
        "--cap-add=NET_ADMIN",
        "--cap-add=NET_RAW",
        "--cap-add=SYS_ADMIN",
        "--cap-add=AUDIT_WRITE",
        "--device=/dev/net/tun:/dev/net/tun",
        "--privileged"
    ],
    "customizations": {
        "vscode": {
            "extensions": [
                "yzhang.markdown-all-in-one",
                "MermaidChart.vscode-mermaid-chart",
                "redhat.vscode-yaml",
                "mhutchie.git-graph",
                "timonwong.shellcheck"
            ]
        }
    },
    "remoteEnv": {
        "DCT_HOME": "/opt/devcontainer-toolbox",
        "DCT_WORKSPACE": "/workspace"
    },
    "workspaceFolder": "/workspace",
    "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached",
    "remoteUser": "vscode",
    "containerUser": "vscode",
    "shutdownAction": "stopContainer",
    "updateRemoteUserUID": true,
    "init": true
}
```

---

## Related

- devcontainer-toolbox repo: `INVESTIGATE-image-mode-devcontainer-json.md` (upstream counterpart)
- `INVESTIGATE-windows-devcontainer-toolbox.md` — original Windows testing
- `INVESTIGATE-devcontainer-toolbox-testing.md` — test suite investigation
