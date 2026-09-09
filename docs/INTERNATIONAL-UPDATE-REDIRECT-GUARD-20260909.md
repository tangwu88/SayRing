# International update request boundary — 2026-09-09

## Baseline and scope

- Baseline: `c9faadae517ca40bd8c35b2e37de09ce2e54c345`, `main`. `git status --short --branch`, `git remote -v`, `git rev-parse HEAD`, and `git fetch --prune origin` completed before edits. Existing production-domain edits are preserved; no pull or reset against the dirty workspace.
- Reviewed repository instructions, international handoff, latest domain-switch record, regression checklist and bug retrospective.
- P1: the APK downloader and generic manifest request followed redirects automatically. Final-URL checking could reject a response only after a request had already reached a disallowed host.
- Scope: update request transport, explicit international installer wiring, global update validation, and focused tests. No update publication, real installation through the updater, account data or device state changes.
- Expected result: rejected destinations receive zero requests; only bounded, same-origin HTTPS redirects are followed. The international installer additionally requires the global package-download path and SHA-256. Package/realm and Android system package/signature gates remain unchanged.

## Changes

- Disable automatic redirects, validate initial and each next URI before sending, limit to three hops, reject loops, userinfo, fragments, non-443 ports, HTTP downgrade and cross-origin targets; cancel redirect response streams.
- Generic downloader retains descriptor-origin compatibility; `AndroidApkUpdateInstaller.global()` restricts each download hop to `https://app.saydian.cn/global/down/files/*.apk` and requires SHA-256.
- Global manifest parsing continues rejecting domestic realm/package and missing hash; iOS store destinations also require standard HTTPS port.
- International manifest endpoint follows `GlobalEnvironment.apiPrefix`, with its test aligned to the approved `/global/api/saydian-app/v2/support/app-update` route.

## Verification

- `dart format lib/services/app_update_service.dart lib/services/global_app_update_service.dart test/global_update_test.dart test/app_update_redirect_guard_test.dart`: four files checked, two formatted.
- `flutter test --no-pub test/app_update_service_test.dart test/global_update_test.dart test/app_update_redirect_guard_test.dart --reporter compact`: **72/72 passed** in the first focused run. Includes original generic/no-hash compatibility, package and realm rejection, corrupted/empty/interrupted APK deletion, and new per-hop guards.
- First focused `dart analyze` found four informational style issues: two initializing-formal suggestions, an unnecessary foundation import, and a null-aware map-entry suggestion. Applied the equivalent syntax corrections; no business/test expectation relaxed.
- `git diff --check`: passed (Git line-ending notices only).
- Second `dart format` checked two files and changed one (initializing-formal formatting); focused `dart analyze` then reported **No issues found**.
- Final `flutter test --no-pub test/app_update_service_test.dart test/global_update_test.dart test/app_update_redirect_guard_test.dart --reporter expanded`: **72/72 passed**. New redirect/preflight test file contains 39 cases. No test failure occurred; the informational analyzer issues above were corrected before delivery.
- Full suite, builds, physical upgrade and server publication remain root-task acceptance items, not inferred from mock HTTP tests. No actual download publication or system APK installation was performed by these fake-client tests.

## 2026-09-10 full-suite fixture regression

- Root's second UTC full suite reported 737 passed / one failure: `online mandatory update collapses every pushed route` in `test/app_update_gate_test.dart` expected the mandatory gate but found none.
- Reproduced with `flutter test --no-pub test/app_update_gate_test.dart --plain-name 'online mandatory update collapses every pushed route' --reporter expanded`: one failure at the same assertion. Before editing, rechecked `git status --short --branch`, HEAD and `git fetch --prune origin`; no merge/reset of the shared dirty tree.
- Cause: the delayed `MockClient` response fabricated its `request` without the actual `?v=19&platform=ios` query. Per-hop validation correctly rejected this as response metadata changed by an unvalidated redirect; it was not a `pumpAndSettle` timing regression.
- Fix: the fixture now attaches the actual Request received by `MockClient`, and explicitly asserts its version/platform query, disabled automatic redirects and persisted mandatory-update state. Production transport/redirect rules remain unchanged; no extra pump delay or relaxed matcher was added.
- `dart format test/app_update_gate_test.dart`: one file formatted. `dart analyze test/app_update_gate_test.dart`: **No issues found**. Scoped `git diff --check`: passed.
- `flutter test --no-pub test/app_update_gate_test.dart test/app_update_service_test.dart test/global_update_test.dart test/app_update_redirect_guard_test.dart --reporter expanded`: **78/78 passed**, covering all six gate widget tests plus the unchanged 72 service/security tests. Root owns the final full-suite rerun.

## 2026-09-10 updater request correlation

- Reason: real-device update checks used a separate HTTP path and were absent from the existing privacy-safe `NetworkAudit`, so a server `requestId` could not be associated with an update response. Rechecked dirty status, fetched origin and confirmed unchanged `c9faada` local/remote baseline; preserved concurrent QA work.
- Files: only `lib/services/app_update_service.dart`, `lib/services/global_app_update_service.dart`, new `test/app_update_network_audit_test.dart`, and this record. No change to `NetworkAudit`, origin policy, APK hash/package checks, redirect limits, native code or other UI.
- Added a `request_started` event immediately before each actual send **after the existing URI preflight**. A second event is recorded as soon as response headers arrive, before body parsing: status plus the existing audit's validated `x-request-id`. Kinds are `update_manifest` and `update_apk`. Thus a 404 or malformed manifest remains traceable, while network failures expose only an attempt, not raw exception text.
- No query parameters, Location value, response body, request headers, credentials, full path or download content are passed to logs. Blocked initial URIs send/log no pretend request; rejected redirect targets never get a second send/start record. The safe event retains host/port/method/kind/path hash and optional status/requestId/outcome, per the existing debug-only audit contract.
- Before implementation, `flutter test --no-pub test/app_update_network_audit_test.dart --plain-name 'global manifest records status 404 and a safe requestId before parsing' --reporter expanded` reproduced the gap: expected two audit events, got zero.
- `dart format lib/services/app_update_service.dart lib/services/global_app_update_service.dart test/app_update_network_audit_test.dart`: 3 checked, 2 formatted. `dart analyze` on the same three files: **No issues found**. Scoped `git diff --check`: passed.
- `flutter test --no-pub test/app_update_network_audit_test.dart test/app_update_gate_test.dart test/app_update_service_test.dart test/global_update_test.dart test/app_update_redirect_guard_test.dart --reporter expanded`: **86/86 passed**. Eight added cases cover status 200/404 before parsing, redirect Location privacy, generic manifest query/invalid-requestId omission, per-hop APK auditing, invalid initial URI zero send, old-host redirect zero second send, and raw network-error omission.
- Some pre-existing **fake-client compatibility** fixtures deliberately declare a domestic origin; their audit events in host test output are not real outbound traffic and do not change international production routing. The new production-oriented audit tests assert the new origin on every event. Do not treat mock events as final phone/network evidence.
- Final full regression/build/physical requestId correlation remain owned by the root task. This subtask did not install, publish, download a real APK or invoke any server write.
