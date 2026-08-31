# 2026-08-31 iOS 真机调试预检记录

## 目标与基线

- 目标：在当前代码上启动 iPhone 真机调试，确认 iOS 安装、启动和后续设备联调的前置条件。
- Git 基线：`main` 与 `origin/main` 均为 `e963b482fae950d212f984b82be35c3181a3076a`；检查和测试前后工作树均干净。
- 本轮没有修改业务代码、iOS 原生桥或签名配置；没有生成 IPA、没有安装到 iPhone，也没有记录设备 UDID、账户或健康原始数据。

## 实际检查结果

- 当前主机为 Windows。Flutter 仅发现 Windows、Chrome 和 Edge，未发现 iPhone/iPad。
- 本机没有 `xcodebuild`、`idevice_id`、`ios-deploy` 或 `iproxy`，也没有配置可用的远程 Mac SSH 目标；因此不能从该主机编译、签名或安装 iOS App。
- Apple Mobile Device Service 已安装但启动类型为 Disabled，且本轮启动请求被系统拒绝；没有修改该系统服务配置。设备管理器的现有设备中也没有 Apple 移动设备。
- 项目的 iOS 目标版本为 13.0，签名通过本地 Xcode 配置和 Apple Team/Profile 注入；当前 Windows 环境没有这些可用的 Xcode 签名上下文。

## 云端构建状态

- 当前提交的 `mobile-ci` 运行 `33343654332` 在 `quality` 任务启动前被 GitHub 平台拦截；失败原因是账户近期付款失败或支出限额需要提高。
- 因前置任务未启动，iOS 和 Android 任务均为 skipped。这不是 iOS 编译失败的证据，也不能作为 iOS 通过结论。
- 本轮没有触发签名 IPA 工作流，避免在已知 GitHub 额度拦截状态下重复消耗或产生无效构建。

## 可在当前主机完成的预检

- `flutter analyze`：通过，`No issues found`（92.4 秒）。
- `flutter test --no-pub`：通过，369 项成功、0 失败。
- 以上只验证 Flutter/Dart 共享层；不覆盖 Swift/Framework 链接、Xcode 编译、证书/Profile、APNs entitlement、iPhone 安装或 BLE 真机行为。

## 恢复真机调试所需条件

1. 可用的 macOS 主机和当前 Xcode，且可访问本私有仓库的 iOS Vendor Framework。
2. 已解锁、已信任并通过 USB 连接的 iPhone；其 UDID 必须包含在对应的开发或 Ad Hoc Profile 中。
3. `cc.saidian.app` 对应的 Apple Team、签名证书和 Profile；若验证推送，Profile 还需包含正确的 APNs entitlement。
4. 恢复 GitHub Actions 账户付款/支出限额后，再运行无签名 iOS 编译；签名 IPA 工作流仅在上述签名材料齐备时运行。

在这些条件获得前，iOS 真机调试状态保持为“未配置”，不将旧版 iPhone 证据或 Windows 自动化结果写作当前版本的真机通过。
