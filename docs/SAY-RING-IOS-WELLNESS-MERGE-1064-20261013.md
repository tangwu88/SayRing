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
