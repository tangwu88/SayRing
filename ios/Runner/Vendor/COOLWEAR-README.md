# CoolWear iOS SDK 20260910

- User-provided original archive: Android&amp;amp;iOS_SDK20260910.zip, received 2026-10-03 19:10 CST. Source archive stays read-only outside this repository.
- Archive SHA-256: e3a7b8ade9383fdd7a1cfb3981bfb4815fa6ccf33cad549b190d2cedc329a339.
- Copied only sdk/SDk/BluetoothLibrary.framework from inner IOS sdk_en.zip. No Demo, Pods, sample contacts, raw logs, or Word document is shipped.
- Original BluetoothLibrary binary SHA-256: f56c39605abded5f57b7ab28f245d67218b9df9e8edbb7fe037755b8cd3ca624.
- arm64 iPhoneOS dynamic framework, minimum iOS 13.0; no simulator slice. Embed and sign the copy at build time, never alter the retained original archive/framework.
- Interface source: supplied CoolWear iOS Bluetooth SDK Integration Guide 1.0.3 (2026-08-26), exported headers and Demo. Sample initializer signatures sometimes differ; exported headers control compilation.
- Vendor copyright notices remain intact. Use only as a dependency of Say Ring; integration does not grant redistribution rights for an independent SDK package.
- Do not import Demo auto-reconnect, user defaults, raw logging, HealthKit access, sample demographics or account IDs. Account-owned App recovery selects an exact scan UUID, never a name-only target.
- iOS type 9 contains mixed child data; it is not history completion. Unsupported history/sleep/workouts/HRV/controls return COOLWEAR_FEATURE_UNVERIFIED until separately validated.
