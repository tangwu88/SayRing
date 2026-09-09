# International authentication and Android device retest — 2026-09-10

## Scope, baseline and protection

- Request: repair registration/password login, then restart normal Android physical-device debugging. Use only the isolated `https://app.saydian.cn/global` service; no domestic or local fallback.
- Before this round, `git fetch --prune origin` succeeded. `HEAD` and `origin/main` were `d69c1fcdf44dac1c3eb7dff90673a9b7d8b3ca72`, ahead/behind `0/0`. Two known parallel subtasks own synthetic-account QA tools and the confirmed login-consent fix. Preserve their changes.
- Read the repository instructions, international handoff, change index, prior authentication smoke, bug retrospective and regression checklist. Private test artifacts remain outside Git in an ACL-protected operator/SYSTEM directory. Do not record contacts, passwords, tokens, member IDs, device addresses or raw health/UI dumps here.
- Preserve the installed App data and watch state. No uninstall, clear-data, OTA, contact/watch-face overwrite or restoration of old environment data.

## Deployment unblocked (append-only continuation of earlier failures)

- The prior `/global` HTTP 404 and Tencent Cloud sign-in failures remain recorded in `INTERNATIONAL-AUTH-SMOKE-20260910.md`; they were real failures, not App login success.
- After the user signed in, the server owner reported successful independent deployment at `4bf44bd9c9d5cc33a775d317cc7227740a249f45` and instructed this task to stop touching the server. The owner reports a branch-specific Git auto-update timer and no long-lived GitHub credential transfer. This App task has not independently audited that timer.
- Root's server checks were read-only: verified the trusted host fingerprint, global container health and free disk; build cache was already `0 B`. No cleanup, server edit, migration, credential transfer or database initialization was performed by this App task. `docker buildx ls` was unavailable; no plugin installation or alternate destructive command followed.
- `node tool/global_auth_smoke.mjs`: **PASS**. Readiness HTTP 200 (`b11b71b5-979b-4dc7-a8e3-b63cdf5a24cb`), capabilities HTTP 200 (`af7d1788-2321-438a-be54-ac7bb174e483`), anonymous member HTTP 401 (`13e540a7-e951-463a-82ca-a9803c478879`), terms HTTP 200 (`306b2cc2-f996-4f77-8658-711ba7350e62`), privacy HTTP 200 (`93dd90a9-d5f0-43bc-aee8-0957060c9490`). Actual capabilities explicitly enable email/SMS and set `verificationRequired=false`.
- These GET checks validate readiness and published document contracts, not actual account login or professional legal approval. The served English terms explicitly identify a controlled pre-release test service.

## Initial Android checks and confirmed App issue

- Huawei Android 10 physical phone remained authorized. The normal Debug package `cn.saydian.app.global`, `0.1.21+1003`, is installed; the prior media-fix APK hash is documented in the media record.
- Tapped the existing login retry action: the prior unavailable-state cleared after real capability retrieval. Opened Create account: contact/password/confirmation and explicit terms consent are present; no verification-code field or sending action is shown under current temporary capabilities.
- Opened the actual terms from the normal App: nonempty English pre-release terms loaded from the new service. No credential was entered during these read-only checks.
- **P1, login consent has no reachable control:** normal sign-in passes the default false consent despite hiding the checkbox; controller stores that false before authentication succeeds, blocking subsequent consent-gated device restoration/notification initialization. A notification-only permission action can separately grant privacy consent, which is not an appropriate substitute. Expected: explicit published-document agreement, no implicit default consent, and failed authentication does not overwrite consent. The delegated fix and its exact tests have a separate record; final integration results will be appended below.

## Pending checks

