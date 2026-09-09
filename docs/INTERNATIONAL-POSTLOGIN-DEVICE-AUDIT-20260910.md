# Post-login device source audit — 2026-09-10

## Scope, baseline and evidence boundaries

- Read-only audit of the Android/Flutter device menu, real capability gates, read/write contracts and network/logging boundaries. Root alone operates the phone. This audit did not operate a phone, call a live SDK/server, read credentials, install a build, change runtime source or modify the Git index.
- Starting commands: `git status --short --branch`, `git rev-parse HEAD`, `git remote -v`, `git fetch origin --prune`, `git rev-list --left-right --count HEAD...origin/main`. Starting worktree was clean; `HEAD` and `origin/main` were `619484c24fea57af9fe28122916de14ffcb5dc88`, ahead/behind `0/0`. Concurrent inspection documents/fixtures appeared later and were left untouched.
- Read `AGENTS.md`, `CHANGE-TEST-LOG.md`, `INTERNATIONAL-HANDOFF.md`, `BUG-RETROSPECTIVE-20260829.md`, `REGRESSION-CHECKLIST.md`, the current authentication/device record, joint coverage matrix and native privacy record before drawing conclusions.
- The latest `INTERNATIONAL-AUTH-DEVICE-20260910.md` supersedes the historical `/global` 404 for the specifically recorded deployed/authentication paths. It records a preserved existing signed-in phone session on build `0.1.21+1004`. This subtask did not repeat live authentication or change that session.
- The matrix's diagnostic W9 connection/sync rounds and configuration reads remain evidence for that tested build/device only. They do not establish every feature's write/readback, another SDK/model's capabilities, or complete native egress/log privacy. Root's separate `INTERNATIONAL-POSTLOGIN-DEVICE-CHECK-20260910.md` owns the current phone results; the menu below is a proposed safe sequence, not a claim it was executed.

## Capability and bridge gates checked

| Layer | Current source behavior | Acceptance boundary |
| --- | --- | --- |
| Top-level device menu | `lib/ui/pages.dart` shows feature categories only when connected and capability state is `ready`; `AppController.visibleDeviceFeatures` intersects hardware `features` with `integratedFeatures` | Disconnected: connection/help only. Loading/unavailable: progress or retry, not a guessed complete directory. Empty categories remain hidden |
| Read/write/action entry | `lib/services/app_controller.dart` checks device availability, resolved capabilities, hardware support and integration before forwarding device operations | A supported hardware flag alone must not expose an unimplemented App action |
| Veepoo Android | `MainActivity.kt` combines reports/function packages and intersects integrated features; watch/photo-face integration additionally requires the JL platform path | These are reported capabilities, not a promise inferred from a marketing model name. The sport-mode exception below needs correction |
| Yucheng | `lib/services/yucheng_payload_mapper.dart` maps individual support bits; currently integrated feature set is find-watch, camera and watch-face switching. Bridge does not route its catalogue through Veepoo | A hidden Yucheng feature can mean App integration is absent, not that all watches lack that hardware. No conservative W8 list should become a visible fallback |
| Health monitoring route | Device menu opens `PermissionManagementPage(healthOnly: true)` in `lib/ui/pages.dart`, not the unused generic feature panel | Review the actual route's device settings reads and avoid switches/calibration; do not count unused panel code as working UI |
| Serial and completion behavior | Device features expose busy/loading states and route to native callbacks; several writes report callback success without a separate UI readback. Some methods, including alarm/watch-face operations, have stronger native verification | This audit did not execute writes or prove cancellation/reconnection races safe. A success toast alone is not independent configuration readback |

## Phone-safe read-only menu checklist

Run one visible page at a time, wait for its read to settle, then return. Never enter a hidden feature through a debug route to simulate model support. Record only page names, load/empty/error states and counts; do not put device addresses, contact contents, identifiers or health values in Git. A view may query the watch or approved catalogue but must not write settings.

