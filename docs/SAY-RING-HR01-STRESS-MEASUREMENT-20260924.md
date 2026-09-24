# Say Ring HR01 压力测量回调与连接窗口修复

## 范围与基线

- 时间：2026-09-24（UTC+08:00）。
- 分支：`codex/rebuild-from-handoff`；修改前 HEAD：`e2a0eca463f306ece68c179e71d7fb489a0b2d03`。
- 修改前工作树干净；首次 `git fetch origin --prune` 返回 `Empty reply from server`。提交前重试成功，确认 `origin/codex/rebuild-from-handoff` 仍为 `eefa533f13cbe38a6b8d562b47ed4c0a209f57f2`，本地修改前提交领先 6、落后 0；未拉取、未覆盖、未强推。
- 用户现象：HR01 压力检测启动后一直没有返回结果。
- 本轮只调整 CoolWear/HR01 压力实时回调兼容和自动历史同步时机；不改压力值算法、服务端接口、数据库结构或其他设备传输。

## 根因与 SDK 证据

1. 用户提供的 CoolWear Android AAR 对协议数据类型 45 同时保留 `RCVD_STRESS_SHOW` 与 `RCVD_SPORT_HRV_FOR_SHOW` 两条解析/回调命名；`sendStressSwitch` 与相关实时数据使用同一协议族。参考 LuckRing 在该 HR01 上的实际流程，手动压力可能从后一个“real HRV”命名回调返回，而原桥只监听 `RCVD_STRESS_SHOW`，因此真实包到达后没有完成 App 压力会话。
2. 真机日志显示 HR01 链路会短暂断开并自动重连。原逻辑在首次连接立即启动最长约 30 秒的历史同步，重连后又曾重复同步；现场链路窗口短于同步过程，压力按钮持续被“正在读取数据”门禁占用。
3. 手机上旧参考 App 曾在无前台进程时仍残留同一 HR01 的 GATT 客户端连接，造成双客户端争用。调试期间临时停用并停止旧进程，未解绑、未清数据；结束时 `com.yucheng.HealthWear` 已恢复 `enabled=1`，`com.kewo.coolring` 保持系统正常启用状态。

## 实施内容

### 1. 兼容压力实时回调

- Android 桥同时注册 `RCVD_STRESS_SHOW` 和 `RCVD_SPORT_HRV_FOR_SHOW`。
- 备用回调只在当前确实存在压力测量会话、链路仍连接且尚未发出结果时生效；从 SDK `K6_HrvStruct.getHrvNums()` 读取设备实报值。
- 只接受十分钟内的真实时间戳和 `1..100` 有效压力值；无效、过期、空值保持未知，不补零、不推断、不随机生成。
- 仍使用 SDK 文档对应的 `sendStressSwitch` 启停命令；日志只记录固定来源标签与样本数量，不记录用户压力值。

### 2. 给手动测量保留连接窗口

- CoolWear/HR01 首次连接及自动重连后不再自动执行长历史同步，连接成功后立即进入可测量状态。
- 历史同步没有删除，设备页继续提供“同步数据”按钮供用户主动执行。
- 非 CoolWear 设备保持原首次连接和重连自动同步行为，避免改变既有手表流程。

### 3. 回归保护

- 新增源码契约测试，固定双回调注册、备用字段读取、`sendStressSwitch` 命令及禁止随机压力值。
- 新增控制器测试，确认 CoolWear 首连和重连均不自动触发历史同步，同时继续显示手动同步提示；既有非 CoolWear 重连测试明确保持自动同步次数。

## 修改文件

- `android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java`
- `lib/services/app_controller.dart`
- `test/device_sdk_source_test.dart`
- `test/qa_user_flows_test.dart`
- `docs/CHANGE-TEST-LOG.md`
- 本文

## 验证流水

### 自动化与构建

