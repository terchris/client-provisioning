# Investigate: Devcontainer does not start on first open

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) -- The implementation process
> - [PLANS.md](../../PLANS.md) -- Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `-- DONE` to phase headers, update status.

## Status: Completed

**Goal**: Make the devcontainer start automatically when a user opens a repo in VS Code for the first time on a freshly installed machine.

**Last Updated**: 2026-02-13

**Related**:

- `.devcontainer/devcontainer.json` -- the devcontainer configuration
- `scripts-win/devcontainer-toolbox/devcontainer-init.ps1` -- Windows init command
- `scripts-mac/devcontainer-toolbox/devcontainer-init.sh` -- Mac init command
- `scripts-win/devcontainer-toolbox/install.ps1` -- Windows Intune installer
- `scripts-mac/devcontainer-toolbox/devcontainer-init-install.sh` -- Mac installer
- [QUICK-START.md](../../QUICK-START.md) -- onboarding guide for script maintainers

---

## Problem

On a freshly installed Windows PC (or Mac), VS Code does not detect the `.devcontainer` folder unless the **Dev Containers** extension (`ms-vscode-remote.remote-containers`) is already installed.

Without the extension:

- VS Code opens the repo as a normal local folder
- The `.devcontainer/devcontainer.json` file is completely invisible to VS Code
- No prompt appears -- the user sees raw source files and has no idea the project is meant to run in a container
- The user must manually find and install the Dev Containers extension before anything works

This breaks the "clone and go" experience described in [QUICK-START.md](../../QUICK-START.md).

### This affects more than just this repo

The `devcontainer-init` command (deployed via Intune and Jamf) is designed to set up **any** project folder for devcontainer use. It downloads `devcontainer.json` and tells the user:

> 1. Open this folder in VS Code
> 2. Click 'Reopen in Container' when prompted

But on a fresh machine, step 2 never happens because the Dev Containers extension is not installed. The user sees nothing. This affects every developer who uses `devcontainer-init` on any repo, not just this one.

### The full deployment chain

```text
Intune/Jamf installs:
  WSL2 (Windows only) → Rancher Desktop → devcontainer-toolbox

devcontainer-toolbox install.ps1 / devcontainer-init-install.sh:
  Pulls Docker image → Installs devcontainer-init command → Adds to PATH

User runs:
  devcontainer-init ~/projects/my-repo
    → Creates .devcontainer/devcontainer.json
    → Tells user: "Open in VS Code, click Reopen in Container"
    → BUT: Dev Containers extension is not installed → nothing happens
```

The missing step is between "devcontainer-toolbox installed" and "user opens VS Code" -- the Dev Containers extension must be on the host VS Code.

---

## Current state

| Item                               | Status                                                               |
|------------------------------------|----------------------------------------------------------------------|
| `.devcontainer/devcontainer.json`  | Exists -- defines the devcontainer image and in-container extensions  |
| `.vscode/extensions.json`          | **Missing** -- no host extension recommendations file                |
| Dev Containers extension           | Must be installed manually on the host                               |
| `devcontainer-init.ps1` (Windows)  | Does not check for or install the extension                          |
| `devcontainer-init.sh` (Mac)       | Does not check for or install the extension                          |
| `install.ps1` (Windows Intune)     | Does not install the extension                                       |

**Important distinction:** The extensions listed in `devcontainer.json` under `customizations.vscode.extensions` (markdownlint, shellcheck, git-graph, etc.) are installed **inside the container** after it starts. They do not help with the bootstrap problem. The Dev Containers extension must be installed on the **host** VS Code before `devcontainer.json` is even recognized.

---

## Research findings

### How VS Code extension recommendations work

VS Code supports a `.vscode/extensions.json` file that lists recommended extensions for a workspace. When a user opens the workspace:

