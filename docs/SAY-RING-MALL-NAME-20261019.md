# 2026-10-19 商城名称统一为赛电商城

## 范围与基线

用户要求将 SayRing 商城改为“赛电商城”。仅修改 Say Ring 中文商城显示文案及相应测试，不改变 App 名称、包名、API、订单数据、购买权限或后台显示开关，不操作手机数据或现有商店审核。

修改前工作区干净，当前分支为 `codex/macos-update-20260930`，基线 `3e1907de5c70ec52a288399cd7d6886605b099d6`。核对 origin 后执行 `git fetch origin` 和 `git merge --ff-only origin/codex/macos-update-20260930`，结果 Already up to date。

已阅读 AGENTS、国际交接说明、最新修改索引及真机续验记录、问题复盘和回归清单。本轮不覆盖前轮开关正向真机验收尚待完成的结论。

## 修改

- `app_zh.arb` / `app_zh_Hans.arb`：商城名称与查找设备时的商城提示统一使用“赛电商城”。
- `app_zh_Hant.arb`：对应繁体“賽電商城”。其他语言和 App 自身的 Say Ring 品牌不变。
- 使用 `flutter gen-l10n` 生成中文本地化代码；商城页标题及首页入口沿用既有 `l10n.shop`，不新增独立名称来源。
- 完成订单的感谢提示复用 `l10n.shop`，避免残留旧商城名称。
- 更新原有首页、模块开关与购物流程断言，新增中文各变体的实际生成结果及 App 名称不变回归；首页另断言旧名称不存在。

## 验证记录

- `flutter gen-l10n` 成功；仅本轮 Dart 文件执行 `dart format`，格式检查通过。首次格式化调整一个测试断言排版，第二次新增测试格式化零变更。
- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub test/global_l10n_test.dart test/module_visibility_test.dart test/qa_user_flows_test.dart test/ui_shell_test.dart --reporter expanded`：199 项全部通过。
- `git diff --check` 通过。运行源码与生成资源中的旧中文商城名称已清除，测试仅保留一处旧名称的“不存在”断言。
- `TZ=UTC flutter test --no-pub --reporter expanded`：1336 项全部通过（1 分 12 秒）。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded`：1336 项全部通过（2 分 19 秒，期间双端编译）。协议拒绝/网络错误日志为既有反例测试，未出现测试失败。
- `node --test tool/test_coolwear_ios_integration.mjs tool/test_qring_reconnect_integration.mjs tool/client_package_contract.test.mjs tool/measure_ios_bundle.test.mjs`：27 项全部通过，含实际 Objective-C 取消方法的宿主合成回归；不是戒指真机结果。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py'`：35 项通过。
- 修改文件的 `dart format --output=none --set-exit-if-changed`：5 文件、零变更；`git diff --check` 通过。

## 本轮构建

开始前确认没有其它 `flutter build/run`、`xcodebuild` 或 Gradle 构建，APFS 可用 8.6GiB；未清除任何缓存、归档或手机容器。iOS 两种模式严格串行，使用生产 API 根、`cn.saydian.ring` 和验证用版本 `1.0.2 (1119)`，`--no-pub` 保持依赖不变。

- `flutter build ios --debug --no-codesign --no-pub --build-name=1.0.2 --build-number=1119 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`：成功，Xcode 编译 38.8 秒。
- 同参数 iOS `--profile --no-codesign`：成功，Xcode 编译 186.1 秒，App 66.8MB。产物 Info.plist 实读 `cn.saydian.ring` / `1.0.2` / `1119` / UIDeviceFamily=[1]；Runner SHA-256 `0725caa3abb1f549f3311bd97c21417431540d80845cdf257b73b188925c91c6`。
- `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.2 --build-number=1119 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`：成功，Gradle 183.3 秒。
- 同参数 Android `--release` 加项目既有 `SAIDIAN_ALLOW_QA_RELEASE=true`：成功，Gradle 197.3 秒，APK 70.4MB。此 QA Release 不是正式签名发行授权。
- 两个 APK 均通过 `aapt dump badging` 实读 `cn.saydian.ring` / `1.0.2` / `1119`；Debug SHA-256 `fa3b7f6b9ef9f006ee60ffc71bedef5eda91d2aa0045f7a0fa11a5b08ff5a2f7`，QA Release SHA-256 `0c9bc60345d6160b393b900e782fa48af51f23d8e04a914177eb18c1509d5845`。
- Android `./gradlew :app:testDebugUnitTest`：BUILD SUCCESSFUL，44 秒；`:app:testDebugUnitTest` 实际执行，12 个 XML 测试套件共 53 项，零失败/错误/跳过，不是沿用 UP-TO-DATE 的测试结论。

已知工具链警告保留：SQLCipher/宇程插件未支持 Swift Package Manager，微信 SDK 缺 Apple Silicon iOS 26+ 模拟器 arm64；本轮编译目标为 iphoneos 真机 SDK，不将编译成功说成模拟器或手机验收通过。

Android 既有 CameraX/JPush 插件 KGP 未来兼容性和 Android SDK XML 版本警告亦保留；本轮没有为改名升级插件或工具链。

四种构建均未失败；构建后可用空间约 3.5GiB，后续大型构建应重新核查磁盘与占用，不删除保留的签名包、SDK 或健康数据来腾挪。

## 交付边界

本轮不修改生产模块开关、不发起购买、支付、真实验证码或健康数据请求。自动化中的网络与设备数据为既有测试夹具，不是真实业务验收。

手机现有 1118 与前轮数据保持不动；本轮文字变更需安装包含本次源码的新包后才会在手机上出现。新包真机、生产商城显隐正向联调及现有硬件待验项不能用本轮单元/页面测试代替。

本轮 iOS 仅编译无签名 Debug/Profile，不安装、不启动新包，不运行真机 XCTest，也未重复编译 RunnerTests。原已签名 1118 冻结包及私有健康数据备份保持不动；无签名 1119 不能直接部署手机，不作为正式 IPA 或上架包。

提交前重新 fetch origin，当前分支与远端仍无分叉（0/0）。仅提交本轮 11 个文件到既有开发分支；不推进仍有整体验收待办的 main（当前 `8e7541d`），不做服务端部署、TestFlight 或 App Store 操作。推送会触发独立 CI，本轮本机结果不冒认远端 CI 已通过。