- Bump only the build number to `0.1.21+1004` so the rebuilt consent fix is distinguishable from earlier `1003` APKs; package/name/signing/data scope remain unchanged. Re-fetch before this edit: remote still matches baseline, no merge or overwrite.
- Host checks in this round: `node --test tool/test_native_log_privacy.mjs` **8/8**; `TZ=UTC` and `TZ=Asia/Shanghai node --test harmony-native/tests/*.test.mjs` **481/481 each**. These source checks do not erase the previously documented closed-vendor raw-log limitation.
- `android/gradlew.bat :app:testDebugUnitTest --console=plain`: successful in 16 seconds, target test task **UP-TO-DATE**, 16 cached cases/zero failures in XML. Do not claim these 16 cases were freshly executed. Existing Kotlin-plugin/Gradle deprecation warnings retained; no dependency change was made for this auth fix.

- Root independently ran the initial account-tool mocks: 18/18 passed, both `node --check` passed. Independent review then found two missing negative cases (cleanup before verified revocation, and legal-version changes between capability reads). Live account creation was withheld until fixes and expanded tests pass; the initial green mocks were not treated as complete acceptance.
- Latest pre-change GitHub CI runs for `d69c1fc`, `621bb89` and `b323114` were verified `completed/success`; new runtime edits require fresh checks. Added offline-only account-tool tests to existing CI; no live credentials or real account creation in CI. The first patch used an incorrect existing step label and changed nothing; after reading the actual workflow, the exact insertion succeeded.

- Audited opt-in synthetic account registration/refresh/logout/password login and server readback.
- Real App consent, login/logout, cold restart and attached Android debugging using the dedicated QA account; no injected session tokens.
- Static/full regression/build checks for any runtime change, then intentional Git submission. iOS signing/physical acceptance and OTP/payment channels remain outside this Android round.

## Actual isolated account round

- The first opt-in invocation failed closed with `private_directory_invalid`, `accountMayExist=false`, `privateRecordWritten=false`. No network mutation or credential record occurred. Root independently checked directory realpath/type and protected ACL; a diagnostic `node -e` command also failed from nested shell quoting and was not retried with secret data.
- Root cause: the fixed Windows PowerShell helper could not auto-load `Get-Acl` under the inherited module environment. The tool now reads the identical DACL using the .NET Framework directory ACL API; allowed principals/protected-ACL requirements were **not relaxed**. The actual directory passed read-only validation. Final combined tool tests independently re-run: **78/78** (31 account-tool and 47 GET-smoke cases).
- After independent review and code freeze, executed once successfully: `node tool/global_auth_account_qa.mjs --allow-isolated-qa-account --private-dir <operator-protected-outside-repo-directory>`.
- Actual registration returned HTTP 201 and a valid session, requestId `f694827b-557b-4f18-9ae9-1286e9263909`; member readback HTTP 200 matched the opaque account in memory (`a0f7aa3d-6e04-4480-ae94-d8758321aaa1`).
- Refresh HTTP 201 (`8d4c84e8-6840-4bcc-bce1-28a3cb9ce1a8`) rotated both tokens and retained the same account; both old tokens were rejected with HTTP 401. Logout HTTP 201 (`53e74598-6087-4ff4-a9d8-1f2683080014`) was followed by access and refresh rejection.
- Password login HTTP 201 (`5071d2b8-e234-4b22-b459-82c0aa746608`), same-member readback HTTP 200 (`4361a771-75f3-4406-b535-c715f3a665ba`), final logout HTTP 201 (`30965090-033c-46ad-9ba1-0ed18c738255`), then both tokens HTTP 401. Final `loginFlowPassed=true`, `cleanupConfirmed=true`, `manualRecoveryNeeded=false`.
- One synthetic reserved-domain account remains for controlled QA; credentials stay in the pre-protected private journal, no tokens or member IDs stored in that journal. No OTP delivery, verified-contact assertion, profile/health/commerce write, account deletion or cross-realm credential testing was performed by this script. Sent only aggregate results/request IDs to the server owner.

## Final source/build and Android retest

