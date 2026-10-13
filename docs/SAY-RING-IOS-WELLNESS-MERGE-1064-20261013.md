# 2026-10-13 保持已上架活动/睡眠范围并提交新审核版本

## 授权、基线与实施范围

- 用户确认新审核版本保持已上架 1062 的活动和睡眠范围；当前暂时无法连接 iPhone，不阻断可独立完成的源代码、构建、上传和审核提交。
- 修改前 main 干净，fetch / pull --ff-only 成功，基线 `552280d4802ca3b97daf38adc6aa0b201913373c`。
- 找到同一 origin 的已上架源码分支 `codex/macos-update-20260930`，提交 `cf510fd99e1e2047fcbb775f07abde67dec9df91`，含 `55fb3b5` 的活动/睡眠限制与已上架 1062 验证记录；此前 main 未合并这条分支。
- 合并已有发布分支，保留 main 的名称包含路由、首页卡片设置、AI 错误提示和其它主线提交。只解决实际冲突，不新编医疗算法，不清除历史健康数据。
- 复用已有 Flutter/原生/API/存储投影范围限制，iOS 只开放活动和睡眠、普通设备功能；Android 按原有功能支持，生理记录原数据保留但不得在此 iOS 版本展示或同步。
- 1063 已上传但不符合用户本次审核范围，不选择它提交审核。收敛后使用新的 `1.0.1 (1064)`，仍为固定 `cn.saydian.ring`，iOS 15+，已批准的无 JPush 发布配置。
- 真机当前不可连接，不把主机测试、签名或 Apple 校验称为新版本真机验收。

## 命令与结果

- 所有本轮日志保存在忽略目录 `build/ios-wellness-1064-20261013/`，结果按实际执行追加。
- 旧线程读取失败（旧 host 不可用）；转为读取当前仓库已有 Git 发布分支，已定位完整的原审核范围实现，不依赖旧线程登录或设备数据。

## Merge and validation details

- Merged the existing published macOS branch; 16 files had explicit conflicts. Preserved both histories, current substring routing, product-specific legal validation, home-card preferences and safe AI error messages. iOS now reuses the supplied CoolWear SDK from the published baseline, with the same approved name rules.
- Initial analyzer found duplicate age/product arguments from both branches; removed only duplicate entries, preserving explicit age consent and Say Ring document validation. Final preliminary analyzer passed; 154 targeted scope/routing/home/legal tests passed.
- First full UTC run reported 5 failures: reconnect cleanup on native disconnect failure, two enlarged-text headings, the moved safe AI failure bubble and a source-shape unbind assertion. Corrections preserve generic disconnect failure behavior, explicitly clear stale UI only during reconnect, keep the heading readable, restore the existing safe bubble and update the assertion to the merged callback barrier.
- Initial Android/iOS compile failed on duplicate pendingDisconnect fields introduced by automatic merge; deduplicated identical declarations. Retry logs are separate.
- iOS command/event/API/local-store projections remain independent of account and remote flags; physiological records are retained rather than erased. SDK name matches still require real capabilities.
- Locked offline pub get and pod install --deployment succeeded. Initial native release policy and tool tests passed; actual device verification is unavailable by the user's current constraint.

## Final regression results

- `TZ=UTC flutter test --no-pub --concurrency=2 --reporter expanded` and the Asia/Shanghai equivalent: 1244/1244 each. Both final logs retained; initial 5-failure run remains separate.
- `flutter analyze --no-pub`: no issues. Targeted scope/routing/legal/home tests 154 passed; merge-regression retry 145 passed.
- Android native unit tests: 11 suites, 51 tests, no failures; Debug and dual-ARM QA Release APK builds succeeded (7.7s / 50.4s). QA APK is not a production Android release.
- iOS Debug and Profile retries succeeded (10.9s / 53.3s); the old local xcconfig still stamped these QA artifacts as 1063, so the production archive uses a new min-OS-only xcconfig and explicit 1064 build arguments. No old QA binary is used for upload.
- Release Python checks: 34 passed; Node tool checks: 120 passed / 1 Windows ACL skipped; native activity/sleep Foundation policy and Swift typecheck passed. CoolWear Foundation history/battery/name/capability policy and QRing 28 name cases passed.
- Nine iOS frameworks passed arm64 architecture inspection. No SDK binary was rewritten, no clinical accuracy or new ring/phone acceptance was claimed.

## Production defaults, archive and signing authorization

- Final production review kept the iOS-only scope independent of runtime flags and preserved the main branch Android AI eligibility. The old factory test assumed the macOS review default on every platform; replaced it with actual iOS and Android factory checks. The failed intermediate run is retained.
- Final analyzer is clean and complete Flutter tests pass 1245/1245 in UTC and Asia/Shanghai. Final Android Debug/QA Release and iOS Debug/Profile rebuilt after this default correction. Final iOS QA versions read explicit 1064 with the min-OS-only override.
- Final production archive `.build/SayRing-1.0.1-1064-final.xcarchive` succeeded. Actual Info.plist: cn.saydian.ring, 1.0.1 (1064), iOS 15.0, UIDeviceFamily [1], arm64, production main target.
- Final export and direct upload both returned 70: No Accounts and no local iOS Distribution private key. Earlier 1063 export/upload had succeeded using Xcode cloud signing; current Xcode authorization is unavailable. Opened Xcode and requested native account refresh, without requesting a password in chat or creating any API key.
- 1064 is not yet exported or uploaded; the existing 1063 is not selected for review. The 1.0.1 draft keeps the accepted 1062 description/screenshots and has new accurate 1064 notes; submission remains authorized and pending Xcode authentication.

