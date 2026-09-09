# Logged-in Android functional inspection — 2026-09-10

## Scope and baseline

- User asked to check App functions after login. This round inspects actual routes, reads current data, runs isolated diagnostic fixtures and records findings; it does **not** authorize implementation of unrelated changes or real transactions.
- `git status --short --branch`, `git remote -v`, `git fetch --prune origin`, `git rev-parse HEAD origin/main`, `git rev-list --left-right --count HEAD...origin/main`: clean starting `main`, both `619484c24fea57af9fe28122916de14ffcb5dc88`, `0/0`.
- Read App instructions, previous authentication/device record and coverage matrix. Historical `not accepted` entries are not silently changed merely because the server has since deployed.
- Current Huawei Android 10 phone is authorized, international App `cn.saydian.app.global`, `0.1.21+1004`; preserve the existing real signed-in account and connected watch. No logout, new account, profile/goal/health-rule save, contact/face overwrite, OTA, real payment/refund/shipping or AI message submission.
- Root alone operates the phone. Three parallel source/test audits inspect health/care/AI, device features and commerce/profile/settings; no runtime implementation. Source audit and mocked reproduction are not phone/SDK acceptance.
- Read current UI tree before every target action; reject missing/ambiguous targets and null trees rather than using stale coordinates. Only navigation/scroll/back/cancel and safe read-only pages. Do not enter camera mode because opening it also sends a watch control command. Avoid reading contacts into the inspection output.
- UI summaries redact contacts, identifiers, device addresses and numerical content. Raw UI dumps remain on the debug device/private environment; no screenshots, credentials or raw health values enter Git.

## Actual phone navigation

| Area | Actual action and result | Boundary |
| --- | --- | --- |
| Session/home | Installed build 1004, health home and three bottom tabs visible | No fresh signup or account switch in this round |
| Messages | Home bell opens message page, `暂无消息`; back returns home | No received-event/open/read mutation tested |
| Remote care | Opens empty relationship list; Add care opens a contact form with both email and phone guidance; Cancel works | No invitation sent, no sharing permissions changed. **Two back bars** visible at distinct vertical positions on care page; record as layout duplication |
| Encyclopedia | Opens actual page and settles to `该分类暂无百科内容` | No available article to test detail content; a transient empty accessibility tree during transition was refreshed, not called a permanent blank page |
| AI | Chat page/input/send control open; back returns home | No real message submitted or provider reply accepted; send button has no accessible label in Android UI tree |
| Health warnings | Page loads heart-rate/BP/temperature switches and Save action; current list `暂无健康预警` | Read only, no toggle/save or generated alert; cloud warning rules are not watch capability controls |
| Health history | All-data opens existing BP/ECG groups; BP day/week and a single-record detail open and return; ECG day/month shows `该时间段暂无数据` | Local history is not cloud rehydration. No measurement/calibration or numerical/medical validation. The BP month/scroll combined call lost its returned exec session metadata; a subsequent fresh tree confirmed a record was visible, but this is **not** full month-view validation |
| Mall/search | Actual catalogue opens empty; enter non-personal keyword `watch`, search and return with no failure | No current product to validate detail, SKU, image, currency or checkout; no cart/order/payment write |
| My cards/profile | My device card navigates to Device; avatar/user card opens profile editor with existing fields and avatar action; Back works | No upload, typing, gender selection or profile save. Underlying health/care pages tested separately; not all duplicate shortcuts were tapped |
| Device state | My device card and Device root show disconnected; only start-search and connection help visible, no guessed feature catalogue | No disconnect was issued in this round. Time/cause of the lost connection is **not established**; do not call this a reproduced connection-regression cause |
| Device search/help | Search finds multiple nearby peripherals, including multiple identically named devices; Back exits scan. Connection guide opens with nonempty body and no `SDK/BLE/Veepoo/接口未配置` match | No device selected by name/RSSI; no connection/sync/control/settings or hidden page forced. Connected-device feature acceptance remains pending |
| Orders | My pending-payment and pending-shipment tabs open, both explicitly show `此功能暂时无法使用，请稍后再试` | This is unavailable, **not** successful order-history integration. No transaction or after-sales request |
| Units | Opens km/miles and Celsius/Fahrenheit choices | Existing selections preserved, no toggle; restart-loss defect is reproduced only with isolated controller fixtures |
| Account settings | Profile, addresses, reset, privacy, logout and deletion entries visible | Logout/delete never clicked; real phone session retained |
| Addresses | Address book shows unavailable toast **and** `暂无收货地址`, with three Add actions; toolbar Add opens domestic `省/自治区` form | Failure is misleadingly mixed with empty state. No address input/save, no default toggle; Back twice exits. Source confirms international legacy address writes are blocked |
| Reset password | Correct reset heading, email/phone fields, but top message says `注册暂时无法使用，请稍后再试` | No OTP, password or consent submitted. Wrong registration copy on reset page is not evidence that actual registration is closed; see commerce audit appendix |
| Privacy/terms | Account privacy and About user-agreement pages load nonempty text with matching headings and no load-failure marker | This verifies route/content load, not legal sufficiency or all locales; no agreement acceptance/version mutation |
| Help/feedback | Form, type choice, submit and FAQ entries open; connection FAQ expands | No feedback submission/contact entered. Expansion works; no provider support ticket created |
| Customer support | Explicit unavailable card plus warning not to send passwords, codes or full health records to unofficial accounts | Consistent with public support `configured:false`; no external channel launched |
| About/update | Version page opens; Check update shows `Updates are not available yet. Please try again later.` | Manifest HTTP404, not latest-version success; no download/install. English update message in Chinese UI is a locale inconsistency |
| Permissions | Seven permission rows and settings actions visible; Back works | Status read only; no Android permissions changed or system setting opened |

