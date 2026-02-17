# Investigate: CI/CD pipeline for .intunewin builds

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
>
> - [WORKFLOW.md](../../WORKFLOW.md) -- The implementation process
> - [PLANS.md](../../PLANS.md) -- Plan structure and best practices
>
> **UPDATE THIS PLAN AS YOU WORK:** Mark tasks `[x]` when done, add `-- DONE` to phase headers, update status.

## Status: Completed

**Goal**: Determine how to set up an Azure Pipelines CI/CD pipeline that builds `.intunewin` packages and stores them as downloadable artifacts.

**Last Updated**: 2026-02-12

---

## Context

We have two Intune packages (`scripts-win/rancher-desktop/`, `scripts-win/wsl2/`) with more planned. Each has a `build.ps1` that creates `.intunewin` packages using `SvRooij.ContentPrep.Cmdlet` on Linux/pwsh. Currently builds are manual (run `build.ps1` in the devcontainer). The repo is hosted on Azure DevOps (`dev.azure.com/YOUR-ORG/Azure/_git/client-provisioning`). No CI/CD pipeline exists yet.

---

## Current State

| Item | Status |
|------|--------|
| Azure Pipelines config | None -- no `azure-pipelines.yml` exists |
| Build scripts | `scripts-win/rancher-desktop/build.ps1`, `scripts-win/wsl2/build.ps1` |
| Build test | `scripts-win/rancher-desktop/tests/run-tests-build.ps1` (build, extract, verify) |
| PowerShell install | `.devcontainer.extend/project-installs.sh` -- pwsh 7.5.4 + PSScriptAnalyzer + SvRooij.ContentPrep.Cmdlet |
| Validation tools | `docs/ai-developer/tools/validate-powershell.sh`, `validate-bash.sh` |

---

## Feasibility

**Yes, this is straightforward.** Key findings:

- Azure Pipelines `ubuntu-latest` agents have PowerShell 7 pre-installed
- `PSScriptAnalyzer` and `SvRooij.ContentPrep.Cmdlet` install in one command each and work on Linux
- Pipeline artifacts are free, downloadable from the Azure DevOps portal, retained for 30 days (configurable up to 730 days)
- Path-based triggers can limit builds to only run when `scripts-win/` changes

---

## Recommended Approach

### Pipeline structure: Template loop

Use a reusable YAML template with a parameter list of packages. Each package builds as a separate parallel job. Adding a new package = adding one entry to the list.

**Why this over alternatives:**

| Approach | Pros | Cons |
|----------|------|------|
| Simple steps (all in one job) | Easy to write | Sequential, no parallelism |
| Matrix strategy | Parallel, simple | Hard to add metadata per package |
| **Template loop (recommended)** | **Parallel, clean, easy to extend** | **Slightly more YAML files** |
| Dynamic matrix (git diff detection) | Only builds what changed | Complex, fragile, overkill for 2-5 packages |

We don't need change detection yet. Building all packages takes seconds (the `.intunewin` packaging is fast). If we reach 10+ packages, we can add it later.

---

## Open Questions (Resolved)

### Q1: Should the pipeline also run validation?

**Decision**: Yes. Added as a separate Validate stage that runs before builds.

### Q2: Should the pipeline run the build test (extract + verify)?

**Decision**: Yes, for packages that have the test. The template checks if `tests/run-tests-build.ps1` exists and runs it if present.

### Q3: Artifact retention

**Decision**: Keep the 30-day default. Packages are trivially rebuildable.

### Q4: WSL2 build.ps1 output naming

**Decision**: Separate follow-up task. Not part of the pipeline plan.

---

## Next Steps

- [x] Create PLAN for implementing the pipeline (PLAN-intunewin-cicd-pipeline.md)
- [ ] Rename WSL2 output file for consistency (small follow-up)
