# USB Testing on a Private Mac

How to test the Rancher Desktop scripts on a private Mac, emulating Jamf behavior.

## Before you start

**WARNING: These tests will destroy ALL Docker/container data on this Mac.** The install and uninstall scripts wipe Rancher Desktop completely, including:

- All Docker images, containers, and volumes
- All Kubernetes resources
- All Rancher Desktop configuration and preferences

**Do NOT run these tests on a Mac that has important container data.** Use a clean test machine or a Mac where you don't mind losing everything. Files on the host filesystem (outside of containers) are not affected.

## test.log

When running the tests a file logs/test.log is created. It contains all info about the test.
You can see an example of the [test.log here](tests/example-test.log)

## What Jamf does

Jamf runs scripts as **root** via `bash /path/to/script.sh`. There is no interactive terminal — scripts must work unattended. Running with `sudo bash` on your Mac is equivalent.

## How to run the tests

1. Copy the `scripts-mac/rancher-desktop/` folder to a USB stick
2. Plug the USB into your Mac
3. Open Terminal and run:

```bash
cd /Volumes/<USB_NAME>/rancher-desktop
bash tests/run-all-tests.sh
```

The script runs all 10 tests in order. It will:

- Tell you what each test does
- Auto-verify profile values (no manual checking needed for most tests)
- Auto-launch and auto-quit Rancher Desktop
- Auto-verify Docker commands
- Only prompt you for things that require visual GUI inspection (4 prompts total)
- Let you skip tests or quit early
- Print a pass/fail summary at the end

Everything is logged to `logs/test.log`. Bring the USB back so Claude Code can read the log.

### Running individual tests

If you need to re-run a single test, use the individual test scripts:

```bash
sudo bash tests/test-1-install.sh
sudo bash tests/test-2-first-launch.sh
# ... etc
```

These don't log to file — use `run-all-tests.sh` for a full logged session.

---

## Part 1: Clean machine (tests 1–8)

Start with Rancher Desktop **not installed**. Tests run in order — each builds on the previous.

### Test 1: Fresh install (fully automated)

**What the script does:**

1. Runs `rancher-desktop-install.sh` with default settings
2. Checks that `/Applications/Rancher Desktop.app` exists
3. Auto-verifies profile values: moby, k8s disabled, memoryInGB, numberCPUs

**What you need to do:**

- Nothing — this test is fully automated. Watch the output for PASS/FAIL.

---

### Test 2: First launch + Docker (1 manual check)

**What the script does:**

1. Auto-launches Rancher Desktop and waits for Docker to be ready
2. Asks you to check Preferences (manual — GUI visual check)
3. Auto-runs `docker version` and `docker run --rm hello-world`
4. Auto-quits Rancher Desktop

**What you need to do:**

1. When prompted, open **Preferences** and check:
   - Container Engine = Docker (moby)
   - Kubernetes = disabled
   - Virtual Machine shows the auto-detected RAM and CPU values
2. Answer the prompt (y/n)

---

### Test 3: K8s plist merge (fully automated)

**What the script does:**

1. Prints the deployment profile (BEFORE)
2. Runs `rancher-desktop-k8s.sh --enable`
3. Prints the deployment profile (AFTER)
4. Auto-verifies `enabled => 1` and all other keys preserved

**What you need to do:**

- Nothing — this test is fully automated. Watch the output for PASS/FAIL.

**Why this matters:** The k8s script uses PlistBuddy to merge a single key. If the merge is broken, it would destroy the keys set by the install script.

---

### Test 4: Config partial update (fully automated)

**What the script does:**

1. Prints the deployment profile (BEFORE)
2. Runs `rancher-desktop-config.sh --memory 6`
3. Prints the deployment profile (AFTER)
4. Auto-verifies `memoryInGB => 6`, `numberCPUs` unchanged, all other keys preserved

**What you need to do:**

- Nothing — this test is fully automated. Watch the output for PASS/FAIL.

**Why this matters:** The config script only passed `--memory`, not `--cpus`. Only the memory value should change — everything else should be preserved.

---

### Test 5: Uninstall safety check

**What the script does:**

1. Runs `rancher-desktop-uninstall.sh` **without** `--confirm`
2. Verifies the app and profile still exist

**What you need to do:**

- Confirm the script printed an error about `--confirm` being required
- Confirm nothing was deleted

**Why this matters:** The uninstall script destroys all container data. The `--confirm` flag prevents accidental runs.

---

### Test 6: Full uninstall

**What the script does:**

1. Runs `rancher-desktop-uninstall.sh --confirm`
2. Checks that the app, profiles, user data, and symlinks are all removed

