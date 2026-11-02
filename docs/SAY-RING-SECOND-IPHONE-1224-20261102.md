# Second iPhone installation: 1.0.10 (1224)

The normal application entry point from the same synchronization-fix source used for the TestFlight upload was built and installed over USB on a connected iPhone 15 Pro Max on 2026-11-02. The installed application list confirmed version 1.0.10, build 1224 and the correct Say Ring application identity. Signature and target provisioning checks passed, and the application launched successfully.

The observed device page offered Add device. No R8 connection or history synchronization was verified during this installation check. The phone subsequently moved to another application while account and ring preparation remained pending. Installation and startup must not be recorded as new-account or nonempty activity/sleep acceptance.

The existing R8 initialization and synchronization integration target was separately built and signed for this phone. It has not yet been installed or executed on this phone. The normal application remains installed. Device logs and screenshots stay in local private build output.

No account replacement, application uninstall, ring reset or history deletion was performed by the agent. Continue with the intended account and R8, using the preserving-data driver and restoring the normal entry point after an integration run. This USB development installation does not establish TestFlight processing completion or installation through TestFlight.
