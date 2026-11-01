# SMB save investigation and validation

Status: active investigation, 2026-11-02 (Asia/Seoul). The focused upstream change is a draft: [BambuStudio PR #12850](https://github.com/bambulab/BambuStudio/pull/12850).

## Established latency contribution

At upstream `79df7ae309be398ed30c9f397c13c9911c2edc57`, a normal successful editor save can refresh the hidden home page twice. Each refresh synchronously obtains metadata for the entire recent-project history on the GUI thread. On Windows, the relevant Boost implementation opens each path, obtains its file time, and closes the handle. A large history on SMB therefore adds avoidable latency after saving.

The inspected QIDI fork has the same path. OrcaSlicer also has synchronous archive writing; its much smaller history in this environment is a confounding variable. This evidence does not establish that all delays originate in Bambu-specific code.

The patch queues hidden home-page refreshes and consumes one refresh when the actual home browser is visible. Deferred nonnegative image requests widen to `INT_MAX`: saving A and then B can move both entries, so retaining only image index zero would leave A's thumbnail stale. Metadata-only requests remain metadata-only. No background thread or delayed callback is introduced.

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

An initial configuration failed because an unquoted PowerShell `-DCMAKE_INSTALL_PREFIX=../install-dir` argument supplied an empty value. A small local CMake script reproduced the empty value, and quoting the complete argument retained the path. CI now quotes an absolute install path. [Run 41323002157](https://github.com/mk0000001/BambuStudio/actions/runs/41323002157) passed configuration and is compiling the full application; completion is not yet claimed.

For version-matched GUI comparison, official upstream artifact 11820868650 from run 38399527415 was downloaded and its SHA256 verified: `ebd2afc17c3f494a69a24a2165b01440014319be1360f452be12dbdc3eced0c5`. Test app data directories exclude account credentials, printer access codes and original recent paths. Original running projects are not overwritten.

## Separate Save As picker investigation

Source dependencies differ: the inspected Bambu/QIDI wxWidgets branch uses the legacy Windows picker path, while Orca 2.4.2's dependency prefers `IFileDialog` with fallback. Installed binary imports alone cannot prove which path ran, or identify the exact dependency commit used in those binaries. An API replacement is therefore not justified by the evidence so far.

With the user's explicit administrator approval, a Windows WPR FileIO capture ran for 45 seconds. During it, the installed Bambu Studio opened and cancelled Save As twice in the reported SMB directory. WPR successfully stopped and saved the ETL. No original project was saved. Raw ETL/CSV and private paths remain local.

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

This reproduces a multi-second save-associated interruption under controlled conditions and is consistent with the independently measured history-scan cost. A patched GUI comparison is still pending.

## Remaining validation

- Finish the patched full Windows build and inspect its artifact.
- Perform isolated native GUI before/after saves, archive integrity/reopen checks, and recent-page thumbnail/visibility checks.
- Obtain a trace during an actual long picker stall before proposing a picker implementation change.
- Keep PR #12850 draft until its native integration evidence is adequate. Upstream acceptance and a future release remain maintainer decisions.

No claim is made that the entire reported symptom has been fixed.
