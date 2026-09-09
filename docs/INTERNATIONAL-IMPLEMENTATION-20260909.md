# International implementation — 2026-09-09

## Scope and baseline

- Approved plan: independent private `tangwu88/saydian-app-global`, Android/iOS/HarmonyOS, eight locales, isolated global accounts and first-party services.
- Workspace: `F:/xcodeplace/saydian-app-global`; domestic worktree is not edited.
- Upstream main: `fa79aa3610be25762fc4b5e7245de0f1f86245ef`.
- Upstream feature branch: `6d2595d59b17129d2548b2feb511935755cc45d5` (`codex/harmony-native-login-home`).
- Server changes use an independent `F:/xcodeplace/saydian-server-global` workspace, never the colleague's dirty worktree.

## Commands and outcomes (append-only)

1. Read repository instructions, change/test index, latest push/payment record, bug retrospective and regression checklist.
2. `git clone --no-hardlinks F:/xcodeplace/saidian-app-import-20260811 F:/xcodeplace/saydian-app-global`: passed; preserves source history without shared object hardlinks.
3. Initial `git fetch --prune upstream`: failed `Repository not found`; Git Credential Manager had two accounts and selected the wrong one. Retry with `-c credential.username=saydian88-cmyk -c credential.interactive=never`: passed. Never print credentials.
4. First merge attempt: failed before changes because clone did not inherit repository-local committer identity. Restored the existing project's local name/noreply email, not global Git settings.
5. `git merge --no-commit --no-ff upstream/codex/harmony-native-login-home`: five conflicted files. Retained both StoreKit/report and WeChat/native fixes in AppDelegate/controller/pages; chose concise current empty-state copy; retained ECG no-fake-waveform assertions. `git ls-files -u`: empty; conflict-file `git diff --cached --check`: passed.
6. Chrome confirmed owner `tangwu88`; created `saydian-app-global` with Private selected and no auto-generated README/license. Result page explicitly reports Private. Existing GCM `tangwu88` credential verified by `git ls-remote origin` (empty repository, success).

## Implementation groups

- Identity/configuration: independent package IDs, no domestic production automation or service credentials, isolated update URLs. Expected: side-by-side installation, no domestic traffic.
- Authentication: verified email or E.164 phone, server capability gates, shared V2 contract and stable string account IDs. Preserve refresh single-flight and account-generation protections.
- Localization: default English, eight explicit locales, persisted selection, native permission resources. No automatic watch-language writes.
- Business: preserve genuine records and capabilities; never turn unavailable providers or absent data into success.

## Acceptance state

Implementation in progress. No international APK/HAP, iOS compilation, real OTP delivery, payment, deployment, or real-device acceptance has passed yet. Historical domestic build evidence is not international acceptance.