| Visible operation | Actual source/read on entry | Safe action | Do not execute in this read-only round |
| --- | --- | --- | --- |
| Device home | Controller connection/capability state and cached device information | Inspect connection label, loading/retry state and non-empty categories | Connect/disconnect/switch device, synchronization or capability reset |
| Watch-face centre | `readDeviceFeature(watch_faces)`; Veepoo profile/list plus approved vendor preview enrichment; Yucheng watch list | Load list/previews and return; note unavailable catalogue separately | Apply/install/delete a face or begin a transfer |
| Photo watch face | Read compatible watch-face profile/list | View instructions/capability result only | Open photo picker, select private photo or send a face |
| Find watch | Action page, no automatic ringing on entry | Inspect page and return | Start/stop find action |
| Camera remote | `DeviceFeaturePage.initState` schedules camera initialization and enables watch remote mode automatically | **Skip entry**: opening is not read-only | Camera permissions, camera initialization, watch-mode enable or shutter |
| Phone calls | Android `readBTInfo` | Read status; return | Establish pairing/enable automatic connection/audio |
| Contacts | Android reads current watch contact list | Prefer skip when avoiding private contents; otherwise only inspect state/count with no raw UI dump | Pick phone contacts, add/edit/delete/sync; copying names/numbers into evidence |
| Notifications | Android `readSocialMsg` plus phone notification-access status | Read permission label and visible options; return | Toggle notifications, open/change system permission settings |
| Alarms | Android text/scene-alarm read | Read list, empty/error state and return | Toggle/add/edit/delete; do not confuse clearing stale local SDK alarm cache during a read with deleting watch alarms |
| Weather | Android weather/status read | Read current configuration; return | Sync weather, change city/enable flag, request location. Weather-provider configuration failure is not hardware absence |
| World clock | Android world-clock read | Read list/count and return | Add/remove/save clocks |
| Health reminders | Android reminders or legacy long-seat read | Read list/status only | Open interval editor until the valid-value issue below is handled; toggle/save/delete |
| Health monitoring | Actual `healthOnly` settings route and device settings reads | Read supported settings/state and return | Enable/disable monitoring, measure, calibrate or save |
| Health assessment | Android supported function-switch reads | Read supported assessment state and return | Toggle/save or perform an assessment |
| Screen display | Android sequential brightness/duration/raise-to-wake reads | Read currently supported controls and return | Slider/switch/time changes or Save; duration DTO issue below is not yet fixed |
| About device | Current device metadata/capabilities | View supported capability labels and return | Export raw diagnostics/device identifiers |
| Connection help | Local help/navigation | Open and return | Navigate into permission changes or reconnect actions |

The global synchronization button is not a read-only cloud action: it can persist and upload records for the current real account. No synthetic measurement, extra health upload, destructive watch reset, OTA, contact overwrite or face transfer belongs in this inspection. Cloud health-warning preferences are distinct from watch hardware capability settings.

## Confirmed source issues, not claimed as current-watch failures

| ID / priority | Evidence and deterministic condition | User impact / smallest correction to consider |
| --- | --- | --- |
| PD-01 / P2 | `lib/ui/prototype_pages.dart:3417` builds ten fixed notification rows. At `3465` the support flag is `supported?.contains(key) ?? true`; `_featureSwitch` renders unsupported rows disabled rather than omitting them. Android returns actual `supportedKeys` in `MainActivity.kt:4054` | With only `sms` supported, nine unsupported options still appear; if the field is absent all ten become enabled. Filter by explicit supported keys and use an unavailable/retry state for missing capability information. Add partial/empty/missing-list Widget fixtures |
| PD-02 / P2 | `MainActivity.kt:9171-9172` expands either `supportsAppSportControl()` or `supportsMultiSportMode()` into `running`, `walking`, `cycling`, `hiking`. These helpers read broad App-control/multisport flags, not four independent mode-support bits | Visible modes are inferred instead of verified per mode. Resolve supported modes from an authoritative SDK contract; do not assume a current device supports each mode merely because it reports multisport. Yucheng already maps individual support bits. Add source/contract fixtures that distinguish generic support from specific mode support |
| PD-03 / P2 | `DeviceScreenSettings.fromMap` reads duration min/max at `lib/domain/feature_models.dart:100-101`, but `toMap` at `115` omits both. The slider uses those bounds at `lib/ui/prototype_pages.dart:4867-4884`; Android write clamps with absent-bound defaults `1..60` at `MainActivity.kt:3911-3912` | If a watch reports an allowed maximum above 60, a valid UI selection such as 90 is silently sent as 60 while the callback can report success. Preserve authoritative bounds through the write contract or use validated native read-state bounds, then read back. Add a non-default-range DTO/bridge fixture. No current watch bound was assumed or changed |
| PD-04 / P2 | Reminder editor uses the raw read interval as `DropdownButtonFormField.initialValue` at `lib/ui/prototype_pages.dart:4286`, but items are only `[30,45,60,90,120]` at `4290`. Android reminder writes accept `15..240` at `MainActivity.kt:4728` and reads return the actual interval | A valid existing value such as 15 or 180 is absent from the dropdown items: debug builds assert when opening the editor and the selection cannot be faithfully represented in other builds. Include an actual valid returned value or consistently model the real allowed range. Add read-value fixtures for 15/180 and for invalid/missing values |

