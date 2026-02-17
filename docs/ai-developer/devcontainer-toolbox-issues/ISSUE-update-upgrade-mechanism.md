# Need script-level updates without full container rebuilds

## Problem

Today, any change to a toolbox script (bug fix, new feature, new tool) requires rebuilding the entire container image and having every developer pull the new image. This is slow and disruptive:

- A one-line fix to a bash script triggers a full image rebuild
- Every developer must pull a multi-GB image update
- The container must be rebuilt locally, which takes minutes
- Developer work is interrupted while the container restarts

This doesn't scale as the toolbox grows (currently 34 tools) and more teams adopt it.

## Two distinct concepts: update vs upgrade

The toolbox already has a `dev-update` command that handles full container updates (pulling a new image and rebuilding). This is still needed for changes to the Dockerfile or base image (new OS packages, runtime versions, system configuration).

But most day-to-day changes are to the scripts in `additions/` and `manage/` -- bug fixes, new tools, metadata updates. These don't require a new container image. We need a second concept that updates just the scripts inside a running container.

| Concept              | What changes                                                    | Command      | Rebuild? | Version                                          |
|----------------------|-----------------------------------------------------------------|--------------|----------|--------------------------------------------------|
| **Script sync**      | Script fixes, new tools, commands in `additions/` and `manage/` | `dev-sync`   | No       | `tools.json` `"version"` (auto)                  |
| **Container update** | Base image, OS packages, runtime versions, Dockerfile           | `dev-update` | Yes      | `/opt/devcontainer-toolbox/version.txt` (manual)  |

Each concept has its own version track:

- **`tools.json` version** (e.g. `1.2.4`) -- auto-bumped by CI/CD when any script changes. Used by `dev-sync` to detect if new scripts are available.
- **`version.txt`** (e.g. `1.6.5` currently) -- bumped manually by a human when the container image needs a rebuild (Dockerfile changes, new OS packages, runtime upgrades). Used by `dev-update` to detect if a new image is available.

`dev-sync` is fast (seconds) and non-disruptive -- the developer keeps working. `dev-update` is the existing full rebuild for when the container image itself changes. A human decides when a container rebuild is needed and bumps `version.txt` accordingly.

## What is needed

### 1. `dev-sync` command

A new command that runs inside a live container and pulls updated scripts from the GitHub repo without rebuilding the image:

```text
Developer runs: dev-sync

dev-sync:
  1. Fetches scripts-version.txt from GitHub (~6 bytes, same cost as version.txt)
  2. Compares remote version with local tools.json version
  3. If versions match:
     → "Already up to date (v1.2.0)" — done
  4. If versions differ:
     a. Downloads updated script bundle (zip/tar.gz from GitHub release)
     b. Replaces /opt/devcontainer-toolbox/additions/ and /opt/devcontainer-toolbox/manage/
     c. Reports what changed (which tools were added/updated)
```

**Performance:** The version check (step 1-2) is as lightweight as today's `version.txt` check -- a single HTTP request for a few bytes. The full bundle is only downloaded when something actually changed. This makes `dev-sync` safe to run on every container start without slowing things down.

`dev-sync` must update both `additions/` (install scripts) and `manage/` (dev commands, tools.json, lib/).

**New commands in `manage/`:** The `dev-*` commands work because they are symlinked from `/usr/local/bin/`:

```text
/usr/local/bin/dev-help  →  /opt/devcontainer-toolbox/manage/dev-help.sh
/usr/local/bin/dev-setup →  /opt/devcontainer-toolbox/manage/dev-setup.sh
...
```

When `dev-sync` pulls updated scripts and a new `dev-*.sh` file appears in `manage/` that doesn't have a symlink yet, `dev-sync` must create it:

```bash
# After extracting new scripts, create symlinks for any new dev-* commands
for script in /opt/devcontainer-toolbox/manage/dev-*.sh; do
    cmd_name=$(basename "$script" .sh)
    link="/usr/local/bin/$cmd_name"
    if [ ! -L "$link" ]; then
        ln -s "$script" "$link"
        echo "  New command available: $cmd_name"
    fi
done
```