- 首次误用 `flutter format`：失败，Flutter 没有该子命令；随后改用 SDK 同目录的 `dart format`，本轮两份 Dart 文件格式化成功，失败记录保留。
- 压力 SDK 源码与用户流程定向测试：54/54 通过。
- `flutter analyze --no-pub`：通过，`No issues found`。
- `TZ=UTC flutter test --no-pub`：875/875 通过。
- `TZ=Asia/Shanghai flutter test --no-pub`：875/875 通过。
- Android `:app:testDebugUnitTest :app:compileDebugJavaWithJavac --offline`：通过；5 份 XML、23 项，失败/错误/跳过均为 0。仅有既有 Kotlin/AGP 迁移警告。
- 隔离账号、只读接口门禁和原生日志隐私 Node 测试：87/87 通过；未调用真实验证码、注册、支付或生产写入。
- Android Debug：构建成功；`app-debug.apk` 为 186,124,027 字节，SHA-256 `F6F83F328CBD25EEE83DFD570113AF0CDEF4C6A937657F513ABFF3A4B3B0F651`。
- Android QA Release：以 `SAIDIAN_ALLOW_QA_RELEASE=true` 构建成功；`app-release.apk` 为 69,332,256 字节，SHA-256 `AFE554836CD237D59FA7DA229508E97062DA7971808A923E11EF99378D105748`。
- 两包均为 `cn.saydian.ring`、`0.1.21 (1004)`、minSdk 26、targetSdk 36、`arm64-v8a/armeabi-v7a`；`apksigner verify --print-certs` 通过。两包仍为 Debug 证书，证书 SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，QA Release 不是生产上架包。
- `git diff --check`：通过，仅有 Git 对 Java 文件未来行尾转换的提示，无空白错误。

### 华为真机

- 设备：华为 JAD-AL00；最终 Debug APK 通过 `adb install -r` 覆盖安装成功，保留账号与 App 数据。
- 现场确认 HR01 可扫描、连接、完成设备信息握手并实报心率、血氧、HRV、温度能力；新版本连接后设备页立即显示可点击的“同步数据”，不再自动进入“正在读取数据”。
- 清除旧 App 的残留 GATT 争用后，HR01 仍出现约十余秒后断开、再次扫描阶段不广播的现场不稳定；压力详情页到达时链路已经断开，未得到本轮最终真实压力回调，因此不记录也不伪造压力结果。
- 尝试使用手机 `cmd bluetooth_manager disable/enable` 重启蓝牙栈时，系统返回 `No shell command implementation.`，该方法未执行任何蓝牙开关；实际通过停止当前连接进程释放残留客户端。失败方法保留，后续不要据此声称已重启蓝牙。
- 调试结束已恢复旧参考 App 的启用状态；未卸载、未解绑、未清除其数据。Say Ring 最终 Debug 包保留在手机上。

## 页面与接口边界

- 压力详情页、日期切换、趋势空状态和健康总览入口可到达；本轮未改页面结构或样式。
- 本轮未修改 API 地址、参数、Token、健康上传、云端读取或数据库；现有接口契约随全量和 Node 测试通过，不等于生产接口或供应商设备完整联调通过。
- Windows 无 Xcode/CocoaPods/codesign，iOS Debug/Profile 构建与 iPhone 真机未执行；不能用 Android 或 Flutter 测试代替。
- 未推送 Git、未部署线上、未发布 APK。

## 待验收

- 待 HR01 能持续广播并保持稳定连接时，在佩戴、静止、近距离条件下启动一次压力测量，确认日志进入 `source=real_hrv` 或 `source=stress`，页面收到设备真实 `1..100` 结果并保存；未经该步骤不能写“压力真机闭环通过”。
- 如果同一戒指需要在 LuckRing 与 Say Ring 间切换，应先彻底退出占用戒指的另一应用；同一 HR01 被两个 GATT 客户端占用时不作为 App 功能失败结论。
- 使用 macOS/Xcode 串行执行 iOS Debug/Profile 构建并复核同一业务门禁；正式分发前配置生产签名并提升版本号。
