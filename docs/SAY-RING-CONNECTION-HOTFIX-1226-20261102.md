# Connection recovery hotfix 1.0.10 (1226)

On 2026-11-02 the user authorized repairing the connection/synchronization audit findings, uploading the corrected iOS binary and requesting expedited App Review. Source started from clean, fetched `b3d678b` on the Say Ring integration branch. This is a bug-fix release; no health algorithms, clinical scope, legal agreements, supply regions, account identity or existing health records are changed.

## Changes

- iOS retrieves the exact owner-bound peripheral first. If the OS cache has no object, bounded discovery searches for that same UUID, then performs a fresh vendor handshake. A valid already-pending radio request remains indefinite. Owner/target changes, cancellation and Bluetooth power loss retire discovery; same-name devices are not adopted.
- First-binding uncertainty is stored by environment, account and exact ring before requests or destructive commands. Reconnect/restart cannot silently remove it or repeat an ambiguous reset. Factory initialization requires its matching native completion; acknowledged history-only clearing requires a subsequent handshake. See [first-binding safeguards](SAY-RING-FIRST-BIND-PENDING-GUARD-20261102.md).
- Old QRing command waits retire only after confirmed native teardown or a completed new handshake. Old queued writes and late callbacks cannot affect the new session. Merely changing a recovery target or a failed teardown does not release the command barrier.
- Native readiness and the shared routing confirmation use a current-session snapshot without waiting for optional battery/firmware requests. Actual optional reads retain serialization; absent information remains unknown.
- Android CoolWear recovery can finish discovery when its exact saved target appears. Normal add-device scans retain their full result window. Identity and actual vendor capability checks still precede adoption.

## Verification

- Full static analysis: no issues.
- Complete Flutter suite in Asia/Shanghai and UTC: 1,790 passed in each run. A subsequently added routing snapshot contract was included in the 38-case routing suite, all passed; runtime inputs did not change.
- Production-method native regression: 59 passed, including exact-target cache fallback, cancellation, snapshot readiness, first initialization and Android early discovery. These are synthetic callback tests, not radio measurements.
- Signed normal iOS Debug/Profile, signed Profile QA and normal Release archive: successful. Android Debug and explicit QA Release builds: successful; no Android publication or physical acceptance is claimed here.
- iOS identity is Say Ring, `cn.saydian.ring`, 1.0.10 (1226), team W7SXQ4A226. Real Xcode 27.2/SDK 27.2 built the archive; iOS 15.0 matches current published compatibility. No build metadata was rewritten.

The first device run on iPhone 15 Pro Max and its existing R8 passed two software reconnections, a real battery response, enabled manual synchronization, SDK completion and preservation of the previously loaded record IDs. Optional camera/gesture entries remained available. The subsequent observation timed out after the app entered the background; that run is not reported as a complete pass. A second run and ordinary-main restoration are tracked below. Private device identifiers, account information, health readings, screenshots and full logs stay in ignored local output.

## Failures and boundaries

The first native test pass found an outdated capability fixture missing existing 1224 initialization members; the fixture was brought up to the real production contract. Initial controller tests exposed fixture/type errors, corrected without weakening data-isolation assertions. Full regression found an old expectation that a retired owner's read succeeded; the corrected test requires rejection and proves that no reset reaches native code. The first new QA analysis used the wrong reconnect method name; it was corrected before building. The first phone backup attempt failed after USB disconnected; the user reconnected and the new backup succeeded. All failure logs remain local.

A lost one-time server authorization cannot be safely replayed with the current server contract. This patch preserves the unknown state; it does not claim to automatically resolve every such account or reconstruct uncertainty already lost by older binaries. Unacknowledged Android history-clear requests remain unknown. Controlled reconnects do not establish long-range, force-quit or long-term locked-screen reliability. No sleep samples were fabricated or inferred.

The browser operation channel remained unavailable during preparation. Upload acceptance, TestFlight processing, App Review submission and expedited-review acceptance must each be recorded from their own evidence. An urgent request does not guarantee Apple's approval or timing.

## Follow-up: second 15 Pro Max run and upload

The repeated iPhone 15 Pro Max/R8 acceptance run completed successfully with `acceptanceCompleted=true` and a successful host test exit. Its two controlled software reconnections reached ready in 1,060 ms and 1,037 ms. The phone received a real battery response, manual history synchronization completed successfully, and all 13 previously loaded record IDs remained present. This synchronization reported zero newly received records; completion is not a claim that new activity or sleep samples were created. Camera and gesture-control entries remained offered; this run did not prove their physical effects.

The observation collected 90 sampling checkpoints, but the app was backgrounded and subsequently brought back. The recorded `foregroundStableSeconds` field must therefore not be interpreted as 90 continuous foreground seconds, nor as acceptance of sustained background, locked-screen or natural-disconnect recovery. The earlier timed-out run above remains a failed/incomplete run.

Normal production `lib/main.dart` version 1.0.10 (1226) was restored in place afterward. The private Documents comparison found all 10 original files with identical hashes and no removals; one test-proof file was added. The test retained the existing account and ring. This file comparison covers Documents, not an assertion that every byte of the app container or database was independently compared.

Xcode accepted the upload of Say Ring 1.0.10 (1226), bundle `cn.saydian.ring`, at **2026-11-02 17:26:18 Asia/Shanghai**, reporting that the uploaded package was processing and that upload succeeded. The release proof also confirms matching runtime inputs, normal-main restoration and completed device acceptance. This establishes upload acceptance only; TestFlight processing completion, group availability, App Review submission and expedited-review acceptance remain unverified.

An initial follow-up attempt on iPhone XR failed its target-device precondition because the target was null. It did not reach connection or synchronization acceptance and is under investigation as part of the user's additional XR test request. The browser's native operation pipe remained unavailable, so App Review and expedited-review submission have **not** been completed in this record. Supporting raw logs, device proofs and comparisons remain in ignored local build output.


## XR diagnostic follow-up

The XR test harness was corrected to record private boolean state and wait up to 20 seconds for the existing account-scoped target instead of force-unwrapping a null target. It never connects a raw saved object, adopts another owner, resets a ring or clears history. Targeted analysis and formatting passed; the signed Profile diagnostic build succeeded. The application runtime source and uploaded 1226 archive are unchanged by this test-only correction.

The repeat XR run confirmed successful account and privacy-consent reads, but no saved binding, remembered ring or connected ring at either initialization or the end of the wait. It failed the explicit target precondition before sending connection/history commands. This is not an XR Bluetooth/synchronization pass or evidence that a radio connection failed. Ordinary main 1.0.10 (1226) was restored and its installed version/build read back. The user was asked to connect R8 on XR and keep it foreground; no response had arrived when this record was written.

A preservation check found that the pre-install XR Documents backup contained 54 old QA screenshots/JSON files, while the subsequent export contained only the new QA proof. The backup's original command was verified to target this XR. No uninstall command, Documents deletion path or signing identity change was found in the inspected installation/runtime/test code. The 54 missing QA files were restored from that backup with removal disabled; a fresh export contained all 54 original hashes unchanged plus the new proof. This anomaly remains unexplained and must not be described as an uninterrupted whole-container preservation pass. The current encrypted health database exists in Application Support, but no pre-install database copy was taken in this round, so whole-database equivalence is unverified. No ring reset, account replacement, cloud deletion or health-data restoration was performed.

XR connection/activity/sleep acceptance remains pending a real selected ring. Submission and expedited review remain pending because the browser operation channel is unavailable.
