# 2026-10-13 蓝牙名称包含字符路由

## 原因、范围和预期

- 用户确认：蓝牙名称包含 `R8`、`R21`、`R22` 时走 QRing；包含 `R7`、`K80`、`HR01`、`HR05` 时走 LuckRing（现有 CoolWear 通道）。忽略大小写和首尾空白，标记可位于名称任意位置。
- 修改 Flutter 分类、Android 两个原生扫描/连接名称策略、iOS QRing 名称策略，以及对应测试和当前说明。鸿蒙缺少这两个 SDK，只拒绝将这些名字错投到已有厂商。
- 保留其它已支持的厂商规则；用户确认的型号标记优先于旧厂商前缀。同一名称同时包含两个通道的型号标记时拒绝自动选择。
- 名称只决定候选 SDK；真实握手、能力响应、健康算法、同步和绑定恢复条件不变。LuckRing 当前仅接入 Android；iOS/鸿蒙缺少对应 SDK，不宣称可连接。

## 基线和检查

- `git status --short --branch`、`git remote -v`、`git fetch --prune origin`、`git pull --ff-only origin main` 成功；原始 main 干净，基线 `5463cf1e33ca0e0082e0dc025ddbf3cb3d44467e`。
- 在 `codex/ring-name-routing-20261013` 实施；已阅读交接、最近 R7Ultra 记录、跨端复盘和回归清单。
- 已检查 Flutter/Xcode/Gradle 进程：此项目无正在执行的 iOS 构建；后续 iOS 编译串行。

## 本轮命令和结果

