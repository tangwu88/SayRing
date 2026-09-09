# International post-login commerce/profile/settings audit — 2026-09-10

## Scope, baseline and authority

- This is a **read-only product/contract audit**, not feature implementation. Root exclusively operates the phone. This subtask has not read credentials/private journals, created accounts, submitted user data, uploaded files, sent feedback, installed an APK or operated a backend.
- Read App `AGENTS.md`, current international handoff/change index, authentication-device and consent records, joint coverage and prior read-only-commerce record. Older coverage 404 snapshots are historical; current public GET results are below.
- `git status --short --branch`, `git remote -v`, `git fetch --prune origin`, `git rev-parse HEAD`, `git rev-list --left-right --count HEAD...origin/main`: App starts clean on `main`, `619484c24fea57af9fe28122916de14ffcb5dc88`, matching origin, **0/0**. No merge/reset/commit/push.
- Server source inspected read-only at `F:/xcodeplace/saydian-server-global`, clean `codex/global-api-foundation`, `99bc69692969052dae489028466d329cc5619833`. This is the inspected checkout SHA, not an independently verified deployment revision.
- Initially only this new record was authorized. Root subsequently explicitly authorized a separate pure-mock host audit probe to verify suspected profile defects. Added `tool/audit_global_postlogin_profile_test.dart`; no runtime, existing test, CI or index changed. Its passing assertions **reproduce current defects**, not accept correct behavior; it is intentionally outside default `test/` and is not a release regression gate.

## Actual entry → contract → current state

All short HTTP paths below are relative to `https://app.saydian.cn/global/api/saydian-app/v2`. Canonical V2 literals are mapped by the international transport; do not replace them with V1 paths or disable origin protection.

| Actual entry | Client and server contract | Audit conclusion |
| --- | --- | --- |
| Health home → Shop | `ShopHomePage` branches to `GlobalShopHomePage` (`lib/ui/shop_pages.dart:92`); GET `commerce/home`, GET `commerce/products` with keyword/categoryId/page/pageSize/locale | Truly connected browse-only entry. Server returns `{banners,categories,featured}` and paginated `{items,total,page,pageSize}`; UI separately loads products, so no featured/items mismatch. Public current catalog is empty, not a demonstrated DTO omission. |
| Catalog → product | `GlobalCommerceApi.getGlobalShopProduct(String)` (`lib/services/global_api_client.dart:689`), `GlobalShopProductPage` (`lib/ui/global_shop_pages.dart:250`); GET `commerce/products/{opaque-id}` | UUID retained; actual strings/detailHtml/skus/gallery mapped. No product exists in the current public list, so real detail/images/translation cannot be accepted this round. Host navigation/DTO tests pass. |
| Product price / purchase | `globalCatalogPrice` (`lib/ui/global_shop_pages.dart:350`), client transaction overrides (`lib/services/global_api_client.dart:633`, `:646`, `:696`); server `commerce/global-commerce-policy.ts:22` and `commerce-store.service.ts:321` | Missing currency/exponent stays “Price to be confirmed”; no inferred CNY/conversion. International checkout remains closed and page has no purchase/cart submission. Server markets currently empty. An empty list is not proof of valid prices or usable checkout. |
| My → orders/status shortcuts/after-sales | `SettingsPage._openOrders`, `OrdersPage` (`lib/ui/pages.dart:8784`), `AfterSalesPage` (`:8475`); international `getOrders/getOrderDetail/getOrderExpress/applyOrderRefund` fail before network | **Not implemented internationally**, not a working empty history. Existing order/status DTO is integer/V1 while actual V2 supports opaque IDs. UI can show unavailable state; do not turn on it by stripping guards. True server routes exist at `commerce/orders` and `commerce/orders/{id}`, but App intentionally does not consume them. |
| Account settings → delivery addresses | `lib/ui/pages.dart:9729` → `ShopAddressBookPage`; V1-shape international methods reject without network (`global_api_client.dart:717`, `:754`) | **Closed/unmigrated**. “Add address” still opens a domestic form, see P2-A below. Real V2 GET `commerce/addresses` and POST/PATCH use countryCode/international mobile/name/detail/postalCode; no write tested. |
| My avatar / Account → personal information | `ProfileEditPage` (`lib/ui/pages.dart:9900`) → GET/PUT `members/me`; `global_api_client.dart:396–436`; server `members/members.controller.ts:9–24`, `members.service.ts:21` | Real profile route and gender/birthday/heightCm/weightKg/masked contact mapping exist. However save success/owner isolation have reproduced P1s below; not accepted for mutation. |
| Profile → choose avatar → save | `AppController.saveMemberProfile` → multipart POST `files?purpose=avatar`, field `file`, image/jpeg/png/webp; returned URL → profile PUT → GET | Real upload contract exists. Server emits `${PUBLIC_BASE_URL}/api/saydian-app/v2/files/{id}`; isolated config fixes public base to `/global`. GET file is intentionally public for ACTIVE **avatar** only (`support.service.ts:254`); missing Bearer is **not** a confirmed avatar blocker. Storage/upload/content delivery were not live-tested. |
| My → units / language | Unit radios → `setUnits` memory-only (`app_controller.dart:1734`); language picker uses existing persistent `GlobalLocaleController` | Unit choice does not persist (P2-U below), separate from persistent App language. No automatic watch language write or server unit request from this page. |
| My → feedback | `prototype_pages.dart:4981` → `AppController.submitFeedback` → POST `support/feedback` (`global_api_client.dart:220`), server `support.service.ts:29` returns opaque `{id,status}` | Actual authenticated contract connected; client checks nonempty returned ID, not fabricated success. Text length UI 5–500 is within server 5–2000; contact >100 is only rejected by server. No feedback POST executed. Visible controls/help remain partially Chinese (P2-L). |
| My → customer service | `CustomerServicePage(isGlobalEdition:true)` (`prototype_pages.dart:5150`) | Explicit unavailable screen, **not wired** to GET `support/config`; correct for current `configured:false`, but it will not automatically expose future server-configured channels. Domestic phone/WeChat actions are not rendered for global. |
| Account → reset password / logout / deletion / legal | International auth page / V2 `auth/logout`, `auth/delete-account` (`global_api_client.dart:979`, `:997`); current global legal page for about/account (`pages.dart:9766`, `prototype_pages.dart:5260`) | Actual routes exist; reset remains capability/verification gated. Logout has earlier real API evidence, not re-run here. Deletion is real server mutation and intentionally not clicked. Legal routes no longer use the old numeric article IDs in global. |
| About → check update | Root update gate → `GlobalAppUpdateService.check` (`global_app_update_service.dart:4`), GET `support/app-update` | Real global, package-bound, explicit SHA/destination validation; unavailable manifest is not “up to date”. Current GET404 means publication unavailable; no download/install attempted. |