At completion the phone is back on the signed-in Health home, build `0.1.21+1004`; one Flutter attach process remains. No App reinstall, force-stop, clearing, logout, watch reset or user-data mutation was performed. Health dashboard/report generation and billing were not opened on the real account: dashboard entry calls `billing/entitlements`, whose server GET can expire memberships/write its ledger. That normal business side effect is not treated as a strictly read-only probe.

## Authenticated live service read evidence

Fixed origin **`https://app.saydian.cn/global/api/saydian-app/v2/`**. Used the already-authorized dedicated reserved-domain QA account, not the phone's real account. Credentials were read in memory from its protected private journal after validating its synthetic pattern; neither values nor private records enter Git. No new account was created. `HttpClientHandler.AllowAutoRedirect=false`, 15-second timeout, 256 KiB response cap, fixed GET allowlist and `auth/login`/`auth/logout` only. No automatic refresh, arbitrary endpoint, provider send or business write.

All 12 authenticated GETs returned **HTTP200/code200**. Counts below are this empty QA account, not the real user's health/care/message values.

| GET path | Shape/state | requestId |
| --- | --- | --- |
| `health/records?limit=1` | items 0 | `72affd72-4891-436e-8444-37c14dbedb48` |
| `health/warning-rules` | items 0 | `836665b0-d160-482c-988a-5861d9606634` |
| `health/warnings?limit=1` | items 0 | `0f6ef345-33ec-4b68-bb1f-c623e56ac3f8` |
| `health/profile` | object | `9610e52a-9181-4bd4-9934-b9ab98f8e741` |
| `health/reports/eligibility` | object | `eff5a55d-fe7b-4895-9e65-0663857bdf45` |
| `health/reports` | items 0 | `780e0313-94c1-42ab-84d7-904633bb7ff2` |
| `ai/messages?sessionId=saydian-global-1` | items 0 | `237421e0-e32b-4fde-942a-6cdad7e7125f` |
| `care/relationships` | items 0 | `74ccec80-35ec-409a-aa16-9b9c53db4cf4` |
| `notifications?page=1&pageSize=1` | items 0 | `43b23265-a949-47ff-81ff-5c1430e64ce5` |
| `notifications/unread-count` | object | `2f517941-672a-4a8d-a602-df689d4e2516` |
| `members/me` | object | `821e2d0b-c1cf-467c-8493-c092445e2ad7` |
| `members/me/goals` | object | `08f9263c-4f62-4d82-87e2-af1c1f00d4f1` |

