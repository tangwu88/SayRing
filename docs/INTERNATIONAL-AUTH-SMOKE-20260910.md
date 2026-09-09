# International authentication read-only smoke — 2026-09-10

## Scope and expected result (recorded before implementation)

- Parent task requested a minimal deployment gate after `/global` authentication endpoints remained unavailable. The legacy `tool/qa_live_api.mjs` uses old routes and automatic redirects; do not reuse it for international acceptance.
- Read `AGENTS.md`, international handoff/change index/latest media record, regression/retrospective guidance, Flutter global account/auth/legal contracts, and the server's public status/auth/legal controllers without modifying the server.
- Baseline: clean `main`, `79b14e3f83b287dec63f68d56c86cbb745abd068`. `git fetch --prune origin` succeeded; ahead/behind `0/0`. No checkout, merge, reset, commit or push.
- Change only this record plus new `tool/global_auth_smoke.mjs` and `tool/global_auth_smoke.test.mjs`. Do not change App behavior, old tools, package configuration, existing tests or log indexes.
- CLI will issue GET only to fixed HTTPS `app.saydian.cn` port 443 under `/global`: readiness, global auth capabilities, anonymous current-member rejection, and the two validated legal references returned by capabilities. No URL override, arbitrary paths, credentials, cookies, login, registration, OTP or mutation mode.
- Success requires real readiness, exact global realm, explicit enabled registration, anonymous HTTP 401, and reviewed nonempty terms/privacy documents sharing the returned consent version. Missing deployment, disabled registration and missing legal content fail distinctly; network success alone is not business acceptance.
- Output is restricted to fixed check/status labels, HTTP status, normalized realm, validation Booleans and a syntactically bounded request ID. Never print response bodies, messages, legal HTML, identifiers, health values, contacts, tokens, request URLs containing untrusted values, or exception text.
- Tests will use synthetic fetch responses (no live server, account or watch), including redirect/host/path attacks, 404, unready service, disabled/missing capabilities, anonymous authorization failure, stale/unreviewed legal documents and privacy.

## Execution record

- Before implementation, one read-only source lookup guessed two nonexistent status-controller filenames; `rg` located the actual `apps/api/src/status.controller.ts`. No source or server state was changed by that failed lookup.
- Implementation, test and live-read results follow below; not yet executed at initial record creation.
- Initial `node --test tool/global_auth_smoke.test.mjs`: **40 passed / 1 failed**. The intended double-`global` attack fixture accidentally generated a valid singly prefixed legal path, contradicting the explicit positive compatibility case. Corrected only that fixture to actually generate `/global/global/api/...`; no path guard was relaxed.
- Re-ran `node --test tool/global_auth_smoke.test.mjs`: **41/41 passed**. Both `node --check tool/global_auth_smoke.mjs` and `node --check tool/global_auth_smoke.test.mjs` passed. `git diff --check` passed; `git status --short` contained only the three new scoped files.
- First live `node tool/global_auth_smoke.mjs`: **exit 1 / failed**. The fixed readiness, capabilities and anonymous-member GETs all returned HTTP 404. No legal request was sent because capability references were unavailable. Logged only fixed validation fields plus request IDs: readiness `0e25fbda-79a5-4bce-bfb5-299794aa1b1a`, capabilities `7e61f34b-f84c-4a2e-81c0-633ed4562c60`, member `b50d6966-e84d-460a-8c54-2d05d812418b`. No credentials, OTP, registration, login or server mutation occurred. This is an observed deployment blocker, not a passing test or client-side workaround.
- Added final fail-closed cases: a verification-required SMS-only capability with no usable country is not open registration; legal markup containing only whitespace/comments/scripts is not readable legal content. Timeout rejection is scheduled before abort to keep its reported status deterministic. Final commands/results follow.
- Final `node --test tool/global_auth_smoke.test.mjs`: **47/47 passed**. `node --check tool/global_auth_smoke.mjs` and `node --check tool/global_auth_smoke.test.mjs`: passed. Node version: `v24.18.0`. No dependencies installed, no formatter run, no existing files modified.

## Run after deployment

From `F:/xcodeplace/saydian-app-global` with Node 22+:

```powershell
node --test tool/global_auth_smoke.test.mjs
node tool/global_auth_smoke.mjs
```

- The CLI accepts **no arguments** and reads no credential files or environment URL overrides. Exit `0` means the narrowly defined GET gate passed; `1` means network/contract/deployment/registration/legal failure; `2` means invalid arguments. There is no login/register/write option.
- JSONL output has a final `summary` record; inspect the individual Boolean checks to distinguish unavailable registration from missing deployment or stale legal content. `loginOrRegistrationTested` remains false even on exit 0.
- At most five serial GETs are sent: `/global/health/ready`, `/global/api/saydian-app/v2/auth/capabilities?locale=en`, anonymous `/global/api/saydian-app/v2/members/me`, and the two validated capability-provided legal paths. Canonical legal references gain `/global` once. Any redirect is rejected, with no follow-up to its Location.
- Every response has a 15-second deadline and 256 KiB JSON limit. Increasing that limit or relaxing path/realm/legal guards to make a failing deployment green is not an accepted fix.

## Acceptance boundary

This GET gate cannot prove successful login, account creation, refresh, genuine message delivery, credential isolation, watch synchronization or device-to-server persistence. Those need separately authorized QA credentials/hardware and server-side readback. The parent task owns deployment and final integrated acceptance.

## Parent review and deployment access check

- Parent independently re-ran `node --test tool/global_auth_smoke.test.mjs`: **47/47 PASS**, plus both `node --check` commands and `git diff --check`. Added this offline test to the existing dual-timezone CI host-contract job; CI does not call the live service or submit accounts.
- Latest direct GET checks still returned 404: readiness requestId `c249e7aa-970d-45b8-94eb-69662600612b`, capabilities `ab6be09a-c79e-433e-a03e-c1d8f63f0c79`. Android ADB remained online. No App behavior changed; no rebuild/reinstall/restart was used as a substitute for working authentication.
- Confirmed the separate server workspace remains on `codex/global-api-foundation` at `4bf44bd9c9d5cc33a775d317cc7227740a249f45`. The existing domestic automatic deploy receiver is bound to the domestic root; it must not be used as an arbitrary remote shell or repurposed to bypass international deployment setup. International auto-deployment is still not installed/accepted.
- Existing local known_hosts contains the target server identity, but a bounded strict-host-key SSH check returned `Permission denied (publickey,password)`. The historical server-info file did not identify this host and was not used to attempt authentication. No password or key was displayed, transferred or reset.
- Two existing Tencent OrcaTerm tabs are owned by the server task; access was refused and their sessions were not taken over. A separate newly created inspection tab showed **0 connected sessions** and a Tencent Cloud sign-in dialog. Preserved that new tab for the user to authenticate; do not assert that GitHub credential authorization also logs into Tencent Cloud.
- The earlier explicit approvals for narrowly scoped recoverable build-cache cleanup and GitHub credential use remain valid. They were forwarded to the server task. No remote deletion, gateway edit, DB initialization/migration, credential transfer or server configuration write occurred in this App turn.
- Reused current authenticated-browser inventory only for the scoped server console; no unrelated page content was read. One guessed global README path did not exist; the actual `docs/global-deployment.md` was found using `rg --files`. No destructive command ran from a failed lookup.
- **Authentication repair remains blocked at server deployment/access.** Ask the user to complete Tencent Cloud sign-in in the preserved terminal, then verify the actual host and serial deployment state before using the approved cleanup/deployment workflow. Only after real global auth and dedicated QA account tests pass should normal Android physical debugging restart be marked complete.
