# SMB 3MF save responsiveness — design draft

Status: approved by the user on 2026-11-02 (Asia/Seoul): “설계 승인, 그대로 끝까지 진행”.

## Intent

Reduce the temporary Windows “Not responding” state when saving 3MF projects to SMB, while preparing a focused Bambu Studio fork change that upstream maintainers can review for a future release. The user reports this for all 3MF projects, with eventual recovery, in Bambu Studio and QIDI Studio; OrcaSlicer does not show the same symptom in their normal use.

The first change targets a demonstrated source of unnecessary work during saving: synchronous refresh of a hidden home page's entire recent-project list. This is a latency contribution established by source inspection and API-level measurements, not yet a stack-trace-confirmed explanation of every second of the observed GUI freeze.

## Evidence

- Installed versions: Bambu Studio `02.08.02.61`, QIDI Studio `02.07.02.73`, OrcaSlicer config version `2.4.2`.
- Bambu source inspected at master `79df7ae309be398ed30c9f397c13c9911c2edc57` and release tag `v02.08.02.61` (`926a7192574bcb9b3a732e1ec59a46d79cb45466`).
- QIDI source inspected at `403b619d56147160bb883e94f95a7951245bc6d0`; Orca source at tag `v2.4.2` (`8500fcdccaa10b5099ac20d252af3a7c560046f1`) and current main.
- All three retain synchronous project serialization and direct ZIP writing to a destination-side `.tmp` file. This shared architecture alone does not establish why only two applications appear affected.
- `Plater::export_3mf()` calls `set_project_filename()` after a successful interactive save; `Plater::save_project()` calls it again. Each reaches `MainFrame::add_to_recent_projects()` and `WebViewPanel::SendRecentList(0)`.
- `SendRecentList()` calls `MainFrame::get_recent_projects()` synchronously. That function calls `boost::filesystem::last_write_time()` for every history entry, even when the home page is hidden and only the newest image was requested.
- Bambu's dependency definition selects Boost 1.84.0. Its Windows `last_write_time()` opens a handle, gets the timestamp, then closes the handle. Source: https://github.com/boostorg/filesystem/blob/boost-1.84.0/src/operations.cpp#L3513
- Actual history entries: Bambu 241 (15 missing), QIDI 124 (1 missing), Orca 18 (1 missing). Configured maximums differ greatly: 99999 / 9999 / 18. Do not publish private paths or full configuration files.
- A read-only Windows probe used the same public API sequence and access/share flags as Boost: `CreateFileW(FILE_READ_ATTRIBUTES | FILE_READ_EA, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS)`, `GetFileTime`, `CloseHandle`.
- One sequential scan took 2033.8 ms / 1127.5 ms / 163.0 ms respectively. These are component timings on this machine and SMB connection, not timings of the application save as a whole. Two scans can contribute roughly 4.1 s / 2.3 s / 0.3 s under those conditions.
- A diagnostic 8 MiB sequential UCRT write took 5.3 ms locally and 867.6 ms over SMB, including an `_ftelli64` before each 64 KiB write. Removing those position queries did not improve this one SMB comparison (1305.1 ms). There is no evidence here to justify modifying miniz's position handling. Uniquely named diagnostic files were deleted afterward.
- Native GUI A/B testing, a save-time thread trace, and a patched full application build have not yet been performed.

## Approaches

### Proposed: defer hidden recent-list refreshes

Keep history updates and project saving synchronous as today. When a recent-list refresh is requested while the web panel is hidden, remember the request instead of collecting metadata. Merge repeated requests. Widen deferred nonnegative image requests to all thumbnails (`INT_MAX`), because hidden saves can reorder history; retaining only the largest original index could miss an updated thumbnail. Preserve metadata-only refreshes (`-1`). When the panel becomes visible, send one fresh list; visible requests retain their exact image range unless a wider request is pending.

Advantages: small cross-platform change, removes the O(history size) SMB scan from the ordinary editor save path, follows an existing deferred home-page request pattern. It can be reviewed independently of the ZIP serializer.

Limitation: the first visible home-page refresh still performs synchronous metadata reads. Actual ZIP generation, thumbnail extraction for the newly saved project, configuration persistence, and other save-stage delays remain possible. This change must be described as eliminating redundant hidden-page work, not making all SMB I/O asynchronous.

### Alternative: asynchronously query all recent-project metadata

Snapshot paths and history identity on the GUI thread, query metadata on a worker, and publish results only if the panel and snapshot remain valid. Add lifetime, ordering, shutdown and bounded-concurrency handling.

Advantage: also prevents history scanning from freezing the visible home page. Tradeoff: materially larger lifecycle and concurrency change. Prefer as a separate follow-up if visible-page latency remains unacceptable.

### Alternative: stage every 3MF locally, then copy to SMB

Could reduce fragmented destination writes, but does not remove the demonstrated post-save history scans. Requires additional disk space and careful failure-safe replacement; cannot explain the observed difference in history sizes. Exclude from the first patch absent stronger evidence that archive writing is the dominant delay.

The user approved the minimal-first approach, followed by the remaining dialog investigation, verification, fork upload and upstream PR.

## Behavior and interfaces