Finally logged out **only this dedicated diagnostic session**, server acknowledged; its subsequent `members/me` returned401. Cleanup requestId: `59513482-d165-4fd7-84a4-e91828fe4dc7`. No token persisted/output, no current-phone logout. GET200 proves those query/shape paths, not nonempty data, cross-user sharing, AI generation, waveform preservation or full bidirectional synchronization.

Public GET evidence is in [commerce audit](INTERNATIONAL-POSTLOGIN-COMMERCE-AUDIT-20260910.md): home/products200 with no products, markets200/empty, support200/configured false, update manifest404, and anonymous private-resource401 checks. App's order/address guards remain closed despite server V2 routes existing.

Password-reset follow-up: anonymous `auth/capabilities?locale=en` HTTP200/code200 reports registration email/SMS enabled with verificationRequired=false, but recovery email/SMS disabled (requestId `0302a037-dd57-48e5-bacd-6c9ddf81d428`). Thus the reset banner is wrong copy, **not registration being disabled**. Password recovery must remain verification-gated until a real channel is ready; do not extend the temporary registration exception to recovery.

## Findings and priority (not fixed)

| Priority / ID | Confirmed gap | Evidence / status |
| --- | --- | --- |
| P1 / P1-P | Old avatar upload can continue with old profile under the new account's token | Real international multipart client + controller, synthetic HTTP and explicit synthetic B session after real controller logout; no real-user exploit. [Profile probe](../tool/audit_global_postlogin_profile_test.dart). Unfixed |
| P1 / H02 | Late old-account health dashboard can return/display on a retained page after real controller login switches to B | Real client/controller normal login and HTTP200; retained Widget shows old report marker while B session remains current. This is **not** a demonstrated natural full-App navigation exploit on the phone. [Health probe](../tool/audit_global_postlogin_health_test.dart). Unfixed |
| P1 / P1-R | Profile PUT200 + readback GET500 still returns saved=true and editor can report success | Real client/controller isolated reproduction; proves unconfirmed success, not server data loss. Unfixed |
| P1 / H01 | App does not pull cloud health history after login/new phone | Controller reads only local store; sync uploads pending records only. Server GET exists and was checked above. Source-level missing integration, not a new-phone end-to-end reproduction |
| P2 / account & commerce | Unit choice lost on controller recreation; height UI/server range mismatch; impossible domestic address form, incomplete translation, unavailable orders/support/update | First two have explicit isolated probes; source and phone observations are separately detailed in commerce audit |
| P2 / device | Unsupported notification rows rendered, generic sport flag expanded into named modes, screen-duration bounds dropped, reminder dropdown cannot represent some native-valid intervals | Four source/contract gaps, **not** current-watch failures; [device audit](INTERNATIONAL-POSTLOGIN-DEVICE-AUDIT-20260910.md) |
| P2 / health & care & AI | Care notification event IDs disagree; composite care values not displayed; missing English content fallback; provider chat request lacks history | Two-sided source review, no real AI/invite submission; [health audit](INTERNATIONAL-POSTLOGIN-HEALTH-AUDIT-20260910.md) |
| P2 / actual UI | Duplicate care back bars, unlabeled AI send action, reset page uses registration-unavailable copy, Chinese UI gets English update message | Observed on current phone; no runtime fix this round |

## Commands, failures, tests and release boundary

