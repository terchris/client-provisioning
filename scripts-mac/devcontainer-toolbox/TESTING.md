# USB Testing on a Private Mac

How to test the devcontainer-toolbox scripts on a private Mac, emulating Jamf behavior.

## Before you start

**Prerequisites:** Rancher Desktop must be installed and running on the test Mac. The devcontainer-toolbox scripts depend on Docker, which is provided by Rancher Desktop. If Rancher Desktop is not installed, install it first using `scripts-mac/rancher-desktop/rancher-desktop-install.sh`.

These tests will:

- Pull a Docker image (~1-2 GB download)
- Install `devcontainer-init` to `/usr/local/bin`
- Create and remove temp folders in `/tmp`
- Clean up everything at the end (test 6)

## test.log

When running the tests a file `logs/test.log` is created. It contains all info about the test. Bring the USB back so Claude Code can read the log.

## What Jamf does

Jamf runs scripts as **root** via `bash /path/to/script.sh`. There is no interactive terminal — scripts must work unattended. Running with `sudo bash` on your Mac is equivalent.

## How to run the tests

1. Copy the `scripts-mac/devcontainer-toolbox/` folder to a USB stick
2. Plug the USB into your Mac
3. Make sure Rancher Desktop is running
4. Open Terminal and run:

```bash
cd /Volumes/<USB_NAME>/devcontainer-toolbox
bash tests/run-all-tests.sh
```

The script runs all 7 tests in order. It will:

- Verify Rancher Desktop is installed and Docker is running
- Run each test automatically (no manual checks needed)
- Let you skip tests or quit early
- Print a pass/fail summary at the end

Everything is logged to `logs/test.log`.

### Running individual tests

If you need to re-run a single test:

```bash
sudo bash tests/test-0-prerequisites.sh
sudo bash tests/test-1-pull.sh
# ... etc
```

These don't log to file — use `run-all-tests.sh` for a full logged session.

---

## Test 0: Prerequisites (fully automated)

**What the script does:**

1. Checks Rancher Desktop is installed (`/Applications/Rancher Desktop.app`)
2. Checks `docker` command is available in PATH
3. Checks Docker daemon responds to `docker ps`

**What you need to do:**

- Nothing — this test is fully automated. If it fails, install and start Rancher Desktop first.

---

## Test 1: Pull image (fully automated)

**What the script does:**

1. Runs `devcontainer-pull.sh`
2. Verifies exit code is 0
3. Verifies the image exists locally with `docker images`

**What you need to do:**

- Nothing — this test is fully automated. The image download may take a few minutes.

---

## Test 2: Install command (fully automated)

**What the script does:**

1. Runs `devcontainer-init-install.sh` (installs to `/usr/local/bin`)
2. Verifies the file exists and is executable
3. Verifies `devcontainer-init` is available in PATH
4. Verifies `devcontainer-init -h` works

**What you need to do:**

- Nothing — this test is fully automated.

---

## Test 3: Fresh init (fully automated)

**What the script does:**

1. Creates a temp folder
2. Runs `devcontainer-init.sh -y` on the temp folder
3. Verifies `.devcontainer/devcontainer.json` was created
4. Verifies the JSON file is valid
5. Verifies no backup was created (fresh folder should not need one)

**What you need to do:**

- Nothing — this test is fully automated.

---

## Test 4: Init with backup (fully automated)

**What the script does:**

1. Creates a temp folder with an existing `.devcontainer/` containing a marker file
2. Runs `devcontainer-init.sh -y` on the temp folder
3. Verifies `.devcontainer.backup/` was created with the marker file
4. Verifies the marker file content is preserved
5. Verifies new `.devcontainer/devcontainer.json` was created and is valid JSON

**What you need to do:**

- Nothing — this test is fully automated.

**Why this matters:** When a developer runs `devcontainer-init` on a project that already has a `.devcontainer/` folder, the script must back up the existing config before replacing it. This test confirms the backup works and preserves the original files.

---

## Test 5: Init error paths (fully automated)

**What the script does:**

Tests three error scenarios:

1. **Backup already exists** — runs `devcontainer-init.sh` on a folder that already has `.devcontainer.backup/`. Should refuse with ERR009.
2. **Nonexistent path** — runs `devcontainer-init.sh` on `/nonexistent/path`. Should refuse with ERR002.
3. **Target is a file** — runs `devcontainer-init.sh` on a file instead of a directory. Should refuse with ERR003.

**What you need to do:**

- Nothing — this test is fully automated.

**Why this matters:** Error handling prevents data loss and gives clear feedback when something is wrong.

---

## Test 6: Cleanup (fully automated)

**What the script does:**

1. Removes `/usr/local/bin/devcontainer-init`
2. Removes all temp test directories from `/tmp`
3. Verifies cleanup is complete

**What you need to do:**

- Nothing — this test is fully automated.

---

## Troubleshooting

**"Rancher Desktop is not installed"** — Install Rancher Desktop first. Use `sudo bash scripts-mac/rancher-desktop/rancher-desktop-install.sh` or install manually from [rancherdesktop.io](https://rancherdesktop.io/).

**"Docker daemon is not running"** — Open Rancher Desktop and wait for it to finish starting. The Docker daemon takes a minute to be ready.

**"Failed to pull image"** — Check your internet connection. The image is ~1-2 GB and requires access to Docker Hub.

**"Permission denied" on /usr/local/bin** — The test runner should handle sudo elevation automatically. If running individual tests, use `sudo bash tests/test-2-install.sh`.
