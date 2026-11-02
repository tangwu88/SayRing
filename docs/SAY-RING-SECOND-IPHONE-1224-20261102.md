# Second iPhone installation: 1.0.10 (1224)

The normal application entry point from the same synchronization-fix source used for the TestFlight upload was built and installed over USB on a connected iPhone 15 Pro Max on 2026-11-02. The installed application list confirmed version 1.0.10, build 1224 and the correct Say Ring application identity. Signature and target provisioning checks passed, and the application launched successfully.

The observed device page offered Add device. No R8 connection or history synchronization was verified during this installation check. The phone subsequently moved to another application while account and ring preparation remained pending. Installation and startup must not be recorded as new-account or nonempty activity/sleep acceptance.

The existing R8 initialization and synchronization integration target was separately built and signed for this phone. During the subsequent continuation it was installed and executed through the preserving-data driver. It stopped at the authenticated, non-local, non-preview account precondition before accessing a remembered ring or requesting history. The driver exited with a failed precondition; this is not a passed synchronization test or evidence of a ring-read failure.

The normal application was restored without uninstalling and its installed version was read back as 1.0.10 (1224). A private before/after comparison of the Documents directory found no original files missing or modified. This comparison covers Documents only, not the health database or whole container. The intended new-account login and R8 connection are still required before repeating history acceptance. Device logs and screenshots remain local.

No account replacement, application uninstall, ring reset or history deletion was performed by the agent. Continue with the intended account and R8, using the preserving-data driver and restoring the normal entry point after an integration run. This USB development installation does not establish TestFlight processing completion or installation through TestFlight.

## Follow-up after the intended account and R8 were prepared

The user completed login and connection. The existing synchronization target then passed on the second iPhone: the same account and ring were retained, initialization was complete, the synchronization action was enabled and a real SDK synchronization completed. Activity samples were present for the current target. The manual request returned no additional records; this must not be confused with an empty local activity store.

The optional activity/sleep acceptance path verifies nonzero current-day wearable activity after user-confirmed walking, activity day/week/month pages, sleep date navigation and the existing exclusion of unconfirmed calorie units from kcal statistics. It saves screenshots and completion evidence both on the phone and through the driver. No product behavior changes were made in this round.

The first extended run finished on the phone but its host VM-service discovery did not complete; its private device report was recovered and the waiting driver stopped. A subsequent verified run connected successfully, completed every assertion in about one minute and exited zero. Current activity was shown in the normal data views. The user confirmed no recent sleep wear; the sleep store and page were empty, so a nonempty sleep import remains unverified. The existing calorie-unit protection was visually checked and retained; no guessed conversion was introduced.

The normal main-entry 1224 application was restored, launched and read back on the phone after testing. The local default build configuration was restored too. The before/after Documents comparison found no missing original files; one test-report file changed and new test evidence was added. This does not establish whole-database integrity. Source analysis for the extended integration target passed. Private health values, identifiers, screenshots and verbose device logs are excluded from this public record.
