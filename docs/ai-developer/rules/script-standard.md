# Script Standard

The universal rules that apply to **all** scripts in this repo, regardless of language. Bash, PowerShell, and any future languages must follow these conventions.

For language-specific syntax (how to implement these in bash or PowerShell), see the language rules files:
- [bash.md](bash.md) — Bash scripts for macOS
- [powershell.md](powershell.md) — PowerShell scripts for Windows

---

## Required Metadata Fields

Every script must define these 5 fields near the top. Validation tools check that all are present.

| Field | Format | Example |
|-------|--------|---------|
| `SCRIPT_ID` | lowercase, hyphenated | `"devcontainer-init"` |
| `SCRIPT_NAME` | Human-readable title | `"Devcontainer Init"` |
| `SCRIPT_VER` | Semantic version (auto-bumped, see below) | `"0.2.0"` |
| `SCRIPT_DESCRIPTION` | One-line description | `"Initialize devcontainer toolbox on a Mac"` |
| `SCRIPT_CATEGORY` | Uppercase category | `"DEVOPS"` |

### SCRIPT_CATEGORY values

Use an uppercase label that describes the script's purpose. Current categories in use:

| Category | Use for |
|----------|---------|
| `DEVOPS` | DevOps tooling, infrastructure setup, container management |

Add new categories as needed (e.g. `NETWORKING`, `SECURITY`, `MONITORING`). Keep them short, uppercase, and use underscores for multi-word names.

### SCRIPT_VER and automatic versioning

Patch versions are bumped automatically by a git pre-commit hook (`.githooks/pre-commit`). When you commit a change to a script, the patch number increments (e.g. `0.2.0` -> `0.2.1`). You don't need to bump it manually.

Minor and major bumps are done manually using the set-version tools:

- `bash docs/ai-developer/tools/set-version-bash.sh <package>`
- `bash docs/ai-developer/tools/set-version-powershell.sh <package>`

See [SCRIPT-STANDARDS.md](../../SCRIPT-STANDARDS.md) for the full versioning guide.

---

## Standard Help Format

Every script must support a help flag (`-h`/`--help` for bash, `-Help` for PowerShell). The output must follow this structure:

```
<SCRIPT_NAME> (v<SCRIPT_VER>)
<SCRIPT_DESCRIPTION>

Usage:
  <SCRIPT_ID> [options]

Options:
  -h, --help  Show this help message

Metadata:
  ID:       <SCRIPT_ID>
  Category: <SCRIPT_CATEGORY>
```

The validation tool checks:
- First line contains `SCRIPT_NAME (vSCRIPT_VER)`
- `SCRIPT_DESCRIPTION` appears in the output
- A `Metadata:` section exists with `ID:` and `Category:` fields

Scripts may add extra sections (Arguments, Examples, Prerequisites, etc.) between Options and Metadata.

---

## Standard Logging

**Do not use raw print/echo/Write-Host for output. Always use the logging functions.**

Every message the script prints must go through a logging function. They add timestamps and severity levels, which makes log files useful for debugging.

| Function | Use for |
|----------|---------|
| `log_info` | Status updates, descriptions, instructions |
| `log_success` | Something worked: "App installed", "Profile written" |
| `log_error` | Something failed: "ERR002: Failed to download..." |
| `log_warning` | Non-fatal issues: "Restart required", "tool not found" |

The output format is: `[HH:MM:SS] LEVEL  message`

The only acceptable uses of raw output are:
- Blank lines for visual separation
- Separator lines for formatting
- Inside the help function's heredoc/here-string

See the language rules file for the exact function implementations.

---

## Startup Message

Every script must print its name and version as the first log line when it starts running. Use the `log_start` function, which is defined alongside the other logging functions:

| Language | Definition | Call |
|----------|-----------|------|
| Bash | `log_start() { log_info "Starting: $SCRIPT_NAME Ver: $SCRIPT_VER"; }` | `log_start` |
| PowerShell | `function log_start { log_info "Starting: $SCRIPT_NAME Ver: $SCRIPT_VER" }` | `log_start` |

Output:
```
[17:38:34] INFO  Starting: Devcontainer Initialization Ver: 0.1.0
```

The validation tool checks that the source contains the exact string `"Starting: $SCRIPT_NAME Ver: $SCRIPT_VER"` (present inside the function definition).

Call `log_start` in the main execution section, **after** the help check (so it does not print when the user runs with `-h`/`-Help`).

---

## Unique Error Identifiers

Every error log call must include a unique error code in the format `ERR001`, `ERR002`, etc. Error codes are unique **within each script** (not across the repo). This lets the ops team identify exactly which error occurred — especially when users report errors over the phone.

Rules:
- Start at `ERR001` in each script and increment sequentially
- Detail lines (captured stderr) use the same code as their parent error
- The code goes at the start of the message, before the description
- Keep codes sequential — don't skip numbers

When a user calls and says "I got ERR005", you can immediately find the exact error in the exact script.

---

## No Hardcoded Values

Put all URLs, paths, filenames, and defaults in a CONFIGURATION section as variables. Functions should only reference variables — never hardcode values inline.

This makes scripts easier to maintain — changing a URL or path means editing one line at the top, not hunting through functions.

---

## Verify Every Action

Never assume a command succeeded — verify the result. If a command fails silently, the script must detect that and exit with an error.

Apply this to all side effects: file/directory removal, file creation, downloads, mounts, copies, process termination. If you can check whether it worked, check it.

---

## Capture Error Output

When a command fails, the ops team needs to know **why** it failed. Capture the error output and include it in the error log. This is critical for commands that can fail for multiple reasons (downloads, file operations, system commands).

For cleanup commands where failure is acceptable, capturing error output is not needed.

---

## Check Commands Before Using Them

If a script depends on a command that is **not** part of the standard OS install, check that it exists before using it and give a clear error if it's missing.

Put required command checks early in the script, before it does any work.

Optional commands should fall back gracefully with a warning.

---

## Package Structure

Every script folder is a **package**. Each package groups related deployment scripts together with their documentation and tests.

### Required files

| File | Purpose |
|------|---------|
| `README.md` | What the package does, how to use it, examples |
| At least one script | The deployment script(s) |

### Recommended files

| File | Purpose |
|------|---------|
| `TESTING.md` | How to test on a real machine (or target environment) |
| `tests/` folder | Functional test scripts that verify the scripts work |

### Terminology

| Term | Meaning |
|------|---------|
| **Package** | A script folder with its scripts, docs, and tests |
| **Validation** | Checks that scripts follow the standard (syntax, help, metadata, lint) — run via language-specific validation tools |
| **Tests** | Functional tests that verify scripts actually work on a target machine — live in `<package>/tests/` |

---

## Checklist Before Committing

- [ ] Script follows the standard (metadata, logging, help, argument parsing)
- [ ] All 5 metadata fields are set
- [ ] Help flag produces standard format
- [ ] Validation passes for every folder containing changed scripts
- [ ] No lint errors
- [ ] Script is idempotent (safe to run twice)
- [ ] Every action is verified (file created? directory removed? process stopped?)
- [ ] All error logs have unique error identifiers (`ERR001`, `ERR002`, etc.)
- [ ] Logging uses standard functions — no raw output
