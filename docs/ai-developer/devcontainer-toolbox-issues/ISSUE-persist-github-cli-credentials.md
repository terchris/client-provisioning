# Persist GitHub CLI credentials across devcontainer rebuilds

## Problem

The GitHub CLI (`gh`) stores authentication tokens in `~/.config/gh/` (primarily `hosts.yml`). When the devcontainer is rebuilt, this directory is lost and the user must re-run `gh auth login` every time.

The toolbox already solves this for Claude Code credentials using a symlink from `~/.claude` to `.devcontainer.secrets/.claude-credentials/`. The same pattern should be applied to GitHub CLI credentials.

## Current behavior

1. User runs `gh auth login` and authenticates via browser
2. Token is stored in `~/.config/gh/hosts.yml`
3. Container is rebuilt
4. `~/.config/gh/` is gone — `gh` commands fail with "not logged in"
5. User must re-authenticate

## Expected behavior

1. On container startup, the entrypoint (or install script) symlinks `~/.config/gh` to `.devcontainer.secrets/.gh-config/`
2. User runs `gh auth login` once — token is written through the symlink to persistent storage
3. Container is rebuilt — symlink is recreated, credentials are already there
4. `gh` commands work immediately

## Suggested implementation

Create a `gh-credential-sync.sh` library following the same pattern as `claude-credential-sync.sh`:

```bash
ensure_gh_credentials() {
    local target_dir="/workspace/.devcontainer.secrets/.gh-config"
    local link_path="/home/vscode/.config/gh"

    mkdir -p "$target_dir"
    mkdir -p "$(dirname "$link_path")"

    if [ -L "$link_path" ]; then
        local current_target=$(readlink -f "$link_path")
        if [ "$current_target" != "$target_dir" ]; then
            rm "$link_path"
            ln -sf "$target_dir" "$link_path"
        fi
    elif [ -d "$link_path" ]; then
        # Migrate existing config to persistent location
        cp -a "$link_path"/* "$target_dir/" 2>/dev/null || true
        cp -a "$link_path"/.[!.]* "$target_dir/" 2>/dev/null || true
        rm -rf "$link_path"
        ln -sf "$target_dir" "$link_path"
    else
        ln -sf "$target_dir" "$link_path"
    fi
}

ensure_gh_credentials
```

This should run from the entrypoint, the same way `claude-credential-sync.sh` does. The `gh` CLI is pre-installed in the base image, so this does not need an install script — just the symlink setup.

## Why this matters

GitHub CLI auth is needed for:
- Pushing code
- Creating and managing pull requests (`gh pr create`)
- Filing issues (`gh issue create`)
- Viewing CI checks (`gh run list`)
- AI assistants (like Claude Code) performing git operations on behalf of the user

Without persistence, every rebuild breaks the workflow.

## Discovered

Found while setting up GitHub CLI in the `client-provisioning` devcontainer. The toolbox has no persistence mechanism for `gh` credentials, unlike Claude Code and Azure DevOps which already have solutions.
