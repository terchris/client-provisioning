# Script Standards

How scripts work in this repo. Every script -- bash and PowerShell -- follows the same conventions for versioning, help, logging, and validation.

---

## Versioning

Every script has a version number in its metadata block:

```bash
# Bash
SCRIPT_VER="0.2.0"

# PowerShell
$SCRIPT_VER         = "0.2.0"
```

The version follows semantic versioning: `MAJOR.MINOR.PATCH` (e.g. `0.2.0`, `1.0.0`).

The version is printed at startup when the script runs:

```text
[14:32:01] INFO  Starting: Install Rancher Desktop Ver: 0.2.0
```

This helps identify which version of a script is deployed on a machine.

### Automatic patch bumps

Patch versions are bumped automatically by a git pre-commit hook (`.githooks/pre-commit`). When you commit a change to a script, the hook:

1. Detects which `.sh` and `.ps1` files are staged
2. Checks if the file has a `SCRIPT_VER` field
3. Skips new files (first commit) and files where only the version line changed
4. Increments the patch number (e.g. `0.2.0` -> `0.2.1`)
5. Re-stages the file with the updated version

You don't need to bump patch versions manually -- it happens on every commit.

### Manual minor and major bumps

Minor and major version bumps are done by a human using the set-version tools:

```bash
# Bump all bash scripts in a package
bash docs/ai-developer/tools/set-version-bash.sh rancher-desktop

# Bump all PowerShell scripts in a package
bash docs/ai-developer/tools/set-version-powershell.sh wsl2
```

When to bump:

- **PATCH** (0.2.0 -> 0.2.1): automatic on every commit
- **MINOR** (0.2.x -> 0.3.0): new features, new scripts added to a package
- **MAJOR** (0.x.0 -> 1.0.0): breaking changes

---

## Help flag

Every script supports a help flag that shows usage, options, and metadata:

```bash
# Bash
bash scripts-mac/rancher-desktop/rancher-desktop-install.sh --help

# PowerShell
pwsh scripts-win/rancher-desktop/install.ps1 -Help
```

The help output includes the script name, version, description, usage, options, and metadata fields (ID, category).

---

## Logging

Every script uses standard logging functions:

| Function | Output |
| -------- | ------ |
| `log_info` | `[14:32:01] INFO  message` |
| `log_success` | `[14:32:01] OK    message` |
| `log_error` | `[14:32:01] ERROR message` |
| `log_warning` | `[14:32:01] WARN  message` |
| `log_start` | `[14:32:01] INFO  Starting: Script Name Ver: 0.2.0` |

`log_start` is called at the beginning of every script to identify itself.

---

## Validation

All scripts are validated automatically. Run the validators before committing:

```bash
# Validate bash scripts (scripts-mac/)
bash docs/ai-developer/tools/validate-bash.sh

# Validate PowerShell scripts (scripts-win/)
bash docs/ai-developer/tools/validate-powershell.sh
```

Each validator runs 5 checks per script:

| Check | What it verifies |
| ----- | ---------------- |
| syntax | Script parses without errors (bash -n / PowerShell AST) |
| help | Help flag works and outputs expected format |
| meta | Required metadata fields are present (SCRIPT_ID, SCRIPT_NAME, SCRIPT_VER, SCRIPT_DESCRIPTION, SCRIPT_CATEGORY) |
| startup | Source contains the `log_start` function with the standard format |
| lint | No lint warnings (shellcheck for bash, PSScriptAnalyzer for PowerShell) |

---

## Templates

New scripts should be based on the templates:

- **Bash**: [docs/ai-developer/templates/bash/script-template.sh](ai-developer/templates/bash/script-template.sh)
- **PowerShell**: [docs/ai-developer/templates/powershell/script-template.ps1](ai-developer/templates/powershell/script-template.ps1)

The templates include all required sections: metadata, logging functions, help, argument parsing, and main logic.

---

## Full standard

For the complete rules (error codes, exit codes, metadata alignment, etc.), see:

- [Script standard](ai-developer/rules/script-standard.md) -- shared rules for all scripts
- [Bash rules](ai-developer/rules/bash.md) -- bash-specific rules
- [PowerShell rules](ai-developer/rules/powershell.md) -- PowerShell-specific rules
