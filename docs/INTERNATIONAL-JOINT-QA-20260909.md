# Android / isolated international API joint QA

## Baseline and approved scope

- App: `main`, `c9faadae517ca40bd8c35b2e37de09ce2e54c345`; `git fetch origin --prune` succeeded, ahead/behind `0 0`.
- Preserve the six tracked default-domain changes and the untracked production-domain note already in the working tree. No reset, clean, user-data deletion, or domestic deployment.
- The `导入 saydianserver 项目` task owns the independent global service deployment and server repository. Existing `/api` and `/admin` stay unchanged. New fixed route: `https://app.saydian.cn/global/api/saydian-app/v2`.
- Current phone: Huawei PPA-LX3, Android 10, authorized ADB, package `cn.saydian.app.global` 0.1.20 (1002). Existing debug session points at localhost 8082; it is not new-domain acceptance.
- Existing phone session, health files, contacts, watch faces, and watch settings must be preserved. No OTA, factory reset, real payments, SMS, refunds, or shipments.

## Confirmed issues before changes

1. P1: APK downloader follows HTTP redirects before rejecting the final foreign origin.
2. P1: general network images bypass API origin protection and accept arbitrary HTTPS media.
3. P1: installation-scoped session/health/notification/device keys can carry local environment state into a different API environment.
4. P1: V2 UUID commerce data reaches integer-ID legacy pages; catalog response shapes do not match and missing prices can render as zero/CNY.

Expected result: first-party network operations stay on the isolated new-domain route; official third-party services are separately audited; no environment can claim another environment's session/data/watch binding; actual server capability controls unavailable services.

## Validation record

- Planning probes: root `/health/ready` HTTP 200 revision `795e66bd69c64295a00c2b3e42c52a290c8f56eb`; root auth capabilities and both `/global` readiness/capabilities HTTP 404. This is not a deployed global realm.
- Initial inspection: ADB online, location mode 3; existing PID running. No new APK installation or full functional acceptance yet.
- Implementation and command-level results will be appended below. Subsystem notes retain focused test failures and corrections. Raw screenshots/logs/build artifacts remain ignored and private.

### Client request boundary round

- Changed global API mount to `/global/api/saydian-app/v2`, with explicit canonical-to-deployed path mapping; credentials/resources reject non-standard production ports. Existing API methods retain server canonical controller paths internally.
- Added production-safe network image provider (all current direct `Image.network`/`NetworkImage` callers replaced); first-party media is same-origin only, manufacturer previews use a distinct vendor allowlist. Weather/watch catalogue requests reject redirects before any next request.
- Debug API/resource audit records method, host, hashed path, HTTP status and validated UUID requestId only; no query/body/header values.
- An initial generated test patch was rejected because adjacent context hunks overlapped. No source was discarded; changed to non-overlapping exact hunks and reapplied successfully.
- `dart format` on the 10 root-owned changed files: 9 formatted, no unrelated files reformatted.
- `flutter test --no-pub test/global_network_boundary_test.dart test/global_api_test.dart test/global_health_api_test.dart test/device_watch_face_market_service_test.dart --reporter expanded`: **63/63 PASS**, including new-domain mapping, old-domain zero-request denial, five redirect statuses, vendor separation and privacy-safe audit.
- Focused tests are not full-suite or physical-watch acceptance. Those gates remain pending below.

- First full analyzer encountered in-progress commerce localization/imports plus missing `dart:typed_data` in the image provider and three null-aware map lint messages. Corrected the root imports/map syntax and waited for commerce generation to finish. A second analyzer saw one commerce-test braces lint; subsystem owner corrected it.
- First full UTC suite: **673 passed / 4 load failures**, all four caused by the concurrently added `globalShopLoadMore` getter not yet generated when the compiler started. Do not treat that run as a pass. Generation is now complete; restart the entire suite against stable files, not only the four failed files.
- Existing real phone UI confirmed connected `SD-Watch-W9`; screenshot is private ignored evidence. This remains the previous local-API package, not the final package.

### 2026-09-10 regression corrections and pre-install protection

