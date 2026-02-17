# Investigate: Testing devcontainer-toolbox scripts

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Completed**: 2026-02-10

**Goal**: Determine how to test `scripts-mac/devcontainer-toolbox/` scripts on a Mac, following the same pattern as `scripts-mac/rancher-desktop/tests/`.

**Last Updated**: 2026-02-10

---

## Context

The `scripts-mac/rancher-desktop/` package has a mature test suite:

- 10 functional tests with a master runner (`run-all-tests.sh`)
- Shared helper library (`test-helpers.sh`)
- Tests run on a real Mac via USB stick, emulating Jamf (scripts run as root with `sudo`)
- Auto-verification where possible, manual GUI checks only when needed
- Full logging to `logs/test.log`
- `TESTING.md` documents the full process

The `scripts-mac/devcontainer-toolbox/` package has 3 scripts but **no tests**. We need to investigate what a test suite would look like.

**Important dependency:** The devcontainer-toolbox requires Rancher Desktop to be installed — it provides Docker. The test suite must verify Rancher Desktop is installed and running before testing the devcontainer scripts. This means the devcontainer-toolbox tests should run **after** Rancher Desktop is installed (either via the rancher-desktop test suite or manually).

---

## Questions to Answer

### What is testable?

1. `devcontainer-pull.sh` — pulls a Docker image. What do we verify? Image exists locally after pull? What if the image is already cached?
2. `devcontainer-init-install.sh` — copies script to `/usr/local/bin`. What do we verify? File exists, is executable, is in PATH?
3. `devcontainer-init.sh` — creates `.devcontainer/` folder and downloads `devcontainer.json`. What do we verify? Folder created, file downloaded, backup works?

### What are the prerequisites?

1. The devcontainer-toolbox depends on Rancher Desktop for Docker. Should the test runner verify Rancher Desktop is installed and Docker is running before starting?
2. Rancher Desktop tests require a clean machine (no Rancher Desktop installed). Do devcontainer-toolbox tests have a similar "clean state" requirement, or do they assume Rancher Desktop is already set up?
3. `devcontainer-init-install.sh` writes to `/usr/local/bin` — requires sudo (same as Jamf). The other two scripts don't require sudo. How do we handle mixed privilege requirements?

### What patterns carry over from rancher-desktop?

1. The master runner pattern (`run-all-tests.sh`) — does it make sense for 3 scripts?
2. The test-helpers pattern — what helpers are reusable vs rancher-desktop-specific?
3. The USB stick workflow — same approach? Copy folder to USB, run on a Mac?
4. Logging to `logs/test.log` — same pattern?

### Error path testing

1. What happens when Rancher Desktop is not installed?
2. What happens when Docker is not running? (Rancher Desktop installed but not started)
3. What happens when `/usr/local/bin` is not writable? (ERR003 in init-install)
4. What happens when `.devcontainer.backup/` already exists? (ERR009 in init)
5. Can we test error paths without breaking the test machine?

### Network dependencies

1. `devcontainer-pull.sh` downloads a Docker image (~1-2 GB). Is this too slow for repeated testing?
2. `devcontainer-init.sh` downloads `devcontainer.json` from GitHub. What if GitHub is down? Should we test with a local override?

---

## Current State

| Script | Side effects | Requires sudo | Requires Rancher Desktop | Requires network |
| ------ | ------------ | ------------- | ------------------------ | ---------------- |
| `devcontainer-pull.sh` | Pulls Docker image to local cache | No | Yes (installed + running) | Yes (Docker Hub) |
| `devcontainer-init-install.sh` | Copies file to `/usr/local/bin` | Yes | No | No |
| `devcontainer-init.sh` | Creates `.devcontainer/` folder, downloads file | No | Yes (installed + running) | Yes (GitHub) |

---

## Script-by-script analysis

### devcontainer-pull.sh

**What it does:**

1. Checks Docker is installed (`command -v docker`)
2. Checks Docker daemon is running (`docker ps`)
3. Runs `docker pull terchris/devcontainer-toolbox:latest`

**Testable scenarios:**

- Happy path: Rancher Desktop running, image pulls successfully
- Image already cached: pull still succeeds (Docker handles this)
- Verify image exists locally after pull (`docker images | grep devcontainer-toolbox`)
- Custom image name: `devcontainer-pull.sh my-image:latest`

**Error scenarios:**

- Rancher Desktop not installed — hard to test without uninstalling
- Rancher Desktop not started — Docker daemon not running

### devcontainer-init-install.sh

**What it does:**

1. Finds `devcontainer-init.sh` (auto-detects location or takes argument)
2. Copies to `/usr/local/bin/devcontainer-init`
3. Makes executable (`chmod +x`)
4. Verifies it's in PATH (`command -v devcontainer-init`)

**Testable scenarios:**

- Happy path: install from same directory
- Happy path: install from `scripts-mac/devcontainer-toolbox/` path
- Verify file exists at `/usr/local/bin/devcontainer-init`
- Verify file is executable
- Verify `devcontainer-init -h` works after install
- Reinstall over existing — should overwrite cleanly

