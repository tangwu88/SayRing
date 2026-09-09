# International recovery and bounded QA independent review — 2026-09-10

## Scope and baseline

- Independent, host-side review of the final per-SDK recovery drain/generation changes in `wearable_routing.dart`, their controller cancellation contract, and `global_joint_device_diagnostic.dart`.
- Read the repository instructions, international handoff, change/test index, environment-isolation and QA-driver records, and regression/retrospective guidance. Preserve the concurrent parent/other-agent modifications.
- Verified `main` / `c9faadae517ca40bd8c35b2e37de09ce2e54c345`; `git fetch --prune origin` succeeded and `git rev-list --left-right --count HEAD...origin/main` returned `0 0`. No merge, reset, stash, commit or push was performed by this reviewer.
- No product/test/driver source was modified or formatted. This new record is the only file changed in this review round. No phone, watch, server or package build was operated.

## Findings and resolution

1. The earlier canceled-recovery P1 is closed for the reviewed strict production recovery path. The actual connect/required-disconnect future remains tracked per SDK until native completion, independently of the caller's bounded timeout. A same-SDK connection is rejected with a retryable recovery-pending result while its old channel drains; timeout is not treated as native cancellation.
2. The earlier cross-SDK late-completion P1 is closed in the reviewed path. Cleanup checks the retired source's generation; it cannot clear a newer active SDK's connection ownership. Retired native events are suppressed while that source drains. The current tests explicitly keep a new Yucheng connection usable after late Veepoo completion and after a cleanup wait times out.
3. The QA driver remains isolated to its explicit Debug entrypoint/new-domain environment and exact configured target. Its per-operation timeout aborts the suite without adding speculative disconnect/reconnect commands; its settle polling has its own deadline. Account change, another device and active measurement/sport trigger an abort. Errors record static reason or exception type, not exception text, identifiers, credentials or raw health values. Newly added readiness/state observations use enums and Booleans; the event subscription is canceled at suite exit.
4. No new confirmed P0/P1/P2 was found in this focused review. This does not certify every device operation or full release behavior.

## Second-round live readiness observation — unresolved, not a product fix

- The existing sanitized `build/joint-qa-20260909/device-diagnostic-stream.log` records one successful cycle, including exact-target connection and repeat synchronization. In cycle two, disconnect completed in 222 ms, exact scan found one target, and the connect call returned after 3306 ms; then the driver's strict readiness postcondition failed while the final exact-target identity check remained true.
- That log does not include the failing connection-state enum, capability-state enum or error-presence detail. A later screenshot's background synchronization percentage does not establish `DeviceConnectionState.syncing`: controller background history synchronization updates separate progress fields, while a normal `_connectDevice` return reaches `ready` before starting background history.
- The parent subsequently observed user interaction at the login screen. The run was therefore not proven exclusive. There is insufficient evidence to assign this event to stale native disconnects, a duplicate connect, account transition, or another cause.
- The parent added state/readiness diagnostics for a future controlled run. This reviewer did not relax readiness requirements or modify connection logic on this hypothesis. Reproduce without concurrent app interaction, preserve the failure enum/Boolean evidence, then fix a demonstrated product fault if present.

## Executed commands and results

Toolchain: `D:/Dev/Flutter/3.44.9/bin`.

1. `flutter.bat test --no-pub --reporter expanded test/global_wearable_restore_test.dart test/wearable_routing_test.dart test/wearable_bootstrap_test.dart test/app_controller_wearable_restore_race_test.dart test/app_controller_account_wearable_test.dart test/global_joint_device_diagnostic_test.dart` — **48/48 passed**. This independently re-runs the 37 recovery/routing/controller tests plus 11 bounded-driver tests; synthetic fixture results are not real-device/server acceptance.
2. `dart.bat analyze lib/services/wearable_routing.dart lib/debug/global_joint_device_diagnostic.dart test/global_wearable_restore_test.dart test/global_joint_device_diagnostic_test.dart` — **No issues found**.
3. Read-only source searches initially had one PowerShell regex-quoting error and one guessed nonexistent UI filename. Re-ran searches using simple patterns and the existing `lib/ui/pages.dart`; no code, test, state or evidence was changed by those failed searches.
4. Full Flutter/timezone suites, native tests, Android builds, installation and physical three-cycle/device-to-server acceptance remain the parent task's separate integrated gate. No such acceptance is claimed by this review.
