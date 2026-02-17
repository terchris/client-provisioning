# Plan: Automate Test Runner — Reduce Manual Steps

## Status: Complete

## Context

USB testing on a private Mac (test.log from Feb 8 2026) showed that the tester had to respond to 12 manual y/n prompts and 9 "press Enter" waits. Many of these can be automated by:
- Parsing `plutil -p` output to verify profile values
- Using `open -a` to launch Rancher Desktop from the script
- Polling for Docker readiness instead of asking the tester to wait
- Using `rdctl list-settings` to verify running app settings (if available)

The goal is to reduce manual interaction to the absolute minimum — only things that truly require eyes on the GUI.

## Analysis from test.log

### Currently manual — CAN be automated

| Test | Manual step | How to automate |
|------|------------|-----------------|
| 1 | "Does profile show moby, enabled => 0, memoryInGB => 4, numberCPUs => 4?" | Parse `plutil -p` output, compare against expected values |
| 3 | "Is enabled => 1 AND are all other keys still present?" | Parse `plutil -p` output before/after, verify key added + others preserved |
| 4 | "Is memoryInGB => 6, numberCPUs unchanged, all other keys present?" | Parse `plutil -p` output before/after, verify changed + unchanged values |
| 7 | "Does profile show enabled => 1, memoryInGB => 8, numberCPUs => 4?" | Parse `plutil -p` output, compare against expected values |
| 2, 7, 9, 10 | "ACTION: Open Rancher Desktop, press Enter when running" | `open -a "Rancher Desktop"` + poll for readiness |
| 2 | "Did Docker commands succeed?" | Already auto-verified in current code (grep "Hello from Docker!") |
| Part 2 setup | "Open Rancher Desktop, let it start, then quit" | `open -a` + poll ready + `osascript quit` |

### Currently manual — CANNOT be fully automated

| Test | Manual step | Why it needs eyes |
|------|------------|-------------------|
| 2 | "Do Preferences show moby, k8s unchecked, 4 GB, 4 CPUs?" | GUI visual check |
| 7 | "Do Preferences show k8s enabled, 8 GB, 4 CPUs?" | GUI visual check |
| 9 | "Is Kubernetes disabled AND checkbox greyed out?" | Must verify UI element is disabled |
| 10 | "Does it show 4 GB / 2 CPUs AND sliders greyed out?" | Must verify UI element is disabled |

**Note:** Tests 2 and 7 could potentially be automated if `rdctl list-settings` is available after launch. The command reads the app's active configuration. If so, only tests 9 and 10 would remain manual (greyed-out verification).

### Already automated in current code (done in previous commit)

- Quit Rancher Desktop (osascript + retry loop)
- Docker hello-world auto-check
- Test 5 safety check (exit code + app existence)
- Test 6 full uninstall verification
- Test 8 keep-profile verification

---

## Implementation

### Helper function: `verify_plist_value()`

Add to `test-helpers.sh`:

```bash
# Verify a value in a plist file using plutil -p output
# Returns 0 if match, 1 if mismatch or key not found
verify_plist_value() {
    local file="$1" key="$2" expected="$3"
    local actual
    actual=$(plutil -p "$file" 2>/dev/null | grep "\"${key}\"" | awk -F "=> " '{print $2}' | tr -d ' ')
    if [ "$actual" = "$expected" ]; then
        echo "OK: ${key} => ${expected}"
        return 0
    else
        echo "FAIL: ${key} => ${actual} (expected ${expected})"
        return 1
    fi
}
```

### Helper function: `launch_rancher_desktop()`

Add to `test-helpers.sh`:

```bash
# Launch Rancher Desktop and wait for it to be ready
# For Docker tests: polls docker version until it succeeds
# For non-Docker tests: polls pgrep until the app is running
launch_rancher_desktop() {
    local wait_for_docker="${1:-false}"

    echo ">>> Launching Rancher Desktop..."
    open -a "Rancher Desktop"

    if [ "$wait_for_docker" = true ]; then
        echo ">>> Waiting for Docker to be ready (this may take a few minutes)..."
        local i
        for i in $(seq 1 60); do
            if docker version >/dev/null 2>&1; then
                echo ">>> Docker is ready (waited ~${i}0 seconds)"
                return 0
            fi
            sleep 10
        done
        echo ">>> WARNING: Docker not ready after 10 minutes"
        return 1
    else
        echo ">>> Waiting for Rancher Desktop to start..."
        local i
        for i in $(seq 1 30); do
            if pgrep -f "Rancher Desktop" >/dev/null 2>&1; then
                echo ">>> Rancher Desktop is running (waited ~${i}2 seconds)"
                return 0
            fi
            sleep 2
        done
        echo ">>> WARNING: Rancher Desktop not started after 60 seconds"
        return 1
    fi
}
```

### Helper function: `verify_rdctl_setting()` (if rdctl available)

