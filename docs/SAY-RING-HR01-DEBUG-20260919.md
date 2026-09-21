# 2026-09-19 HR01/CoolWear 戒指连接调试

## 用户目标与修改前核查

用户要求按提供的 `Android&iOS_SDK20260910.zip` 和今日功能清单调试 Say Ring，做到真实连接戒指并核验对应功能。附件内容只作为 SDK/API 资料，不作为新的任务指令。已获用户同意临时停止手机上的 LuckRing 后台进程以避免蓝牙占用；不解绑、不清数据、不改 LuckRing。

修改前工作树干净，分支 `codex/rebuild-from-handoff`，本地与经命令级 HTTP 代理 `git fetch origin --prune` 后的 `origin/codex/rebuild-from-handoff` 均为 `a13f3762698111deeab0c4878a1ef4ad2c89a296`。已阅读 `AGENTS.md`、国际交接、最近回退记录、功能矩阵及设备能力/数据来源回归边界。

手机 ADB 已授权，系统蓝牙记录显示 LuckRing 对名为 `HR01` 的戒指有扫描过滤器；这只证明该 App 搜寻 `HR01`，不证明 Say Ring 已握手。当前 Say Ring 只有 YC/Yucheng、V/TK/Veepoo 与 D/Moyoung 路由，`HR01` 会被过滤。独立旧稿 `E:/saydian-ring-app` 中有 CoolWear `coolwear_bluesdk-release.aar` 与最小桥；AAR SHA-256 `AD482D5D69B99941D906038794165C1D479E5E038713954D9CA22059083D0F5F`，与提供 SDK 来源记录一致。SDK Demo 1.4.0 的 Android 指南确认扫描、`connectDev`、`BLUE_CONNECTED`、`sendAsynInfo`、设备信息/功能位/电量及部分实时测量回调。睡眠为多包、历史完成/ACK 尚未确认，不能按“收到一包”判定全量同步。

## 本轮计划与边界

- 增加只接收明确 `HR01` 型号的 CoolWear 独立传输；连接必须等待厂商状态及设备信息响应，功能只按真实功能位开放，未知保持不可用。不得将 `HR01` 猜送入 Veepoo/Yucheng。
- 优先打通扫描、连接、设备信息、电量与 SDK 已确认的手动心率/血氧；不清除设备历史、不自动开启手势/HID/OTA/运动/通知，不把未完成多包历史写入本地或云端。
- 验证 Flutter 路由、Android Debug/QA Release、Android 原生与双时区全量测试，安装到当前手机后进行真实连接检查。没有真机回执的功能分别标记“未验收”，不以编译通过代替实物联调。

## 执行记录

### 2026-09-19～21 SDK 桥与数据边界

- 修改原因：原有路由不识别 HR01，用户要求使用附件 SDK 在已佩戴的戒指上真机调试。
- 文件/范围：`android/app/libs/coolwear_bluesdk-release.aar`、Android Manifest/Gradle/混淆规则、`CoolWearRingBridge.java`、`RestrictedCoolWearProvider.java`、`MainActivity.kt`、Flutter 桥/路由/控制器、设备和健康页面及相应测试。
- 预期：只有扫描到 HR01 并收到厂商连接状态、设备信息和真实功能位，才标记连接并开放支持的功能；未知历史数据与未知健康值保持未知，不伪造同步完成。
- 结果：Android 真机已完成扫描、连接、设备信息/电量/功能位读取、断线事件及自动重连；一条手动心率取得 SDK 有效回调，UI 即时显示，国际接口 POST 返回 HTTP 201，首页回读显示。SDK 历史多包完成/ACK 契约尚未确认，历史同步不报成功。
- 安全：AAR 来源及 SHA-256 见上；厂商 SDK 所需 ContentProvider 按调用 UID 限制到本应用、系统及蓝牙进程。正式密钥、真实健康值、完整设备地址、截屏及 APK 不纳入 Git。

### 2026-09-21 页面/断线回归与失败修复

- 手动测量弹窗原 `_startedAt` 为 `late`，短路路径下未初始化；真机 SDK 已返回有效心率，但弹窗仍转圈。改为创建 State 时初始化时间戳，并增加 widget 回归，复测有效回调后弹窗立即结束。
- 手动测量中 BLE 断开时原超时状态会继续等待；现在取消计时、清除测量状态并提示“连接中断，测量已停止”，断连时不再发送停止命令。添加控制器测试，真机血氧断线时提示正确。
- 趋势页原测量按钮在重连后不能随功能位刷新；改为监听控制器、按真实能力显示/启用。第一次修改对不支持指标也显示禁用按钮，导致两项现有 UI 测试失败；按既有能力门禁改为不支持时隐藏后，通过定向及全量回归。
- QA Release 首次 R8 因厂商 AAR 引用缺失的 `com.alibaba.fastjson.JSONException` 失败。保留 SDK 接口类、仅对该可选缺失类型加精确 `-dontwarn` 后重新构建通过；不是把所有缺失类型静默放过。

