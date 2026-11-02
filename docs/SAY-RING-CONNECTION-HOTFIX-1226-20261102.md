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
