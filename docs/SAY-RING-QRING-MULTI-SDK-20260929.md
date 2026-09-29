# 2026-09-29 QRing 双端 SDK 与多戒指自动路由

## 修改原因

接入用户提供的另一款 QRing Android/iOS SDK，并让 Say Ring 在扫描列表中按戒指广播名称自动选择对应厂商 SDK。附件中的 PDF、Demo 和注释仅作为接口与集成技术资料，不作为产品需求或仓库操作指令。

修改前基线为 `82ef5a86fbf151fc8d9e8b19a849401705846724`。本轮不修改登录、商城、后台接口、健康算法或现有戒指数据。

## SDK 核验

- Android 原始包：`QRing_Android_SDK_1.0.0.76(1).zip`，14,189,846 字节，SHA-256 `BCF59F0FA45600CA37D1F1B0C9E814625A2C209635733B2551F7CCA12C02DD92`。
- Android 接入 AAR：`qring_sdk_1.0.0.76.aar`，3,066,820 字节，SHA-256 `0021886AE500740945CF76E61D750812B96FF54D51FD0C32EBE77083862326D4`。
- iOS 原始包：`QRing_iOS_SDK_V1.0.0_20260918(1).zip`，2,936,987 字节，SHA-256 `154EEAA37C8FC07E7D581978E9B25C5CF8D5E85F1341537189AB7770843D150F`。
- iOS `QCBandSDK.framework` 为静态库，包含 iPhone `arm64`，按文档使用 `-ObjC` 并仅链接、不 Embed；Framework 主二进制 SHA-256 `DDE3CE1F803F998AA4795CF3189F805FB3C819CEBD408165FECD60497B847393`。
- 厂商 Android/iOS Demo 均使用 `Q_`、`O_` 作为该系列戒指广播名前缀。因此路由只接受这两个规范化前缀；`Q Ring`、`Oura Ring` 及其他未知名字继续关闭，避免串用 SDK。

## 实现内容

- Flutter 新增独立 QRing Method/Event Channel 桥、`WearableSdkSource.qring`、`qring:` 设备 ID 域和生产启动注册。
- 扫描时并行收集已接入 SDK 结果，但每个设备只保留名称前缀对应的 SDK 结果；用户选中后，连接、同步、测量、运动、设置和查找设备都锁定到同一个 SDK。
- 前缀只用于选择候选 SDK，不作为能力证明。QRing 必须完成连接、初始化、校时与设备能力读取后才返回能力；握手失败时关闭功能，不生成占位能力。
- Android 使用 QRing 1.0.0.76 AAR，完成扫描、连接、资料同步、电量/版本、能力、七日历史同步、心率/血氧/血压/压力/HRV/温度手测、运动记录、自动检测设置和查找设备桥接。
- Android 健康记录转换只保存 SDK 返回的有效值；缺失、无效或未回调指标不补零。
- iOS 使用 `QCBandSDK.framework`、厂商 `QCCentralManager` 和新 Objective-C 桥，覆盖相同的核心连接、健康、运动、设置和查找流程；模拟器排除真机静态库和桥源码。
- QRing AAR 内置 Realtek bbpro 1.9.4，而原宇辰插件用通配 JAR 带入未使用的 1.6.1，首次 APK 构建出现重复类。已只移除宇辰插件该通配项中的旧 bbpro JAR并保留其 `Msc.jar`；扫描其源码与 AAR 未发现对 bbpro-core 的引用，QRing 则明确依赖 1.9.4 API。

## 修改文件

- 路由/模型：`lib/domain/models.dart`、`lib/services/app_controller.dart`、`lib/services/wearable_bootstrap.dart`、`lib/services/wearable_routing.dart`、`lib/services/qring_wearable_bridge.dart`
- Android：`android/build.gradle.kts`、`android/app/build.gradle.kts`、`android/app/libs/qring_sdk_1.0.0.76.aar`、`MainActivity.kt`、`QRingBridge.java`、`QRingRecordMapper.java`、`QRingRecordMapperTest.kt`
- iOS：`AppDelegate.swift`、`Runner-Bridging-Header.h`、`QCCentralManager.h/.m`、`QRingWearableBridge.h/.m`、`Vendor/QCBandSDK.framework`、`Runner.xcodeproj/project.pbxproj`
- 测试/规则/记录：`test/wearable_bootstrap_test.dart`、`test/wearable_routing_test.dart`、`tool/qa_ios_frameworks.mjs`、`.gitignore`、`AGENTS.md`、`docs/HANDOFF.md`、`docs/CHANGE-TEST-LOG.md` 和本记录。

