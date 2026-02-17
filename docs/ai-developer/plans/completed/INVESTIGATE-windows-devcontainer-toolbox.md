# Investigate: Windows devcontainer-toolbox package

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) -- The implementation process
> - [PLANS.md](../../PLANS.md) -- Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `-- DONE` to phase headers, update status.

## Status: Complete

**Goal**: Determine how to create a Windows/Intune equivalent of `scripts-mac/devcontainer-toolbox/` for deploying devcontainer environments to Windows machines.

**Last Updated**: 2026-02-12

---

## Context

The Mac version (`scripts-mac/devcontainer-toolbox/`) has three scripts deployed via Jamf:

| Script | Purpose |
| ------ | ------- |
| `devcontainer-pull.sh` | Pull the Docker image to the local machine |
| `devcontainer-init-install.sh` | Install `devcontainer-init` command system-wide to `/usr/local/bin` |
| `devcontainer-init.sh` | Initialize a project folder with `.devcontainer/` config (downloads from GitHub) |

The workflow: pull image -> install the init command globally -> run init per-project to create `.devcontainer/` config.

We need the same capability on Windows, deployed via Intune as a `.intunewin` package (like the existing `rancher-desktop` and `wsl2` packages).

---

## Questions to Answer

**All questions answered.**

- The `devcontainer.json` config is the same on Windows, Mac, and Linux -- no platform-specific changes needed.
- The Windows version will be a single `install.ps1` (standard Intune pattern), not multiple scripts like the Mac version.
- Both Intune and Jamf are fully automatic -- scripts run non-interactively as SYSTEM (Intune) or root (Jamf).
- Starting Rancher Desktop and getting a working `docker` command is already solved in `scripts-win/rancher-desktop/install.ps1` -- it launches Rancher Desktop, polls `rdctl api /v1/backend_state` until STARTED, then runs Docker commands. The devcontainer-toolbox `install.ps1` reuses the same pattern but pulls the devcontainer image instead of running hello-world.
- Global command installation: install `devcontainer-init.ps1` to `C:\Program Files\devcontainer-toolbox\`, add a `.cmd` wrapper so users can type just `devcontainer-init` from any terminal (cmd, PowerShell, Windows Terminal), and add the folder to the system PATH. This is the Windows equivalent of installing to `/usr/local/bin` on Mac.

---

## Current State

### What exists on Mac

```text
scripts-mac/devcontainer-toolbox/
  devcontainer-pull.sh            -- pull Docker image
  devcontainer-init-install.sh    -- install devcontainer-init to /usr/local/bin
  devcontainer-init.sh            -- init a project folder with .devcontainer/
  tests/                          -- 7 test scripts + helpers
```

**Key behaviors:**
- `devcontainer-pull.sh` -- checks Rancher Desktop is running (docker daemon available), pulls `ghcr.io/terchris/devcontainer-toolbox:latest`
- `devcontainer-init-install.sh` -- copies `devcontainer-init.sh` to `/usr/local/bin/devcontainer-init`, needs root
- `devcontainer-init.sh` -- creates `.devcontainer/` in target dir, downloads `devcontainer.json` from GitHub, backs up existing config, supports `-y` for non-interactive mode

### What exists on Windows

| Package | Status |
| ------- | ------ |
| `scripts-win/rancher-desktop/` | Complete -- installs Rancher Desktop via Intune |
| `scripts-win/wsl2/` | Complete -- installs WSL2 via Intune |
| `scripts-win/devcontainer-toolbox/` | Does not exist yet |

### Intune deployment model

Intune packages have a standard structure:
- `install.ps1` -- main installer (runs as SYSTEM)
- `detect.ps1` -- detection script (checks if installed)
- `uninstall.ps1` -- uninstaller (optional)
- `build.ps1` -- creates `.intunewin` package

Scripts run as **SYSTEM** (not user), non-interactively, with no terminal. Exit code 0 = success, non-zero = failure.

---

## Approach: Single install.ps1 + bundled init tool

Standard Intune package with `install.ps1` as entry point. The `devcontainer-init.ps1` is bundled in the package and installed to a global location (e.g. `C:\Program Files\devcontainer-toolbox\`) during install.

**What `install.ps1` does:**

1. Verifies Rancher Desktop is installed (check install paths)
2. Launches Rancher Desktop (same approach as `rancher-desktop/install.ps1`)
3. Polls `rdctl api /v1/backend_state` until STARTED (same wait pattern)
4. Runs `docker pull ghcr.io/terchris/devcontainer-toolbox:latest`
5. Installs `devcontainer-init.ps1` to `C:\Program Files\devcontainer-toolbox\`
6. Creates `devcontainer-init.cmd` wrapper (so users type `devcontainer-init` without `.ps1`)
7. Adds `C:\Program Files\devcontainer-toolbox\` to the system PATH
8. Shuts down Rancher Desktop (same `rdctl shutdown` pattern)

The `.cmd` wrapper is one line: `@pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0devcontainer-init.ps1" %*`

This gives the same experience as Mac (`/usr/local/bin/devcontainer-init`) -- users type `devcontainer-init` from any terminal.

**What `detect.ps1` checks:**

- Container image is present
- `devcontainer-init.ps1` is installed in the expected location

**What `uninstall.ps1` does:**

- Removes the init tool from the global location
- Optionally removes the container image

**Script standards:**

- All `.ps1` scripts must follow [rules/script-standard.md](../../rules/script-standard.md) (metadata, help, logging, error codes)
- Validate with `bash docs/ai-developer/tools/validate-powershell.sh devcontainer-toolbox` before committing
- Build with `build.ps1`, verify with `run-tests-build.ps1`

