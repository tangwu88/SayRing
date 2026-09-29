# 2026-09-29 R22 戒指扫描修复与 Android 真机验证

## 原因与范围

- Bug（P1）：QRing App 能发现 `R22_C493`，Say Ring 的“添加设备”列表却没有该戒指。预期是经 QRing SDK 扫描后列出该设备，并仅在真实握手和能力回报后开放功能。
- 修改前分支 `codex/home-health-device-update-download`，工作树干净，HEAD `a2bb04b12e8f8e8fc6591d170c4cbc517ca3ab70`；`git fetch origin --prune` 和 `git pull --ff-only origin codex/home-health-device-update-download` 成功，远端对应分支与 `main` 均为 `403051a22f594586964dfd6680034582396af153`。本地领先的一次提交是前轮安装记录，未覆盖他人改动。
- 根因：厂商 SDK Demo 的 `DeviceBindActivity.kt` 使用不带名称过滤的扫描，`Q_`/`O_` 限制仅在注释中；我们的 Android 原生桥、Flutter 路由与 iOS 桥都按这两个前缀拒绝 `R22_C493`。
- 只增加 `R22_[0-9A-F]{4}` 这一个严格名称形状；其他未知名称继续关闭。首次配对后 R22 停止广播，原有恢复流程必须重新扫描，因此又补充只按当前环境已保存的精确设备 ID 回查系统配对并重连。QRing 连接始终需 SDK 校时与能力读取。未修改健康算法、服务器接口、会员数据或其他厂商路由。

## 文件与预期

- `lib/services/wearable_routing.dart`、`lib/services/wearable_bridge.dart`、`lib/services/qring_wearable_bridge.dart`、`android/app/src/main/java/cc/saidian/saydian_app/QRingBridge.java`、`ios/Runner/QRingWearableBridge.m/.h`：三端统一允许 R22 名称，并保留扫码来源、当前扫描结果和连接能力门禁。Flutter 同时规范化首尾空格；仅 Android 对当前环境之前保存且系统确实配对的同一设备提供无广播恢复，iOS 该方法返回不可用。
- `test/wearable_routing_test.dart`、`android/app/src/test/kotlin/cc/saidian/saydian_app/QRingNamePolicyTest.kt`：覆盖 `R22_C493`、错误后缀/未知名称拒绝、精确已配对设备恢复和错误 ID 拒绝。
- `AGENTS.md`、`docs/HANDOFF.md`、`docs/CHANGE-TEST-LOG.md` 和本记录：更新已验证的路由边界及交接说明。

## 自动化与构建

- `dart format` 仅处理本轮 Dart 源码/测试文件；最初 `flutter test --no-pub test/wearable_routing_test.dart` 为 17/17，通过新增恢复用例后又与 `test/global_wearable_restore_test.dart` 合跑 32/32 通过。
- `flutter analyze --no-pub`：最终 0 issue；`TZ=Asia/Shanghai flutter test --no-pub -r expanded`、`TZ=UTC flutter test --no-pub -r expanded`：最终各 887/887 通过。首轮完整测试启动时工具曾输出两行 `File modified during build. Build must be rerun.`，但两轮最终均返回 0；最终重跑未再输出该提示。
- `gradlew :app:testDebugUnitTest --quiet`：最终 28/28，0 失败、0 错误、0 跳过。
- `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --target-platform=android-arm,android-arm64 --no-pub`：最终成功；APK 69,915,062 字节，SHA-256 `063A672790048DC7ACCBF23C5ACC02FE1C05E4E4126FDB08A424E36E8AA65B5D`。
- `flutter build apk --debug --target-platform=android-arm,android-arm64 --no-pub`：最终成功；APK 186,164,767 字节，SHA-256 `28467FDF4657D9715CEE96D7BEEBCBB58C66B7BD5BC11BF124A5094EA350B22D`。
- QA Release 实包经 `aapt` 核对为 `cn.saydian.ring`、`0.1.21 (1004)`、双 ARM ABI，经 `apksigner` 核对仍为 QA 证书 SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，不是正式市场签名。
- `node tool/qa_ios_frameworks.mjs`：通过，`QCBandSDK` 为 iPhone arm64 静态库；Windows 无法执行 Xcode 编译和 iPhone 真机扫描，故 iOS 本轮只完成源码与框架结构检查。

