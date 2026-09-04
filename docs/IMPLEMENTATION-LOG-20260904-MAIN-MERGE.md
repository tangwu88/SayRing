# 2026-09-04 合入 main 并保留 iOS 支付修复

## 范围与基线

- 用户确认将 `origin/main` 合入当前 `codex/ios-full-migration`，保留已有 iOS 支付修复。
- 修改前工作区干净；已执行 `git fetch --prune origin` 和当前分支的 `git pull --ff-only`。
- 当前分支及其远端基线：`b1f024889d8b57191688286e5ead464a2728060c`。
- 本次合入目标：`0a6e4d6318703b486053a016907565a49d5af111`；共同祖先为 `e963b48`，双方分别有 1 和 7 个独立提交。
- 本轮只进行代码合并、自动化回归和本机构建，不安装 App、不连接手机或手表、不发起真实支付、不操作生产服务；不将本轮结果写成真机或上线验收通过。
- 仅推送当前开发分支，不改写历史，也不更新远端 `main`。

## 15:30 合并与冲突处理

- 原因：远端已增加服务端契约适配、通知、个人资料、W9 同步和 Android 图标更新；当前分支独立保有 iOS 支付桥接和支付参数兼容修复。
- `git merge --no-ff --no-commit origin/main` 首次自动合并遇到 1 处文本冲突，位于 `test/api_client_test.dart`，未自动创建提交。
- 根因：当前分支在同一位置新增“直接返回支付宝签名串”测试，`main` 则修改紧邻的多商品结算测试名称和实现。
- 处理：保留新增签名串测试，同时使用 `main` 的多商品购物车结算测试名称与断言；不删除任何一方的测试。
- 人工修改文件：`test/api_client_test.dart`、本记录及 `docs/CHANGE-TEST-LOG.md`。其余合入文件沿用 Git 自动三方合并结果，随后审查重叠代码。
- 支付请求采用 `main` 的已部署契约：multipart 表单、`pay_type=1/2`、`trade_type=app` 及字符串订单号/金额；服务端仍负责校验真实应付金额和生成签名。
- 支付响应保留当前分支的签名串直返兼容、嵌套字段解析及 iOS 微信/支付宝原生桥接，不自行生成或改写签名。
- 预期：合入的服务端契约、页面与 Android 修复可用，现有 iOS 支付功能和回归覆盖不丢失。

## 验证记录

### 15:30–15:32 合并审查与首批自动化

- `git diff --name-only --diff-filter=U`：冲突处理并暂存后无输出，无残留冲突。
- 对比合并前 `HEAD`：`ios/`、支付解析桥接、支付桥接单测、iOS IPA 工作流和 iOS 发布门禁脚本均保持原有内容。
- `dart format test/api_client_test.dart`：检查 1 个文件、0 改动。
- `dart format --output=none --set-exit-if-changed lib test`：73 个文件、0 改动，通过。
- `git diff --check` 和 `git diff --cached --check`：通过。
- `flutter analyze --no-pub`：通过，`No issues found`。
- `TZ=UTC flutter test --no-pub --reporter expanded test/api_client_test.dart test/app_payment_bridge_test.dart test/qa_user_flows_test.dart`：91/91 通过。
- `TZ=UTC flutter test --no-pub --reporter expanded`：382/382 通过。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded`：382/382 通过。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py' -v`：20/20 通过；其中发布/回滚测试使用隔离夹具，不操作真实发布服务。
- `bash -n scripts/release/*.sh`、`shellcheck scripts/release/*.sh`、`actionlint`：通过。
- 工具链沿用 Flutter 3.44.9 / Dart 3.12.2，不升级依赖或 SDK。
- 原始自动化日志保存在本机临时目录 `/tmp/saydian-main-merge-20260904.STaMUL`，未纳入 Git；本文件记录可交接的结果摘要。

### Android 构建

