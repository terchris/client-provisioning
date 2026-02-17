# Claude Code credential sync does not migrate legacy credentials or support API key auth

## Problem

The `claude-credential-sync.sh` script (implemented for issue #46) symlinks `~/.claude` to `.devcontainer.secrets/.claude-credentials/`. This works for new setups, but has two gaps:

1. **Legacy credential migration** — Users who previously saved credentials using the old manual-copy approach have a file at `.devcontainer.secrets/claude-credentials.json`. On rebuild, the sync script creates the `.claude-credentials/` directory and the symlink, but never checks for or migrates the legacy file. Claude Code starts with an empty credentials directory and forces a re-login, even though valid credentials exist one directory up.

2. **API key authentication** — Claude Code supports two authentication methods, but only OAuth (Claude Max) is handled:
   - **OAuth (Claude Max/Pro)** — Handled by the symlink. Credentials stored in `~/.claude/.credentials.json`.
   - **API key (LiteLLM / Anthropic API)** — Uses `ANTHROPIC_API_KEY` environment variable. Not handled at all. Users with an API key (e.g., routed through a LiteLLM proxy) must manually export the variable after every rebuild.

## Current behavior

### Legacy migration

```
.devcontainer.secrets/
├── claude-credentials.json          # Old format (from manual copy era) — IGNORED
└── .claude-credentials/
    └── (empty on first rebuild)     # Symlink target — no .credentials.json
```

The sync script at `/opt/devcontainer-toolbox/additions/lib/claude-credential-sync.sh` does not check for the legacy file. Users who followed the old `howto-copy-claude-manually.md` instructions are forced to re-authenticate.

### API key

There is no mechanism to persist or restore `ANTHROPIC_API_KEY`. Users who authenticate via API key (e.g., through a LiteLLM proxy or direct Anthropic API) must manually export the variable in every new terminal session after a rebuild.

## Expected behavior

### Legacy migration

When `ensure_claude_credentials()` runs and `.devcontainer.secrets/.claude-credentials/.credentials.json` does not exist, it should check for the legacy file at `.devcontainer.secrets/claude-credentials.json` and copy it into the new location:

```bash
# In ensure_claude_credentials(), after mkdir -p "$target_dir":
legacy_file="/workspace/.devcontainer.secrets/claude-credentials.json"
target_creds="$target_dir/.credentials.json"

if [ ! -f "$target_creds" ] && [ -f "$legacy_file" ]; then
    cp "$legacy_file" "$target_creds"
    chmod 600 "$target_creds"
    echo "   Migrated legacy credentials from claude-credentials.json"
fi
```

### API key

Follow the same pattern as other persistent env vars (git identity, Azure DevOps PAT). Store the API key in `.devcontainer.secrets/env-vars/` and export it on startup:

```bash
# Store (one-time, by user or config script):
echo "$ANTHROPIC_API_KEY" > .devcontainer.secrets/env-vars/anthropic-api-key
chmod 600 .devcontainer.secrets/env-vars/anthropic-api-key

# Restore (in entrypoint, install script, or ~/.bashrc):
APIKEY_FILE="$DCT_WORKSPACE/.devcontainer.secrets/env-vars/anthropic-api-key"
if [ -f "$APIKEY_FILE" ]; then
    echo "export ANTHROPIC_API_KEY=\"\$(cat $APIKEY_FILE 2>/dev/null)\"" >> ~/.bashrc
fi
```

This supports LiteLLM proxy setups where `ANTHROPIC_API_KEY` holds the proxy key, as well as direct Anthropic API usage.

## Files involved

- `/opt/devcontainer-toolbox/additions/lib/claude-credential-sync.sh` — Add legacy migration logic
- `/opt/devcontainer-toolbox/additions/install-dev-ai-claudecode.sh` — Optionally add API key restore step
- `/opt/devcontainer-toolbox/entrypoint.sh` — Sources `claude-credential-sync.sh` on every start
- `/workspace/.devcontainer.secrets/howto-copy-claude-manually.md` — Update to reflect symlink approach is now automatic; add API key instructions

## Discovered

Found after rebuilding the devcontainer. Valid OAuth credentials existed at `.devcontainer.secrets/claude-credentials.json` (saved Feb 10) but were not picked up by the sync script. The user had to re-authenticate manually. API key auth gap identified as a second use case that is not covered.