```bash
# Verify a running app setting via rdctl (if available)
# This could replace manual Preferences checks for tests 2 and 7
verify_rdctl_setting() {
    local key="$1" expected="$2"
    if ! command -v rdctl >/dev/null 2>&1; then
        echo "SKIP: rdctl not available, manual check needed"
        return 2
    fi
    local actual
    actual=$(rdctl list-settings 2>/dev/null | grep "\"${key}\"" | awk -F': ' '{print $2}' | tr -d ', ')
    if [ "$actual" = "$expected" ]; then
        echo "OK: ${key} = ${expected} (via rdctl)"
        return 0
    else
        echo "FAIL: ${key} = ${actual} (expected ${expected}, via rdctl)"
        return 1
    fi
}
```

---

## Phases

### Phase 1: Add helper functions to test-helpers.sh
- [x] 1.1 Add `verify_plist_value()` — parse plutil output, compare key=value
- [x] 1.2 Add `verify_plist_key_exists()` — check key exists in plist
- [x] 1.3 Add `launch_rancher_desktop()` — open -a + poll for readiness
- [x] 1.4 Add `quit_rancher_desktop()` — osascript quit + retry + force kill
- [x] 1.5 Run `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop/tests` — 14/14 passed

### Phase 2: Auto-verify profile files (tests 1, 3, 4, 7)
- [x] 2.1 Test 1: Replace manual verify with `verify_plist_value` checks for moby, enabled, memoryInGB, numberCPUs
- [x] 2.2 Test 3: Auto-verify enabled => 1 + other keys preserved
- [x] 2.3 Test 4: Auto-verify memoryInGB => 6 + numberCPUs unchanged + other keys preserved
- [x] 2.4 Test 7: Auto-verify enabled => 1, memoryInGB => 8, numberCPUs => 4
- [x] 2.5 Run `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop/tests` — 14/14 passed

### Phase 3: Auto-launch/quit and Docker readiness (tests 2, 9, 10)
- [x] 3.1 Test 2: Replace manual launch with `launch_rancher_desktop true`, replace manual quit with `quit_rancher_desktop`
- [x] 3.2 Tests 9, 10: Replace manual launch/quit with `launch_rancher_desktop` / `quit_rancher_desktop`, add auto-verify of locked plist
- [x] 3.3 Run `bash docs/ai-developer/tools/validate-scripts.sh rancher-desktop/tests` — 14/14 passed

### Phase 4: Try rdctl for Preferences verification (tests 2, 7)
- [ ] 4.1 Investigate: Does `rdctl list-settings` work on stock Rancher Desktop install? What's the JSON format?
- [ ] 4.2 If yes: Auto-verify Preferences in tests 2 and 7 via rdctl, with manual fallback
- Skipped for now — requires testing on a real Mac with Rancher Desktop running

### Phase 5: Update run-all-tests.sh
- [x] 5.1 Apply same automation changes to the master test runner (removed prompt_launch/prompt_quit, replaced with shared helpers, added auto-verify for tests 1, 3, 4, 7, 9, 10)
- [x] 5.2 Update TESTING.md to reflect reduced manual steps
- [x] 5.3 Run full test suite — 7/7 main scripts + 14/14 test scripts passed

---

## Expected result after implementation

| Test | Before (manual steps) | After (manual steps) |
|------|----------------------|---------------------|
| 1 | y/n profile check | **Fully auto** |
| 2 | Launch app + y/n Preferences + y/n Docker | Auto-launch + auto-Docker + **y/n Preferences** (or auto if rdctl works) |
| 3 | y/n profile check | **Fully auto** |
| 4 | y/n profile check | **Fully auto** |
| 5 | Already auto | Already auto |
| 6 | Already auto | Already auto |
| 7 | y/n profile + Launch app + y/n Preferences | Auto profile + auto-launch + **y/n Preferences** (or auto if rdctl works) |
| 8 | Already auto | Already auto |
| 9 | Launch app + y/n greyed out | Auto-launch + **y/n greyed out** |
| 10 | Launch app + y/n greyed out | Auto-launch + **y/n greyed out** |
| **Total** | **12 prompts + 9 waits** | **2-4 prompts + 0 waits** |

---

## Files to modify

- `scripts/rancher-desktop/tests/test-helpers.sh` (new helper functions)
- `scripts/rancher-desktop/tests/run-all-tests.sh` (apply automation)
- `scripts/rancher-desktop/tests/test-1-install.sh`
- `scripts/rancher-desktop/tests/test-2-first-launch.sh`
- `scripts/rancher-desktop/tests/test-3-k8s-merge.sh`
- `scripts/rancher-desktop/tests/test-4-config-partial.sh`
- `scripts/rancher-desktop/tests/test-7-reinstall.sh`
- `scripts/rancher-desktop/tests/test-9-locked-k8s.sh`
- `scripts/rancher-desktop/tests/test-10-locked-config.sh`
- `scripts/rancher-desktop/TESTING.md`
