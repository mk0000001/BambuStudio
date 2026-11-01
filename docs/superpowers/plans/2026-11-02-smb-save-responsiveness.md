# SMB Save Responsiveness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove redundant hidden-home recent-file scans during 3MF saving, investigate the separate Windows picker stall, and deliver a tested, reviewable Bambu Studio fork and upstream draft PR.

**Architecture:** Coalesce recent-list refresh requests in a small C++17 policy object. WebViewPanel collects metadata only when the target home browser is shown on screen; its existing idle hook consumes a pending request after visibility changes, avoiding thread/lifetime changes. Analyze the native picker separately and retain measured and unverified conclusions distinctly.

**Tech Stack:** C++17, wxWidgets, Catch2, CMake, Windows x64 GitHub Actions, WSL Ubuntu 24.04/GCC 13.3 for focused tests.

**Spec:** `docs/superpowers/specs/2026-11-01-smb-save-responsiveness-design.md` (approved 2026-11-02).

## Global Constraints

- Keep all GUI and webview access on the GUI thread. No `wxYield()` or unmanaged detached threads.
- Do not change project file format, mesh serialization, slicing, printer networking, or save-success/error semantics.
- Preserve recent-list order, timestamp format, missing-file labels, image protocol, persistence and configured capacity.
- Never overwrite original user projects for diagnosis. Do not publish private configuration or file paths.
- Keep “measured API latency,” “policy tests passed,” “app built,” and “GUI fix verified” as separate evidence levels.
- User approved proceeding through implementation, GitHub fork/upload and upstream PR; use native execution in this chat.

## Review Focus

- Initial hidden-page requests for `INT_MAX` must survive later requests for image `0` or metadata `-1`.
- Showing a child browser while its parent is hidden must not dispatch; a later idle with the target actually visible must flush once.
- Switching from MakerWorld to home/recent must deliver pending data even if the parent panel was already shown.
- Missing/offline history entries must not be queried at all while the home browser is hidden.
- Saving remains synchronous elsewhere; no claim that picker stalls or all SMB stalls are fixed without GUI evidence.

---

### Task 1: Defer and coalesce hidden recent-list scans

**Files:**
- Create: `src/slic3r/GUI/RecentProjectsRefresh.hpp`
- Modify: `src/slic3r/GUI/WebViewDialog.hpp`, `WebViewDialog.cpp`
- Create: `tests/slic3rutils/recent_projects_refresh_tests.cpp`
- Modify: `tests/slic3rutils/CMakeLists.txt`

**Interfaces:**
- Produces `Slic3r::GUI::RecentProjectsRefresh::request(int images)` and `take(bool ready) -> std::optional<int>`; requests merge by largest image index, deferred nonnegative requests widen to INT_MAX for reordered thumbnails, and take consumes only when ready.
- WebViewPanel retains public `SendRecentList(int)` and gains private `FlushRecentList()`; existing idle hook invokes the flush.

- [x] Write Catch2 tests for hidden requests returning no dispatch value, once-only visible consumption, repeated hides/shows, visible requests, `-1`/`0`/positive/`INT_MAX` coalescing, and no pending state initially.
- [x] Compile/run before implementation; confirm failure is the absent production header/policy.
- [x] Implement the header and integrate request/flush with `m_browser && m_browser->IsShownOnScreen()`; check readiness before metadata or JS work. Keep pending data until the actual target browser is visible. Preserve existing staff-pick show handler.
- [x] Compile/run focused tests using `g++ -std=c++17 -Wall -Wextra -pedantic -I src -I tests -DCATCH_CONFIG_MAIN tests/slic3rutils/recent_projects_refresh_tests.cpp -o /tmp/bambu-recent-refresh-tests && /tmp/bambu-recent-refresh-tests` from the WSL-mounted checkout. Expected: all tests pass.
- [x] Verify wx integration by inspection, add the test source to the existing suite, run `git diff --check`, and commit the focused patch.

### Task 2: Publish fork branch and run Windows build/test CI

**Files:**
- Create fork-only `.github/workflows/smb-save-validation.yml` to compile focused tests on Windows and Linux and optionally call upstream Windows x64 dependency/application build workflow.
- Keep fork-only CI, plans and investigation docs separate from the upstream code branch.

**Interfaces:**
- Consumes Task 1's policy header/test and clean patch commit.
- Produces fork URL, exact branch SHA, focused test results and actual Windows build artifact or concrete build failure.

- [x] Create/verify `mk0000001/BambuStudio` fork; retain upstream remote and use a dedicated feature branch, never push upstream master.
- [x] Upload focused patch using connected GitHub tools if local Git credentials are unavailable. Read all changed file content from disk, and publish one tree/commit rather than one commit per file.
- [x] Add a fork-only validation branch/CI that does not trigger a broad multi-OS dependency build. Compile the actual Task 1 tests with Windows MSVC and Linux GCC; include baseline-negative control where practical.
- [x] Enable fork Actions as needed and dispatch Windows x64 build using the observed upstream workflow. Monitor actual results, fix only task-relevant build problems, and retain honest limitations for unrelated baseline issues.
- [x] If a full portable artifact builds, download and inspect it before running, and use an isolated app data directory for GUI tests. Record artifact checksum/commit.

### Task 3: Validate SMB behavior and investigate picker independently

**Files:**
- Add/update `docs/superpowers/investigations/2026-11-02-smb-validation.md` on the investigation branch.
- Diagnostic scripts/harnesses belong to fork investigation tooling or ignored execution workspace, not automatically to the upstream patch.

**Interfaces:**
- Consumes Task 2's built artifact if available, plus existing installed baseline apps and verified source differences.
- Produces actual before/after timings, saved archive verification, and a separate evidence-based disposition for the picker stall.

- [x] Measure baseline and patched saves using disposable synthetic or copied projects across local/mapped/UNC destinations, long history, missing entries, repeated Save and Save As; reopen saved ZIPs and inspect integrity.
- [x] Verify return to home/recent with expected thumbnails and timestamps, hidden parent and window minimize/restore. Pending consumption is tested once-only.
- [ ] Exercise the online hidden-home-child browser route natively: the corresponding menus were absent in the isolated profile; source transitions were inspected and the gap is recorded.
- [ ] Trace or isolate legacy-vs-modern picker behavior with matched folder/view settings and no persistent changes to network mappings or user preferences. Do not infer an API replacement is a proven fix from source differences alone.
- [x] If the exact picker hang cannot be reproduced/captured, save a reproducible diagnostic path and explain that limitation; do not apply an unrelated wxWidgets upgrade or declare the whole symptom fixed.
- [x] Record tests, commands, versions, measurements and outstanding gaps. Commit only shareable findings; redact local identities/paths.

### Task 4: Whole-branch review and upstream draft PR

**Files:**
- Fork investigation report and upstream PR description (English).

**Interfaces:**
- Consumes focused patch, test/build evidence and Task 3's honest limitations.
- Produces reviewed fork, upstream draft PR and linked artifacts.

- [x] Search existing upstream issues/PRs for the same recent-list fix before submitting.
- [x] Dispatch one fresh code reviewer for the whole focused branch, with this plan/spec and execution ledger; assess integration and lifetime concerns deliberately.
- [x] Resolve important findings, run the covering tests RED→GREEN and rerun the focused suite. Keep build/GUI failures separate from policy test success.
- [x] Open an upstream draft PR describing only the focused change and actual verification. Include measured component latency and unresolved picker/full-app limitations; do not claim next-release acceptance.
- [ ] Attach the PR to this chat and deliver fork/branch/PR and actual artifact links, along with any required next action if an external blocker remains.
