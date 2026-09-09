# International bounded device QA driver — 2026-09-10

## Purpose and boundaries

- Before modifying, update `origin` safely, inspect the worktree, and read `AGENTS.md`, `INTERNATIONAL-HANDOFF.md`, `CHANGE-TEST-LOG.md`, `BUG-RETROSPECTIVE-20260829.md` and `REGRESSION-CHECKLIST.md`. This round shares the parent task's fetched `main` baseline `c9faadae`; preserve all colleagues' changes.
- The ordinary application entrypoint does not import this driver. `lib/main_global_joint_qa.dart` uses the normal `SaydianApp` UI and real `AppController.production`, wearable bridges and API client. It is explicitly blocked in Release mode and outside HTTPS `app.saydian.cn:443` with `/global/api/saydian-app/v2`.
- `allowAutomaticWearableRestore: false` prevents startup/automatic recovery from selecting a previously saved watch before the private QA target is checked. Environment-specific storage still applies; old installation-level keys/databases are not adopted.
- This driver does not install packages, control ADB, create accounts, deliver OTP, pay, refund, ship, clear storage, start measurements, write settings/contacts/watch faces, launch the camera, or perform OTA. The parent operator owns physical-device authorization and observation.

## Private configuration and invocation

Build/run the explicit Debug target `lib/main_global_joint_qa.dart` using the approved international environment. Do not point this entrypoint at a local server. The default Release entrypoint remains `lib/main.dart`.

The operator supplies UTF-8 JSON in the application's private `getApplicationSupportDirectory()/global-joint-qa.json` (Android app files directory), using a private input channel rather than putting credentials in shell arguments or source control. Only these keys are accepted:

| Field | Meaning |
| --- | --- |
| `targetDeviceId` | Required exact routed identifier, prefixed `veepoo:` or `yucheng:`; obtain it from the authorized target, never select by name or signal strength. |
| `deviceOnly` | Optional Boolean, default false. True permits signed-out guest device testing only and explicitly excludes cloud acceptance. Cannot be combined with credentials. |
| `username`, `password` | Paired dedicated test-account credentials for cloud mode. No registration or automatic account creation. |
| `safeFindWatch` | Optional Boolean, default false. True permits the exposed find-watch start/stop command; physical response still needs a human observer. |

Configuration is limited to 8192 bytes, loaded with a 5-second deadline and not printed. Missing configuration performs no driver login, guest entry, scan or connection. Invalid configuration aborts without printing its contents. Device-only mode refuses to log out an existing account. Cloud mode reads international authentication capabilities before real login; a missing or non-global service aborts before scanning.

The driver rejects another connected device or an active measurement/sport operation. After authentication it locks the account identity for the run and aborts if it changes. Do not operate the app concurrently while the bounded run is active. Remove the private configuration when finished so a later QA entrypoint cold start cannot repeat authorized operations unexpectedly; do not delete application health data or credentials as cleanup.

## Operations and evidence interpretation

1. Wait for controller device work to settle, then scan and select only the exact configured ID.
2. Connect, require the exact target and ready state, await automatic synchronization, read device details/capabilities/battery availability, then request a manual sync.
3. Repeat for three rounds with serial disconnect/reconnect; a successful run leaves the same target connected.
4. Inspect all 14 feature entries. Only visible, integrated read operations execute. Camera/find-watch are action-only and skipped in the read sweep; health-monitoring settings expose counts but not a definitive success result. Empty responses are not accepted as successful data reads.
5. In cloud mode, attempt the controller's real synchronization and require separate server-side evidence for upload acceptance/readback. The driver never reports cloud acceptance from completion of a void method.

Commands normally have a 75-second deadline; synchronization/settling have a 4-minute deadline; initialization has 90 seconds. A timeout is not native cancellation: the driver aborts instead of queuing another operation or speculative disconnect. The settle loop has its own deadline so a timed-out polling future cannot continue reading controller state indefinitely. Normal controller/native queue protection remains in force.

Output uses `[SaydianJointQA]` JSON with static case/reason labels, counts, Booleans, status and elapsed milliseconds. No credentials, Token, full contact, target identifier/MAC/UUID, raw health values, raw errors or stack traces are logged by this driver. Unexpected errors use `runtimeType` only. SDK/network logs have separate privacy guards and acceptance records.

- `passed`: the stated narrow postcondition was checked; it does not imply all hardware behavior or backend persistence passed.
- `observed`: the call returned or state/count was observed; not proof of data validity.
- `skipped`: no operation executed, including unsupported/hidden features.
- `not_verified`: evidence is insufficient, e.g. empty health samples, pending upload counts not exposed by the public controller, settings reads without a success contract, or missing server readback.
- `failed`: the postcondition failed or an operation errored/timed out.
- `suite_complete` is always `partial` or `failed`, with `cloudAccepted: false`. A full joint acceptance requires the parent's domain, service readback, health values/idempotency, runtime logs, phone/watch and remaining functional checks.

Cached record counts cannot prove that a new device packet arrived or that repeated sync is idempotent. Do not reinterpret `nonemptyCache` as upload success or manufacture data to make it nonempty. This subtask does not expose new controller APIs solely to produce an apparent acceptance result.

## Files and change/test record

- Added `lib/main_global_joint_qa.dart`, `lib/debug/global_joint_device_diagnostic.dart`, and `test/global_joint_device_diagnostic_test.dart`.
- Parent added the optional automatic-recovery gate in `AppController`. A final minimal initializing-formal adjustment resolves `prefer_initializing_formals`; the public production factory parameter and default remain unchanged.
- `D:/Dev/Flutter/3.44.9/bin/dart.bat format lib/main_global_joint_qa.dart lib/debug/global_joint_device_diagnostic.dart test/global_joint_device_diagnostic_test.dart`: scoped formatting completed. Initial scoped analysis reported 14 style infos (curly control flow/null-aware map entries); corrected without changing behavior. Initial ten-case driver suite passed **10/10**.
- Added an explicit settle-poll deadline regression. First `flutter test --no-pub --reporter expanded test/global_joint_device_diagnostic_test.dart`: **10 passed / 1 failed** because the expired polling loop evaluated one more controller getter after the outer deadline. Moved its own deadline check before controller getter evaluation; no product timeout was relaxed.
- Repeated the same command after `dart format lib/debug/global_joint_device_diagnostic.dart`: **11/11 passed**. Cases cover exact environment, normal entrypoint separation, strict config, absent config, three guest cycles and final connection, existing-account refusal, non-global capability failure, login ordering, missing exact target, timeout abortion, account change, privacy of emitted records and termination of expired polling.
- `dart format lib/services/app_controller.dart`: completed the parent-requested initializing-formal lint fix. `dart analyze lib/services/app_controller.dart lib/services/wearable_routing.dart lib/main_global_joint_qa.dart lib/debug/global_joint_device_diagnostic.dart test/global_wearable_restore_test.dart test/global_joint_device_diagnostic_test.dart`: **No issues found**.
- The recovery/storage safety work and its review corrections have a separate command-level record in `INTERNATIONAL-ENVIRONMENT-STORAGE-20260909.md`; the latest targeted recovery group passed **37/37**.

These are host-side fake-controller/unit tests, not phone/watch or server acceptance. No physical device was operated, full APK built, server mutated, or Git commit/push performed by this subtask. The parent task owns integrated full regression, build/install/cold start, capture of sanitized live evidence and final Git delivery.
