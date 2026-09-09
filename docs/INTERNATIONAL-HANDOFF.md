# Saydian international — implementation handoff

## Start here: update before editing

1. `git status --short --branch` and `git remote -v`.
2. `git fetch --prune origin`; only if clean, `git pull --ff-only origin main`. Never discard another colleague's work. Use an explicit checkpoint before merging remote changes.
3. Read [implementation/test history](INTERNATIONAL-IMPLEMENTATION-20260909.md), [Flutter localization record](INTERNATIONAL-L10N-20260909.md), and the Harmony international record. Record subsequent changes and tests in Git as well.

App workspace: `F:/xcodeplace/saydian-app-global`. Remote: `https://github.com/tangwu88/saydian-app-global` (Private). Preserved domestic history via `upstream`; do not use that remote for international pushes.

Server workspace: `F:/xcodeplace/saydian-server-global`, branch `codex/global-api-foundation`, independently cloned from `tangwu88/saydianserver`. See its `docs/global-api.md`, `docs/global-deployment.md` and `docs/implementation-log/2026-09-09-global-foundation.md`. No colleague's original server working tree was edited.

## Identity and environment

| Layer | International value |
|---|---|
| App name | Saydian |
| Android application ID / iOS bundle ID | `cn.saydian.app.global` |
| Native Harmony bundle | `cn.saydian.app.global.hm` |
| First-party root | `https://app.saydian.cn` |
| Fixed global API gateway prefix | `/global/api/saydian-app/v2` |
| Secure storage prefix | `saydian.global` (separate app sandbox as well) |
| Flutter health database | `saydian_global_health_v1.db` |
| First-launch locale | English; persistent manual selection |
| Supported locale resources | en, zh-Hans, zh-Hant, de, fr, es, ja, ko |

Do not copy domestic `.env`, signing material, push secrets, account sessions, production workflow secrets or production data. Android/iOS native MethodChannel names remain stable internal ABI, not network domains. Official third-party weather/watch-face hosts remain independent of first-party API routing.

## API contract highlights

- Password login: explicit `channel:email|sms`, normalized `identifier`, `password`; UUID member IDs remain strings. Global session uses access/refresh tokens and ISO UTC expiry. Refresh is single-flight and cannot overwrite a different signed-in account.
- Capabilities distinguish registration from recovery. Email/SMS verification is disabled without a verified real provider; SMS countries are an explicit allowlist. Codes use a challenge ID, purpose, expiry, cooldown and one-use server protection; no successful fake sending.
- Registration requires reviewed terms/privacy with returned `consentVersion`. Health analysis separately requires the reviewed `health_ai_analysis` document/version. Missing legal content blocks new consent, not ordinary password login; it never silently authorizes push.
- Global care uses relationship UUIDs, email/E.164 invitations, explicit per-metric sharing and revocation. Local calendar day endpoints become UTC instants; no forced Beijing-day conversion.
- Global encyclopedia uses V2 UUIDs and language parameters. AI messages preserve the user's text and pass current language. Server article/PDF/report translations require separately supplied content; local UI translations are not that content.
- Updates require an explicit global realm and matching package ID, HTTPS and SHA-256 for direct packages under `/global/down/files/`. Real TestFlight/App Store targets only when actually provided. A missing manifest is unavailable, not evidence of latest-version acceptance.
- Compatibility DTOs still exist in imported code. The root change/test record and per-module notes identify routes not yet fully migrated. Do not infer full V2 business coverage from the account/health tests.

## Reproducible local checks

Use Flutter `D:/Dev/Flutter/3.44.9`, JDK `F:/Codex/home/tools/jdk17`, Android SDK `F:/Codex/home/tools/android-sdk`, Gradle cache `D:/Dev/Gradle`. Enter the **global** workspace and use its own `tool/handoff` scripts; these resolve their checkout dynamically. The checked-in `config/dev.json.example` uses only the global root/update endpoint and leaves unconfigured weather credentials empty.

```powershell
$env:JAVA_HOME='F:/Codex/home/tools/jdk17'
$env:ANDROID_HOME='F:/Codex/home/tools/android-sdk'
$env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
$env:GRADLE_USER_HOME='D:/Dev/Gradle'
$env:Path="$env:JAVA_HOME/bin;D:/Dev/Flutter/3.44.9/bin;$env:Path"
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --debug --target-platform=android-arm,android-arm64
$env:SAIDIAN_ALLOW_QA_RELEASE='true'
flutter build apk --release --target-platform=android-arm,android-arm64
```

An allowed QA release uses the existing non-production signing path; it is **not an app-store signing approval**. Production signing and providers must be configured independently. Do not publish a package merely because it compiles. Use `aapt dump badging` to check the actual package ID/name, then verify its SHA-256. Every published download must be re-downloaded and hash checked.

Flutter CI retains static/unit checks plus Android and macOS no-codesign jobs; former domestic publication workflows are inert examples in `docs/legacy-workflows/`. CI execution is separate evidence and may require GitHub account runner/billing availability. Native Harmony host tests are `node --test harmony-native/tests/*.test.mjs`; they are not ArkTS/HAP builds.

### Local Android emulator Debug (UI-only)