- `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64`：通过，产物 `build/app/outputs/flutter-apk/app-debug.apk`。
- Debug 构建提示 CameraX/JPush 仍使用旧式 Kotlin Gradle Plugin，以及 Android SDK XML 版本不一致；未导致本次构建失败，本轮不升级工具链或插件。
- `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub --target-platform=android-arm,android-arm64` 首次失败：`Gradle build daemon has been stopped: stop command received`，退出码 1。
- 该次未报源码编译错误；不能据此归因到合并代码，也没有证据确认停止请求来自哪个进程。后续使用 `GRADLE_OPTS=-Dorg.gradle.daemon=false` 隔离共享常驻构建进程后复验，不修改应用源码。
- 第二次 QA Release 失败：Flutter 插件加载器找不到本机 `camera_android_camerax-0.6.30/android` 缓存目录。此前同一工作区 Debug 构建已通过，现场确认该目录现已不存在。
- 后续按 `flutter pub get --enforce-lockfile` 恢复锁定依赖，不执行升级。恢复前 `pubspec.lock` 的 SHA-256 为 `ab7bd0f7caf84a54744acb851762901b2355cf434253637e2d6109f1e89521cd`，恢复后再次核对。
- 依赖恢复通过，CameraX 目录重新存在；`pubspec.lock` SHA-256 与恢复前完全一致，`pubspec.yaml`、`pubspec.lock` 无 Git 差异，未升级依赖。
- 第三次 QA Release：同一锁定依赖下使用 `GRADLE_OPTS=-Dorg.gradle.daemon=false SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub --target-platform=android-arm,android-arm64`，通过，耗时 254.3 秒。
- QA Release 产物：`build/app/outputs/flutter-apk/app-release.apk`；ZIP 内容确认包含 `arm64-v8a` 和 `armeabi-v7a`。仅用于内部 QA，不是生产发布或安装验收。
- Debug APK SHA-256：`db7ac278ecbcfd24567802873e10413d750e61ae5e736753f4ccae65ad5fb5c3`。
- QA Release APK SHA-256：`d81d46ed1b100b13aca43bf3e0323a5c0d2e1004840831a10c2f3cd385c1bf26`。
- `cd android && ./gradlew --no-daemon :app:testDebugUnitTest --console=plain`：通过，`BUILD SUCCESSFUL`，测试任务实际执行；电量门禁 7 项、表盘 profile 5 项，共 12/12 通过，0 失败、0 跳过。
- Android 原生编译仍有厂商回调参数名、已弃用 API 和 Gradle 后续版本兼容警告；未出现编译错误，本轮不扩展为 SDK/Gradle 升级任务。
- 失败记录保留并追加处理结论；未执行项目不得标记为通过。

### iOS 无签名构建

- 确认本仓库没有其他 iOS 构建进程后，使用 Xcode 26.6 串行执行 Debug 和 Profile 构建。
- `flutter build ios --debug --no-codesign --no-pub`：通过，Xcode 编译耗时 64.9 秒。
- `flutter build ios --profile --no-codesign --no-pub`：通过，Xcode 编译耗时 62.4 秒，产物 `build/ios/iphoneos/Runner.app`。
- 继续保留 `WechatOpenSDK-XCFramework 2.0.7` 和 `AlipaySDK-iOS 15.8.30`，未修改 iOS 原生代码、Pods 锁文件或本机签名配置。
- Flutter 提示部分插件未支持 Swift Package Manager、微信 SDK 缺少所需模拟器架构；本轮为 iPhone 目标无签名编译，没有据此宣称模拟器或真机运行通过，也未临时修改 SDK。
- 本轮未执行 iOS Release 构建、RunnerTests 运行或手机安装；以上构建结果不等同于签名、冷启动或真实支付验收。

### 15:45 提交前最终门禁

- 恢复依赖并完成双端构建后再次执行 `flutter analyze --no-pub`：通过，零问题。
- 再次执行 UTC 与 Asia/Shanghai 两套完整 Flutter 测试：各 382/382 通过，0 失败。
- 提交前再次 `git fetch --prune origin`，确认远端 `main` 仍为 `0a6e4d6`，当前开发分支远端仍为 `b1f0248`，没有新增并行提交需要追加合入。
- 冲突文件清单为空，工作区及暂存区差异检查通过；构建没有改动被跟踪的依赖锁文件、iOS 配置或其他非本轮文件。
- 合并记录与测试冲突处理随本次合并一起提交；只推送 `codex/ios-full-migration`，保留双亲历史，不强推、不更新远端 `main`。
- 本轮结论为“代码合并及以上本地验证完成”，不是“真机或正式上线通过”；远端 CI 以推送后的实际结果为准。

## 验收边界

- 真机、真实支付、服务端实时状态及生产签名/推送/更新资源均不在本次代码合并验证范围。
- 历史实施记录中的真机和服务端结果仅为当日记录，未在本轮重新验证。
- 后续如需真机复测，仍遵守用户“连接 W9S，不再连接 ET488”的限制。
