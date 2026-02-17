# Fix: Test verification false failures (grep -q + pipefail)

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `— DONE` to phase headers, update status.

## Status: Completed

**Goal**: Fix false FAIL results in tests 3 and 4 caused by `grep -q` + `pipefail` SIGPIPE race condition.

**Completed**: 2026-02-08

---

## Problem

Tests 3 and 4 in `run-all-tests.sh` report FAIL, but the actual scripts worked correctly. The profile dumps in the log show all keys present with correct values. The failures are false negatives caused by a bug in the `verify_plist_key_exists` function in `test-helpers.sh`.

### Log evidence

**Test 3** (k8s merge) — profile AFTER is correct:
```
"containerEngine" => { "name" => "moby" }
"kubernetes" => { "enabled" => 1 }
"virtualMachine" => { "memoryInGB" => 4, "numberCPUs" => 4 }
```

But verification reports:
- `enabled => 1` — OK (uses `verify_plist_value`)
- `Key 'name' missing` — FALSE NEGATIVE (uses `verify_plist_key_exists`)
- `Key 'memoryInGB' missing` — FALSE NEGATIVE (uses `verify_plist_key_exists`)
- `Key 'numberCPUs' present` — OK (uses `verify_plist_key_exists`)

**Test 4** (config update) — same pattern, same false negatives for `name` and `enabled`.

## Root cause

`grep -q` + `set -o pipefail` = SIGPIPE race condition.

In `test-helpers.sh`, the `verify_plist_key_exists` function (line 171):

```bash
if plutil -p "$file" 2>/dev/null | grep -q "\"${key}\""; then
```

`grep -q` exits **immediately** after finding the first match, without reading the rest of the pipe. If `plutil -p` is still writing output when `grep -q` exits, `plutil` gets SIGPIPE (exit code 141). With `set -o pipefail` (enabled by both `run-all-tests.sh` and the individual test scripts), the pipe's exit status becomes 141 instead of 0 — even though grep found the match.

### Why `numberCPUs` passes but others fail

The key's position in the `plutil -p` output determines the race:

| Key | Position in output | grep -q behavior | Result |
|-----|-------------------|-------------------|--------|
| `name` | Line 3 (early) | Exits early, plutil SIGPIPE | **FAIL** |
| `enabled` | Line 5 (mid) | Exits early, plutil SIGPIPE | **FAIL** |
| `memoryInGB` | Line 9 (late) | Exits early, plutil might SIGPIPE | **FAIL** |
| `numberCPUs` | Line 10 (last data) | plutil already done, no SIGPIPE | **PASS** |

### Why `verify_plist_value` works

It uses `grep` without `-q`, capturing output into a variable:

```bash
actual=$(plutil -p "$file" 2>/dev/null | grep "\"${key}\"" | head -1 | sed ...)
```

Without `-q`, grep reads **all** input before exiting. And the function checks the captured text (`$actual`), not the pipe exit status. So pipefail doesn't affect the result.

---

## Phase 1: Fix — DONE

### Tasks

- [x] 1.1 In `test-helpers.sh` line 171, replace `grep -q` with `grep ... >/dev/null` in `verify_plist_key_exists`
- [x] 1.2 Bump `test-helpers.sh` version from `0.2.0` to `0.2.1`

### Validation

```bash
bash docs/ai-developer/tools/validate-bash.sh rancher-desktop/tests
```

All 14 scripts pass.

---

## Acceptance Criteria

- [x] `verify_plist_key_exists` no longer uses `grep -q`
- [x] Validation passes
- [x] Manual: re-run USB tests on the Mac — 12/12 PASS

---

## Files to Modify

- `scripts-mac/rancher-desktop/tests/test-helpers.sh` — fix `grep -q` → `grep ... >/dev/null` in `verify_plist_key_exists`, bump version