No fixes were made in this audit, and the existing green suite does not contain the four proposed regression fixtures. These findings are source/contract mismatches; they do not establish which interval/range/mode the currently connected watch actually reports.

## Request and logging boundaries

- Flutter device catalogue/weather/media reads use purpose-scoped `SafeResourceClient` allowlists. It validates before sending, disables automatic redirects and rejects redirect responses without issuing the next hop. Approved watch-face hosts are `vphband.com`/subdomains over HTTPS on the explicitly allowed ports; weather is the configured HTTPS QWeather API host. They are third-party exceptions, not fallback first-party API origins.
- `NetworkAudit` records host/port/method/kind, a route hash, status, validated request ID and outcome; it does not record request/response bodies, query values, authorization headers or raw health records. Update-check/download audit has dedicated mock privacy coverage.
- App-owned Android `PrivateStageLog` permits fixed stages and suppresses raw messages/exceptions; the native log source tests passed below. This is only a source-level check.
- The existing native privacy record still identifies closed Yucheng `YCBTLog.saveFile` logging outside the public open-log switch. Turning exposed SDK debug flags off and passing source checks does **not** establish zero raw SDK health logs. Keep raw runtime logs private and this vendor issue unresolved until a real verified fix exists.
- No Kotlin first-party business HTTP call was identified in the inspected App-owned device entry points. Closed SDK binaries and their possible endpoints are not proven silent by that result. This subtask performed no packet capture; the parent's previously observed new-domain requests do not prove every native SDK egress path has been covered.

## Commands and results

1. Read-only baseline commands above: clean initial `main`, fetched remote, same full commit and `0/0`.
2. `$env:TZ='UTC'; & 'D:\Dev\Flutter\3.44.9\bin\flutter.bat' test --no-pub --reporter expanded test/device_sdk_source_test.dart test/wearable_routing_test.dart test/yucheng_wearable_bridge_test.dart test/ui_shell_test.dart test/global_network_boundary_test.dart test/app_update_network_audit_test.dart test/health_record_log_privacy_test.dart` — **134 passed**, exit 0. Includes source capability guards, routed bridge/Yucheng behavior, device UI states, network redirect blocking and audit privacy. These are host fixtures, not real watch calls. Rejected old-host fixtures are deliberate mock cases, not real old-domain traffic.
3. `node --test tool/test_native_log_privacy.mjs` — **8 passed**, exit 0. Does not remove the closed-SDK runtime privacy limitation.
4. `gh run list --repo tangwu88/saydian-app-global --commit 619484c24fea57af9fe28122916de14ffcb5dc88 --limit 5 --json databaseId,workflowName,status,conclusion,headSha,url` — GitHub CLI returned **HTTP 404** for the private repository. CI result is **not verified by this subtask**, not a failed CI build. No account switch/login or credential extraction was attempted; root was notified to use its existing authorized channel if needed.
5. A final source-location search initially used two wrong guessed file paths; `rg --files lib android` resolved the actual `lib/ui/` and `android/app/src/main/kotlin/cc/saidian/saydian_app/` paths, and the bounded search/read was rerun successfully. No file was changed by the failed lookup.
6. `git diff --check` — exit 0. Because this new document is untracked, also ran `git diff --no-index --check -- NUL docs/INTERNATIONAL-POSTLOGIN-DEVICE-AUDIT-20260910.md`: no whitespace errors, exit 1 for the added-file difference; Git issued only its LF-to-CRLF working-copy warning. No compile, installation, live server query, runtime edit, Git staging, commit or push was performed by this audit.

## Handoff

- Root can use the safe menu sequence above while preserving the signed-in account and watch settings. Record actual phone findings separately, including hidden/unavailable/timeouts rather than marking every visible button passed.
- Four confirmed P2 contract/display gaps await scoped fixes and negative fixtures; do not silently replace this failure record after a later fix.
- Complete configuration write/readback/recovery, real mode control, notification delivery, camera operation, other models/firmware, complete native egress and closed-SDK log privacy remain outside this read-only acceptance.
