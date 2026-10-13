# 2026-10-13 iPhone 真机调试与 TestFlight 新构建

## 授权、基线与范围

- 用户要求启动苹果真机调试，并提交新构建到 TestFlight；Public 仓库推送授权继续有效。
- 修改前 main 干净，fetch / pull --ff-only 成功，基线 `499c9c2940a40d2cad4131b8b50e6c055dee732e`。
- 当前设备 iPhone 15 Pro Max，已安装 Say Ring `cn.saydian.ring / 1.0.0 (1062)`；App Store Connect 同产品最新构建 1062，商店版本 1.0 已可分发。新 TestFlight 使用下一补丁版本 `1.0.1 (1063)`。
- 不更改跨平台 pubspec 版本或业务代码；通过 iOS 构建参数指定版本。继续使用已批准的无 JPush iOS 发布模式、固定产品 ID 和国际 API。
- 本机 Xcode 27 要求至少 iOS 15，构建通过忽略目录的 `XCODE_XCCONFIG_FILE` 单项覆盖；此次实际 IPA 的最低版本将是 15.0。
- 真机 Debug 与 Release 归档串行；完成上传后恢复 Flutter 附加调试。签名、本机配置和构建产物不入 Git。

## 验证与执行记录

- `xcrun devicectl list devices`：目标 USB 已连接；`security find-identity -v -p codesigning`：Apple Development 有效，当前没有 Apple Distribution 私钥。
- 公开国际能力接口回读 Say Ring 微信公开 AppID；专属 Universal Link 返回 200，AASA 包含本产品团队/ID，仅写入忽略的本机配置。没有请求验证码或读取用户健康记录。
- 设备进程筛选初次使用 `executable contains`，CoreDevice 因 executable 为 URL 类型拒绝；改用结构化 JSON 回读，不把筛选命令失败判为 App 崩溃。
- 初次本机配置生成在 stdin 中文行遇到 Python 编码错误，未写入配置、未启动 Flutter；改用文件补丁和 ASCII 配置脚本。
- 后续 Debug、发行归档、最终签名及苹果上传/处理结果待按实际输出追加。

## Execution details

- `flutter run --build-name` was rejected because run does not support that option; config-only build followed by run installed the pubspec Debug version 0.1.21 (1006). No user data was removed. Final Debug will use an explicitly built IPA with 1.0.1 (1063).
- Debug native build completed in 19.2 seconds; machine events confirmed app.debugPort (52663) and app.started. A direct HTTP VM query timed out; this is not a crash diagnosis.
- Native Xcode UI inspection was denied Accessibility access for osascript. No permission or security setting was changed. Continue using the supported Xcode command line.
- Debug stopped before the Release archive. Archive uses automatic development signing, then automatic App Store Connect export must re-sign for distribution; final production signature remains a required verification.
- `python3 scripts/release/test_release_gate.py`: 32 tests passed. Business source is unchanged from the full routing validation baseline.

## Archive, export and upload

- `flutter analyze --no-pub`: no issues. Release business code is unchanged from 499c9c2; full Flutter, Android and iOS Debug/Profile validation is recorded in the name-routing report.
- `flutter build ios --config-only --release --no-codesign --no-pub --build-name=1.0.1 --build-number=1063 --dart-define-from-file=config/ios-app-store-no-push.json` succeeded.
- `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS -derivedDataPath build/ios-testflight-20261013/DerivedData -archivePath .build/SayRing-1.0.1-1063.xcarchive -jobs 2 -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" PROVISIONING_PROFILE_SPECIFIER= FLUTTER_BUILD_NAME=1.0.1 FLUTTER_BUILD_NUMBER=1063 archive`: ARCHIVE SUCCEEDED; production gate passed with explicit no-JPush mode. Archive is development-signed, followed by App Store Connect re-signing.
- `xcodebuild -exportArchive -archivePath .build/SayRing-1.0.1-1063.xcarchive -exportOptionsPlist .build/sayring-1063-export-options.plist -exportPath .build/SayRing-1.0.1-1063-export -allowProvisioningUpdates`: EXPORT SUCCEEDED. Xcode automatic cloud signing produced a valid Apple Distribution signature without importing/exporting a private key.
- Exported IPA: `.build/SayRing-1.0.1-1063-export/Say Ring.ipa`, 37,804,444 bytes, SHA-256 `38db836d7535bd6415ca2fd2ba5a7f4c49029ccfa4cae96fb63b79aeecbc48b2`. ZIP integrity and strict deep codesign verification passed; cn.saydian.ring, 1.0.1 (1063), iPhone-only arm64, iOS 15.0; get-task-allow=false, production APNs, correct team/application and associated domain.
- Export with the same archive and destination=upload succeeded. ContentDelivery: UPLOAD SUCCEEDED with no errors; Delivery UUID `c8973f4a-67fb-440c-a84e-b7333f8a4c1c`. Fourteen pre-existing vendor frameworks lack dSYM; warnings did not block upload. Do not substitute the local export SHA for Apple transport bytes.
- Final signed Debug build using explicit 1.0.1 (1063) succeeded in 21.6 seconds; IPA prepared for Flutter run --use-application-binary. Terminal startup then found the phone unavailable, verified independently by devicectl/xctrace. Reconnection requested; final attachment remains pending.
- User additionally authorized App Store review submission. Created 1.0.1 draft and prepared QRing name-matching release notes. Existing store 1062 describes activity/sleep only, but this Git baseline still exposes physiological measurement. Asked which scope the new review version should use; no inaccurate submission has been made.

## Verified current state

- App Store Connect TestFlight upload table contains 1.0.1 (1063), currently Processing; version 1.0.1 is present. Upload transport success is confirmed separately.
- App Store Connect 1.0.1 draft is Preparing for Submission, inherited automatic release after approval; QRing release notes saved. No review submission has been sent while scope clarification is pending.
- Distribution profile is iOS Team Store Provisioning Profile: cn.saydian.ring, UUID e3952987-a785-4e72-ab17-50213d653737, no device restriction, correct team W7SXQ4A226.
- iPhone remains unavailable; no attempt to install on another device or erase data. The ready-to-run local Terminal command is `.build/run-sayring-ios-debug.command`.

## 当前待完成项

- 17:39 左右，苹果上传详情仍为 Processing，只有已有的 90683 后台定位用途警告，没有上传错误；本版仍只声明前台定位和蓝牙后台模式，未据警告扩张权限。
- 审核草稿保存成功，但当前 Git 的生理指标功能与已上架 1062 的活动/睡眠描述不一致；功能范围问题尚未收到回复，未提交不实审核资料。
- iPhone 仍为 unavailable；初次 Debug 曾成功附加，最终 1063 的调试恢复需重新 USB 连接并解锁。
- Git Data API 创建与本地完全相同的文件树并快进 main/任务分支；原始本地提交保留在 checkpoint 分支。首次普通分支删除因 API 提交元数据不同而拒绝，改为保留并重命名 checkpoint，再创建远端跟踪分支，没有丢弃提交或强推。
