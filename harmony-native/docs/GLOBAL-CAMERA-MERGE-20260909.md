# International camera merge — 2026-09-09

- Parent checkpoint `9f84b03`; incoming reviewed domestic commit `887af66` adds actual CameraKit preview/capture and gallery saving. Resolve only two conflict regions, not whole-file replacement.
- `Index.ets`: retain camera preview, lifecycle teardown, capture callbacks, gallery preview, explicit start/capture/close; wrap new visual/accessibility strings with existing translation lookup. Retain international account/report/PDF routes and global app identity.
- `base/element/string.json`: retain English base descriptions and add truthful on-demand camera reason. Add complete module/Bluetooth/location/camera permission resources for en, zh_Hans, zh_Hant, de, fr, es, ja, ko. Native permission dialogs follow system resource selection, distinct from the app's persisted custom language selector. No claim that custom selector changes OS dialogs.
- Verified automatically merged `module.json5` retains empty domestic provider metadata and only adds in-use CAMERA permission. `AppScope/app.json5` still uses `cn.saydian.app.global.hm`.
- Map new camera errors/labels to English fallback for non-Simplified-Chinese locales; full native camera 8-language translation remains unaccepted. Avoid passing arbitrary native camera exception details through to UI; only known user-facing errors pass.
- Resource qualifier syntax follows [Huawei resource matching documentation](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V2/resource-categories-and-access-0000001544463977-V2), including language/script qualifiers and English base fallback.

## Checks and corrections

- First pure TypeScript check found duplicate fallback object keys for three already-translated camera statuses (`TS1117`). Removed the new duplicates and retained existing entries; no alternate duplicate-value logic added.
- `node --test --test-reporter=spec tests/*.test.mjs`: **481 tests passed**, 0 failed, 0 skipped. Includes one incoming camera contract regression plus three international identity/resource/translation merge guards, on top of the previous 477.
- Existing TypeScript compiler `tsc --noEmit --skipLibCheck --target ES2022 --module esnext --moduleResolution bundler` over global models/AccountClient: **passed** after duplicate-key fix. This does not compile ArkUI or CameraKit.
- `node tools/audit-global-locale.mjs`: **574 semantic rows × 8**, audited Index literals **663/663** English-covered, **272** English fallback literals. New native camera labels/errors are tested separately for English coverage; they are not claimed as full 8-language acceptance.
- Working/staged `git diff --check`: final conflict markers removed and checked. No native build or physical capture test was run; merge/host checks do not establish a HAP or actual gallery permission behavior.
- Parent owns final merge commit. Only resolved conflict files are staged by this worker; remaining new translation/resource/test/log changes are left for explicit parent staging.