## Confirmed defects, reproduction and minimal recommendations (not fixed)

### P1-P — old avatar result can submit the old profile under a new account

- Evidence: `lib/services/app_controller.dart:2747` waits for avatar upload, then `:2751` sends the old nickname/gender/birthday/body without rechecking owner or generation. `lib/services/global_api_client.dart:472` returns a successful upload without an owner-after-await check; `lib/services/api_client.dart:1982` validates authorization retry only when unauthorized, and `:2060` reads the **current** vault session for each new request.
- Pure-mock reproduction uses the **real GlobalSaydianApiClient**, real multipart path and controller, not a fake replacement upload: begin A's avatar upload, complete `controller.logout`, write synthetic B session, then release A's successful upload response. The next profile PUT carries B's Bearer and A's profile payload, and returns success. No actual network/image/account is used.
- Expected: no profile PUT or success callback after account transition; any known uploaded artifact should remain associated with its original account, not be attached to the new one.
- Minimal fix after separate authorization: capture generation/owner before starting, verify after upload and before each subsequent protected operation/readback; pin authorization to that account and reject late success/error/UI effects. Do not rely only on disabled buttons.

### P1-R — failed profile readback still reports “saved”

- Evidence: `app_controller.dart:2759` awaits `refreshMemberProfile`, but `:2725–2728` catches its GET error and returns normally; `_guard` (`:4605–4613`) therefore returns true. `pages.dart:10085–10089` displays saved and pops the editor.
- Reproduced with real international client: PUT `members/me` HTTP200, subsequent GET500, `saveMemberProfile` returns true, `errorMessage` is nonempty and `memberProfile` remains empty. This is not proof that the server lost the PUT; it proves the App claims a confirmed complete save despite failed verification.
- Expected: distinguish saved-but-not-confirmed from confirmed readback; retain editor input and offer retry. Compare submitted fields against owner-bound readback, not merely an HTTP acknowledgement.

### P2-H — profile height validation contradicts server range

- `pages.dart:10064` and validation hint allow 50–300 cm; server `apps/api/src/members/members.service.ts:53` accepts 50–250. Widget probe enters 275 into actual ProfileEditPage, successfully reaches a PUT with 275, then receives synthetic server400 according to the source bound.
- Minimal correction: shared displayed/client range 50–250, with boundary tests 50/250 accepted, 49/251 rejected before networking. Do not change health algorithms or server limits.

### P2-U — selected units are lost after restart

- `app_controller.dart:377–378` hardcode default km/°C; `:1734–1737` only mutate memory and notify. Probe sets miles/°F then constructs another controller using the same vault: defaults return.
- Minimal correction: persist explicit unit preference in the proper environment/account namespace and restore before rendering; do not silently send watch settings. App language persistence is unrelated.

### P2-A — unavailable addresses still invite a full impossible domestic form

