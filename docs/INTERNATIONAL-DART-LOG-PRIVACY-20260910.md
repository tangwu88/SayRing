# Dart log privacy follow-up — 2026-09-10

## Scope and baseline

- Before this source round: `git status --short --branch`, `git remote -v`, `git fetch --prune origin`, `git rev-parse HEAD`, and `git rev-list --left-right --count HEAD...origin/main` confirmed international `main` at `c9faadae517ca40bd8c35b2e37de09ce2e54c345`, ahead/behind **0/0**. The existing dirty worktree belongs to the coordinated joint-QA task and was preserved; no pull/reset/clean/stash occurred.
- Only the health-record persistence error log and its new regression test were changed. No health data, account rules, Bluetooth flow, native SDK binary, domain, Pub Cache content or device state changed in this follow-up.

## Defect and fix

- P1: `_saveWearableRecord` logged the raw exception plus stack trace. A SQLite/platform exception can include SQL arguments, device identifiers, record values or other private material.
- Changed the log to a fixed stage string plus `error.runtimeType`. Removed metric selection, raw error text and stack trace from this log; the ordinary user-facing save-failure message remains unchanged.
- The regression injects a synthetic storage exception containing a synthetic record/device identifier, health value and test secret. It requires the entire output to equal `Health record persistence failed: PlatformException`, while preserving the visible device result, leaving the failed store empty, and keeping the original failure explanation. No production identity or real health data is in the fixture.

## Commands and outcomes

1. `dart format lib/services/app_controller.dart test/health_record_log_privacy_test.dart`: 2 files formatted.
2. `flutter test --no-pub --reporter expanded test/health_record_log_privacy_test.dart test/app_controller_account_wearable_test.dart`: **6 passed / 1 failed**. The new fake API omitted the public article read triggered by `initialize`, raising `UnimplementedError: getArticles`; this was a fixture omission, not a product persistence failure.
3. Added an empty synthetic article response to the fake, without changing real controller/API behavior. `dart format test/health_record_log_privacy_test.dart`: 1 file / 0 changes.
4. Repeated the same two-file test command: **7/7 passed**.
5. `dart analyze lib/services/app_controller.dart test/health_record_log_privacy_test.dart`: **No issues found**. Toolchain: `D:/Dev/Flutter/3.44.9/bin/{dart,flutter}.bat`.

## Yucheng Dart vendoring assessment — not implemented

- Existing dependency remains pinned to `5ca3050d7170509d386f548fcae7d5f8b457febf`. Its five Dart source files total approximately 167 KB; entrypoint, method channel, platform interface and types reference one another.
- A normal `dependency_overrides` path replaces the entire plugin root. The current Android settings derive the original native source from the resolved plugin project; CocoaPods also loads iOS from the same plugin root. A Dart-only replacement at that path would therefore break both native source resolutions.
- Maintaining the original pinned native plugin while overriding only selected Dart files would require a separately namespaced Dart fork or an additional source-generation/native-redirect workflow. Neither is a small removal of a few logging lines. Per this round's explicit simplicity boundary, that work was **not** introduced. The existing license, dependency pin, native sources and binary artifacts remain unchanged, and Pub Cache was not patched.
- Still-open source paths: `yc_product_plugin_method_channel.dart` prints the discovered device list, full callback event values, device information and measurement response; `yc_product_plugin_data_type.dart` prints a full parsed map. Native wrapper logging guards do not cover these Dart statements. They remain a privacy acceptance failure, not a completed fix. Future work should use a reviewed, authorized source fork/vendor release with reproducible Android/iOS resolution and runtime regression.

## Physical log audit supplied to the parent task

The preceding read-only check read only the scoped QA process logcat buffer; all dynamic payloads stayed in the inspecting process and only tag/count classifications were returned. It did not clear logs or stop tests. Counts are from one rolling buffer snapshot, not the entire run:

| Tag | Observation | Attribution |
| --- | --- | --- |
| `VPOperateManager` | 78 lines, all with MAC-shaped strings | SDK `VPOperateManager$vp_b.onDeviceFounded` directly calls Android `Log.e` with `SearchResult.toString`. |
| `BluetoothLESearcher` | 84 lines, 78 with MAC and UUID shapes | SDK `$2.onScanResult/onBatchScanResults` directly logs whole Android scan results. |
| `System.out` | 424 lines; 423 length/type lines; 1 MAC-shaped line | `VpBleByteUtil.isBrandDevice` unconditionally prints advertising length/type. Address conversion utilities also unconditionally print input/output addresses; the single runtime address line was not conclusively mapped before the rolling buffer advanced. |
| `BluetoothGatt` | 70 lines; 13 with UUID shapes in this snapshot | Android framework logging, separate from the SDK's directly emitted logs. |
| `SaydianNative` | 8 fixed-stage lines, no examined identity/value markers | The app wrapper's stage projection worked for those observed lines only. |
| `flutter` | 9 lines, 2 MAC-shaped | Specific lines were not retained or fully attributed; the Yucheng Dart scanning-list log is a source-confirmed reachable path. |

Read-only `javap -c -private` on the resolved `vpprotocol-2.3.77.15` / `vpbluetooth-1.20` runtime JARs confirmed these unconditional direct Android Log/System.out calls bypass the public `VPLogger`/`BluetoothLog` debug switches. The `Test` tag also has a direct log in `VPOperateManager`'s origin-history reader; that static stage output alone is not proof of raw health-value leakage.

This round did not patch, replace or instrument closed-source SDK binaries, intercept global stdout, suppress system logs, or claim complete log privacy. Absence of English health keywords in a snapshot is not proof that health values cannot be exposed. The parent task must retain native/third-party Dart privacy as a failed gate until a supported fix and fresh cold-start/scan/connect/sync capture pass.
