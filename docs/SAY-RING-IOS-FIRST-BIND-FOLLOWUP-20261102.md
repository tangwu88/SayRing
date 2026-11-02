# iOS first-binding initialization recovery

Some previously bound rings could remain connected without an available sync action when an optional activity-goal command did not reply.

- Complete required initialization only after a confirmed reset, a fresh time/capability handshake, and a successful profile write for the same account and ring.
- Keep optional activity-goal support unconfirmed instead of using it as a prerequisite for history synchronization.
- A server decision to preserve existing data no longer overwrites a pending native initialization.
- Preserve account isolation, stale-callback rejection, existing records, and the prohibition on repeating an uncertain reset.

Validation: automated regression and platform compilation checks passed. Initialization recovery and the sync action were verified on a physical device. Availability of newly generated activity and sleep samples requires separate verification. This source change does not imply a store release.

Detailed device diagnostics and local configuration records are intentionally excluded from this public summary.