1. A hidden `WebViewPanel::SendRecentList(images)` must not call `MainFrame::get_recent_projects()` or execute JavaScript.
2. Repeated hidden requests coalesce. Do not lose a prior all-thumbnail request when a later save requests only image zero.
3. On becoming visible, exactly one pending refresh is delivered using the current history; no pending request means no extra scan.
4. A visible explicit request still behaves as before and incorporates any pending wider image request.
5. The existing show-event behavior for pending staff picks must continue working. Propagate the wx show event correctly.
6. Home/recent navigation and page initialization must continue to obtain a complete initial list. Check both parent-panel visibility and child-browser visibility transitions before choosing the final trigger.
7. The current list order, missing-file label, timestamp format, image protocol, history persistence, and user-selected history capacity remain intact.
8. Keep all GUI and webview access on the GUI thread. No `wxYield()` or unmanaged detached threads.
9. Do not change project file format, mesh serialization, slicing, printer networking, or save-success/error semantics.

Likely files: `src/slic3r/GUI/WebViewDialog.cpp`, `WebViewDialog.hpp`; a small independently testable request-coalescing helper only if needed to test real production logic without constructing the heavyweight GUI. Tests belong to `tests/slic3rutils/` and its CMake source list. Follow existing project style and avoid unrelated cleanup.

## Validation and acceptance

- Regression test first: hidden requests do no dispatch; multiple requests dispatch once on show; `-1`, `0`, positive ranges and `INT_MAX` coalesce correctly; no duplicate dispatch after consumption; hiding again retains subsequent requests.
- Exercise the production request policy, not a separate reimplementation. Compile and run a focused C++17/Catch2 test using the repository's bundled Catch header. WSL Ubuntu 24.04 has GCC 13.3.0 available; the Windows host currently has no detected CMake/MSVC toolchain.
- Inspect actual wx integration, especially initialization, show-event timing, child browser visibility, tab switching, and use-after-destruction risks.
- Attempt a Windows portable CI build using the upstream dependency workflow in the fork. Keep the build limited to Windows x64 where possible. Report failures and incomplete builds explicitly; never label an unbuilt branch a tested executable release.
- GUI A/B matrix using disposable copies of a small 3MF: local disk, mapped SMB, UNC SMB, long recent history, missing recent files, repeated Ctrl+S, Save As, home/recent re-entry, and startup after a save. Confirm saved ZIP integrity and reopenability. Never overwrite the user's original project for diagnosis.
- Keep “measured API latency,” “policy tests passed,” “app built,” and “GUI fix verified” as separate evidence levels.

## Delivery

- Create a GitHub fork under authenticated account `mk0000001` with a focused `fix/smb-save-recent-refresh` branch based on Bambu master; retain upstream as a remote. The user has requested the fork and upload.
- Commit the design/investigation and implementation plan to the fork as appropriate; keep the upstream code PR focused on production code, targeted tests, and necessary build integration.
- Include an English cause explanation, verified measurements, reproduction steps, exact tested commit, and honest test limitations.
- Open an upstream draft PR once a reviewable patch and meaningful test evidence exist. Mark ready only after the relevant build and GUI validation succeed. Upstream acceptance and inclusion in the next release are maintainers' decisions.
- Share fork, branch, draft PR and any actual built artifact links. If publishing is blocked, preserve all local changes and provide the exact blocker.

## Approval and remaining investigation

The user approved this design and explicitly requested continuous execution through delivery. Execute the implementation plan in this chat; no additional design or execution-method confirmation is required for this approved scope.

The user subsequently confirmed freezes occur BOTH before/inside the Save As picker and after Save / Ctrl+S. Treat the pre-dialog path as a separate, unresolved investigation: native shell enumeration of SMB paths, wxWidgets' Windows dialog implementation, and focus callbacks. Do not claim the recent-list patch fixes pre-dialog stalls without tracing it. The inspected `MainFrame` activation handler only calls `Plater::on_activate()` to show a delayed error; there is no established activation-to-history-scan connection.

The first patch is a scoped contribution to the overall project. Complete save-dialog diagnosis and full GUI validation remain part of the user's requested outcome even if that patch passes its focused tests.

## Builder review and dialog investigation update

A separate read-only builder review raised one material scope question: whether the first delivered optimization must resolve both phases. Resolve this from the user's original objective by keeping both phases in the project acceptance criteria, while allowing individually reviewable patches. Do not declare the project complete after the recent-list patch alone.

The installed Bambu application's Save As dialog was opened once via Ctrl+Shift+S and cancelled via Escape. The first accessibility observation was temporarily unavailable; the next showed the Windows picker populated with the target SMB directory. This is not a quantitative timing or a captured “Not responding” reproduction. No file was saved during this probe.

There is an additional source-level difference relevant to the picker:

- Both Bambu and QIDI dependency manifests point to `bambulab/wxWidgets` master. At the inspected head `abb542694ef4534a50e65c5b877b2774d02952ae`, its Windows `wxFileDialog::ShowModal()` uses the legacy `GetSaveFileName` / `GetOpenFileName` path.
- OrcaSlicer 2.4.2 pins `SoftFever/Orca-deps-wxWidgets` tag `v3.3.2`. Its Windows dialog prefers the newer COM `IFileDialog` path, including `CLSID_FileSaveDialog`, with fallback to the legacy API.
- Sources: https://github.com/bambulab/wxWidgets/blob/abb542694ef4534a50e65c5b877b2774d02952ae/src/msw/filedlg.cpp and https://github.com/SoftFever/Orca-deps-wxWidgets/blob/v3.3.2/src/msw/filedlg.cpp
- This is a hypothesis about the pre-dialog stall, not proof that replacing the picker fixes it. The Bambu/QIDI dependency manifests track an unpinned branch, so these source heads also do not establish the exact wxWidgets commit used in the user's installed binaries.
- Investigate using matched initial folder, view mode, mapped/UNC path, shell extensions, and disconnected mapped drives. A disconnected mapping was observed, but no network mapping was modified and no causal claim is warranted.
