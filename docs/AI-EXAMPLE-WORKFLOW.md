# Example: From Idea to Merged Feature

A complete example showing how a user and Claude Code work together to investigate, plan, implement, and publish a feature.

> **Convention:** Lines starting with **YOU:** are what you type. Lines starting with **CLAUDE:** are what Claude responds. Indented blocks show file contents or command output.

---

## Step 1: Ask Claude to Investigate

You have an idea but aren't sure how to approach it.

**YOU:** I want to add a script that installs Rancher Desktop on Mac machines via Jamf. Can you investigate how this should work?

**CLAUDE:** I'll create an investigation for that. Should I create an `INVESTIGATE-*.md`?

**YOU:** Yes

**CLAUDE:** Created `docs/ai-developer/plans/backlog/INVESTIGATE-rancher-desktop-install.md`. Please review it.

> Claude researches the topic and writes findings into the investigation file:
> how Rancher Desktop installs on macOS, what configuration files it uses,
> what can be managed via Jamf MDM profiles, etc.

**YOU:** *\[Reviews the investigation file, adds comments or corrections\]*
Looks good. Now create a plan for the install script.

---

## Step 2: Claude Creates a Plan

**CLAUDE:** I'll create a plan based on the investigation. Should I create a `PLAN-*.md`?

**YOU:** Yes

**CLAUDE:** Created `docs/ai-developer/plans/backlog/PLAN-rancher-desktop-install.md`. It has 3 phases:

> ```
> Phase 1: Create the install script
> Phase 2: Create the uninstall script
> Phase 3: Add tests and documentation
> ```

Please review the plan and let me know if it looks good or needs changes.

**YOU:** *\[Opens the plan file, reads through phases and tasks\]*
Phase 2 should also handle keeping user data when uninstalling. Otherwise looks good. Plan approved, start implementation.

---

## Step 3: Claude Implements Phase by Phase

**CLAUDE:** Do you want to work on a feature branch? (recommended)

**YOU:** Yes

**CLAUDE:** Created branch `feature/rancher-desktop-install`. Moving plan to `active/`. Starting Phase 1...

> Claude writes the install script following the script standard,
> runs validation, and updates the plan file marking tasks as done.

**CLAUDE:** Phase 1 complete. Created `scripts-mac/rancher-desktop/rancher-desktop-install.sh`. Validation passes. Does this look good?

**YOU:** *\[Reviews the script\]*
Yes, continue.

**CLAUDE:** Starting Phase 2...

> This repeats for each phase. Claude commits after each phase,
> asks for confirmation, and continues to the next.

**CLAUDE:** All phases complete. 12/12 tests pass. Please review the changes.

**YOU:** Looks good, complete it.

---

## Step 4: Claude Publishes

**CLAUDE:** Done! I've:

> - Moved plan to `completed/`
> - Pushed the feature branch
> - Created PR #4151
> - Squash merged into main
> - Switched to main and pulled
> - Deleted the feature branch

Ready for the next task.

---

## What You Control

| You decide | Claude handles |
|------------|----------------|
| What to build | Investigation research |
| Whether to investigate first or go straight to a plan | Plan structure and phases |
| Plan approval and edits | Script writing and validation |
| Go/no-go after each phase | Git operations (branch, commit, PR, merge) |
| When to stop or change direction | Updating plan status and moving files |

You can say **"stop"** at any time and Claude will pause and wait for instructions.