## Git delivery and deferred device debug

- Connected GitHub Git Data API used the exact locally verified tree `361967db894105a60226bff545ce6359e367f419`. The remote merge commit `79c5c620bf7e17ff0979dd1253a52a8f940b6937` keeps both the existing main and published macOS branch as parents; fetch verifies both task branch and main. Local original commits remain on a checkpoint branch.
- Signed Debug 1064 build succeeded in 18.7 seconds; strict deep verification passed with correct app/team and get-task-allow=true. `.build/SayRing-1.0.1-1064-debug.ipa` and the updated local `.build/run-sayring-ios-debug.command` are ready for a future USB connection. No installation or resumed attachment has occurred.
- Xcode native authentication refresh is still pending. Review notes are saved with the accepted activity/sleep scope; 1064 upload and App Store review submission remain unfinished.

## Native account refresh continuation

- User reported that the native Apple Developer account was refreshed, then confirmed the account and team W7SXQ4A226 were visible in Xcode Accounts. No password, verification code or signing private key was requested or read.
- Retried the unchanged final archive with `xcodebuild -exportArchive -archivePath .build/SayRing-1.0.1-1064-final.xcarchive -exportOptionsPlist .build/sayring-1064-export-options.plist -exportPath .build/SayRing-1.0.1-1064-export-auth-refreshed -allowProvisioningUpdates` at 21:20; exit 70, No Accounts and no local iOS Distribution private key. Separate log: `build/ios-wellness-1064-20261013/export-auth-refreshed.log`.
- After the user confirmed the team was displayed, retried using export path `.build/SayRing-1.0.1-1064-export-team-confirmed` at 21:26; exit 70 with the same errors. Separate log: `build/ios-wellness-1064-20261013/export-team-confirmed.log`. Neither attempt uploaded a binary.
- Native preference inspection and `defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists` showed an empty `IDE.Identifiers.Prod` list. Distribution logs reported that no App Store Connect account was found for the correct team. This is a native account availability problem, rather than a failed source build or test.
- System Events accessibility is unavailable. A normal AppleScript quit request returned user-cancelled (-128); did not force-quit Xcode, erase preferences, revoke certificates, create API keys or change app identity. Opened the final archive in Xcode and requested a normal user-managed quit/reopen to refresh persisted account state.
- Live App Store Connect check: TestFlight version 1.0.1 still contains only 1063 with missing export compliance; 1064 is absent. The 1.0.1 review draft remains preparing for submission with the accurate 1064 activity/sleep notes. No older build was selected or submitted.
- Existing tests and final archive are unchanged; no redundant rebuild or regression run was performed for this documentation-only continuation. Physical-device debug remains deferred because the user cannot connect the iPhone.

## Verified Xcode restart and Organizer fallback

- User reported that the account/team remained visible after reopening Xcode. At 21:45, the `export-xcode-reopened` attempt still returned exit 70 / No Accounts. The original Xcode process was still running from 14:33; no second Xcode installation was found.
- A screenshot of the native Apple Accounts detail window showed Xuewu Tang, Admin role, and Certificates/Identifiers/Profiles access. This visible team information does not prove that the command-line export has a usable App Store Connect session. No password or credential content was inspected.
- Activated Xcode and issued a normal AppleScript quit. Verified the original process exited, then opened `.build/SayRing-1.0.1-1064-final.xcarchive`; new Xcode process started at 21:49. No force-quit or account-preference deletion was used.
- Retried `xcodebuild -exportArchive` with the unchanged final archive, existing App Store Connect export options, `-allowProvisioningUpdates`, and separate output path `.build/SayRing-1.0.1-1064-export-clean-restart`; exit 70 / No Accounts. Logs `export-xcode-reopened.log` and `export-clean-restart.log` remain under the existing ignored build directory.
- The final archive CreationDate is 2026-10-13 19:21:04 Asia/Shanghai. Organizer opened with the top final 1.0.1 (1064) selected, correct cn.saydian.ring / W7SXQ4A226 / arm64 verified from the visible window. The other 1064 archive is superseded and must not be uploaded.
- No callable native window-control capability was available; plugin discovery found no Xcode integration. Requested the user complete Organizer's Distribute App → App Store Connect → Upload for the already selected final archive, including native authentication if needed. Subsequent compliance, build selection and final App Store submission remain authorized for the agent.
- At this checkpoint no 1064 upload success or review submission has been verified. Source, tests, signed Debug and final Release archive remain unchanged; this is an authentication/distribution continuation only.
