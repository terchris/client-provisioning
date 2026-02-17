# Fix: Devcontainer does not start on first open

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) -- The implementation process
> - [PLANS.md](../../PLANS.md) -- Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `-- DONE` to phase headers, update status.

## Status: Completed

**Goal**: Ensure VS Code prompts users to install the Dev Containers extension on first open, so the devcontainer starts automatically on fresh machines.

**Completed**: 2026-02-13
**Last Updated**: 2026-02-13

**Investigation**: [INVESTIGATE-devcontainer-first-open.md](../backlog/INVESTIGATE-devcontainer-first-open.md)

---

## Problem

On a freshly installed machine, VS Code does not detect `.devcontainer/` because the Dev Containers extension (`ms-vscode-remote.remote-containers`) is not installed. The user sees raw source files and has no idea the project is meant to run in a container.

The fix is `.vscode/extensions.json` -- a VS Code workspace file that recommends extensions. When present, VS Code shows a notification: *"This workspace has extension recommendations"* with an **Install All** button. Once the Dev Containers extension is installed, it immediately detects `.devcontainer/` and prompts to reopen in container.

---

## Phase 1: Add `.vscode/extensions.json` to this repo -- DONE

### Tasks

- [x] 1.1 Create `.vscode/extensions.json` with `ms-vscode-remote.remote-containers` in the `recommendations` array

### Validation

User confirms file exists and contains the correct extension ID.

---

## Phase 2: Update `devcontainer-init.ps1` (Windows) -- DONE

After `devcontainer-init` creates `.devcontainer/devcontainer.json`, it should also ensure `.vscode/extensions.json` exists with the Dev Containers extension recommendation. This fixes the problem for all future projects initialized on Windows.

The logic must handle three cases:

1. **File does not exist** -- create it with the recommendation
2. **File exists but does not include the extension** -- add it to the existing `recommendations` array
3. **File exists and already includes it** -- do nothing

PowerShell has built-in JSON support (`ConvertFrom-Json` / `ConvertTo-Json`), so no external tools are needed.

### Tasks

- [x] 2.1 Add `Ensure-VscodeExtensionsJson` function to `scripts-win/devcontainer-toolbox/devcontainer-init.ps1` that handles all three cases
- [x] 2.2 Call the function from the main block after `New-DevcontainerJson`
- [x] 2.3 Run `bash docs/ai-developer/tools/validate-powershell.sh` -- all checks pass

### Validation

User confirms the script logic is correct. Validator passes.

---

## Phase 3: Update `devcontainer-init.sh` (Mac) -- DONE

Same logic as Phase 2, but for the Mac bash script. Since `jq` is not available on a fresh Mac, use `python3` (which ships with macOS) for JSON manipulation.

### Tasks

- [x] 3.1 Add `ensure_vscode_extensions_json` function to `scripts-mac/devcontainer-toolbox/devcontainer-init.sh` that handles all three cases using `python3`
- [x] 3.2 Call the function from `main()` after `create_devcontainer_json`
- [x] 3.3 Run `bash docs/ai-developer/tools/validate-bash.sh` -- all checks pass

### Validation

User confirms the script logic is correct. Validator passes.

---

## Testing

Both the PowerShell and bash/python3 functions were tested against a temp directory with all three cases:

| Case | PowerShell | Bash/python3 |
|------|-----------|-------------|
| File does not exist | Creates with extension | Creates with extension |
| File exists, extension missing | Adds to existing array | Adds to existing array |
| File exists, extension present | Skips (no change) | Skips (no change) |

### PowerShell test

```powershell
# Case 1: no .vscode/ directory — creates file from scratch
$tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "test-ext")
Ensure-VscodeExtensionsJson -TargetDir $tmp
# Result: .vscode/extensions.json created with ms-vscode-remote.remote-containers

# Case 2: file exists with other extensions — adds to array
Set-Content "$tmp/.vscode/extensions.json" '{"recommendations":["some-other.extension"]}'
Ensure-VscodeExtensionsJson -TargetDir $tmp
# Result: recommendations now contains both extensions

# Case 3: file already has the extension — no change
Ensure-VscodeExtensionsJson -TargetDir $tmp
# Result: "SKIP: already present", file unchanged
```

### Bash/python3 test

```bash
# Case 1: no .vscode/ directory — creates file from scratch
tmp=$(mktemp -d)
ensure_vscode_extensions_json "$tmp"
# Result: .vscode/extensions.json created with ms-vscode-remote.remote-containers

# Case 2: file exists with other extensions — adds to array
echo '{"recommendations":["some-other.extension"]}' > "$tmp/.vscode/extensions.json"
ensure_vscode_extensions_json "$tmp"
# Result: recommendations now contains both extensions

# Case 3: file already has the extension — no change
ensure_vscode_extensions_json "$tmp"
# Result: python3 prints "already_present", file unchanged
```

---

## Acceptance Criteria

- [x] `.vscode/extensions.json` exists in this repo with `ms-vscode-remote.remote-containers`
- [x] `devcontainer-init.ps1` creates `.vscode/extensions.json` in the target folder (handles create/add/skip)
- [x] `devcontainer-init.sh` creates `.vscode/extensions.json` in the target folder (handles create/add/skip)
- [x] Both validators pass
- [x] Investigation file updated with completed tasks

---

## Files to Modify

| File | Change |
|------|--------|
| `.vscode/extensions.json` | **Create** -- Dev Containers extension recommendation |
| `scripts-win/devcontainer-toolbox/devcontainer-init.ps1` | Add `.vscode/extensions.json` creation logic |
| `scripts-mac/devcontainer-toolbox/devcontainer-init.sh` | Add `.vscode/extensions.json` creation logic |
| `docs/ai-developer/plans/backlog/INVESTIGATE-devcontainer-first-open.md` | Mark completed tasks |