The physical QA variants remain ARM-only. For the local `Saidian_API_36` x86_64 emulator, opt in only for a Debug session:

```powershell
$env:SAIDIAN_EMULATOR_DEBUG='true'
flutter run -d emulator-5554 --debug `
  --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn `
  --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update `
  --dart-define=QWEATHER_API_KEY=
```

The Gradle gate rejects this switch for Release builds. The emulator validates Flutter/UI and local storage only; its x86_64 image cannot validate ARM-only watch SDK behavior, real Bluetooth, push delivery, online signup, payment, or production services. On this Windows host, a stale AVD long-path resolver could list an AVD but fail to start it; use an ignored local resolver or repair the local AVD setup, never commit AVD images, snapshots or resolver files.

## Remaining release gates — do not mark complete

- Real deployment of isolated global API/Worker/DB/Redis/storage, migrations and gateway tests. Current local server work is source/scaffold verification only.
- Real reviewed legal documents, authorized email/SMS testing and enabled countries; no contact information or real sending credential was supplied in this task.
- International catalog price books, tax/shipping/inventory coordination and payment rails are not implemented/accepted. Checkout remains disabled, not CNY with a new currency symbol. Full global commerce/address/order UI and remaining compatibility routes need contract migration.
- All-screen localization is not complete: Flutter has 499 ARB keys across eight languages; the targeted reachable static-copy inventory is covered, but nested/dynamic messages and model-derived values remain. Harmony has 574 semantic rows, with 272 untranslated rows falling back to English after camera merge. Report/PDF and stored push/body translations still require completion and linguistic review. First-launch English and resource availability alone do not prove eight-language acceptance.
- Harmony canonical V2 cloud health synchronization is not complete. The old minute-aggregating V1 uploader is explicitly blocked for the global build; records remain locally pending and must not be reported as uploaded. Do not enable it by removing the guard.
- ECG waveforms require an explicitly known sample rate and confirmed V2 artifact storage. Unrepresentable waveforms must remain pending, never silently discarded as uploaded.
- Actual iPhone/signature, Harmony SDK/HAP compilation, physical phones and two different watch firmware/model tests. International macOS CI no-codesign compilation has passed (see below), but it is not signed IPA or real-device acceptance. Do not reuse domestic historical screenshots/builds as international acceptance.
- Public downloads, paid production transactions, app-store submissions and TestFlight publication require separate accepted channels. This task has not performed them.

## Verified source checkpoints

- International App foundation checkpoint: `9f84b03` (retains integrated domestic history, not a release-complete declaration). Latest upstream Harmony camera merge and package results follow in the command-level log.
- Server source and tests pushed to `tangwu88/saydianserver`, branch `codex/global-api-foundation`, commit `af7a77a4b7470ed6a786802ad99f8721abd26646`. Do not merge into production main without the isolated deployment review.
- Before camera merge: Flutter 628/628, analyzer clean, Android native 15/15, Harmony 477/477 host tests; server 499 passed / 4 DB skipped. Windows cannot run seven imported POSIX release-helper tests. CI and platform build results must be checked independently.
- Final local media-isolation regression: Flutter **630/630**, analyzer clean, format **118 files / 0 changes**. Final Harmony host count **481/481**. The media tests, documentation and dev configuration example do not alter packaged runtime inputs.
- [First CI run on source 7215990](https://github.com/tangwu88/saydian-app-global/actions/runs/34331730481): **SUCCESS, 33m40s total**. Quality passed in 7m31s, including both Flutter timezones and all Linux release helpers; both Harmony timezone jobs passed. Android passed in **25m14s** (Debug, Release QA and native unit tests). iOS passed in **15m27s** on macOS 26/Xcode 26.5: Debug/Profile/Release no-codesign plus RunnerTests `build-for-testing`. XCTest compile only; no executed XCTest, IPA or iPhone acceptance. Final record/example/media-test changes leave runtime/workflow inputs unchanged and have separate 630-test local evidence; their delivery commit skips redundant CI, not validation of new runtime code.

## Internal Android QA package

- Machine-readable package identity, source provenance and acceptance gates: [GLOBAL-QA-20260909.json](release/GLOBAL-QA-20260909.json). This is an internal handoff manifest, not a live App update response or publication approval.
- File: `build/global-qa/Saydian-global-0.1.20+1002-qa.apk` (68,190,604 bytes, ignored by Git).
- SHA-256: `a3169fe4c897da4222d603189d9003fe0cd08e326dd4ae5df42bf07978c1ab66`.
- Package: `cn.saydian.app.global`; label `Saydian`; version `0.1.20+1002`; Android 8+/two ARM ABIs. Both Debug and Release QA compile; Release is debug-signed, not an app-store package.
- Latest Harmony camera merge host tests: 481/481. No HAP/iOS binary has been supplied.
- No phone is currently visible to ADB. Installation coexistence and watch tests remain pending. Before handing a copied APK to QA, verify this hash; never point the domestic download page at it.
- The global server is not yet deployed (capabilities HTTP 404); this APK is for isolated UI/device QA, not proof of working online registration or commerce. Supply reviewed legal text and separately approved provider/deployment configuration before live onboarding tests.
