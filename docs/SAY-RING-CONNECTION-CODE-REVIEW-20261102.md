# Connection and synchronization review

Reviewed the shared controller/routing and the QRing/CoolWear native connection paths on 2026-11-02, following the second-iPhone acceptance run. This round changes documentation only.

Three boundary cases were reproduced with isolated providers and production methods:

1. An empty iOS peripheral cache starts neither a connection nor a retry, while the shared exact-recovery route can still report the attempt as started. This can prevent fallback to discovery of the same saved target.
2. An unresolved first-binding decision is held on the initial connection but can be lost on reconnect once a remembered target exists. Pending initialization needs account/target continuity; uncertain results must never authorize another reset or an old-history import.
3. A new QRing connection can continue waiting behind an unfinished command from the retired session. Generation checks reject stale work, but do not immediately release the old queue tail. Any correction must retain native cancellation confirmation and single-channel safety.

Two additional latency opportunities were identified from source, rather than measured as new device regressions: optional iOS QRing battery/firmware reads precede connection-ready publication, and Android CoolWear automatic recovery normally waits for the full scan batch even when the exact target appears early.

The three supplemental probes exposed the current behavior. A native empty-cache fixture exercised the actual production recovery method, and the existing seven groups of connection/synchronization tests passed all 94 cases. The intentionally failing probes and detailed review remain in private local audit output; temporary probe files were removed from the default test suite.

Leaving device search already resumes recovery, and native disconnect handling already completes an in-flight QRing history request; these were not reported again as missing protections. Healthy-link device acceptance is separate from the exceptional conditions above. No runtime connection change, timeout reduction, device reset, server deployment or store submission was performed by this review.
