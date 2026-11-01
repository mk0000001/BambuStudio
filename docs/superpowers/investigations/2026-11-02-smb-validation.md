# SMB save investigation and validation

Status: active investigation, 2026-11-02 (Asia/Seoul). The focused upstream change is a draft: [BambuStudio PR #12850](https://github.com/bambulab/BambuStudio/pull/12850).

## Established latency contribution

At upstream `79df7ae309be398ed30c9f397c13c9911c2edc57`, a normal successful editor save can refresh the hidden home page twice. Each refresh synchronously obtains metadata for the entire recent-project history on the GUI thread. On Windows, the relevant Boost implementation opens each path, obtains its file time, and closes the handle. A large history on SMB therefore adds avoidable latency after saving.

The inspected QIDI fork has the same path. OrcaSlicer 2.4.2 (`8500fcdccaa10b5099ac20d252af3a7c560046f1`) also directly calls `SendRecentList(0)` from `add_to_recent_projects()` and synchronously collects recent-file metadata. Its much smaller history in this environment is a confounding variable. Later Orca main (`b5517b693e898261a6e28f940b110cd62683fede`) introduces lazy home-page construction and checks `WebViewPanel::if_built()` at that call site; that later implementation must not be mistaken for the installed 2.4.2 behavior. This evidence does not establish that all delays originate in Bambu-specific code.

The patch queues hidden home-page refreshes and consumes one refresh when the actual home browser is visible. Deferred nonnegative image requests widen to `INT_MAX`: saving A and then B can move both entries, so retaining only image index zero would leave A's thumbnail stale. Requests using the `-1` sentinel retain that argument. No background thread or delayed callback is introduced.

## Native Windows component benchmark

The fork's read-only diagnostic executable performs the relevant Win32 metadata sequence against locally supplied history paths. It compares two baseline scans with two requests while hidden and one refresh on returning home. The policy is the actual production header; the collector emulates Boost. These are single component measurements, **not end-to-end GUI save timings**.

| History | Entries | Baseline queries / ms | Patched hidden queries / ms | Return-home queries / ms |
| --- | ---: | ---: | ---: | ---: |
| Bambu Studio | 241 | 482 / 4353.79 | 0 / 0.0000 | 241 / 2141.60 |
| QIDI Studio | 124 | 248 / 2409.98 | 0 / 0.0001 | 124 / 1273.83 |
| OrcaSlicer | 18 | 36 / 370.552 | 0 / 0.0000 | 18 / 166.171 |

Configured history capacities and existing projects were not modified. Private history lists are not committed.

## Tests and review

- Catch2: six cases, 21 assertions, covering pending state, coalescing, once-only consumption, metadata-only requests and reordered thumbnail requests.
- The original tests failed before the policy header existed. The thumbnail regression failed before widening hidden requests and passed afterward.
- GCC 13.3 C++17 with `-Wall -Wextra -pedantic`: passes.
- Windows MSVC 19.51: passes, including execution of the downloaded diagnostic test executable on the affected PC.
- [Focused CI run 41321338926](https://github.com/mk0000001/BambuStudio/actions/runs/41321338926): Windows and Linux pass.
- Independent whole-patch review identified the thumbnail issue above; it was fixed and the covering test rerun. Native GUI behavior and full application compilation remain separate validation requirements.

The Windows diagnostic artifact SHA256 is `7a77b26db1a73d96ee12bcad18c38cdf98fb91de32e658869289215992e90fe1` (artifact 13088848395).

## Windows application build

The fork-only CI branch reuses official upstream Windows dependency artifact 11538406435 from run 37744640761. Its dependency source tree `dfcee1c78f98fa9ada89f461a2f4653ec9ad4cca` exactly matches the patch's upstream base. No private credentials or additional GitHub permissions were requested.

An initial configuration failed because an unquoted PowerShell `-DCMAKE_INSTALL_PREFIX=../install-dir` argument supplied an empty value. A small local CMake script reproduced the empty value, and quoting the complete argument retained the path. CI now quotes an absolute install path. [Run 41323002157](https://github.com/mk0000001/BambuStudio/actions/runs/41323002157) passed Windows/Linux focused tests and the full Windows application build, including compilation of `WebViewDialog.cpp`, linking, installation, packaging and artifact upload.

Windows artifact 13091314296 was downloaded and its SHA256 verified: `e609629459ed35117cb0ee14456935e6141167bd7367c4e17a6604297395dad5`. It was built from `d3f4c0eb5932953b1fcdba8ea36ae9617234aa3f`; its five product/test files exactly match upstream PR head `a81a1426225987e2ad735ef1618923c5c295380c`. The archive layout was checked before extraction. The tested application DLL SHA256 is `1dcf4f93ef5c4758094d54a9be403648d5968494b88dab6dcdc8b79c06395b17`.

For version-matched GUI comparison, official upstream artifact 11820868650 from run 38399527415 was downloaded and its SHA256 verified: `ebd2afc17c3f494a69a24a2165b01440014319be1360f452be12dbdc3eced0c5`. Test app data directories exclude account credentials, printer access codes and original recent paths. Original running projects are not overwritten.

## Separate Save As picker investigation

Source dependencies differ: the inspected Bambu/QIDI wxWidgets branch uses the legacy Windows picker path, while Orca 2.4.2's dependency prefers `IFileDialog` with fallback. Installed binary imports alone cannot prove which path ran, or identify the exact dependency commit used in those binaries. An API replacement is therefore not justified by the evidence so far.

With the user's explicit administrator approval, Windows WPR FileIO recorded an automated 45-second reproduction window followed by stop/merge and rundown; the resulting Bambu event span is approximately 70 seconds including that overhead. During the reproduction window, the installed Bambu Studio opened and cancelled Save As twice in the reported SMB directory. WPR successfully stopped and saved the ETL. No original project was saved. Raw ETL/CSV and private paths remain local.

`tracerpt` decoded FileIo version 3 records. Start and OperationEnd events were paired by IRP, following [Microsoft's documented correlation](https://github.com/MicrosoftDocs/win32/blob/docs/desktop-src/ETW/fileio-opend.md). The Bambu process contained 22,914 paired operations; its `bambustu_main` thread contained 11,659. The longest paired main-thread operation was 12.5186 ms; none exceeded 100 ms. This warmed, cancelled-dialog capture did **not** capture the reported long stall. It does not rule out intermittent shell, network, non-file waits, or save-stage delays. A FileIO trace also is not a complete sampled CPU/wait-stack diagnosis.

## Native GUI baseline

The version-matched official upstream application loaded the repository's synthetic 20 mm box STL using isolated configuration. Local, mapped-SMB and UNC Save As operations produced 3MF files with valid ZIP CRCs and well-formed model XML. The UNC archive was reopened through the recent-project card and displayed the expected three box instances. The original user projects and running application profiles were not changed.

A separate diagnostic SMB directory contains 226 copies of that synthetic archive and 15 nonexistent history paths, matching a 241-entry history. The metadata component probe on those paths measured 5917.6 ms for two scans and 2263.34 ms for one return-home scan.

The following observations are from pressing Save and then requesting the accessibility tree repeatedly within one automation call. They include input/automation overhead and measure availability of the accessibility tree, **not exact save duration or the Windows hung-window classification**. No arbitrary sleeps were inserted.

| Baseline operation, 241-entry SMB history | Accessibility observations after save input |
| --- | --- |
| Dirty local Ctrl+S (box duplicated) | unavailable at 3188 ms; available at 5273 ms |
| Mapped-SMB Save As | unavailable at 3167 and 6255 ms; available at 6383 ms |
| UNC Save As | unavailable at 3154 ms; available at 6029 ms |

This reproduces a multi-second save-associated interruption under controlled conditions and is consistent with the independently measured history-scan cost.

## Patched native GUI comparison

The patched full application used the same initial 241-path synthetic history and separate credential-free configuration. All 105 files under its `homepage3` resource directory were verified byte-identical to the official baseline. Before saving A, B and C while hidden, the initial full home refresh was displayed and consumed, so the thumbnail test also exercises saves after initialization.

| Patched operation | First accessibility observation after save input |
| --- | ---: |
| Local Save As | available at 1502 ms |
| Dirty local Ctrl+S | available at 641 ms |
| Mapped-SMB Save As | available at 1455 ms |
| Dirty mapped-SMB Ctrl+S | available at 887 ms |
| UNC Save As | available at 1490 ms |
| Dirty UNC Ctrl+S | available at 853 ms |

The same measurement limitations above apply. These are not repeated statistical benchmarks or exact archive-writing durations; the independently measured metadata component and the production gate establish what work the patch removes.

All three patched archives passed ZIP CRC and model XML checks. Their main 3MF build lists contained the expected two, three and four model instances. After hiding the home page for all saves and minimizing/restoring the window, returning home showed the correct C/B/A ordering, four/three/two-box thumbnails, and updated timestamps. The full recent page retained missing-file labels. Opening C from that page displayed the expected four selectable objects.

An online child-browser transition was not exercised because MakerLab/MakerWorld/manual entries were absent in the isolated test profile. The relevant `SetWebviewShow()` paths and existing idle event were inspected, but that is not native execution of those routes. No account or networking-plugin installation was added to expand testing. macOS/Linux GUI behavior and the optional full project test suite were not run.

## Remaining validation

- Obtain a trace during an actual long picker stall before proposing a picker implementation change.
- Exercise the online child-browser visibility route in an environment where that UI is available, and expand platform coverage as needed.
- PR #12850 remains a draft with the executed Windows evidence and these limits. Upstream acceptance and a future release remain maintainer decisions.

No claim is made that the entire reported symptom has been fixed.

## Test distribution

The [experimental Windows release](https://github.com/mk0000001/BambuStudio/releases/tag/smb-save-test-2026-11-02) contains the tested CI binaries plus a provenance README and the repository AGPL license text. The existing bundled notices remain present. Its ZIP passed CRC verification, and the packaged DLL still matches the tested DLL hash above. The ZIP contains no local trial profile, original recent paths or raw ETL/CSV.

Release ZIP SHA256: `6200ba17a8d865645ccc22f6b520284f37a1d06247617e3b36361374f93f44cf`.

![Native home-page verification: four, three and two boxes after hidden saves](https://github.com/mk0000001/BambuStudio/releases/download/smb-save-test-2026-11-02/patched-home-thumbnails.png)