- All work remains on baseline `619484c24fea57af9fe28122916de14ffcb5dc88`. Root re-fetched before finishing records, `HEAD==origin/main`, `0/0`; other agents' audit files preserved. No `lib/`, SDK, manifest, dependency, CI, service or runtime source changes.
- Actual phone: `adb shell pidof`, `adb shell dumpsys package`, fresh `uiautomator dump /data/local/tmp/saydian-qa-window.xml` + XML parse, observed-bound `input tap/swipe`, `KEYCODE_BACK`. Contacts/IDs/health numbers redacted from console summaries. Three identical address buttons were resolved by the previously observed exact toolbar bounds and revalidated before tapping.
- Test harness failures and fixes are preserved in the two audit appendices: incorrect vault method, offscreen Widget, lint and async/timer lifecycle mistakes were corrected **only in new probes**. No production fix is implied. A phone batch once printed only `.output` and lost ongoing session metadata; later calls always retained the whole result and waited for completion before new phone input. Missing/transient trees are refreshed, never treated as a reliable blank-page result.
- Root independent rerun: `flutter test --no-pub --reporter expanded tool/audit_global_postlogin_health_test.dart tool/audit_global_postlogin_profile_test.dart` — **7/7 diagnostic assertions pass**. One healthy control plus six defect-case assertions; passing documents an existing failure, **not security acceptance**. Probes live under `tool/`, deliberately outside default regression discovery; after repair, replace/invert them with real safety regressions.
- `flutter analyze --no-pub` — **No issues found**, exit0, includes both new probes.
- Final `dart format --output=none --set-exit-if-changed tool/audit_global_postlogin_health_test.dart tool/audit_global_postlogin_profile_test.dart` — two files, zero changes; `git diff --check` — no whitespace errors (only normal LF/CRLF working-copy notice).
- `$env:TZ='UTC'; flutter test --no-pub --reporter expanded` — **822/822 existing tests pass**, 52 seconds reported. Generated output: ignored `build/postlogin-audit-tests-utc.log`.
- `$env:TZ='Asia/Shanghai'; flutter test --no-pub --reporter expanded` — **822/822 existing tests pass**, 58 seconds reported. Generated output: ignored `build/postlogin-audit-tests-shanghai.log`.
- Parallel existing targeted suites: health187, commerce86, device134 (overlap exists; **do not add** them as unique total). `node --test tool/test_native_log_privacy.mjs` —8 pass. Detailed exact file lists in the respective audit records.
- Existing authorized GitHub account checked run **34389201195** for exact runtime SHA619484c: **completed/success**, quality, Android, iOS, Harmony contracts UTC and Asia/Shanghai all success. Agent's default CLI404 was private-account access, not CI failure. Harmony contracts are not a native HAP build; iOS CI is not signed iPhone acceptance. This round did not rebuild/reinstall unchanged runtime or claim fresh device coverage from CI.
- Final current-process log buffer aggregation: **86** structured network events; 42 first-party API starts, 41 HTTP200 and one HTTP201; one update-manifest start and404. Every recorded host was `app.saydian.cn`; unexpected API hosts **0**. This is the retained current-process buffer, not an exact timestamp-scoped request counter for only this turn. No raw URL/query/body/token/health values output.
- The same visible current-process log buffer contained **0 FATAL EXCEPTION**, **0 matching App ANR**. This is not complete system-wide crash/packet capture. Closed SDK traffic and vendor raw-log privacy remain unaccepted; host tests and App-owned structured logs do not prove every native egress path safe.
- Final phone returned to signed-in Health home; build0.1.21+1004, one Flutter attach process. The scan was exited; no other device selected. Leave account, records, settings and installed package intact.

## Handoff / next action

**Overall result: not accepted as fully functional.** Navigation, supported read contracts and empty/unavailable states have evidence; four P1 gaps remain, and connected-watch actions were not rerun. Prior W9 rounds belong to their original record and cannot fill this round's missing connection.

Next colleague: first update `origin/main`, read this record and linked audits, then fix owner-bound profile/dashboard operations and confirmed save semantics before cloud-history hydration and smaller UI/contract gaps. Preserve health algorithms/data and source findings. Real profile writes, invitations/revocation, AI/provider response, notification delivery, nonempty catalogue/order/address workflows, all locales/scales, report/payment, true connected SDK feature read/write/recovery, other models and iPhone/Harmony hardware remain explicitly pending.

Only audit documents, command/test index and the two synthetic probes are to be committed. Raw logs, phone dumps/screenshots, account journals, server files, build outputs and binaries stay out of Git. Commit/push remote verification is performed after the record content and staged diff are checked; the enclosing Git commit is the delivery identifier, not a fabricated runtime build.
