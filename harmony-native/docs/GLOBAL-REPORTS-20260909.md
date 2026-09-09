# International Harmony report workflow — 2026-09-09

## Scope and baseline

- Parent coordinates the shared Git checkpoint/fetch; only `harmony-native/**` is edited here. Baseline: merged `06bf2a6`, existing international changes, 457 passing host tests.
- Complete existing V2 health-report generation, failed-report retry and authorized PDF export. No new payment/provider integration, health conclusions, model algorithms or fabricated data.
- Fresh server profile, current reviewed analysis document/version and eligibility gate writes. Purchase remains unavailable; generation uses only actual available credits. Preserve historical read access and never translate server health conclusions in the client.
- Use fixed global authenticated PDF endpoint, bounded binary response, no redirects, owner/session checks, system-selected destination, actual write/flush/size verification. Cancellation is not success.

## Evidence and checks

- Read server `reports/health-reports.controller.ts` and service create/eligibility/retry/full/export, Flutter `api_client.dart`, and international handoff before changes.
- Found server retry did not independently check withdrawn/outdated analysis consent; reported to the server owner for server-side enforcement as well as client gating.
- Official API references: [DocumentViewPicker.save](https://raw.githubusercontent.com/openharmony/interface_sdk-js/master/api/@ohos.file.picker.d.ts), [fileIo write/fsync/stat](https://raw.githubusercontent.com/openharmony/interface_sdk-js/master/api/@ohos.file.fs.d.ts). Picker returns user-selected URIs; file APIs write binary data and report written bytes. Use API 17-compatible existing RCP with `autoRedirect:false`, not API 23-only NetworkKit redirect options.
- The prior bounded Windows SDK search found no usable Harmony SDK/HDC/Hvigor. Host tests and TypeScript checks below do not constitute ArkTS compilation, a signed HAP or physical-device export acceptance.

## Implementation and safety follow-up

- Added strict UUID profile/eligibility/report models; fresh profile/eligibility gates each create/retry, single-flight write protection, explicit current-version notice reading/agreement/withdrawal and failed-only retry. Existing credits are required for creating a report, but retry does not charge another credit. An `awaiting_payment` race is surfaced without opening a payment flow.
- Added binary authenticated export, one 401 refresh retry, exact global endpoint/no redirects, 20 MiB cap, PDF signature/EOF validation, system-selected save destination, complete write/flush/size checks, and stale account/page rejection. Cancellation does not create a success message. Failures never delete the user-selected file; the error advises checking for an incomplete file.
- Added 15 eight-language report UI rows; original server legal/report paragraphs remain unchanged. New consent never comes from a guessed version or client translation.
- Parent requested blocking the imported minute-merged V1 health uploader until lossless V2 mapping is finished. `globalAuth` now rejects before transport and acknowledgment. The real queue coordinator test proves records remain pending with `uploaded:0`; this is a **known unavailable international upload path**, not a completed V2 migration. Local watch synchronization/storage are preserved.
- Removed legacy `token` headers from normal and multipart native requests; international credentials now use `Authorization` only.

## Commands, outcomes and corrections

1. Initial readonly `rg` with explicit Windows wildcard file arguments twice reported path syntax errors; reran on actual directories/exact files. No source effect. New analysis-notice UI was initially written against guessed `ArticleBlock.type/value`; immediate local interface inspection corrected this to existing `kind/text` before tests. Regression reads the real block contract. One multi-file documentation patch failed context verification and applied nothing; reread exact tails and reapplied separately.
2. `node --test --test-reporter=spec tests/global-reports.test.mjs tests/global-auth.test.mjs tests/legacy-safe-http.test.mjs`: **32 passed**, 0 failed (before native-save tests and safety follow-up).
3. `node --test --test-reporter=spec tests/global-reports.test.mjs tests/global-report-export.test.mjs`: **20 passed**, 0 failed. Includes cancelled picker, owner/page changes, partial/open/flush/size/close failures, redirect/401/403/404/503, malformed PDF, size cap and no V1 upload/no acknowledgment.
4. `node --test --test-reporter=spec tests/*.test.mjs`: **477 passed**, 0 failed, 0 skipped. Existing 457 tests retained; 20 new tests.
5. Existing server TypeScript compiler `tsc --noEmit --skipLibCheck --target ES2022 --module esnext --moduleResolution bundler` over GlobalAuth/Locale/Configuration/Update/HealthReports and AccountClient: **passed**. This excludes ArkUI/ArkTS native compilation.
6. `node tools/audit-global-locale.mjs`: **574 semantic rows × 8 locales**, 651/651 audited single-quoted Chinese Index literals have English mappings; 260 use English fallback. Dynamic strings, native callbacks, server content, layout and mother-tongue review remain outside this static metric.
7. `git diff --check -- .`: **passed**, existing LF→CRLF notices only. No commit/push/package was produced by this subtask; parent will checkpoint and merge the separately reviewed incoming Harmony camera change before final suite.

Server-generated report/PDF content still requires separately reviewed translations; no live health/account data or paid operations are used by host tests. The new native chooser/download path remains **uncompiled and not physically exercised** without a Harmony SDK/device. These host checks do not certify a release HAP.
