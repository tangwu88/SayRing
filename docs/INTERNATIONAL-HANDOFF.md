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

Use Flutter `D:/Dev/Flutter/3.44.9`, JDK `F:/Codex/home/tools/jdk17`, Android SDK `F:/Codex/home/tools/android-sdk`, Gradle cache `D:/Dev/Gradle`. Enter the **global** workspace, not the domestic environment script's hard-coded directory.

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

## Remaining release gates — do not mark complete

- Real deployment of isolated global API/Worker/DB/Redis/storage, migrations and gateway tests. Current local server work is source/scaffold verification only.
- Real reviewed legal documents, authorized email/SMS testing and enabled countries; no contact information or real sending credential was supplied in this task.
- International catalog price books, tax/shipping/inventory coordination and payment rails are not implemented/accepted. Checkout remains disabled, not CNY with a new currency symbol. Full global commerce/address/order UI and remaining compatibility routes need contract migration.
- All-screen localization is not complete: see exact Flutter/Harmony records. Long health/device copy, dynamic messages, report/PDF and stored push/body translations still require completion and linguistic review. First-launch English and resource availability alone do not prove eight-language acceptance.
- ECG waveforms require an explicitly known sample rate and confirmed V2 artifact storage. Unrepresentable waveforms must remain pending, never silently discarded as uploaded.
- Actual iPhone/macOS build/signature, Harmony SDK/HAP compilation, physical phones and two different watch firmware/model tests. Do not reuse domestic historical screenshots/builds as international acceptance.
- Public downloads, paid production transactions, app-store submissions and TestFlight publication require separate accepted channels. This task has not performed them.

The following sections are updated after final checks; consult the command-level record for current pass/fail counts and package hashes.