1. VS Code detects the recommendations file
2. A notification popup appears (bottom-right): *"This workspace has extension recommendations"*
3. The user can click **Install All** or **Show Recommendations**
4. Once the Dev Containers extension is installed, it immediately detects `.devcontainer/devcontainer.json` and shows a second notification: **"Reopen in Container"**

This creates a two-step flow: (1) accept extension install, (2) click "Reopen in Container". Not fully automatic, but requires no manual searching.

### Installing extensions from the command line

VS Code ships with a `code` CLI that can install extensions:

```bash
code --install-extension ms-vscode-remote.remote-containers
```

This works without VS Code being open. It can be run from a provisioning script, a deployment script, or from `devcontainer-init` itself. The challenge is finding the `code` CLI:

- **Windows:** `C:\Users\<user>\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd` (user install) or `C:\Program Files\Microsoft VS Code\bin\code.cmd` (system install)
- **Mac:** `/usr/local/bin/code` (if shell command installed) or `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`

### Other mechanisms investigated

| Mechanism                           | How it works                                                            | Viable?                          |
|-------------------------------------|-------------------------------------------------------------------------|----------------------------------|
| `.vscode/extensions.json`           | Prompts user to install recommended extensions on first open            | **Yes -- for repos**             |
| `code --install-extension` in script | Run from `devcontainer-init` or `install.ps1` to pre-install            | **Yes -- for all projects**      |
| VS Code bootstrap folder            | Place `.vsix` in VS Code install dir, auto-installed on first launch    | Possible but fragile             |
| "Open in Dev Containers" badge       | One-click link from browser, auto-installs extension + clones           | Good for browser-based onboarding |
| VS Code Profiles                     | Export/import a profile with extensions pre-configured                  | One-time setup, not automatic    |
| Azure DevOps "Clone in VS Code"     | Clones repo and opens in VS Code                                       | Does **not** install extensions  |

### The "Open in Dev Containers" badge

VS Code supports a special badge that can be added to README files or wiki pages:

```markdown
[![Open in Dev Containers](https://img.shields.io/static/v1?label=Dev%20Containers&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=REPO_URL)
```

When clicked from a browser, this:

1. Opens VS Code via the `vscode://` URI protocol
2. Automatically installs the Dev Containers extension if not present
3. Clones the repo into a container volume
4. Starts the devcontainer

This is the only mechanism that truly auto-installs the extension without separate user action. However, it clones fresh rather than opening an existing local checkout.

---

## Recommended approach

There are two scenarios to solve:

### Scenario A: New projects (devcontainer-init)

When a user runs `devcontainer-init ~/projects/my-repo`, the script already creates `.devcontainer/devcontainer.json`. It should **also** ensure `.vscode/extensions.json` contains the Dev Containers extension recommendation.

The logic must handle three cases:

1. **File does not exist** -- create it with the recommendation
2. **File exists but does not include `ms-vscode-remote.remote-containers`** -- add it to the existing `recommendations` array
3. **File exists and already includes it** -- do nothing

`devcontainer-init` runs on the **host** machine (before the container exists), so `jq` is not available. The approach differs per platform:

**Windows (`devcontainer-init.ps1`):** PowerShell has built-in JSON support:

```powershell
$extFile = Join-Path $TargetDir ".vscode\extensions.json"
$extId = "ms-vscode-remote.remote-containers"

if (Test-Path $extFile) {
    $json = Get-Content $extFile -Raw | ConvertFrom-Json
    if (-not $json.recommendations) {
        $json | Add-Member -NotePropertyName recommendations -NotePropertyValue @($extId)
    } elseif ($json.recommendations -notcontains $extId) {
        $json.recommendations += $extId
    } else {
        return  # already present
    }
} else {
    New-Item -ItemType Directory -Path (Join-Path $TargetDir ".vscode") -Force | Out-Null
    $json = [PSCustomObject]@{ recommendations = @($extId) }
}

$json | ConvertTo-Json -Depth 10 | Set-Content $extFile -Encoding UTF8
```