Similarly, if a `dev-*.sh` script was removed in the update, the orphaned symlink should be cleaned up.

The script bundle could be a tar.gz published as a GitHub release artifact or downloadable from a known branch URL:

```bash
# Example: download and extract
curl -fsSL "https://github.com/terchris/devcontainer-toolbox/releases/download/v1.2.0/toolbox-scripts.tar.gz" \
  | tar xz -C /opt/devcontainer-toolbox/
```

Alternatively, `dev-sync` could use `git archive` or the GitHub API. The key requirement is that it works without git auth (the repo is public).

### Edge cases to handle

The project's `.devcontainer.extend/enabled-tools.conf` lists tools that should be auto-installed. After `dev-sync` updates the scripts, the tool list may be out of sync. Cases to handle:

**1. Tool in `enabled-tools.conf` not in toolbox**
`tool-foobar` is listed but no `install-tool-foobar.sh` exists. Warn: "Unknown tool 'tool-foobar' in enabled-tools.conf -- skipping."

**2. Tool renamed in toolbox**
`tool-azure-devops` was renamed to `tool-azdo`. Warn about the unknown old name. Ideally `tools.json` could carry a `renamedFrom` field to suggest the new name.

**3. Tool removed from toolbox**
`tool-old-thing` existed in the previous version but was deleted. Same as case 1 -- warn and skip.

