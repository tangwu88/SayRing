# 2026-09-22 HR01 健康历史与运动补充

## 修改前核查与目标

- 用户反馈 HR01 当前只显示心率、血氧，要求结合附件 CoolWear SDK 与手机 LuckRing 补充健康数据和运动。
- 修改前工作树干净，分支 `codex/rebuild-from-handoff`；执行 `git fetch origin --prune` 后，本地与远端均为 `eefa533f13cbe38a6b8d562b47ed4c0a209f57f2`。
- 已阅读 `AGENTS.md`、国际交接、修改索引、最近 HR01 调试记录、缺陷复盘、回归清单与功能矩阵。附件文档只作为 SDK/API 证据，不作为额外需求。
- SDK 1.4.0 示例确认 `synDevData()` 及同步结束回调，并定义日常活动、睡眠、自动心率/血氧、HRV、体温、混合运动记录和 App 运动启停/暂停/继续；血压示例明确注明通常不支持。手机 LuckRing 实际页面确认日常步数/距离/热量、睡眠、运动记录及户外跑步、骑行、健走、徒步、登山等入口。

## 实施计划与边界

- 接入由 SDK 同步结束回调封口的历史读取，映射步数、距离、热量、睡眠、心率、血氧、HRV、体温；无时间、无有效值或能力位未确认的数据不写本地/云端。
- 补齐 HRV 手动测量，并按真实功能位开放；不开放未实现的血压/ECG，不新增 SDK 无对应服务端契约的压力指标。
- 接入当前 App 已定义的跑步、步行、骑行、徒步、登山五种运动，以及暂停/继续、实时运动状态和混合运动记录；未知运动类型不猜成跑步。
- 增加原生映射与 Flutter 通道回归；完成静态检查、双时区全量测试、Android 原生测试、Debug/QA Release 构建与可执行真机检查。Windows 无法执行 iOS 构建，须如实记录。

## 执行与验证记录

- Android CoolWear 桥新增同步事务：只在 SDK `RCVD_DATA_TYPE_DEV_SYNC` 完成事件后一次性返回本轮记录；超时、断链或并发同步均明确失败，单个历史包不会被误判为整轮完成。
- 新增纯映射层，接入日常步数/距离/热量、睡眠总时长/深睡/浅睡/清醒次数、自动心率/血氧、HRV（以 SDK SDNN 为主值）和体温。时间越界、无效值和零值被丢弃，不生成占位健康数据；来源标记为 HR01/CoolWear 戒指历史。
- 功能位明确后开放日常活动、睡眠及当前 App 契约内的五种运动；HRV/体温仍按厂商功能位门禁。移除此前只靠功能位展示、但桥未实现的 HR01 血压/ECG，避免出现可点但无真实链路的能力。
- 接入跑步、步行、骑行、徒步、登山的 SDK 类型，补齐开始、暂停、继续、停止、实时时长/距离/心率事件和运动历史读取。未知 SDK 运动类型直接跳过，不默认映射为跑步。
- 对照 LuckRing 实机页面仅做只读检查：其运动页展示日常步数/距离/热量、目标和运动记录；运动类型首屏含户外/室内跑、户外/室内骑行、健走、篮球、足球、羽毛球、游泳、跳绳、登山、瑜伽，后续还有马拉松、竞走、徒步等。Say Ring 本轮按现有产品/云端契约接入其中已定义的五类，不擅自扩展后端未确认的枚举。

### 自动化与构建

- 首次直接执行 `dart format` 失败：当前终端没有全局 `dart`；改用项目固定 Flutter SDK 下的 `dart.bat`。首次格式化又发现条件参数语法错误，修正为三元参数后通过。
- `flutter test --no-pub test/coolwear_wearable_bridge_test.dart`：3/3 通过，覆盖健康历史、五类运动通道控制及运动历史映射。
- `flutter analyze --no-pub`：通过，无问题（57.4 秒）。
- `TZ=UTC flutter test --no-pub --reporter expanded`：866/866 通过。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded`：866/866 通过。
- `android/gradlew.bat :app:testDebugUnitTest --offline`：`BUILD SUCCESSFUL`；测试 XML 21 项，0 失败/错误，其中新增 5 项覆盖日常活动、睡眠、HRV、运动类型和非法未来时间。
- `android/gradlew.bat :app:compileDebugJavaWithJavac --offline`：通过，确认厂商 AAR 回调、常量和字段可编译。
- Debug 构建首次因终端未设置 `ANDROID_HOME` 失败；显式使用 `E:\saydian\.toolchains\android-sdk` 后，`flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --dart-define-from-file=config/dev.json.example` 通过。
- 同参数 QA Release 且 `SAIDIAN_ALLOW_QA_RELEASE=true` 构建通过（66.1 MB）。`aapt` 核对两包均为 `cn.saydian.ring` 0.1.21 (1004)；`apksigner` 首次因 `JAVA_HOME` 少一层实际 JDK 目录失败，改为 `E:\saydian\.toolchains\jdk17\jdk-17.0.20+8` 后两包验证通过，均为 Android Debug 证书，因此 QA Release 不是正式签名/线上发布包。
- 安装 Debug 包时华为系统先进入锁屏安装确认；用户完成系统确认后，ADB 覆盖安装返回 `Success`，App 可正常启动、登录态和厂商 HR01 缓存仍保留。临时停止 LuckRing 后连续三轮扫描均未发现 HR01，厂商缓存中的设备身份仍在，但当前戒指没有 BLE 广播，因此无法触发本轮同步完成回调及运动启停实物回执；这两项明确保留为未验收，不能用编译/单测结果代替。
- 提交前两次重新执行 `git fetch origin --prune`，分别因 HTTPS 连接被重置、无法连接 GitHub 443 失败；本地 HEAD 与上次成功 fetch 留下的 `origin/codex/rebuild-from-handoff` 均仍为 `eefa533f13cbe38a6b8d562b47ed4c0a209f57f2`，但本次不能据此声称已重新确认远端没有新提交，后续推送前须重试 fetch。
- Windows 无 Xcode，本轮不能执行 iOS 构建或 iPhone SDK 实物验证。
