# Android native log privacy audit — 2026-09-09

## Baseline and cause

- Scope: Android SDK/native logging only, on App baseline `c9faadae517ca40bd8c35b2e37de09ce2e54c345`; preserve root-task Dart changes. No phone, installation, Bluetooth operation or running Flutter process was modified by this subtask.
- `git status --short --branch` and `git rev-parse HEAD` verified before this round. The same execution round already completed `git fetch --prune origin` and read the repository instructions, handoff and latest logs/checklists.
- P1: cached **vpbluetooth 1.20** bytecode inspected with JDK 17 `jar tf` and `javap -c -private`: `BluetoothLog` static initialization sets `isDebug=true`. `VPLogger.setDebug(false)` forwards to that transport flag, but App initialization did not call it. This explains a viable raw protocol-log path; only new-package live validation can confirm all observed DF output is eliminated.
- MainActivity also interpolated MAC addresses and actual HRV/BP/other measured values into its own Android logs. Yucheng's upstream wrapper directly logged whole health maps/scan identities despite the SDK `isLogEnable` argument. The checked-in JPush wrapper still accepted caller `debug` and logged notification objects/arguments independently.

## Changes and limits

- Before and after Veepoo initialization, and before adapter operations, disable VP/Bluetooth debug logs, local log writer, Bluetrum logger and bundled JieLi console/file loggers. No SDK binaries, BLE algorithms, callback data or device capability decisions are changed.
- Route MainActivity logging through a closed fixed-stage vocabulary. Debug-level messages are suppressed; info/warning/error expose neither original tags, exception text nor any payload substring. Existing callback objects still reach the App unchanged.
- Extend the existing build-local Yucheng source patch: force `initClient(..., false)`, set bundled JieLi logging off before and after init, route wrapper Android Log calls to an output-free module logger, and remove raw wrapper stack printing. Pub Cache remains unchanged.
- JPush's native setup always uses `setDebugMode(false)`; its wrapper logger produces no output, and raw exception printing is removed. App-layer request/callback diagnostics remain separately owned by the main task.
- Closed-source SDK internals, native libraries and externally initialized SDK services are **not** proven silent by source checks. Only APIs verified in the actual linked artifacts are used; no reflection, binary patching or global stderr interception. Final Debug/Release cold-start, connect and sync log capture remains a required main-task gate.
- **Confirmed closed-source residual:** `javap -c` of `ycbtsdk-release` shows `YCBTLog.saveFile(String,String)` and its boolean overload guard file writes with `YCBTClient.OpenLogSwitch`, but then call `android.util.Log.e("yc-ble", concatenated arguments)` outside the conditional branch. No public off switch was found for those calls. Standard `i/w/e/d/write` and `SdkHandler` do use the switch. This is a potential reachable native log leak, not evidence that the currently connected watch invoked the affected path; final W8 testing must inspect `yc-ble`. If invoked, request a vendor-fixed SDK rather than claiming all raw native logs are disabled.

## Native network entry inventory

- Reviewed App Kotlin: no direct `URL`, `HttpURLConnection`, OkHttp/Retrofit, `WebView.loadUrl`, or literal HTTP(S) first-party endpoint found. APK installation consumes a previously downloaded local file. Network watch-face installation receives a validated local file and hands it to the BLE SDK. This is a source inventory, not proof of zero native network requests.
- Yucheng wrapper source: scanning, history/control, local watch-face conversion and vendor SDK calls; exposed log-file helpers remain imported vendor capabilities, but App does not invoke them in this task. Maven repository URLs and JPush documentation links are build/docs-only, not runtime business requests.
- Read-only constant-string inventory of the currently resolved Veepoo protocol JAR found `www.vphband.com`, `120.79.208.77`, `starcourse.location.io` and `starcourse.rx-networks.cn`; vpbluetooth JAR contained no literal URL host in this scan. Yucheng's resolved `ycbtsdk-release` JAR contains `web-api.ycaviation.com`. All three scans found zero `saidian.cc`/`sd.cc` hosts. These are potential SDK-internal hosts, **not** an approved allowlist or proof of traffic; do not replace them with the first-party domain without official SDK support. Full APK/native egress still needs runtime inspection.

## Verification record

- `javac -d build/native-privacy-check <Yucheng Log.java> <JPush Log.java>`: passed; output is ignored build cache, not a package or runtime acceptance.
- `git diff --check`: passed (line-ending notices only).
- `node --test tool/test_native_log_privacy.mjs`: **8/8 passed**, 156 ms; these tests verify source guards, not live SDK behavior.
- Added `PrivateStageLogTest.kt` (eight synthetic sensitive strings projected to fixed stage names) for the root-run Android unit suite. No Gradle compilation or installation performed by this subtask.
- SDK inspection command families: `jar tf <resolved SDK classes.jar>` to identify public logger classes, `javap -private` for available APIs, `javap -c -private` for actual logging branches; read-only ZIP entry text scanning returned only unique URL hosts and old-domain counts, never credentials or runtime health records.
