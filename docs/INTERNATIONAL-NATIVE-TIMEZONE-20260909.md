# International native record timezone correction

## Before editing

- App HEAD `06bf2a632c43db5ba80fab3e0288670459d8b1fe`; international `origin` fetched successfully, concurrent team changes preserved. No pull/reset/cleanup performed.
- Read AGENTS, international handoff/current implementation log, change/test index and regression/retrospective notes.
- Problem: Android and iOS record builders stored today's timezone offset on historical records. In regions with daylight saving, a winter observation uploaded in summer could carry a summer offset. Current UTC observation timestamps and stored historical data must not be rewritten.

## Scoped correction

- Android `MainActivity.kt`: the record builder passes its existing `measuredAt` Date to the offset helper. A pure host-testable helper calls `TimeZone.getOffset(observedAt.time)`.
- iOS `AppDelegate.swift`: the record builder passes its existing `at` Date, and the helper uses `secondsFromGMT(for: observedAt)`.
- Both format a separate sign and absolute hours/minutes so fractional-hour offsets remain intact.
- Android adds three JUnit tests: America/New_York winter/summer, exact spring DST boundary, fractional offsets. iOS adds two tests to the already configured RunnerTests target (no new Xcode project entries).
- No watch command, health value, source field, device capability, existing encrypted record, clock or server deployment was changed.

## Verification

- Pending: parent task runs Android unit/build gates after this source group freezes. Windows cannot execute Xcode/iOS tests; these are not reported as passed.
- The pure tests do not establish real-device historical date interpretation or the user's timezone at original measurement while travelling. Without that historic location context no timezone is inferred or backfilled.