**Error scenarios:**

- Source script not found (run from wrong directory without argument)
- `/usr/local/bin` not writable (run without sudo)

### devcontainer-init.sh

**What it does:**

1. Checks Docker installed and running
2. If `.devcontainer/` exists, backs up to `.devcontainer.backup/`
3. Creates `.devcontainer/` and downloads `devcontainer.json` from GitHub
4. Prints next steps

**Testable scenarios:**

- Happy path: empty folder, creates `.devcontainer/devcontainer.json`
- Verify `.devcontainer/devcontainer.json` exists and is valid JSON
- Backup: existing `.devcontainer/` gets moved to `.devcontainer.backup/`
- Non-interactive mode: `-y` flag skips prompts
- Explicit folder path: `devcontainer-init /tmp/test-project`
- Tilde expansion: `devcontainer-init ~/test-project`

**Error scenarios:**

- `.devcontainer.backup/` already exists — should refuse (ERR009)
- Target path doesn't exist — should refuse (ERR002)
- Target is not a directory — should refuse (ERR003)
- No write permission — should refuse (ERR004/ERR006)

---

## Options

### Option A: Full test suite (mirror rancher-desktop pattern)

Create `scripts-mac/devcontainer-toolbox/tests/` with:

- `run-all-tests.sh` — master runner
- `test-helpers.sh` — shared helpers
- `test-1-pull.sh` — test image pull
- `test-2-install.sh` — test init-install
- `test-3-init-fresh.sh` — test init on empty folder
- `test-4-init-backup.sh` — test init with existing .devcontainer
- `test-5-init-errors.sh` — test error paths
- `test-6-uninstall.sh` — cleanup (remove from /usr/local/bin, remove test folders)
- `TESTING.md` — documentation

**Pros:**

- Consistent with rancher-desktop pattern
- Complete coverage
- Reusable on USB stick

**Cons:**

- May be overkill for 3 simple scripts
- Docker image pull is slow (~1-2 GB)

### Option B: Lightweight test script (single file)

One `test-all.sh` script that runs through all scenarios sequentially. No separate test files, no helpers library.

**Pros:**

- Simple, fast to create
- Matches the simplicity of the scripts being tested

**Cons:**

- Can't run individual tests
- No reusable helpers for future scripts
- Inconsistent with rancher-desktop pattern

### Option C: Full test suite, but skip the slow pull test by default

Same as Option A, but the Docker pull test is optional (skipped unless `--with-pull` is passed). The pull is the only slow and network-heavy test — the others are fast.

**Pros:**

- Complete coverage available when needed
- Fast by default for iterative testing
- Consistent pattern with rancher-desktop

**Cons:**

- Slightly more complex runner logic

---

## Recommendation

**Option A: Full test suite mirroring the rancher-desktop pattern.**

Reasons:

- Consistency across packages — both `rancher-desktop/` and `devcontainer-toolbox/` use the same test structure
- The scripts may look simple, but `devcontainer-init.sh` has real complexity (argument parsing, tilde expansion, backup logic, error handling) that deserves testing
- The USB stick workflow is already established — adding another test folder is low effort
- The Docker pull test is inherently slow, but it only runs once and confirms the core function works

**Prerequisite check:** The master runner should verify Rancher Desktop is installed and Docker is running before starting any tests. If Rancher Desktop is not found, the runner should print a clear message telling the tester to install it first (either via `rancher-desktop-install.sh` or the rancher-desktop test suite).

The test suite should have **7 tests**:

| Test | Script | What it tests | Automated? |
| ---- | ------ | ------------- | ---------- |
| 0 | Prerequisite check | Rancher Desktop installed, Docker running | Yes |
| 1 | `devcontainer-pull.sh` | Pull image, verify in local cache | Yes |
| 2 | `devcontainer-init-install.sh` | Install to `/usr/local/bin`, verify in PATH | Yes |
| 3 | `devcontainer-init.sh` | Fresh init on empty folder | Yes |
| 4 | `devcontainer-init.sh` | Init with existing `.devcontainer/` (backup test) | Yes |
| 5 | `devcontainer-init.sh` | Error paths (backup exists, bad path, no permissions) | Yes |
| 6 | Cleanup | Remove from `/usr/local/bin`, remove test folders | Yes |

All tests can be **fully automated** — no GUI checks needed (unlike rancher-desktop which has Preferences UI). This makes the suite faster and simpler.

**Shared helpers** (`test-helpers.sh`) should provide:

- `header()`, logging functions — same as rancher-desktop
- `verify_file_exists()`, `verify_file_executable()` — new
- `verify_command_available()` — new
- `verify_json_valid()` — new (for checking devcontainer.json)
- `verify_docker_running()` — new (checks Rancher Desktop provides Docker)
- `create_test_dir()`, `cleanup_test_dir()` — new (for temp test folders)

---

## Next Steps

- [x] Create PLAN-devcontainer-toolbox-testing.md with the chosen approach
