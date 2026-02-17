# Persist Claude Code credentials across devcontainer rebuilds

## Problem

When Claude Code (`claude`) is launched for the first time in a devcontainer, it runs an OAuth authentication flow:

1. Claude opens a URL in the browser
2. The user authenticates and receives an auth code
3. The user pastes the auth code back into the terminal
4. Claude stores the credentials in `~/.claude/.credentials.json`

This works fine — until the devcontainer is rebuilt. Since `~/.claude/` lives inside the container, the credentials are lost on every rebuild, forcing the user to re-authenticate each time.

## Where credentials are stored

Claude Code stores its OAuth tokens in:

```
~/.claude/.credentials.json
```

The file contains an access token, a refresh token, expiry timestamp, and scope/subscription metadata. The refresh token is long-lived and allows Claude to renew the access token automatically.

## What is needed

A mechanism to persist `~/.claude/.credentials.json` across container rebuilds using `.devcontainer.secrets/`, consistent with how other credentials (Azure, GitHub PATs, etc.) are stored.

### Save credentials (after first-time auth)

Copy or symlink the credentials file into the secrets volume:

```bash
cp ~/.claude/.credentials.json .devcontainer.secrets/claude-credentials.json
```

### Restore credentials (on container rebuild)

During container startup (e.g. `postStartCommand` or an init script), restore the file:

```bash
if [ -f .devcontainer.secrets/claude-credentials.json ]; then
    mkdir -p ~/.claude
    cp .devcontainer.secrets/claude-credentials.json ~/.claude/.credentials.json
    chmod 600 ~/.claude/.credentials.json
fi
```

### Consideration: symlink vs copy

- **Copy**: Simple, but the file won't stay in sync if Claude refreshes the tokens (it updates the file in place when the access token expires).
- **Symlink**: Keeps the file in sync automatically, but the target must exist before Claude starts. A symlink from `~/.claude/.credentials.json` to `.devcontainer.secrets/claude-credentials.json` would handle token refreshes transparently.

A symlink is probably the better approach:

```bash
if [ -f .devcontainer.secrets/claude-credentials.json ]; then
    mkdir -p ~/.claude
    ln -sf /workspace/.devcontainer.secrets/claude-credentials.json ~/.claude/.credentials.json
fi
```

## Update: manual copy does not work

We tested manually copying `~/.claude/.credentials.json` to `.devcontainer.secrets/` and restoring it before starting Claude Code. It did not work — Claude still prompted for a full OAuth login.

The saved tokens had not expired, but were **revoked server-side**. This happens because:

1. **Token refresh invalidates old tokens** — Claude Code refreshes the access token periodically, writing new tokens to `.credentials.json`. If the backup was saved before a refresh, the saved copy contains revoked tokens.
2. **New OAuth login revokes previous tokens** — When a new login flow completes, the OAuth provider revokes all previously issued refresh tokens.

This confirms that a **static copy is unreliable**. The symlink approach is the right solution because it keeps the file in sync when Claude refreshes tokens.

## Alternative investigated: environment variables

Claude Code supports several environment variables for authentication:

- **`ANTHROPIC_API_KEY`** — Bypasses OAuth entirely. Requires a paid API account (usage-based billing from console.anthropic.com). Does not work with Claude Pro/Max subscriptions, which use OAuth.
- **`ANTHROPIC_AUTH_TOKEN`** — Passes a bearer token directly. Could work with the OAuth access token, but it expires every ~8 hours and cannot self-refresh via an env var. Worse than the file approach.
- **`apiKeyHelper` setting** — Runs a shell command to fetch credentials dynamically. Only helps with API keys, not OAuth token refresh.

**Conclusion:** Environment variables only solve the problem for users with a static Anthropic API key (paid API account). For OAuth-based authentication (Claude Pro/Max subscriptions), the **symlink approach remains the best solution** because it allows Claude Code to refresh tokens in place and have those refreshes automatically persisted.

## Integration with install script

This could be added to the existing `install-dev-ai-claudecode.sh` or handled as a separate restore step in the devcontainer lifecycle. The install script already handles Claude Code installation — adding a credentials restore step would be a natural fit.

## Checklist

- [ ] Decide on symlink vs copy approach
- [ ] Add restore logic to container startup
- [ ] Verify `.devcontainer.secrets/` is in `.gitignore`
- [ ] Document the first-time auth + save workflow for users
- [ ] Test that token refresh works correctly with the chosen approach
