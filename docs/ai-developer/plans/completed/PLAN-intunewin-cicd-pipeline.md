# Feature: CI/CD pipeline for .intunewin builds

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) -- The implementation process
> - [PLANS.md](../../PLANS.md) -- Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `-- DONE` to phase headers, update status.

## Status: Completed

**Goal**: Set up an Azure Pipelines CI/CD pipeline that builds `.intunewin` packages and publishes them as downloadable artifacts.

**Last Updated**: 2026-02-12

---

## Overview

We have two Intune packages (`scripts-win/rancher-desktop/`, `scripts-win/wsl2/`) with more planned. Each has a `build.ps1` that creates `.intunewin` packages. Currently builds are manual. This plan adds a pipeline that:

- Triggers on pushes to `main` that change `scripts-win/`
- Runs PowerShell validation on all scripts
- Builds each package in parallel
- Runs build tests where available (currently only `rancher-desktop`)
- Publishes `.intunewin` files as downloadable pipeline artifacts

Based on findings from the CI/CD investigation (see investigation file for alternatives considered).

---

## Phase 1: Create the reusable build template -- DONE

### Tasks

- [x] 1.1 Create directory `.azure-pipelines/`
- [x] 1.2 Create `.azure-pipelines/build-intunewin.yml` with these steps:
  - Install PowerShell modules (`PSScriptAnalyzer` + `SvRooij.ContentPrep.Cmdlet`)
  - Run `build.ps1` for the package
  - Run build test (`tests/run-tests-build.ps1`) if it exists, skip if not
  - Copy `.intunewin` files to staging directory
  - Publish as named pipeline artifact

### Validation

User confirms template looks correct.

---

## Phase 2: Create the main pipeline definition -- DONE

### Tasks

- [x] 2.1 Create `azure-pipelines.yml` at repo root with:
  - Trigger on `main` branch, path-filtered to `scripts-win/*`, excluding `tests/` and `*.md`
  - `ubuntu-latest` pool
  - Parameters list with current packages (`rancher-desktop`, `wsl2`)
  - A validation job that runs `validate-powershell.sh` before builds
  - A build stage that loops the template for each package

### Validation

User confirms pipeline definition looks correct.

---

## Phase 3: Save investigation file -- DONE

### Tasks

- [x] 3.1 Save `INVESTIGATE-intunewin-cicd.md` to `docs/ai-developer/plans/backlog/` (the investigation that led to this plan)
- [x] 3.2 Update the investigation's "Next Steps" to mark the PLAN task as done

### Validation

User confirms files are in place.

---

## Acceptance Criteria

- [x] `azure-pipelines.yml` exists at repo root
- [x] `.azure-pipelines/build-intunewin.yml` exists with reusable template
- [x] Pipeline triggers only on `scripts-win/` changes to `main`
- [x] Validation runs before builds
- [x] Each package builds in a parallel job
- [x] Build test runs for packages that have one (rancher-desktop)
- [x] `.intunewin` files are published as named artifacts
- [x] Adding a new package requires only adding one entry to the parameters list
- [x] Both validators still pass (`validate-bash.sh`, `validate-powershell.sh`)

---

## Implementation Notes

### Template parameters

Each package entry needs:
- `name` -- used for job name and artifact name (e.g. `rancher-desktop`)
- `dir` -- path to package directory (e.g. `scripts-win/rancher-desktop`)

### Build test detection

Not all packages have build tests yet. The template should check if `tests/run-tests-build.ps1` exists and only run it if present. This avoids requiring every package to have a build test.

### Validation job

Run `validate-powershell.sh` as a separate job that all build jobs depend on. This job must install `PSScriptAnalyzer` first (needed for lint checks). Validation failure blocks all builds, and we don't repeat validation per-package.

### Agent environment

Azure Pipelines `ubuntu-latest` has PowerShell 7 pre-installed but does **not** have the modules we need. Each job must install:

- **PSScriptAnalyzer** -- required by `validate-powershell.sh` for lint checks
- **SvRooij.ContentPrep.Cmdlet** -- required by `build.ps1` to create `.intunewin` packages

This mirrors what `.devcontainer.extend/project-installs.sh` does in the devcontainer. Both modules install in seconds.

---

## Files to Create

| File | Purpose |
|------|---------|
| `azure-pipelines.yml` | Main pipeline definition |
| `.azure-pipelines/build-intunewin.yml` | Reusable build template |
| `docs/ai-developer/plans/backlog/INVESTIGATE-intunewin-cicd.md` | Investigation that led to this plan |