**What you need to do:**

- Read the verification output
- Confirm everything says "OK" or "removed"

**What gets removed:**

- `/Applications/Rancher Desktop.app`
- `/Library/Managed Preferences/io.rancherdesktop.*` (deployment profiles)
- `~/Library/Application Support/rancher-desktop` (user data)
- `docker`, `kubectl` symlinks (if they pointed to Rancher Desktop)

---

### Test 7: Reinstall with custom params (1 manual check)

**What the script does:**

1. Runs `rancher-desktop-install.sh --memory 8 --cpus 4 --kubernetes`
2. Checks the app exists and auto-verifies profile values
3. Auto-launches Rancher Desktop
4. Asks you to check Preferences (manual — GUI visual check)
5. Auto-quits Rancher Desktop

**What you need to do:**

1. When prompted, open **Preferences** and check:
   - Container Engine = Docker (moby)
   - Kubernetes = enabled
   - Virtual Machine shows 8 GB memory and 4 CPUs
2. Answer the prompt (y/n)

**Why this matters:** After a full uninstall, there should be no leftover state causing problems with a fresh install.

---

### Test 8: Uninstall with --keep-profile

**What the script does:**

1. Runs `rancher-desktop-uninstall.sh --confirm --keep-profile`
2. Checks that the app is removed but profile files are kept
3. Cleans up the leftover profiles at the end

**What you need to do:**

- Confirm the app was removed
- Confirm the profile files still exist in `/Library/Managed Preferences/`

**Why this matters:** Some teams want to uninstall the app but keep the deployment profile so the next install picks up the same settings.

---

## Part 2: Locked profiles (tests 9–10)

These tests need Rancher Desktop **installed and launched at least once** so the user has saved preferences. The master script handles the reinstall and first launch between Part 1 and Part 2.

**What happens before Part 2:**

1. The script reinstalls Rancher Desktop for you
2. Auto-launches Rancher Desktop and waits for Docker to be ready (initial setup)
3. Auto-quits Rancher Desktop

### Test 9: Locked k8s profile (1 manual check)

**What the script does:**

1. Runs `rancher-desktop-k8s.sh --disable --lock`
2. Auto-verifies locked profile values
3. Auto-launches Rancher Desktop
4. Asks you to check that the Kubernetes checkbox is greyed out (manual — GUI check)
5. Auto-quits Rancher Desktop and cleans up the locked profile

**What you need to do:**

1. When prompted, go to **Preferences > Kubernetes**
2. Confirm the checkbox is **greyed out** (user cannot change it)
3. Answer the prompt (y/n)

**Why this matters:** The `--lock` flag writes to a locked profile that overrides user preferences. The UI should prevent the user from changing the locked setting.

---

### Test 10: Locked config profile (1 manual check)

**What the script does:**

1. Runs `rancher-desktop-config.sh --memory 4 --cpus 2 --lock`
2. Auto-verifies locked profile values
3. Auto-launches Rancher Desktop
4. Asks you to check that the VM sliders are greyed out (manual — GUI check)
5. Auto-quits Rancher Desktop and cleans up the locked profile

**What you need to do:**

1. When prompted, go to **Preferences > Virtual Machine**
2. Confirm the sliders are **greyed out** (user cannot change them)
3. Answer the prompt (y/n)

**Why this matters:** Same as test 9 — locked profiles enforce settings. The UI should show the locked values and prevent changes.

---

## Quick reference: inspecting profiles

```bash
# Print a profile in human-readable format
plutil -p "/Library/Managed Preferences/io.rancherdesktop.profile.defaults.plist"

# Validate XML
plutil -lint "/Library/Managed Preferences/io.rancherdesktop.profile.defaults.plist"

# Read a specific key
/usr/libexec/PlistBuddy -c "Print :kubernetes:enabled" \
  "/Library/Managed Preferences/io.rancherdesktop.profile.defaults.plist"

# List all profiles
ls -la /Library/Managed\ Preferences/io.rancherdesktop.*
```

## Troubleshooting

**"PlistBuddy not found"** — You are not running on macOS. The k8s and config scripts require macOS.

**"Cannot write to /Library/Managed Preferences"** — Run with `sudo`.

**Rancher Desktop won't start after profile change** — The profile may have invalid XML. Check with `plutil -lint`. If broken, delete the profile and try again:

```bash
sudo rm "/Library/Managed Preferences/io.rancherdesktop.profile.defaults.plist"
```

**Settings didn't change after restart** — You likely wrote to the defaults profile on a machine that already had Rancher Desktop configured. Use `--lock` instead. See the "Deployment profiles" section in README.md.