**4. New tool available after sync**
`dev-sync` pulls a new `install-dev-rust.sh`. The tool is available via `dev-setup` but not auto-installed (it's not in `enabled-tools.conf`).

**5. Tool script updated after sync**
`install-dev-bash.sh` has a newer version. The script is updated on disk. If already installed, the tool continues to work. Developer can re-run the install script to get new packages/extensions if needed.

**6. Tool dependencies changed**
Updated `install-tool-x.sh` now requires a system package not in the image. Warn: "tool-x may require a container rebuild -- new system dependency: libfoo-dev."

The most common case is the first one: a project's `enabled-tools.conf` references a tool that was added to the toolbox after the container image was built. Today this fails silently or with a cryptic error. After `dev-sync`, the install script would be available and could be run. `dev-sync` should detect this case and offer to install newly available tools:

```text
dev-sync: Updated scripts v1.2.0 → v1.3.0
dev-sync: New tool available: tool-foobar (listed in enabled-tools.conf but not yet installed)
dev-sync: Run 'dev-setup' to install it, or it will install on next container rebuild
```

### 2. Version numbers in tools.json

Currently `tools.json` has no version information. The `generated` timestamp is not useful for comparison because it changes on every build regardless of whether anything actually changed.

**What's missing:**

- No top-level version for the toolbox itself (e.g. `"version": "1.2.0"`)
- No per-tool version (e.g. `"version": "0.3.1"` on each tool entry)

**What already exists:**

Every install script already has a `SCRIPT_VER` field:

```bash
SCRIPT_VER="0.2.0"
```

The `tools.json` generator script already parses script metadata (`SCRIPT_ID`, `SCRIPT_NAME`, `SCRIPT_DESCRIPTION`, etc.). Adding `SCRIPT_VER` extraction is straightforward -- it's the same pattern.

**Proposed tools.json changes:**

```json
{
  "version": "1.2.0",
  "generated": "2026-02-14T12:00:00+00:00",
  "tools": [
    {
      "id": "dev-bash",
      "version": "0.3.1",
      "type": "install",
      "name": "Bash Development Tools",
      ...
    }
  ]
}
```

- The top-level `version` is what `dev-sync` uses to decide whether to pull new scripts
- The top-level version is auto-bumped by the generator whenever any tool version changes (see "Additional challenges" below)
- Per-tool versions let developers see exactly which tools changed
- `dev-sync` can report: "Updated 3 tools: dev-bash 0.3.0 -> 0.3.1, dev-python 0.2.0 -> 0.2.1, dev-ai-claudecode 0.1.0 -> 0.1.1"

### 3. Auto version bumping via pre-commit hook

The `client-provisioning` repo uses a `.githooks/pre-commit` hook that automatically bumps `SCRIPT_VER` patch versions on every commit. This ensures version numbers are always current without manual effort.

The hook:

- Detects staged `.sh` and `.ps1` files with a `SCRIPT_VER` field
- Skips files with no real content changes (only version line changed)
- Skips new files (not yet in HEAD)
- Bumps the patch version (e.g. `0.2.0` -> `0.2.1`)
- Re-stages the file with the bumped version

The devcontainer-toolbox repo should adopt the same hook. Here is the full hook from the `client-provisioning` repo (`.githooks/pre-commit`):

```bash
#!/usr/bin/env bash
# .githooks/pre-commit
#
# Auto-bumps SCRIPT_VER patch version for changed .sh and .ps1 script files.
# Only bumps files that:
#   - Are staged for commit (.sh or .ps1)
#   - Contain a SCRIPT_VER field
#   - Already exist in HEAD (new files are skipped)
#   - Have real content changes (not just a SCRIPT_VER line change)
#
# Minor and major version bumps are done manually with set-version-*.sh tools.

set -euo pipefail

bumped=0

for file in $(git diff --cached --name-only); do
    # Only process .sh and .ps1 files
    case "$file" in
        *.sh|*.ps1) ;;
        *) continue ;;
    esac

    # File must exist on disk (not a delete)
    [ -f "$file" ] || continue

    # File must contain SCRIPT_VER
    grep -q 'SCRIPT_VER' "$file" || continue

    # Skip new files (not in HEAD)
    git show "HEAD:$file" > /dev/null 2>&1 || continue

    # Compare content excluding SCRIPT_VER line -- skip if no real change
    staged_content=$(git show ":$file" | grep -v 'SCRIPT_VER' || true)
    head_content=$(git show "HEAD:$file" | grep -v 'SCRIPT_VER' || true)
    [ "$staged_content" = "$head_content" ] && continue

    # Extract current version (|| true to handle grep returning no match under pipefail)
    if [[ "$file" == *.ps1 ]]; then
        current=$(grep '^\$SCRIPT_VER' "$file" | head -1 | sed 's/.*= *"//' | sed 's/".*//') || true
    else
        current=$(grep '^SCRIPT_VER=' "$file" | head -1 | sed 's/^SCRIPT_VER="//' | sed 's/".*//') || true
    fi
    [ -z "$current" ] && continue

    # Parse and bump patch
    major=$(echo "$current" | cut -d. -f1)
    minor=$(echo "$current" | cut -d. -f2)
    patch=$(echo "$current" | cut -d. -f3)
    new_ver="${major}.${minor}.$((patch + 1))"

    # Update file on disk
    if [[ "$file" == *.ps1 ]]; then
        sed -i "s/^\(\\\$SCRIPT_VER *=  *\)\"[^\"]*\"/\1\"$new_ver\"/" "$file"
    else
        sed -i "s/SCRIPT_VER=\"[^\"]*\"/SCRIPT_VER=\"$new_ver\"/" "$file"
    fi

    # Re-stage the file with the version bump
    git add "$file"
    echo "  version-bump: $(basename "$file") $current -> $new_ver"
    bumped=$((bumped + 1))
done

if [ "$bumped" -gt 0 ]; then
    echo "  version-bump: $bumped file(s) bumped"
fi
```

To adopt it:

1. Copy the hook above to `.githooks/pre-commit` in the devcontainer-toolbox repo
2. Make it executable: `chmod +x .githooks/pre-commit`
3. Add to README or CONTRIBUTING: `git config core.hooksPath .githooks`
4. The `tools.json` generator will then pick up the always-current `SCRIPT_VER` values

### 4. Automatic sync on container start

`dev-sync` should run automatically every time the devcontainer starts (via `postStartCommand` or the entrypoint script). This ensures scripts are always current without the developer having to remember anything:

```text
Container starts:
  1. Entrypoint runs dev-sync
  2. dev-sync checks remote tools.json version vs local
  3. If newer scripts available → downloads and replaces silently
  4. Logs what changed to the startup log (visible via dev-log)
  5. Container is ready with the latest scripts
```

This is especially important for the first time a devcontainer is started -- the container image may have been built weeks ago, and scripts could have had multiple fixes since then.

Since `dev-sync` runs on every container start, it also handles the case where a developer hasn't rebuilt their container in a while. They always get the latest scripts automatically.

**Offline handling:** If there is no internet connection (e.g. working on a plane), `dev-sync` should skip silently and log a warning. The existing scripts continue to work -- they're just not the latest version.

**Notification in other commands:** Other commands (`dev-help`, `dev-setup`, `dev-env`) could also show a one-line notification if `dev-sync` found updates but failed to apply them (e.g. network error during startup). Use a cache file (e.g. `/tmp/devcontainer-toolbox-sync-status`) written by `dev-sync` so other commands can check instantly without making network requests.

### Additional challenges

**File permissions.** `/opt/devcontainer-toolbox/` is owned by root. `dev-sync` needs write access to replace files there, and creating symlinks in `/usr/local/bin/` also requires root. Options: run `dev-sync` with `sudo`, change directory ownership to the `vscode` user, or use a wrapper that elevates only for the file operations.

**Atomic replacement and rollback.** If the download fails halfway or the bundle is corrupt, the toolbox could be left in a broken state with some files replaced and others not. `dev-sync` should extract to a temporary directory first, verify the extraction succeeded, then swap the directories atomically:

```bash
# Safe update pattern
tmp=$(mktemp -d)
curl -fsSL "$BUNDLE_URL" | tar xz -C "$tmp"
# Verify extraction succeeded
[ -f "$tmp/manage/tools.json" ] || { echo "ERROR: corrupt bundle"; rm -rf "$tmp"; exit 1; }
# Atomic swap
mv /opt/devcontainer-toolbox/additions /opt/devcontainer-toolbox/additions.old
mv "$tmp/additions" /opt/devcontainer-toolbox/additions
# ... same for manage/
rm -rf /opt/devcontainer-toolbox/additions.old "$tmp"
```

If something goes wrong, the `.old` directories can be restored. The previous `tools.json` should also be kept (e.g. as `tools.json.previous`) so `dev-sync` can report what changed.

**`dev-sync` updating itself.** `dev-sync` lives in `manage/dev-sync.sh`. When it replaces the `manage/` directory, it is overwriting itself mid-execution. This needs careful handling -- either copy the script to a temp location and re-exec from there, or ensure the new files are written atomically so the running script is not affected (bash reads the full script into memory on some systems, but this is not guaranteed).

**Top-level version: auto-bumped in CI/CD.** The `tools.json` generator (`generate-tools-json.sh`) runs in the CI/CD pipeline, not locally. The pipeline can automate the top-level version bump:

```text
Developer pushes to main:
  1. Pre-commit hook has already bumped SCRIPT_VER in changed scripts
  2. CI/CD pipeline runs generate-tools-json.sh
  3. Generator extracts SCRIPT_VER from every install script
  4. Generator compares new per-tool versions against the previous tools.json
     (stored as a release artifact or committed to the repo)
  5. If any tool version changed, or tools were added/removed:
     → Bump the top-level patch version (e.g. 1.2.3 → 1.2.4)
  6. If nothing changed:
     → Keep the same top-level version, skip bundle publish
  7. Write new tools.json with updated versions
  8. Create and publish the script bundle (tar.gz)
```

This is the same principle as the `SCRIPT_VER` pre-commit hook but applied one level up in CI/CD: individual script changes bump `SCRIPT_VER` locally, and the pipeline detects those changes and bumps the top-level `tools.json` version. Fully automatic, no manual version management needed.

Minor and major version bumps (e.g. `1.2.0` -> `2.0.0` for breaking changes) would still be done manually by editing a `VERSION` file or similar, but patch bumps -- which are the vast majority -- happen automatically in the pipeline.

**CI/CD pipeline for the bundle.** The devcontainer-toolbox repo needs a GitHub Actions workflow (or similar) that runs on push to `main`. This pipeline is central to the whole mechanism -- it generates versions, detects changes, and publishes the bundle. Steps:

1. Run `generate-tools-json.sh` to extract `SCRIPT_VER` from all scripts
2. Compare new per-tool versions against the previous `tools.json` (from the last release)
3. If any version changed or tools added/removed: bump the top-level version
4. Create a tar.gz of `additions/` and `manage/` (including the new `tools.json`)
5. Publish as a GitHub release (tagged with the top-level version)
6. If nothing changed: skip steps 4-5 (no release needed)

**Config script compatibility.** `additions/` contains config scripts (`config-git.sh`, `config-azure-devops.sh`) that store credentials in `.devcontainer.secrets/`. These have a `--verify` mode that runs on container startup to restore credentials. If `dev-sync` updates a config script, the new `--verify` must still work with credentials saved by the old version. Config scripts should maintain backwards compatibility with their storage format, or include migration logic.

**`lib/` shared libraries.** The `manage/lib/` directory contains shared code sourced by dev commands. If a dev command is running when `dev-sync` replaces `lib/`, and the running command sources a lib file after the replacement, it could get incompatible code. In practice this is unlikely (scripts source libs at startup, not mid-execution), but the atomic swap pattern above mitigates this.

## Example workflow

```text
Toolbox maintainer fixes a bug in install-dev-bash.sh:
  1. Edits the script
  2. Commits → pre-commit hook bumps SCRIPT_VER 0.3.0 → 0.3.1
  3. CI/CD rebuilds tools.json (now shows dev-bash version 0.3.1)
  4. CI/CD publishes a new script bundle (tar.gz)

Developer in their running container:
  1. Runs: dev-sync
  2. dev-sync fetches remote tools.json, sees version changed
  3. Downloads and extracts new scripts
  4. Reports: "Updated dev-bash 0.3.0 → 0.3.1"
  5. Developer continues working — no rebuild, no restart
```

Compare this to today:

```text
  1. Maintainer pushes fix
  2. CI/CD rebuilds the entire Docker image
  3. Developer runs dev-update → pulls new image → rebuilds container
  4. Developer waits several minutes, loses terminal state
```

## Who this affects

Every team using the devcontainer-toolbox. Currently, a typo fix in one install script requires every developer across all teams to rebuild their container. With `dev-sync`, they run one command and continue working.

### Website documentation

The devcontainer-toolbox website ([dct.sovereignsky.no](https://dct.sovereignsky.no)) generates help pages for each tool from the script metadata. Currently these pages show `Script ID` and `Script` but not the version number. For example, the [Java tool page](https://dct.sovereignsky.no/docs/tools/development-tools/java) shows:

```text
Script ID: dev-java
Script:    install-dev-java.sh
```

Once `SCRIPT_VER` is added to `tools.json`, the website generator should also include it:

```text
Script ID: dev-java
Script:    install-dev-java.sh
Version:   0.3.1
```

This helps developers and maintainers see which version of a tool is documented, and whether the docs match what's installed in their container.

---

## Related

- `tools.json` is generated by the toolbox build process and stored at `/opt/devcontainer-toolbox/manage/tools.json`
- `dev-update` already exists for full container updates (pull new image, rebuild)
- The pre-commit hook is at `.githooks/pre-commit` in the `client-provisioning` repo ([Azure DevOps](https://dev.azure.com/YOUR-ORG/Azure/_git/client-provisioning))
- Issue [#43](https://github.com/terchris/devcontainer-toolbox/issues/43) -- Ship machine-readable tool inventory (completed, created `tools.json`)