**Mac (`devcontainer-init.sh`):** No `jq` on a fresh Mac. But `python3` ships with macOS and can handle JSON:

```bash
EXT_FILE="$TARGET_DIR/.vscode/extensions.json"
EXT_ID="ms-vscode-remote.remote-containers"

mkdir -p "$TARGET_DIR/.vscode"

python3 -c "
import json, os, sys
path = sys.argv[1]
ext_id = sys.argv[2]
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
else:
    data = {}
recs = data.setdefault('recommendations', [])
if ext_id not in recs:
    recs.append(ext_id)
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
" "$EXT_FILE" "$EXT_ID"
```

Both approaches preserve existing recommendations and only add the extension if missing.

**Changes needed:**

- `scripts-win/devcontainer-toolbox/devcontainer-init.ps1` -- add `.vscode/extensions.json` logic
- `scripts-mac/devcontainer-toolbox/devcontainer-init.sh` -- add `.vscode/extensions.json` logic

This is a change to the devcontainer-init scripts in this repo. The fix ships with the next Intune/Jamf deployment.

### Scenario B: Existing projects (devcontainer-toolbox entrypoint)

Existing repos already have `.devcontainer/devcontainer.json` but no `.vscode/extensions.json`. These projects were set up before this fix. The user may have installed the Dev Containers extension manually, or may not have it.

The fix: the **devcontainer-toolbox itself** should create `.vscode/extensions.json` in the workspace if it doesn't already exist. This happens inside the container on startup (the entrypoint script). On the next container rebuild, the file appears in the workspace. If the user later opens the same repo on a fresh machine without the extension, the recommendation prompt appears.

**This is a change to the devcontainer-toolbox project** (upstream at `github.com/terchris/devcontainer-toolbox`), not to this repo. File an issue or PR there.

### Immediate fix for this repo

Since this repo already has `.devcontainer/`, we can create `.vscode/extensions.json` directly right now. This fixes the problem for maintainers of this repo without waiting for the upstream devcontainer-toolbox changes.

---

## Conclusion

The root cause is that the Dev Containers extension is not part of the deployment chain. The fix is `.vscode/extensions.json` -- created in three places:

1. **This repo (immediate):** Add `.vscode/extensions.json` directly -- fixes the problem for maintainers of this repo
2. **devcontainer-init (new projects):** Update `devcontainer-init.ps1` and `.sh` to create `.vscode/extensions.json` alongside `devcontainer.json` -- fixes the problem for all future projects
3. **devcontainer-toolbox entrypoint (existing projects):** Create `.vscode/extensions.json` on container startup if missing -- fixes the problem for all existing projects on next rebuild

---

## Implementation tasks

### This repo (immediate)

- [x] Create `.vscode/extensions.json` with Dev Containers extension recommendation

### devcontainer-init scripts (new projects)

- [x] Update `scripts-win/devcontainer-toolbox/devcontainer-init.ps1` to also create `.vscode/extensions.json` in the target folder
- [x] Update `scripts-mac/devcontainer-toolbox/devcontainer-init.sh` to also create `.vscode/extensions.json` in the target folder

### devcontainer-toolbox (existing projects -- upstream)

- [x] Issue filed: [ISSUE-vscode-devcontainers-extension.md](../../devcontainer-toolbox-issues/ISSUE-vscode-devcontainers-extension.md)

---

## Sources

- [VS Code Extension Marketplace -- Workspace Recommended Extensions](https://code.visualstudio.com/docs/configure/extensions/extension-marketplace)
- [VS Code Developing inside a Container](https://code.visualstudio.com/docs/devcontainers/containers)
- [VS Code Enterprise Extensions (bootstrap folder)](https://code.visualstudio.com/docs/enterprise/extensions)
- [VS Code Create a Dev Container (badges)](https://code.visualstudio.com/docs/devcontainers/create-dev-container)
- [VS Code CLI -- install extension](https://code.visualstudio.com/docs/configure/extensions/command-line-extension-management)
