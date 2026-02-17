# Plan: Devcontainer Toolbox test suite

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) — The implementation process
> - [PLANS.md](../../PLANS.md) — Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Goal**: Create a test suite for `scripts-mac/devcontainer-toolbox/` mirroring the rancher-desktop test pattern.

**Last Updated**: 2026-02-10

**Based on**: [INVESTIGATE-devcontainer-toolbox-testing.md](INVESTIGATE-devcontainer-toolbox-testing.md)

---

## Problem

The `scripts-mac/devcontainer-toolbox/` package has 3 deployment scripts but no tests. The `scripts-mac/rancher-desktop/` package has a proven test pattern (master runner, shared helpers, individual test scripts, USB workflow). We need to apply the same pattern to devcontainer-toolbox.

Key difference from rancher-desktop: all devcontainer-toolbox tests are **fully automated** — no GUI checks needed.

---

## Phase 1: Create test-helpers.sh — DONE

### Tasks

- [x] 1.1 Create `scripts-mac/devcontainer-toolbox/tests/test-helpers.sh` following the standard script template (metadata, logging, help)
- [x] 1.2 Add configuration variables: `SCRIPT_DIR`, `TESTS_DIR`, `TEST_WORK_DIR` (temp folder for test projects)
- [x] 1.3 Add reusable helpers:
  - `header()` — test section header (same as rancher-desktop)
  - `verify_file_exists()` — check a file exists at a given path
  - `verify_file_executable()` — check a file is executable
  - `verify_dir_exists()` — check a directory exists
  - `verify_no_dir()` — check a directory does not exist
  - `verify_no_file()` — check a file does not exist
  - `verify_command_available()` — check a command is in PATH
  - `verify_json_valid()` — check a file is valid JSON (using `python3 -m json.tool` — available on macOS by default)
  - `verify_docker_running()` — check Docker daemon responds
  - `verify_image_exists()` — check a Docker image exists locally
  - `verify_exit_code()` — check a command's exit code matches expected
  - `create_test_dir()` — create a temp test directory
  - `cleanup_test_dir()` — remove temp test directory
- [x] 1.4 Run `bash docs/ai-developer/tools/validate-bash.sh devcontainer-toolbox/tests` — all pass

### Validation

All scripts pass validation (syntax, help, metadata, shellcheck).

---

## Phase 2: Create individual test scripts — DONE

### Tasks

- [x] 2.1 Create `test-0-prerequisites.sh` — verify Rancher Desktop is installed (`/Applications/Rancher Desktop.app` exists), Docker is in PATH, Docker daemon responds to `docker ps`. If any check fails, print a message explaining Rancher Desktop must be installed first.
- [x] 2.2 Create `test-1-pull.sh` — run `devcontainer-pull.sh`, verify exit code 0, verify image exists locally with `docker images`
- [x] 2.3 Create `test-2-install.sh` — run `devcontainer-init-install.sh` with sudo, verify `/usr/local/bin/devcontainer-init` exists and is executable, verify `devcontainer-init -h` exits 0
- [x] 2.4 Create `test-3-init-fresh.sh` — create a temp folder, run `devcontainer-init -y <folder>`, verify `.devcontainer/devcontainer.json` exists and is valid JSON
- [x] 2.5 Create `test-4-init-backup.sh` — create a temp folder with an existing `.devcontainer/` containing a marker file, run `devcontainer-init -y <folder>`, verify `.devcontainer.backup/` exists with the marker file, verify new `.devcontainer/devcontainer.json` is valid JSON
- [x] 2.6 Create `test-5-init-errors.sh` — test error paths:
  - Run `devcontainer-init -y` on a folder that already has `.devcontainer.backup/` — expect ERR009, exit code 1
  - Run `devcontainer-init -y /nonexistent/path` — expect ERR002, exit code 1
  - Run `devcontainer-init -y /tmp/test-file` (a file, not a dir) — expect ERR003, exit code 1
- [x] 2.7 Create `test-6-cleanup.sh` — remove `/usr/local/bin/devcontainer-init`, remove temp test directories, verify cleanup is complete
- [x] 2.8 Run `bash docs/ai-developer/tools/validate-bash.sh devcontainer-toolbox/tests` — all 9 scripts pass

### Validation

All scripts pass validation (syntax, help, metadata, shellcheck).

---

## Phase 3: Create master runner — DONE

### Tasks

- [x] 3.1 Create `scripts-mac/devcontainer-toolbox/tests/run-all-tests.sh` following the standard script template
- [x] 3.2 Add warning banner explaining what the tests do (pulls Docker image, writes to `/usr/local/bin`, creates temp folders)
- [x] 3.3 Add sudo elevation (same pattern as rancher-desktop: show warning first, then `exec sudo bash "$0"`)
- [x] 3.4 Add setup: create `logs/` directory, redirect output to `logs/test.log` via `tee`, log session metadata (hostname, macOS version, arch)
- [x] 3.5 Add test orchestration: run tests 0-6 in order, track pass/fail/skip counts, allow skip/quit between tests
- [x] 3.6 Add summary: print pass/fail/skip totals at the end
- [x] 3.7 Add `.gitignore` in `scripts-mac/devcontainer-toolbox/` to ignore `logs/`
- [x] 3.8 Run `bash docs/ai-developer/tools/validate-bash.sh devcontainer-toolbox/tests` — all pass

### Validation

All scripts pass validation.

---

## Phase 4: Create TESTING.md — DONE

### Tasks

- [x] 4.1 Create `scripts-mac/devcontainer-toolbox/TESTING.md` documenting:
  - Prerequisites (Rancher Desktop installed and running)
  - How to run tests (USB stick workflow, same as rancher-desktop)
  - What each test does and what it verifies
  - How to run individual tests
  - Troubleshooting section
- [x] 4.2 Verify TESTING.md is consistent with rancher-desktop's TESTING.md structure

### Validation

TESTING.md follows the same structure as rancher-desktop TESTING.md.

---

## Acceptance Criteria

- [x] All test scripts pass `validate-bash.sh`
- [x] Test suite mirrors the rancher-desktop pattern (master runner, helpers, individual tests, TESTING.md)
- [x] Test 0 verifies Rancher Desktop is installed before proceeding
- [x] All tests are fully automated (no manual prompts)
- [ ] Logging to `logs/test.log` works correctly — needs Mac testing
- [ ] USB stick workflow documented in TESTING.md

---

## Files Created

- `scripts-mac/devcontainer-toolbox/tests/test-helpers.sh`
- `scripts-mac/devcontainer-toolbox/tests/test-0-prerequisites.sh`
- `scripts-mac/devcontainer-toolbox/tests/test-1-pull.sh`
- `scripts-mac/devcontainer-toolbox/tests/test-2-install.sh`
- `scripts-mac/devcontainer-toolbox/tests/test-3-init-fresh.sh`
- `scripts-mac/devcontainer-toolbox/tests/test-4-init-backup.sh`
- `scripts-mac/devcontainer-toolbox/tests/test-5-init-errors.sh`
- `scripts-mac/devcontainer-toolbox/tests/test-6-cleanup.sh`
- `scripts-mac/devcontainer-toolbox/tests/run-all-tests.sh`
- `scripts-mac/devcontainer-toolbox/.gitignore`
- `scripts-mac/devcontainer-toolbox/TESTING.md`
