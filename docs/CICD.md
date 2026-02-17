# CI/CD Pipeline

How the automated build pipeline works.

---

## What it does

When you push changes to `main` that touch files under `scripts-win/`, the pipeline automatically:

1. **Validates** all PowerShell scripts (syntax, help flag, metadata, PSScriptAnalyzer lint)
2. **Builds** each `.intunewin` package in parallel
3. **Tests** the build output (for packages that have a build test)
4. **Publishes** the `.intunewin` files as downloadable artifacts

---

## When it triggers

The pipeline triggers on pushes to the `main` branch when files under `scripts-win/` change. It ignores changes to test files and markdown files.

Specifically:

- **Included**: `scripts-win/*`
- **Excluded**: `scripts-win/**/tests/*`, `scripts-win/**/*.md`

Changes outside `scripts-win/` (e.g. `scripts-mac/`, `docs/`) do not trigger the pipeline.

---

## Pipeline stages

```
Push to main (scripts-win/ changed)
  |
  v
Validate (run validate-powershell.sh on all scripts)
  |
  v (only if validation passes)
  |
  +---> Build rancher-desktop (parallel)
  +---> Build wsl2            (parallel)
  +---> Build ...             (parallel, future packages)
  |
  v
Artifacts available for download
```

### Validate stage

Runs `docs/ai-developer/tools/validate-powershell.sh` against all scripts in `scripts-win/`. This checks syntax, help output, metadata fields, and PSScriptAnalyzer lint. If validation fails, no packages are built.

### Build stage

Each package runs as a separate parallel job using the `.azure-pipelines/build-intunewin.yml` template. For each package the job:

1. Installs `PSScriptAnalyzer` and `SvRooij.ContentPrep.Cmdlet` (mirrors the devcontainer setup)
2. Runs `build.ps1` to create the `.intunewin` file
3. Runs `tests/run-tests-build.ps1` if the package has one (currently only `rancher-desktop`)
4. Publishes the `.intunewin` file as a named pipeline artifact

---

## Where to find the artifacts

1. Go to **Azure DevOps** > **Pipelines**
2. Click the pipeline run you want
3. Click the **Artifacts** button (or look under the "published" section)
4. Each package has its own named artifact (e.g. `rancher-desktop`, `wsl2`)
5. Click to download the `.intunewin` file

Artifacts are retained for **30 days** by default. Since packages are trivially rebuildable from source, this is sufficient.

---

## Adding a new package

To add a new Intune package to the pipeline, add one entry to the `packages` parameter in `azure-pipelines.yml`:

```yaml
parameters:
  - name: packages
    type: object
    default:
      - name: rancher-desktop
        dir: scripts-win/rancher-desktop
      - name: wsl2
        dir: scripts-win/wsl2
      - name: my-new-package          # <-- add this
        dir: scripts-win/my-new-package
```

No other changes needed. The template handles module installation, building, testing, and publishing automatically.

If the new package has a `tests/run-tests-build.ps1`, the pipeline will find and run it. If not, it skips the test step.

---

## Pipeline files

| File | Purpose |
| ---- | ------- |
| `azure-pipelines.yml` | Main pipeline definition -- triggers, packages list, stages |
| `.azure-pipelines/build-intunewin.yml` | Reusable template for building one package |

---

## Build agent environment

The pipeline runs on Azure Pipelines `ubuntu-latest` agents. These have PowerShell 7 pre-installed but do not include the modules we need. Each job installs:

- **PSScriptAnalyzer** -- used by the validation script for lint checks
- **SvRooij.ContentPrep.Cmdlet** -- used by `build.ps1` to create `.intunewin` packages

This mirrors what `.devcontainer.extend/project-installs.sh` installs in the devcontainer.