- Runtime fix and 93-case targeted results: [consent P1 record](INTERNATIONAL-AUTH-CONSENT-20260910.md). Reading a document does not select agreement; registration remains driven by the explicit no-code capability.
- `flutter analyze --no-pub`: **zero issues**, 15 seconds. `TZ=UTC flutter test --no-pub --reporter expanded` and `TZ=Asia/Shanghai ...`: **822/822 each**, no failures. Logs are ignored local artifacts, not Git attachments.
- Normal `lib/main.dart` APK builds used `--no-pub --target-platform=android-arm,android-arm64`, explicit new-domain API/update defines and empty unconfigured weather key. Debug built in **30.0 s**; explicit internal QA Release (`SAIDIAN_ALLOW_QA_RELEASE=true`) in **84.3 s**. Existing plugin/Gradle future-compatibility warnings remain, not build failures.
- Debug: `build/joint-qa-20260909/Saydian-global-0.1.21-1004-auth-debug.apk`, **155,958,294 bytes**, SHA-256 `f6b822c6152558835eb2c1f4419b27d91794c7f5c961c311a0a3c9d347cf2bb5`.
- QA Release: `build/joint-qa-20260909/Saydian-global-0.1.21-1004-auth-qa-release.apk`, **68,157,960 bytes**, SHA-256 `1afb710e5b6367f381e128a0f33b6a68d84cf319788bf0e1218299fc01b40ade`.
- APK inspection: package `cn.saydian.app.global`, label `Saydian`, version `0.1.21+1004`; existing QA signer SHA-256 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`. This is not production signing or public download publication.
- `adb install -r <debug-apk>` succeeded after both Huawei installation confirmations. First installation time remained unchanged. Readback of the installed `base.apk` hash matched the exact new Debug artifact; did not uninstall or clear data.
- The first immediate UI dump after launch returned `null root node`; no action used its stale file. A fresh subsequent dump succeeded. Found an already authenticated real user session, so **did not replace it with the synthetic account or log the user out**. No QA token injection or automatic watch reset.
- Two normal cold starts preserved the logged-in session. After the second start, Flutter `attach` successfully connected and reported Dart VM Service and DevTools. Before that restart it was only waiting for service discovery; waiting alone was not called attached. Background debug output goes only to the ACL-protected private directory because upstream SDK logs remain sensitive.
- Actual device page after restart: `ConnectedLabelPresent=true`, not synchronizing, device page visible, sign-in page absent. Existing records remain visible. No new manual actuator/measurement/contact/watch-face/OTA operation in this authentication retest.
- Fresh app-scoped log checks: **0 FATAL EXCEPTION/ANR lines**; all observed `kind=api` events use `app.saydian.cn`, unexpected first-party API host count **0**. Authenticated care GETs returned HTTP 200, including `83acfe98-b477-4c49-afdc-5e71d87f1ca9`; eight initial captured API responses after restart were HTTP 200. Vendor watch-face requests to `www.vphband.com` were observed separately, not misclassified as first-party fallback. This is observed-path evidence, not a complete native packet capture.

## Remaining acceptance and handoff

- Positive live registration/password-login/session-rotation tests are API tests. The new login checkbox/reset/no-code form paths have Widget coverage; a new successful registration/login/logout through **this phone's** form was intentionally not forced after discovering the user was already signed in. Do not report API testing as a separate successful fresh phone signup.
- Current handset/watch recovery and attached debugging pass; other models, real OTP/password recovery providers, verified contacts, full health upload/readback, cross-realm negative tests, push/business delivery and commerce/payment acceptance remain separately tracked. Closed-vendor raw log/native-egress limitations remain open.
- Windows did not compile iOS in this round. The pre-change CI was successful; final changed-source macOS/CI status must be reported separately. No signed iOS/production release claim.
- Server owner separately reports its Git timer executed successfully and tracks only `codex/global-api-foundation`, building exact public source revisions about every five minutes; no long-lived GitHub token transferred. App source pushes do not themselves deploy the server or publish APKs. Do not modify domestic deployment or data.
- Before the next edit: fetch the international repository, inspect status, read this record and the consent/tool records, preserve current data and only use dedicated synthetic accounts for write tests. No raw UI dumps, credentials, screenshots, APKs or private debug outputs are committed.