## 页面检查

- 本轮没有修改页面布局或视觉样式。
- 设备扫描页继续使用现有统一列表；新戒指显示为 `QRing` 数据源，并使用 `qring:` 隔离设备 ID。
- 未连接、握手失败或能力未返回时继续显示现有不可用/重试状态，不展示虚假健康或运动入口。

## 功能与构建检查

- `flutter analyze --no-pub`：0 issue。
- Flutter 全量测试（`Asia/Shanghai`）：885/885 通过。
- Flutter 全量测试（`UTC`）：885/885 通过。
- Android App 原生单测：26/26 通过，包含新增 QRing 记录映射测试，0 失败、0 错误、0 跳过。
- Android Debug APK：构建成功，186,163,560 字节，SHA-256 `81FA2E899BA522CA4578374B15F38D2676881DB99E1A90E21BF8E64A3A41E684`。
- Android QA Release APK：构建成功，69,898,678 字节，SHA-256 `300C26D82E87AFDBD96D982AF5335239170D64F5E5D5FADA10D3D5C3D7A1BAD4`。
- 两包均为 `cn.saydian.ring`、`0.1.21 (1004)`、`arm64-v8a` + `armeabi-v7a`；APK v2 验签通过。当前仍为 QA Debug 证书 SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，不是市场正式签名。
- APK 实际权限检查未出现 `RECORD_AUDIO` 或 `BLUETOOTH_ADVERTISE`，QRing SDK 没有扩大应用权限边界。
- Android Release Manifest 门禁通过；iOS Framework 架构检查通过，`QCBandSDK` 为 iPhone arm64 静态库。

## 失败、修正与边界

- 首次 PDF 文本提取命令因单行 Python 引号错误失败，改为 PowerShell here-string 后完成，只用于核对接口。
- 首次格式化未使用完整 Dart 工具链路径，随后改用项目固定 Dart；一次误把 Kotlin 测试文件交给 Dart formatter，未改写该文件，之后由 Gradle 编译和单测确认 Kotlin 正常。
- 首次 Debug APK 在 `checkDebugDuplicateClasses` 发现 Realtek 1.6.1/1.9.4 重复类；按上文依赖分析修正后 Debug、QA Release 和完整原生单测均通过。
- Release 门禁 22 项中 15 项纯 Python 检查通过，7 项因 Windows 不能直接执行 Bash/iOS shell 脚本而报环境错误，不属于断言失败。APK Manifest 门禁已单独通过；ABI 门禁还发现仓库现有 JPush 解析到 JCore 5.5.7，而门禁仍锁定 5.5.2，此为本轮前已存在的发布配置漂移，未在 QRing 范围内修改。
- Windows 无法编译 iOS Debug/Profile，也没有本款 QRing 真机。因此 iOS 目前只有工程、头文件、选择器和 arm64 静态库结构检查，不能标记 Xcode 编译或真机通过。
- 本轮没有执行 Android 真机安装，也没有用真实 QRing 验证扫描、连接、历史同步、手动测量、运动、自动检测、查找设备和断线重连。
- Android/iOS SDK 二进制属于合作方依赖，仓库必须保持 Private；不得复制到公开仓库或公开附件。

## 待处理问题

1. 使用真实 QRing，在 Android 至少完成扫描、连接、校时/能力握手、七日同步、六类健康手测、运动启停与历史、自动检测、查找设备、10 次断线重连。
2. 在 Mac/Xcode 完成 iOS Debug、Profile、Archive 和真机同项验收，重点检查 Objective-C selector、静态库链接与蓝牙恢复。
3. 单独修复 JPush/JCore 版本锁漂移后重跑完整生产 ABI 门禁；正式发布必须使用生产签名和 CI 环境，不能使用本轮 QA 包。