- Account settings links to the address book (`pages.dart:9729–9736`). Empty/failure state and floating action both offer “Add address” (`shop_pages.dart:1970–1975`, `:2010–2014`), opening the domestic form whose phone regex is `^1\\d{10}$` (`:2181`) and province/city/area integers are required (`:2110–2131`). International `saveAddress` always rejects before sending.
- Expected: explain availability before collecting address/contact details; do not ask users to fill a form that cannot succeed. A future proper migration requires opaque ID, country and international phone/address/currency readiness, not enabling the old form.

### P2-L — English App retains Chinese primary controls in these sections

- Certain live branches have literal Chinese: My feedback entry (`pages.dart:8258`), profile gender choices/save/logout (`:10209–10211`, `:10265`, `:10278`), unit choices (`:9549–9556`, `:9572–9573`), order tabs (`:8800–8806`), feedback categories/results/submit/help (`prototype_pages.dart:4993`, `:5026–5028`, `:5051–5055`, `:5087–5109`) and About introduction (`:5228`; global skips remote replacement at `:5250`).
- Expected: all labels/validation/result/help use the chosen locale. Existing English page title alone does not validate the inner flow. No ARB/UI change made during audit.

## Public fixed-origin GET evidence

Executed a PowerShell literal here-string piped to `node --input-type=module`, fixed origin/prefix, hardcoded paths, GET only, `redirect:error`, `credentials:omit`, no Authorization, 15-second AbortSignal. Output only route names/status/requestId/shape flags/counts. No response body, opaque IDs, health values, contacts or tokens printed.

| GET path | Actual result | requestId |
| --- | --- | --- |
| `commerce/home` | 200/code200; banners/categories/featured arrays, featured count 0 | `c07416a2-30aa-4053-80b8-aff28b845e55` |
| `commerce/products?page=1&pageSize=1&locale=en` | 200/code200; items count0, total integer. Price metadata remains **unverified**, because no row exists. | `44ad097b-02cd-48f7-8a14-d7aa92c24390` |
| `commerce/markets` | 200/code200; markets count0. No usable market demonstrated. | `815cbcc1-8f04-4c23-a4fb-64d45ab5895d` |
| `support/config` | 200/code200; configured=false | `1892f713-b474-4b48-a554-9051b51ec593` |
| `support/app-update` | 404; no accepted update manifest | `88a29baa-14f0-4b72-898d-d7ce92eec3e9` |
| `members/me` anonymous | 401, data null | `ddf91df2-984e-4d26-9ef8-990fdc84d576` |
| `members/me/goals` anonymous | 401, data null | `3de42c90-b18d-44f0-88f9-697df5189679` |
| `commerce/cart` anonymous | 401, data null | `7e433d13-890c-4bb0-960d-eb4d5f6a31c7` |
| `commerce/orders` anonymous | 401, data null | `22082d97-7695-4e83-9460-6d0a0f4ea815` |
| `commerce/addresses` anonymous | 401, data null | `ca352a80-f53f-4b05-9a33-7f7ad64a3d67` |

No product detail/foreign resource was fetched using guessed IDs. No assumption that 401 proves authenticated DTO correctness or that public200 proves real transactions.

## Commands, test failures and results

- `rg`/`Get-Content` source inspection included a few misplaced App-relative paths while working in the server directory and unexpanded PowerShell glob paths; these failed with file-not-found and were re-issued against actual files. No file or server correction followed those navigation mistakes.
- `flutter test --no-pub --reporter expanded test/global_commerce_api_test.dart test/global_shop_pages_test.dart test/global_shop_media_test.dart test/global_update_test.dart test/global_network_boundary_test.dart test/global_api_test.dart test/login_page_test.dart`: **86/86 passed**. This preserves known browse-only/currency/redirect/legacy-zero-request/profile-load UI coverage, but those tests do not cover the P1 cases above.
- New explicit `flutter test --no-pub --reporter expanded tool/audit_global_postlogin_profile_test.dart`: first compile failed because the probe called nonexistent `MemorySessionVault.saveSession`; corrected only probe to existing `writeSession`. Second run reproduced both P1s and units but Widget `ensureVisible` failed on an unbuilt offscreen element. Changed only fixture to `scrollUntilVisible`, hid test keyboard and pumped layout. Third run **4/4 probes reproduced**, with no missed-tap warning or real server request. A passing probe means the documented defect remains reproducible.
- `dart format tool/audit_global_postlogin_profile_test.dart`: one new probe file formatted; no runtime formatting. `dart analyze` initially reported one braces lint on a new test branch; added braces rather than suppressing it. Final checks are appended below.
- Final `dart analyze tool/audit_global_postlogin_profile_test.dart`: **No issues found**; `dart format --output=none --set-exit-if-changed` checks one file, **0 changes**; repeated four-probe command: **4/4 current defects reproduced**, no failures. `git diff --check` and trailing-whitespace checks pass. A final combined regex line-location command had a quoting/unclosed-group error; replaced it with separate `rg -F` literal searches rather than changing source. The final worktree contains only this audit's new record/probe and other agents' new audit records.
- Every write-shaped request in these probes uses `http.MockClient`, synthetic contact-free payloads/tokens and an isolated tiny temporary file. The test-owned temporary directory is verified before deletion. No real user file/credentials were read or deleted.

