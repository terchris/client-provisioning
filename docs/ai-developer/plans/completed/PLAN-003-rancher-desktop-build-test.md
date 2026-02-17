# Plan: Rancher Desktop .intunewin build and verify test

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) -- The implementation process
> - [PLANS.md](../../PLANS.md) -- Plan structure and best practices
> - [rules/script-standard.md](../../rules/script-standard.md) -- Shared script standard
> - [rules/powershell.md](../../rules/powershell.md) -- PowerShell-specific rules
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `-- DONE` to phase headers, update status.

## Status: Completed

**Goal**: Create a test script that builds the `.intunewin` package and verifies the contents by extracting and checking all expected files are present and match the originals.

**Last Updated**: 2026-02-12
**Completed**: 2026-02-12

---

## Problem

We have a `build.ps1` that creates the `.intunewin` package using `SvRooij.ContentPrep.Cmdlet`, but no way to verify the package is correct from the devcontainer. The module also provides `Unlock-IntuneWinPackage` which can extract a `.intunewin` file. We need a test script that does the full round-trip: build, extract, verify contents.

---

## Phase 1: Create run-tests-build.ps1 -- DONE

A test script in `scripts-win/rancher-desktop/tests/` that runs in the devcontainer (Linux/pwsh). It follows the standard script template and uses `test-helpers.ps1` for Test-Pass/Test-Fail/Test-Summary.

### Tasks

- [x] 1.1 Create `tests/run-tests-build.ps1` from the PowerShell template
  - Metadata: `$SCRIPT_ID = "rancher-desktop-build-tests"`, `$SCRIPT_CATEGORY = "TEST"`
  - Dot-source `test-helpers.ps1` for test tracking functions
  - Create logs dir and start transcript to `logs/test-results-build.log`
- [x] 1.2 Test 1: Build -- run `build.ps1` and check exit code
  - Run `build.ps1` as a child process via `pwsh -File`
  - Pipe output through `ForEach-Object { Write-Host $_ }` for transcript capture
  - Check exit code is 0
  - Check `install.intunewin` exists after build
  - Check file size is greater than 0
- [x] 1.3 Test 2: Extract -- use `Unlock-IntuneWinPackage` to extract the `.intunewin`
  - Create a temp directory for extraction
  - Run `Unlock-IntuneWinPackage -SourceFile <path>/install.intunewin -DestinationPath <temp>`
  - Check exit succeeds
- [x] 1.4 Test 3: Verify contents -- check all expected files are present in the extracted package
  - Expected files: `install.ps1`, `uninstall.ps1`, `detect.ps1`, `build.ps1`, `README.md`, `INTUNE.md`, `TESTING.md`, `.gitignore`
  - For each expected file: check it exists in the extracted output
  - For the 4 `.ps1` scripts (`install.ps1`, `uninstall.ps1`, `detect.ps1`, `build.ps1`): compare file size against originals to confirm they match
- [x] 1.5 Cleanup
  - Remove the extracted temp directory
  - Remove the built `install.intunewin` (it's a build artifact, gitignored)
  - Always clean up, even on failure (use try/finally)
- [x] 1.6 Summary and exit
  - Call `Test-Summary`
  - Log pass/fail result
  - Stop transcript
  - Exit 0 on all pass, exit 1 on any failure

### Validation

```bash
bash docs/ai-developer/tools/validate-powershell.sh rancher-desktop/tests
```

Then run the test:

```bash
pwsh scripts-win/rancher-desktop/tests/run-tests-build.ps1
```

All checks pass, log written to `tests/logs/test-results-build.log`.

---

## Phase 2: Update documentation -- DONE

### Tasks

- [x] 2.1 Update `TESTING.md` -- add a "Build tests (devcontainer)" section describing the new test and how to run it
- [x] 2.2 Update `README.md` -- add `run-tests-build.ps1` to the Tests folder table

### Validation

User confirms documentation is accurate.

---

## Acceptance Criteria

- [x] `run-tests-build.ps1` follows the standard script template (metadata, help, logging)
- [x] `run-tests-build.ps1` builds `.intunewin`, extracts, verifies contents, cleans up
- [x] All expected files are present in the extracted package
- [x] `.ps1` file sizes match originals (confirms no corruption)
- [x] Test passes when run with `pwsh` in the devcontainer
- [x] Log output written to `tests/logs/test-results-build.log`
- [x] All `.ps1` files pass `validate-powershell.sh`

---

## Files to Modify

| File | Action |
|------|--------|
| `scripts-win/rancher-desktop/tests/run-tests-build.ps1` | New -- build and verify test script |
| `scripts-win/rancher-desktop/TESTING.md` | Add build test section |
| `scripts-win/rancher-desktop/README.md` | Add to tests folder table |
| `docs/ai-developer/plans/active/PLAN-003-rancher-desktop-build-test.md` | New plan file |

---

## Technical Notes

### Commands

- **Build**: `New-IntuneWinPackage -SourcePath <dir> -SetupFile install.ps1 -DestinationPath <temp>`
- **Extract**: `Unlock-IntuneWinPackage -SourceFile <file>.intunewin -DestinationPath <temp>`
- Both are from `SvRooij.ContentPrep.Cmdlet` (installed in devcontainer)

### What goes in the package

`New-IntuneWinPackage` packages ALL files in `-SourcePath`. That means the `.intunewin` will contain everything in the `rancher-desktop/` folder including `tests/`, docs, and `.gitignore`. This is fine -- Intune only runs the install command, the extra files are harmless.

### Transcript capture

The test runs in the devcontainer with `pwsh` (PowerShell 7), not Windows PowerShell 5.1. `Start-Transcript` works the same way in pwsh. Child process output still needs piping through `ForEach-Object { Write-Host $_ }`.