## 真机页面与功能

- 用户允许暂时关闭手机 QRing App（未解绑、未清除数据）；戒指保持在旁边。旧 Say Ring 确在“添加设备”页面；新 QA Release 经 `adb install -r` 覆盖安装，手机 `firstInstallTime` 仍为 2026-09-19，登录仍在。
- 新版“添加设备”列表实际显示 `R22_C493`，信号约 -74 dBm，且 HR01、TK 设备继续按原有来源显示，没有把未知名称泛化成 QRing。
- 点击 R22 后系统出现蓝牙配对确认；通讯录和通话记录访问选项保持未勾选。配对后设备页显示 `R22_C493` 已连接、戒指实报电量 74%、未充电，并出现由能力握手开放的健康监测与查找戒指入口。
- 15:01 的扫描规则测试包覆盖安装后，R22 连续两轮扫描未再广播；用户短暂用充电盒唤醒后仍未广播。手机蓝牙服务保留该设备的连接记录，但这本身不证明 QRing SDK 已连接。原有按广播重新扫描的恢复流程因此无法找回已绑定戒指。
- 增加精确系统配对回查后，最终 QA Release 于 2026-09-29 15:16:01 再次覆盖安装成功，`firstInstallTime` 仍为 2026-09-19，登录保留。冷启动约 35 秒后，设备页自动显示 `R22_C493` 已连接、74% 电量且未充电；无需重新广播或清除系统配对。同步进度曾显示 69%，随后恢复为“同步数据”按钮，未核对逐条健康记录，不能据此声称历史同步完整通过。
- 最近系统日志未发现本应用 `FATAL EXCEPTION`、ANR、QRing 扫描或连接超时。这里只验收发现、配对、重连握手、基础电量，不代表健康测量、历史同步、运动或多轮断线重连全链路通过。
- 本轮没有改变后台 API 契约；自动历史同步可能产生数据，但本轮未验收会员/健康数据的后台写入与跨端回读。接口检查仅限本机 QRing 原生 SDK 链路。

## 失败、修正与待验

- 第一次 Android 原生测试在 `mergeDebugAssets` 被 Gradle 9.1.0 单个 QRing transform 的 immutable workspace 损坏阻断，非测试断言失败。停止本轮 Gradle daemon 后，仅把该确切缓存目录移至 `E:/saydian/.toolchains/gradle-quarantine/` 保留，重新生成后定向与全量原生测试通过；未清理整个 Gradle 缓存或项目。
- 第一次真机覆盖安装因华为系统确认被误取消，`adb install -r` 返回 `INSTALL_FAILED_ABORTED: User rejected permissions`；重新安装并完成系统安全确认后返回 `Success`，安装时间 2026-09-29 14:48:04（Asia/Shanghai）。安装过程未卸载 App、未清数据。
- 增加已配对恢复后，第一次定向测试因 Dart 接口调用缺少显式类型转换而编译失败；补安全类型转换后又发现测试假桥缺少 `stopScan`，补齐后恢复相关 32 项通过。失败记录保留，不将其算成产品缺陷。
- R22 在 QRing App 中的旧绑定状态尚未恢复验证；QRing App 目前保持关闭，以免与 Say Ring 抢占蓝牙连接。用户若切回 QRing，需先在 Say Ring 断开连接。
- 配对后不再广播的精确原因仍未由厂商确认；本轮通过 Android 已保存设备 + 系统配对 + SDK 握手绕过了恢复对广播的依赖，没有删除蓝牙配对。iOS 仍必须有真实广播才能恢复，此处明确保持未验收。
- 待用 iPhone 验证 R22 扫描、连接与能力读取；待 Android/iOS 分别验证真实健康测量、七日历史、运动、自动检测、查找戒指和断线重连。不要把本轮扫描/握手结果写成全部 SDK 功能通过。