## Suggested next root QA (read-only)

1. Existing signed-in phone: open My → profile, inspect only masked contacts and expected values without saving/uploading; navigate back. Do not force a logout or replace the user's session for this audit.
2. For an already-authorized dedicated QA session, GET `members/me`, `members/me/goals`, `commerce/cart`, `commerce/orders`, `commerce/addresses`; compare only DTO field presence and ownership in memory, output booleans/counts/requestId. Do not echo identifiers, addresses, contacts, avatar URLs or tokens. These server reads do not mean the disabled App order/address UI is integrated.
3. Continue the fixed public GETs above. If products appear, use only a returned opaque ID for GET `commerce/products/{id}`; verify currency and exponent before price acceptance. Inspect only allowed new-domain media, with redirects disabled. Current empty catalog supplies no ID.
4. Updates: require an actually published global package-bound manifest and artifact validation before download/install; current404 is unavailable. Support: currentconfigured=false remains unavailable.
5. Profile P1 repair requires a separate implementation authorization, then invert/replace the audit assertions with proper regressions and run full release gates. Current findings must remain **unfixed**, not labeled passed merely because 86 old tests are green.

No APK build, real phone write, account creation/deletion, feedback submission, profile upload, order/payment/refund, delivery operation or Git commit was executed by this audit subtask.

## Read-only follow-up: password-reset unavailable text and phone correlation

- Root reports the actual phone's Account settings → Reset password has the reset title but a banner saying registration is temporarily unavailable. No contact/code/password was entered and no send/submit action was performed. Root owns the phone evidence in [post-login device check](INTERNATIONAL-POSTLOGIN-DEVICE-CHECK-20260910.md); this subtask checked code and one anonymous capability GET only.
- **P2-T, wrong unavailable text for password reset:** `lib/ui/global_auth_page.dart:54` sets `_accountSetupMode` for both sign-up and reset. At `:298–306`, reset correctly chooses `recoveryEmail/recoverySms`, not registration flags. At `:333–336`, however, any setup mode that is not loading and whose selected channel is unavailable renders the same `l.registrationUnavailable`. Translations are `lib/l10n/app_zh.arb:395` / `app_en.arb:418`. The reset title at `:310` is correct; the banner is wrong. Capabilities absent after a failed read also enter that shared message branch.
- Current fixed GET `https://app.saydian.cn/global/api/saydian-app/v2/auth/capabilities?locale=en`: HTTP200/code200/global realm, **registration.email=true, registration.sms=true, verificationRequired=false; recovery.email=false, recovery.sms=false**, requestId `0302a037-dd57-48e5-bacd-6c9ddf81d428`. Therefore the phone banner is **not evidence that registration broke or was disabled**. Temporary no-code registration is open while password recovery is unavailable.
- Server source separates the features (`apps/api/src/auth/global-auth.service.ts:19–35`): registration can use the explicit no-verification flag plus published legal readiness, while recovery always requires `ready.email/ready.sms && deliveryOpen`. `global-verification-delivery.service.ts:16–19`, `:43–64` marks a channel ready only with an enabled webhook provider, CONFIGURED/verified delivery setup, usable HTTPS URL/token and a valid country list for SMS. No secret/provider config was inspected. The live response proves the recovery channels are not ready; it does not identify which private configuration prerequisite is missing.
- Reset intentionally always requires verification (`global_auth_page.dart:57–60`). `_sendCode` checks `permits(identity, recovery:true)` (`:170`) and the shared availability controls prevent using the temporary registration exception for password recovery. **Do not remove reset verification or enable a disabled provider to silence the message.** Minimal future UI fix: distinct localized recovery-unavailable text/CTA and a separate capability-load-failed message; keep real capability enforcement.
- Root additionally observed the unavailable address toast plus “No addresses” empty state, three Add-address affordances and the province/autonomous-region form; this corroborates P2-A without any address submission. Root opened units without changing them, so the P2-U persistence proof remains host-mock/source evidence, not a phone preference mutation.
- Follow-up source navigation initially referenced nonexistent `global_models.dart`; the actual model is `global_account.dart`. Two `Select-Object -First` probes mistakenly supplied an English word instead of an integer and failed before reading files; the corrected numeric invocation succeeded. No runtime/test/CI/server change or mutation followed any of these read-only errors. Only this record was appended.
