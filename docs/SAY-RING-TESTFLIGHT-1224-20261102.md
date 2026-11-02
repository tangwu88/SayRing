# TestFlight upload: 1.0.10 (1224)

The first-binding synchronization fix from commit `7d061863` was archived from the normal application entry point and uploaded to App Store Connect on 2026-11-02. Apple returned `UPLOAD SUCCEEDED with no errors`; the export/upload command exited successfully.

The release uses version 1.0.10 with build number 1224 because version 1.0.9 is already published. The initial 1.0.9 archive was not uploaded. No application logic changed during this packaging step.

Archive identity and signature checks passed. Existing third-party framework debug-symbol warnings did not block upload. Detailed signing and distribution logs remain local.

Apple processing, encryption-compliance completion and availability to the existing TestFlight groups have not yet been verified because the browser connection is unavailable. Upload acceptance alone does not confirm that a tester can install the build. No App Store review submission was performed.

The earlier physical-device check verified initialization recovery, an enabled synchronization action and completion of a real synchronization request. The ring returned no historical records in that check. New-account onboarding on the other iPhone, newly generated activity records and actual sleep samples remain separate acceptance checks. Existing account and health data must be preserved during that validation.