**Documentation (same pattern as rancher-desktop):**

- `README.md` -- package overview, files, prerequisites, related links
- `INTUNE.md` -- exact Intune portal settings (app info, program commands, detection rules, dependencies, assignments)
- `TESTING.md` -- USB stick testing instructions (preparation, how to run each test, troubleshooting)

**What users do after deployment:**

- Run `devcontainer-init` in any project folder to set up `.devcontainer/`

---

## Key Differences from Mac

| Aspect | Mac (Jamf) | Windows (Intune) |
| ------ | ---------- | ---------------- |
| Execution context | root via bash | SYSTEM via PowerShell 5.1 |
| Global command location | `/usr/local/bin` | `C:\Program Files\devcontainer-toolbox\` |
| PATH management | `/usr/local/bin` is already in PATH | Add to system PATH via `[Environment]::SetEnvironmentVariable` |
| Command name | `devcontainer-init` (bash script) | `devcontainer-init` (`.cmd` shim calls native `.ps1`) |
| Container runtime | Rancher Desktop (already deployed) | Rancher Desktop (already deployed via Intune) |
| Config download | `curl`/`wget` from GitHub | `Invoke-WebRequest` from GitHub |
| Package format | Plain scripts via Jamf | `.intunewin` via Intune |
| Interactive mode | `-y` flag for non-interactive | Intune is always non-interactive |

---

## Prerequisites

The Windows devcontainer-toolbox needs a working `docker` command. That means:

1. **WSL2** -- already deployed via `scripts-win/wsl2/`
2. **Rancher Desktop** -- already deployed via `scripts-win/rancher-desktop/`
3. **Rancher Desktop must be running** -- the `docker` CLI only works when Rancher Desktop is started
4. **VS Code** -- assumed installed (not yet managed via Intune)

Intune can enforce deployment order via dependencies between packages (WSL2 -> Rancher Desktop -> devcontainer-toolbox).

The launch/wait/shutdown pattern is already proven in `scripts-win/rancher-desktop/install.ps1` -- the devcontainer-toolbox reuses the same approach.

---

## Testing

Follow the same pattern as `scripts-win/rancher-desktop/` -- USB stick testing on a real Windows PC, plus build tests in the devcontainer.

### USB tests (on a Windows PC)

Copy `scripts-win/devcontainer-toolbox/` to a USB stick. On the test PC (with Rancher Desktop already installed):

**Part 1: Install tests** (`run-tests-install.ps1`)

1. Verify Rancher Desktop is installed
2. Run `install.ps1` -- starts Rancher Desktop, waits for backend, pulls the container image, installs `devcontainer-init` to `C:\Program Files\devcontainer-toolbox\`, adds to PATH
3. Verify `devcontainer-init` command is available from a new terminal
4. Run `detect.ps1` -- verify it reports installed

**Part 2: Init test** (`run-tests-init.ps1`)

1. Run `devcontainer-init` on a temp folder
2. Verify `.devcontainer/devcontainer.json` was created
3. Verify the file is not empty and contains expected content (no JSON validation -- file uses JSONC comments that PowerShell 5.1 cannot parse)
4. Clean up temp folder

**Part 3: Uninstall tests** (`run-tests-uninstall.ps1`)

1. Run `uninstall.ps1` -- removes `devcontainer-init` from `C:\Program Files\devcontainer-toolbox\`, removes from PATH
2. Verify the command is no longer available
3. Optionally verify the container image was removed

Logs go to `tests/logs/` -- bring the USB back for review.

### Build tests (in devcontainer)

Same as rancher-desktop: `run-tests-build.ps1` builds the `.intunewin`, extracts it, verifies contents.

### Prerequisites for USB testing

- Rancher Desktop must already be installed and working (deployed via the rancher-desktop Intune package)
- Internet access (to pull the container image and download `devcontainer.json` from GitHub)
- Admin access on the PC

---

## Summary

Single `install.ps1` Intune package that pulls the container image and installs the `devcontainer-init` tool globally. Follows the same pattern as the existing `rancher-desktop` and `wsl2` packages. The `devcontainer.json` config is cross-platform -- no changes needed. USB stick testing follows the same approach as rancher-desktop.

---

## Expected Files

```text
scripts-win/devcontainer-toolbox/
  install.ps1                     -- pull image, install devcontainer-init, add to PATH
  uninstall.ps1                   -- remove devcontainer-init, remove from PATH
  detect.ps1                      -- Intune detection script
  build.ps1                       -- creates .intunewin package
  devcontainer-init.ps1           -- user-facing tool (installed to Program Files)
  devcontainer-init.cmd           -- .cmd shim so users type devcontainer-init
  README.md                       -- package overview
  INTUNE.md                       -- Intune portal configuration
  TESTING.md                      -- USB testing instructions
  .gitignore                      -- ignore .intunewin build artifacts
  tests/
    test-helpers.ps1              -- shared test functions
    run-tests-install.ps1         -- USB: install + detect tests
    run-tests-init.ps1            -- USB: devcontainer-init test
    run-tests-uninstall.ps1       -- USB: uninstall tests
    run-tests-build.ps1           -- devcontainer: .intunewin build test
    logs/                         -- test output logs
```

---

## Next Steps

- [x] Create PLAN for implementing `scripts-win/devcontainer-toolbox/` -- done, see `plans/completed/PLAN-windows-devcontainer-toolbox.md`
- [ ] Determine if VS Code should be added as an Intune package (separate investigation)
