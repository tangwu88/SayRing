# International authentication consent P1 — 2026-09-10

## Before implementation: reproduction and expected result

- Baseline: `main`, `d69c1fcdf44dac1c3eb7dff90673a9b7d8b3ca72`, matching `origin/main` after `git fetch --prune origin` (ahead/behind **0/0**). Existing untracked account-QA script/test/record belong to another agent and remain untouched. No merge, reset, data deletion or commit in this subtask.
- Fully re-read `AGENTS.md`, `INTERNATIONAL-HANDOFF.md`, `CHANGE-TEST-LOG.md`, `BUG-RETROSPECTIVE-20260829.md`, `REGRESSION-CHECKLIST.md`, latest authentication-smoke record, joint-QA record, coverage matrix and environment-storage record before code changes. Older deployment/hardware snapshots are historical, not current online acceptance.
- **P1 reproduction:** open the international sign-in page as an existing user. It has legal links but no consent checkbox; `_accepted` starts false. A successful login passes false to the controller, which persists false, deactivates push and prevents automatic watch restoration. Password reset creates a session with the same missing-consent path.
- **P1 side effects:** `login` overwrites stored consent before authentication succeeds, so a failed attempt can revoke the previous session's consent. Conversely, `requestNotificationPermission` unconditionally writes privacy consent true even though its UI only asks permission to show notifications; this is not the legal-document agreement shown during authentication.
- **Expected:** sign-in, sign-up and password reset have an explicit unchecked agreement to the server-provided current legal version; no authentication submission before consent/capability readiness. Disabled registration does not block existing-user login. Reading legal content, a late capability response or changing language never selects agreement. Failed login does not modify prior consent. Notification permission never creates privacy consent, and declining notification permission does not revoke a separately granted agreement.
- Scope: `lib/ui/global_auth_page.dart`, the minimal matching consent branches in `lib/services/app_controller.dart`, authentication/notification regression tests, this independent record. Preserve preview entry behavior, actual auth/registration routes, no-code registration capability, native bridges and account-data boundaries. No real account/phone data access, SDK activation, OTP, production write, package build or Git commit by this subtask.

## Implementation and verification

### Source changes

- `GlobalAuthPage` now shows the same unchecked, localized legal agreement for sign-in, sign-up and reset. Authentication submission requires a non-empty current `consentVersion` from the capabilities response and explicit agreement. Loading, failure, empty/whitespace version and stale capability responses cannot grant consent. Registration availability remains independent of existing-account sign-in.
- Changing authentication mode or locale clears the check. Returning from a legal page still reloads capabilities and clears the check; merely opening or reading a legal page never grants consent. Existing reviewed-document and allowed-origin checks remain unchanged.
- `AppController.login` no longer writes consent before the API succeeds. It reuses `_prepareAuthenticatedNotificationSession` after successful authentication, preserving the previous session's decision on authentication failure.
- Verified password reset also requires agreement and a non-empty version before making the session-producing verification call. The verification API and capability-gated no-code registration contract are unchanged.
- Notification explanation/request requires an existing explicit privacy agreement. Requesting OS notification permission cannot write privacy consent. Notification denial does not revoke the independently granted agreement. Preview entry, manual device actions, native bridges, restore serialization and account-data isolation were not changed.

### Commands and outcomes

Run from `F:\xcodeplace\saydian-app-global`; executables are `D:\Dev\Flutter\3.44.9\bin\dart.bat` / `flutter.bat`.

| Command | Result |
| --- | --- |
| `git fetch --prune origin`; HEAD/origin/main/ahead-behind/status checks | Baseline above, 0/0; other agents' work preserved. |
| `dart format lib/ui/global_auth_page.dart lib/services/app_controller.dart test/global_auth_consent_test.dart test/app_notification_controller_test.dart` | Completed, scoped to the four owned Dart files. |
| `flutter test --no-pub --reporter expanded test/global_auth_consent_test.dart test/global_auth_page_test.dart test/app_notification_controller_test.dart` | Initial 47/47 nominal pass, but one new test's submit tap missed the viewport. This was **not accepted as clean evidence**. |
| Test-fixture correction | Hide the test keyboard and pump before/after scrolling to the target; make hit-test warnings fatal in the new auth suite. No production code changed for this fixture issue. |
| `flutter test --no-pub --reporter expanded test/global_auth_consent_test.dart` | 9/9 passed with fatal hit-test checks enabled and no missed-tap warning. |
| `flutter test --no-pub --reporter expanded test/global_auth_consent_test.dart test/global_auth_page_test.dart test/global_legal_page_test.dart test/app_notification_controller_test.dart test/app_controller_wearable_restore_race_test.dart test/app_controller_account_wearable_test.dart` | **93/93 passed**, exit 0. Existing no-code registration, legal origin/version checks, 1.0/1.5/2.0 auth layout, saved-device restoration and account-switch regressions remained passing. |
| `dart analyze lib/ui/global_auth_page.dart lib/services/app_controller.dart test/global_auth_consent_test.dart test/app_notification_controller_test.dart` | **No issues found.** |
| `dart format --output=none --set-exit-if-changed` on the same four Dart files | 4 files checked, 0 changes, exit 0. |
| `git diff --check --` on the five owned source/test/record paths; `git status --short --branch` | No whitespace errors; branch remains main tracking origin/main. Concurrent version, workflow, smoke/account-QA and handoff edits remain untouched. |

New coverage: 9 auth Widget cases; 4 controller cases (failed authentication preserves false/true, reset session gate, OS notification denial retains legal agreement); one conflicting old notification test updated to require prior explicit legal consent. All credentials, legal documents, challenges, responses and wearable objects in these cases are synthetic; network-shaped audit output comes from mocked clients, not live server acceptance.

### Limits and handoff

- Runtime changes are frozen for the parent task's full dual-timezone suite, Android Debug/Release build, installation and real-device testing. This subtask did not build, install, contact a real account, activate native SDKs, send a code or commit/push Git.
- This patch does **not** manufacture consent for old installations whose persisted value is false. Such users must explicitly agree during sign-in/reset; the supported recovery for an already signed-in old session is sign out, then sign in and select the agreement. No new independent in-session consent screen or automatic migration was added.
- UI consent readiness comes from the server's current capabilities. It does not claim to complete legal review itself, make declined registration channels available, or change the server's session/consent contract. Reviewed legal content continues to be checked by the existing legal page.
- Device restoration/push acceptance on actual hardware and old-installation recovery UX still require the parent's physical test. Host unit/Widget success must not be reported as full production/privacy/third-party-channel acceptance.
