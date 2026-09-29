# 2026-09-29 双戒指 SDK 前端运动与睡眠补全

## 原因、基线与参考

- 用户要求按 HR01/CoolWear 与 R22/QRing 两套戒指 SDK，并参考手机上的 LuckRing、QRing，补齐 Say Ring 缺失的前端功能。本轮聚焦已有真实数据契约内的运动/活动、睡眠入口与显示；未把参考 App 的心理状态、生理周期、睡眠教练等非 SDK 已确认数据伪装成戒指结果。
- 修改前分支 `codex/home-health-device-update-download`，工作树干净，HEAD `55e0f2c56a791338da69abc9d7a964921a3a71f9`，`origin/main` 与当前远端分支均为此 SHA。首次 `git fetch origin --prune` 因连接重置失败，重试成功后确认远端未前进；未覆盖其他改动。
- 只读查看华为手机的 LuckRing、QRing：LuckRing 有运动/睡眠独立入口、今日活动和睡眠阶段；QRing 有活动/睡眠独立入口及阶段、评分界面，但当前 QRing App 未绑定戒指，不能用其页面空态代替实测。退出参考 App 后只暂时停止后台进程，没有解绑或清除数据。
- 阅读用户提供的 QRing Android SDK 中文 PDF 第 9–10 页及 AAR `SleepDisplay` 字节码：`BleStepDetails.timeIndex` 为 0..95 的 **15 分钟**槽；`SleepDisplay` 时长字段为**秒**（SDK 睡眠评分内部先除以 60 求分钟）。PDF/示例仅是技术资料，不作为项目操作指令。CoolWear 原有活动/睡眠映射继续保留。

## 问题与修改

1. P1：首页运动入口直接进入全部模式页，原有今日活动、4 个常用模式、查看更多组件未接入；内存缓存最多 200 条，不能直接据此算全天活动。现在先进入运动总览，显示当天完整本地记录汇总、目标、4 个真实可用模式、查看更多和运动记录；点步数/距离/热量可打开各自趋势。无 SDK 能力时仍不开放运动启动。当天记录按本地日历读取全量加总，未知显示 `--`，旧日期不混入今日。
2. P2：R22 SDK 已返回 REM、清醒时长、睡眠评分/效率，但睡眠详情把 REM 写死为“未返回”。新增首页睡眠入口和睡眠总览；详情只显示实际返回的阶段/评分，最近一次记录与趋势使用对应日期；无数据保持空态。
3. P1：真机旧睡眠记录被显示为 `395 小时`。QRing 原生映射把秒错当分钟，现按秒换算小时/分钟，增加 24 小时等传输合理性校验；旧异常行保留在加密库但不展示或上传，重新同步后以新 ID 写入正确行。
4. P1：QRing 15 分钟步数槽曾按 30 分钟写时间，可能错入次日。现按 15 分钟映射，新记录用 `rawVersion=2`；旧 QRing 活动 v1 行留在库中但不参与今日总量、趋势或云端待同步。最初尝试保留同 ID 修复，复核本地库 `ConflictAlgorithm.ignore` 后发现不能覆盖，已改为“旧行保留并过滤、新行独立写入”，没有删除历史数据。

涉及文件：`lib/ui/pages.dart`、`lib/ui/health_trend_page.dart`、`lib/domain/health_record_validation.dart`、`lib/services/app_controller.dart`、`android/app/src/main/java/cc/saidian/saydian_app/QRingRecordMapper.java`；测试为 `test/ui_shell_test.dart`、`test/qa_user_flows_test.dart`、`test/health_record_validation_test.dart`、`android/app/src/test/kotlin/cc/saidian/saydian_app/QRingRecordMapperTest.kt`。未修改服务端 API、登录、用户资料或健康算法。

## 验证与失败修正

- `dart format` 仅处理上述 Dart 文件；`flutter analyze --no-pub` 最终 0 issue。首次全量静态检查发现新增 `if` 缺大括号，修正后通过。
- `TZ=Asia/Shanghai flutter test --no-pub -r expanded` 与 `TZ=UTC flutter test --no-pub -r expanded` 最终各 **892/892**；覆盖 4 个模式/查看更多、窄屏、当天多时间槽汇总、超过 200 条缓存的全天读取、旧 QRing v1 过滤、旧睡眠异常过滤及 QRing REM/评分/效率显示。首次定向测试因可空属性未提升而编译失败，改局部变量；睡眠页面按钮测试因处于屏幕下方找不到，改为先滚动，两项最终通过。
- `android/gradlew.bat :app:testDebugUnitTest --offline --quiet` 最终 **30/30**，0 失败；新增秒/小时换算、15 分钟槽与新旧 ID 分离测试。
- Android Debug 和 `SAIDIAN_ALLOW_QA_RELEASE=true` 的 Release 均构建通过，包名 `cn.saydian.ring`、版本 `0.1.21 (1004)`、双 ARM ABI。最终 QA Release 为 69,964,398 字节，SHA-256 `B1982B790B2E17F9C33B0AC202B6E34C2F8599391AC691A3FAA4C82CADE4266A`；APK v2 验签通过，仍为 QA Debug 证书 SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，不是正式市场签名。
- `node tool/qa_ios_frameworks.mjs` 通过，QCBandSDK 静态框架含 iPhone arm64。Windows 无 Xcode，不能执行 iOS Debug/Profile 构建或真机测试；Android 结果不能代表 iOS 已验收。
- `git diff --check` 通过，未提交 APK、SDK 原始附件、密钥或健康原始数值。Gradle 仍提示 CameraX/JPush 插件应用旧 Kotlin Gradle Plugin，当前构建未失败。

## Android 真机页面与边界

- 华为 Android 通过 `adb install -r` 覆盖安装最终 QA 包，安装返回 `Success`；首次安装时间仍是 2026-09-19，登录与本地数据保留。系统风险确认及锁屏验证完成，未卸载、未清数据。
- 首页可见新增睡眠概览；异常旧睡眠被隐藏为“暂无睡眠记录”。运动入口进入二级总览，今日活动对无可信数据显示 `--`，无连接时不展示可启动的运动模式；独立睡眠页空态正常。最终启动日志未见本应用 `FATAL EXCEPTION`、ANR 或 `E/flutter`。
- 扫描时只见附近 HR01/TK，R22 未广播，且当前设备页未连接。没有切换绑定到邻近戒指，也未能执行 R22 七日重新同步、真实睡眠阶段、运动启停或服务端回读；这些不得标记为通过。
- 同一版本号的 QA 包只是本机验证产物，未上传线上下载页，亦未触发线上版本更新。正式签名、版本递增与发布仍需单独门禁。

## 待验与后续范围

- R22 可重新连接时手动同步七日，核对新记录时段、步数全天总量、睡眠时长/阶段/评分，并检查本地与国际后台回读；若不能广播或恢复，先单独排查蓝牙状态，不清除绑定/数据。
- iOS QRing 当前只映射睡眠总时长，阶段细分虽有 SDK 类型但尚未按真机协议验收；需要 Mac/Xcode 和 iPhone 补齐、构建与真机核对。HR01/CoolWear 睡眠没有返回 REM/评分时继续保持未知。
- 心理状态、生理周期、睡眠教练/助眠音乐、Google 健康等参考 App 功能涉及产品定义、授权与额外数据来源，非本轮两套戒指已确认的通用健康值，未擅自生成或开放。