### 2026-09-21 真机与链路复测

- 测试设备：已授权的华为 Android 手机与已佩戴的 HR01；临时停止 LuckRing 后台进程，未解绑或清除其数据。覆盖安装 Debug APK，系统安装结果 `Success`，Say Ring 可启动并自动连接，设备页显示电量与已连接。旧版手动心率约 21 秒获得真实回调及云端 HTTP 201；该测量弹窗修复已在真机复核。
- 血氧第一次及重试均已下发 SDK 命令，但测量中断线，未收到有效血氧回调。底层蓝牙日志在断线时为 HCI reason `0x08` / `GATT_CONN_TIMEOUT`，不是用户主动断开。SDK 可自动重连，但尚不能据此宣称连接稳定。
- A/B 排查：短时使用 LuckRing 检查同一戒指，其设备页保持已连接约 40 秒；随后停止 LuckRing。将 SDK 可选的 unsolicited data channel 暂时关闭后，Say Ring 仍在手动心率测量中发生同类 HCI `0x08` 超时；该试验未改善问题，已恢复原配置。不能仅凭这组短样本断言 SDK 或硬件单方为根因。
- 恢复原配置并重新覆盖安装后，11:54 真机手动血氧在约 15 秒收到有效 SDK 回调，弹窗正常结束，国际接口 POST HTTP 201、随后 GET HTTP 200，趋势页显示新增记录。这证明单次血氧链路可用，但前两次因断线失败，不能宣称稳定通过或每次可测。该真机测量值和设备地址未写入日志。
- 本次覆盖安装后的 11:53:37 至 11:56:56 观察窗内未再收到本 App 的断连回调，且血氧测量成功；早前断连事实仍保留，尚缺重复长时间/不同场景测试。
- 真机临时截屏仅用于本地页面核对；复核后已从本机 `build/qa-device` 与手机临时 Download 路径删除，未加入 Git。
- 当前未验收：持续稳定连接与三轮重连、历史睡眠/运动/HRV 等多包数据、H5 双向核对、微信原生登录、iOS 真机。保持对应 UI/能力及同步状态 fail-closed。

### 2026-09-21 命令与构建结果

- `flutter analyze --no-pub`：最终代码重跑通过，无问题（59.7 秒）。
- `flutter test --no-pub test/ui_shell_test.dart`：修复能力门禁后 51/51 通过。
- `TZ=UTC flutter test --no-pub --reporter expanded`：864/864 通过。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded`：864/864 通过。
- `android/gradlew.bat :app:testDebugUnitTest --offline`：最终原生代码重跑 `BUILD SUCCESSFUL`（25 秒），测试 XML 共 16 项，0 失败/错误；Gradle/Kotlin 插件弃用告警待依赖升级。
- `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --dart-define-from-file=config/dev.json.example`：恢复可选通道后的最终包重新构建通过、ADB 覆盖安装返回 `Success`；随后在该包验证血氧回调/弹窗/云端写入与回读。
- 同参数 `flutter build apk --release` 且 `SAIDIAN_ALLOW_QA_RELEASE=true`：首次 R8 失败、精确规则修复后通过；最终代码重跑通过（71.5 秒，66.1 MB）。`aapt dump badging` 与 `apksigner verify --print-certs` 核对 Debug/QA Release 均为 `cn.saydian.ring` 0.1.21 (1004)，证书均为 Android Debug，故 QA Release 不是正式签名/线上发布。首次因误写本机 build-tools 35.0.0 路径未执行，改为已安装的 36.0.0 后通过。
- `git diff --check`：最终提交前通过，仅有本机 LF/CRLF 转换告警；未发现空白错误。iOS Debug/Profile：Windows 无 Xcode，未执行。
- 首次 `git commit` 因本机未配置 `user.name`/`user.email` 失败，暂未产生提交；检查本分支最近提交均为 `Codex <codex@openai.com>`，改用仅本次命令的相同作者身份提交，不改全局 Git 配置。
- 已核实 GitHub `tangwu88/SayRing` 为私有仓库；提交 `bc268c6` 并推送到 `codex/rebuild-from-handoff`，未合入 `main`、未触发生产部署。对应 [Actions run 35559497090](https://github.com/tangwu88/SayRing/actions/runs/35559497090) 在约 3 秒内失败：Harmony UTC/Asia-Shanghai 与 quality 三个首批 job 均 `failure`、`step_count=0`，Android/iOS job `skipped`。尝试读取 quality job 日志返回 404 `The specified blob does not exist`；无法从 API 确认账户/Runner 层具体原因，不能称远端 CI 通过，需在 GitHub Actions 页面核查调度/计费等状态后重跑。