- `dart format lib/services/wearable_routing.dart test/wearable_routing_test.dart` 成功；`git diff --check` 通过。
- Flutter 定向路由/绑定选择测试 `flutter test --no-pub --reporter expanded test/wearable_routing_test.dart test/qring_bonded_device_selection_test.dart`：30/30 通过，包含七种名称从错误 SDK 的扫描结果被丢弃、正确通道连接和后续测量锁定。
- `xcrun clang -fobjc-arc -framework Foundation -Iios/Runner test/native/qring_name_policy_test.m -o build/name-routing-qa-20261013/qring-name-policy` 编译并执行：28 个真实 iOS 名称策略用例通过；这是主机逻辑检查，不代表真实设备握手。
- 初次 `node --test harmony-native/tests/wearable.test.mjs` 未执行，shell 中没有 Node。改用捆绑 Node 24.19.0 的完整路径后，定向测试通过；UTC 和 Asia/Shanghai 全量鸿蒙宿主测试均 503/503 通过，不等于 ArkTS/HAP 编译或硬件验收。
- `flutter analyze --no-pub` 零问题。
- 首次 UTC 全量 Flutter：962 通过、1 失败。失败的是旧 `product_identity_test.dart` 对原生桥内部源码字符串位置的断言；真实原生策略已移入共用 helper，旧 R2 行为仍通过 Android/iOS 运行时测试覆盖。用已有/新增的 JUnit、Foundation 实际函数行为测试替代该源码字符串断言；失败日志保留，修正后全量结果待追加。
- `pod install --deployment` 成功，锁定安装 24 个 Pods，Podfile/锁文件未改动。
- 所有本轮完整输出保存在仓库忽略目录 `build/name-routing-qa-20261013/`；失败输出保留，不覆盖。
- Android 原生单测首轮 `./gradlew :app:testDebugUnitTest --no-daemon --offline --max-workers=2` 未进入测试，因本机缺少 Flutter arm/arm64/x86_64 Debug Maven JAR 缓存，离线模式拒绝下载。保留 `android-unit.log`，取消离线模式后以双 ARM 目标重跑单测和 Debug APK，结果待追加；未改动依赖版本或清缓存。
- 修正源码位置断言后 `flutter analyze --no-pub` 零问题；`TZ=UTC` 和 `TZ=Asia/Shanghai` 全量 Flutter 均 962/962 通过，修正前失败日志单独保留。
- 初次 `flutter build ios --debug --no-codesign --no-pub` 被本机 Xcode 27 Target Integrity 拒绝：原工程/Pods 的 iOS 13.0 低于此 SDK 支持的 15.0。参照同日已成功的本机开发环境记录，通过 `XCODE_XCCONFIG_FILE` 注入忽略目录中的单项 `IPHONEOS_DEPLOYMENT_TARGET=15.0` 再串行构建 Debug/Profile；不修改 Podfile、锁文件、正式最低版本或产品身份。
- 使用上述本机覆盖后，iOS 无签名 Debug（79.0 秒）和 Profile（43.8 秒）均构建成功。既有 QRing Foundation 健康映射 48 个断言和 8 个 iOS framework 架构检查通过；没有安装或启动手机，也没有将主机编译写成实际戒指验收。
- Android 联网重跑等待缺失引擎 JAR 下载较慢；已核实当前 Flutter Gradle 插件支持 `FLUTTER_STORAGE_BASE_URL`。同版本依赖的镜像 1 MiB Range 探测返回 206、约 2.9 MB/s，因此停止本次专用 Gradle 客户端，保留日志，使用单条命令的 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` 重跑，不改全局设置、版本或源码构建脚本。

## 最终构建和产物

- Android 单测和 Debug：`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn JAVA_HOME=/Users/saydian/develop/java/jdk-17.0.20.1+1/Contents/Home ./gradlew :app:testDebugUnitTest :app:assembleDebug -Ptarget-platform=android-arm,android-arm64 --no-daemon --max-workers=2`，58 秒成功；XML 汇总 34/34，无失败、错误或跳过。
- 直接执行 Gradle 的首个 Debug APK 使用工具缺省 `1.0 (1)`，因此未作为最终产物交付；随后通过 Flutter CLI 读取 pubspec 后重构建，修正为 `0.1.21 (1006)`。没有修改源码版本。
- Android QA Release：同一本机环境附加 `SAIDIAN_ALLOW_QA_RELEASE=true`，执行 `flutter build apk --release --no-pub --target-platform=android-arm,android-arm64`，143.4 秒成功。仅为 QA 签名，不是生产发布包。
- 最终 Android Debug：`flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64`，17.6 秒成功。
- `aapt dump badging` 确认两个最终 APK 均为 `cn.saydian.ring` / `0.1.21 (1006)`，均含 `armeabi-v7a` 与 `arm64-v8a` 的真实 `libflutter.so`。
- Debug APK：`build/app/outputs/flutter-apk/app-debug.apk`，158,728,268 字节，SHA-256 `f0cd0e4f711800b39328a842b99a733bf263cf71e1b6d8d8214c321a6b3745c2`。
- QA Release APK：`build/app/outputs/flutter-apk/app-release.apk`，69,323,182 字节，SHA-256 `8fafe7cc0b3d66c5a394edbee8e0a27c788dffa60c2ce10cce49733e5829aa7f`。
- iOS Profile Info.plist 回读 `cn.saydian.ring` / `0.1.21 (1006)`，arm64，无签名；此 Mac 的 QA 最低版本覆盖为 15.0，正式工程最低版本未修改。Debug/Profile 编译成功的日志分别保留。
- 结构化本机验证记录为 `build/name-routing-qa-20261013/validation.json`；产物和原始日志不提交 Git。
- 交付前再次 `git fetch --prune origin` 成功；实现分支基线与 origin/main 的 ahead/behind 为 0/0，`git diff --check` 通过。

## 实际设备和同步边界

- ADB 没有在线 Android 设备；iPhone 15 Pro Max USB 已连接，但本轮未安装或启动 App，未扫描、配对或选择实际戒指。七种名称的真实广播发现、SDK 握手、能力读取、同步和重连仍需现场验收。
- LuckRing SDK 只有 Android 已接入；iOS 和鸿蒙不伪装支持，也不将上述名称投到其它厂商。
- 授权前，GitHub 仓库元数据重复回读为 Public，README 原要求 `must be private before any source is pushed`；因此实现先提交本地 `6091fb2`，未推送，等待用户决定。该阶段未更改仓库可见性或触发远端发布。

## 用户授权与 Git 同步

- 2026-10-13 用户明确回复“保持公开并允许推送”，替代旧的 Private-before-push 条件。README 和 AGENTS 已同步该决定；仓库继续保持 Public。
- 授权后的检查：`git status --short --branch` 干净；`git fetch --prune origin` 成功，`origin/main` 仍为实现基线 `5463cf1`，是本地实现提交 `6091fb2` 的祖先。
- 本次额外改动仅为上述授权说明和本实施记录，`git diff --check` 校验；路由源码及已通过的测试/产物未改动，不重复编译。
- 同步目标为 `origin/codex/ring-name-routing-20261013` 和可快进的 `origin/main`；使用普通 Git push，并以 fetch 后两个远端提交均与本地一致作为同步验收。未修改工作流、发布包或仓库可见性。
- 原生 `GIT_TERMINAL_PROMPT=0 git push -u origin codex/ring-name-routing-20261013` 退出 128：本机没有 GitHub HTTPS 写入凭据，读取 Public 仓库仍正常。转用已连接 GitHub 账户的 Git Data API，基于原 main 创建相同文件树并进行非强制分支更新；要求返回的 tree SHA 与本地验证树完全相等，再 fetch 同步本地分支。API 生成新的提交元数据，本地原始提交保留在备份分支，源码和原有远端历史保持完整。