- Second full UTC suite: **737 passed / 1 failed**. The mandatory-update gate fixture supplied a response URL without the real request query. Security protection correctly rejected this fabricated implicit redirect. Fixed the fixture to retain the actual request; six gate tests plus the 72 update tests then **78/78 PASS**, without relaxing production guards.
- Independent review found two restore races (cancelled connect succeeds late; vendor stopScan never finishes). Added generation-owned cleanup and bounded scan/connect/stop cleanup, including five new cases; focused related checks **35/35 PASS**. Full regression rerun remains required.
- Explicit `GlobalSaydianApiClient(baseUri: ...)` now undergoes the same approved-origin validation as build configuration; add zero-send rejection tests for old host, nonstandard port and local override without opt-in.
- Before installation, created a private 102,022,656-byte archive of the existing app files/app_flutter/shared_prefs outside Git. ACL grants only the current Windows account and SYSTEM. SHA-256 `27afe9cb2bd8a3c93007cf1c468d0f4deeeb0cfdf010d5f7cd7f3f2ce41de412`. No app data deleted; archive is same-device recovery evidence, not transferable Android Keystore material.
- New QA version: **0.1.21 (1003)**. Package remains `cn.saydian.app.global`; only same-signature replacement is allowed.

- Third complete UTC run: **744/744 PASS**. This predates the last per-source recovery drain corrections and legal-route corrections; final all-suite gates must be repeated after source freeze.
- `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64` with the approved new-origin and `/global` manifest definitions: **PASS in 85.8 seconds**. Normal Flutter/Kotlin plugin deprecation warnings remain. No local API opt-in used.
- `android/gradlew.bat :app:testDebugUnitTest --console=plain`: **BUILD SUCCESSFUL in 21 seconds**, XML results **16 tests, 0 failures, 0 errors** across four suites. `node --test tool/test_native_log_privacy.mjs`: **8/8 PASS**.
- Third analyzer found only `prefer_initializing_formals` on the QA restore-control constructor parameter; corrected without changing the public factory parameter. Final analyzer rerun required.
- A build-tools command initially used an absent `36.0.0` path; corrected to the observed installed **36.1.0**. Package inspection and signing verification then succeeded. No installation occurred from the failed command.
- Private pull of the existing installed APK and the new QA APK both report signing certificate SHA-256 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`.
- Dedicated `lib/main_global_joint_qa.dart` Debug build: **PASS in 24.1 seconds**. Same-signature `adb install -r` completed **Success**, preserving app data. Huawei displayed two package installation confirmations; both were confirmed for this explicitly authorized package. Installed package now reports **0.1.21 / 1003**.
- QA configuration was installed privately with a single exact device ID, `deviceOnly=true`, `safeFindWatch=false`; the staging copy was removed. No credentials or device address enters Git. Cold launch began at host time **2026-09-10 00:18:34 +08:00**; phone wall clock differs, so log evidence is correlated by current process rather than assuming identical timestamps.
- First physical round: exact target discovered once among 22 scan results; connection ready in about 4.7 seconds. Initial sync returned a nonempty local cache of 21 records. Capabilities resolved (14 hardware / 14 visible features, 13 metrics), device details and battery read succeeded. Values are deliberately omitted. This is **device-side evidence only**, not cloud upload or whole-suite acceptance; subsequent round results follow below.
- Server source checkpoint reported by the owning task: `4bf44bd9c9d5cc33a775d317cc7227740a249f45`; private image build run `34373703094` succeeded. Deployment is still blocked by host disk capacity and image-pull authorization; no cache deletion, credential transfer or production DB write was performed by the App task.

### Physical regression findings (not an acceptance pass)

- First repeat sync: cache remained **21 → 21**, no duplicate local rows observed. Disconnect acknowledged in 222 ms. Second scan found exactly the same target, but after the second connect command the QA driver saw a non-ready state while `connectedToTarget=true`; it stopped with **completedRounds=1 / failed**. A later screen showed an active sync rather than a disconnected watch. Do not reinterpret this as three completed rounds. Investigating the asynchronous connection state before repeating.
- Added enum-only state transition diagnostics and readiness fields to the isolated QA entrypoint. Its fake controller initially lacked `deviceMachine`, causing **3 pass / 8 failures**; added the real state-machine fixture and re-ran **11/11 PASS**. This was a test fixture failure, not relaxed readiness acceptance.
- Final-format precheck initially identified four directly modified files (app, API client, main pages, prototype pages). Formatted those four only; the gate had stopped before analysis/tests, so no final-suite pass was reported from that attempt.
- Cross-platform host contracts: `TZ=UTC node --test harmony-native/tests/*.test.mjs` and `TZ=Asia/Shanghai ...`: **481/481 PASS each**. These are not Harmony HAP or iOS builds.
- Added `node --test tool/test_native_log_privacy.mjs` to the existing CI host-contract job. This checks owned-source log controls only, not closed-source runtime logging.
- Runtime privacy failure: owned `SaydianNative` messages in the inspected process window had no device/health payloads, but the SDK bypasses its own debug switches. `VPOperateManager`/`BluetoothLESearcher` directly log discovered device/scan objects, and `BluetoothClientImpl` logs connection addresses. Hundreds of `System.out length/type` lines were advertisement structure, not health values. OS `BluetoothGatt` logs are a separate source. No claim that vendor runtime logs are fully private; no global stdout interception or unreviewed binary patch was applied.

### Exclusive physical retest, 2026-09-10

- Subsequent inspection found the phone being manually used for login during the first attempt. That attempt lacked a readiness enum, so its second-round failure cannot establish an App defect or a specific cause. Preserved the failed record; did not weaken readiness or change connection logic to mask it. User then explicitly approved pausing manual phone use for the retest.
- The instrumented Debug driver completed **3/3 exact-target connect + initial sync + repeated sync rounds**, with **two explicit intervening disconnects**. Connect times: **3752 / 2953 / 4166 ms**. Each scan found exactly one authorized target; no same-name substitution. Each repeated sync kept cache **21 → 21**. All three rounds reached enum `ready`, resolved 14 hardware/14 visible features and 13 metrics, and read device details/battery successfully.
- Eleven read-only feature requests returned nonempty maps without an error: watch faces, photo watch face, phone calls, contacts, notifications, alarms, weather, world clock, health reminders, health assessment and screen display. This validates the read contract, not hardware actuation or write-and-restore. Health-monitor settings returned four monitor/four interval entries, but the public API has no success contract: **not verified**, not silently counted passed. Find-watch and camera actions were deliberately skipped; no measurement, settings write, contact overwrite, face install, OTA or factory reset.
- Driver terminal record: **partial**, `completedRounds=3`, **32 passed / 5 not_verified / 3 skipped / 0 failed**, target still connected, `cloudAccepted=false`. The observed entries are timings/state transitions, not extra acceptance tests. Old failure did not recur under independent operation; root cause remains unproven.
- Official catalogue `www.vphband.com:9001` and preview images `www.vphband.com:443` returned HTTP200 through the approved resource client. First-party captured requests used `app.saydian.cn:443`; no old first-party domain appeared in these instrumented paths. No packet capture exists for closed-source SDK traffic, so full native egress remains unverified.
- Removed only the test-created app-private `global-joint-qa.json`. The protected local backup remains; old unscoped `saydian_global_health_v1.db` and new environment-scoped database both still exist on the phone. No account/health database deletion or automatic old-data adoption.
- Built normal `lib/main.dart` Debug in **21.0s**, QA Release in **108.6s**, and final native unit task in **17s** with **16/16** XML results. Same-signature normal Debug replacement and cold launch succeeded. Current-process buffer contained **0 fatal/ANR markers** and **0 automatic-QA markers**; this is a bounded check, not an indefinite crash guarantee.
- At that cold start, update manifest, capabilities and content all returned **404** from the new `/global` mount, with redacted request IDs. Example manifest request `174139d3-4074-4883-bd3c-718d2ac1a091`, capabilities `23936c1f-fd42-49bd-a5d2-b7ce18063a94`, content `848f8b12-c6be-402c-98e2-2b63d6c0763f`. No credentials were supplied by the App task; manual user's earlier login is not a dedicated QA account test.
- Cold startup correctly stays signed out in the new environment; automatic watch restore does not bypass absent privacy consent. Thus authenticated cold-start reconnect and watch→cloud→readback **remain unverified**, not inferred from the diagnostic entrypoint.
- Before final UI-copy correction, full analyzer had **0 issues** and dual-timezone suites **801/801 each**. Actual UI inspection then caught HTTP404 capabilities incorrectly labelled as a network failure. Changed only that catch to use the existing typed error mapper; added HTTP404 vs network-error Widget cases. Focused auth checks **8/8 PASS**. Repeat final suites/builds after this correction; final hashes follow below.
- GitHub CLI initially used the other signed-in account and could not resolve the private global repo. Used the existing `tangwu88` Git credential only inside the local GitHub subprocess; repo confirmed **Private / ADMIN**. No credential output, repository storage or transfer to the server.

### Final local gates and delivery boundary

- After the HTTP404 wording fix: `flutter analyze --no-pub` **0 issues**; `TZ=UTC flutter test --no-pub --reporter expanded` **803/803 PASS**; `TZ=Asia/Shanghai ...` **803/803 PASS**. Each suite took about 28 seconds. All tests are real tests, including synthetic HTTP/widget fixtures; they are not 803 real-device scenarios.
- `dart format --output=none --set-exit-if-changed lib test`: **137 files / 0 changes**; `git diff --check` passed. Latest normal Debug rebuild **16.5 seconds**, QA Release rebuild **54.2 seconds**, both succeeded with the fixed origin and isolated manifest, no local debug API opt-in and normal `lib/main.dart`.
- Retained earlier final native **16/16**, privacy-source **8/8**, and Harmony host contracts **481/481 per timezone**. The last UI-only error mapping did not change native sources. macOS/iOS and remote CI results must be tracked by their actual run; Windows local results do not prove them.
- App Git fetch reconfirmed `HEAD == origin/main == c9faadae517ca40bd8c35b2e37de09ce2e54c345` before staging, ahead/behind **0/0**. Only reviewed source, tests, workflow and redacted Markdown are to be staged. Raw logs, screenshots (including user-entered forms), private backups, QA configuration, SDK-inspection dumps and APKs stay outside Git.
- **Overall joint acceptance is NOT PASSED.** New-domain `/global` service/account/health readback is not deployed/accepted; commercial transactions stay closed; closed-source/native and Yucheng Dart logging fails privacy requirements; native egress, permissions matrix, authenticated cold recovery, settings writes/restore, effective measurements, other watches/firmware and channels remain unverified. Device-only success does not close those gates.
- Awaiting user approval for the server task's narrowly scoped recoverable Docker build-cache cleanup. No approval for server credential transfer or production-database access has been inferred from permission to test the phone.

## Final QA artifacts (normal entrypoint; internal only)

The table below records the `b323114` checkpoint. The subsequent relative-media correction, regression results and replacement APKs are in [2026-09-10 media compatibility follow-up](INTERNATIONAL-MEDIA-COMPATIBILITY-20260910.md); use that follow-up for the latest deliverable.

Version **0.1.21 / 1003**, package `cn.saydian.app.global`, label **Saydian**, ABIs `armeabi-v7a, arm64-v8a`. Same non-production signing certificate as the prior installed QA package; not an app-store release.

| Artifact under ignored `build/joint-qa-20260909/` | Bytes | SHA-256 |
| --- | ---: | --- |
| `Saydian-global-0.1.21-1003-debug.apk` | 185294840 | `0500319157b5eb941cfe7faa9f33220dd759d45e145de85d0b037487de6a9c96` |
| `Saydian-global-0.1.21-1003-qa-release.apk` | 68141576 | `ca866d11407205d42657eb6eaff2498677098a1dcaf09e4dc7a7ba330bc9ffd6` |

Older hashes in private preliminary build logs are superseded by this table. The diagnostic APK is a separate test-only entrypoint and is not the user deliverable. Neither APK has been published to the domestic download page or app stores.

Final Debug `adb install -r` returned **Success**. Cold-launched normal activity; the **on-phone base.apk SHA-256 exactly matches `0500319157b5eb941cfe7faa9f33220dd759d45e145de85d0b037487de6a9c96`**, not an earlier build or hot reload. Before commit, staging contains 89 reviewed source/test/doc/workflow files; the staged-path gate rejects raw logs/screenshots/APKs/SDK binaries, and the added-line check found no credential or actual device identifier markers.
