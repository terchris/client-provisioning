# Quick Git Reference

A cheat sheet for the git commands you need when working with this repo. All commands are run in the VS Code terminal inside the devcontainer.

To open a terminal in VS Code: go to **Terminal > New Terminal** (or press `` Ctrl+` ``).

---

## Everyday Commands

| Command                              | What it does                                |
|--------------------------------------|---------------------------------------------|
| `git pull`                           | Download the latest changes from the server |
| `git add -A`                         | Stage all your changes for saving           |
| `git commit -m "message"`            | Save your changes with a description        |
| `git push`                           | Upload your saved changes to the server     |
| `git status`                         | See what files you've changed               |

Or all in one line:

```bash
git add -A && git commit -m "describe what you changed" && git push
```

---

## See What Changed

```bash
# What files have you changed?
git status

# What exactly changed in those files?
git diff

# See the commit history (one line per commit)
git log --oneline
```

---

## Undo Changes

### Discard changes to a file (before committing)

```bash
git checkout -- path/to/file.sh
```

### Undo the last commit (keep the changes as unstaged)

```bash
git reset HEAD~1
```

### Restore a file from a previous version

```bash
# First, find the commit hash
git log --oneline

# Then restore the file from that commit
git checkout <commit-hash> -- path/to/file.sh
```

---

## Inspect History

```bash
# See what changed in a specific commit
git show <commit-hash>

# See who last changed each line of a file
git blame path/to/file.sh

# See the full history of a single file
git log --oneline -- path/to/file.sh
```

---

## Good Commit Messages

Describe *what* you changed:

- `"Update Rancher Desktop install to handle M1 Macs"`
- `"Fix devcontainer-init missing Homebrew check"`
- `"Add WSL2 detection script for Intune"`

Note: the pre-commit hook automatically bumps patch versions on any changed scripts.

---

## Beyond the Basics

For pull requests, branching, merging, pipelines, and other Azure DevOps operations, see [Git Hosting: Azure DevOps](ai-developer/GIT-HOSTING-AZURE-DEVOPS.md).
