# 2026-09-23 LuckRing 健康功能重新对齐

## 修改前核查

- 用户反馈当前健康功能仍与 LuckRing 不一致，要求重新逐项核对。
- 修改前分支为 `codex/rebuild-from-handoff`，工作树干净，HEAD 为 `70c2a81918d1cb9ed3ed235d0f0b00a5f18ee58e`，相对本机 `origin/codex/rebuild-from-handoff` ahead 2。
- `git fetch origin --prune` 失败：无法连接 `github.com:443`；本轮只能以当前本地提交为基线，提交前必须重试，不能声称远端已同步。
- 已阅读 `AGENTS.md`、`docs/HANDOFF.md`、最近 LuckRing 对齐记录、缺陷复盘和回归清单。
- 手机当时处于锁屏/AOD，无法读取 LuckRing 当前 UI；已继续用用户视频、LuckRing APK 资源与厂商 SDK/Demo 做只读对照，解锁后再补真实页面核验。

## 差异与 Bug 报告

### P1：压力链路完全缺失

- 复现：连接 HR01 后进入健康页，或在戒指产生压力数据后同步。
- 预期：像 LuckRing 一样显示压力卡片、历史趋势并支持手动压力测量。
- 实际：App 未注册 `RCVD_STRESS_SHOW`，未调用 `sendStressSwitch`，数据模型与页面也没有压力类型。
- 影响：SDK 已返回的真实压力数据被丢弃，用户无法使用该核心健康能力。

### P1：睡眠详情信息不完整

- 复现：同步到睡眠记录后打开睡眠分析。
- 预期：显示总睡眠、深睡、浅睡、清醒/体动等 SDK 实际返回的分项。
- 实际：映射层保存了深睡、浅睡、体动和清醒次数，但趋势页只显示总时长的通用均值/折线。
- 影响：真实睡眠结构数据存在但用户不可见。

### P2：皮肤温度被误称为体温

- 复现：同步 HR01 温度后查看首页和趋势解释。
- 预期：按 SDK 与 LuckRing 语义显示皮肤温度；若没有足够个人基线，不伪造“波动”值。
- 实际：当前显示为“体温”，并按核心体温 36–37.3℃作解读。
- 影响：容易把戒指的皮肤温度误解为医用体温。

## 本轮实施边界

- 接入真实压力回调、历史/手动测量、能力门禁、本地保存、趋势页和现有小程序 `daily-date.pressure` 上传字段。
- 睡眠页展示 SDK 已返回的真实分项；SDK 没有 REM 类型时保持未知，不用浅睡冒充 REM。
- 温度文案与解读改为皮肤温度；“皮肤温度波动”需要个人基线，样本不足时保持未知，不补零。
- LuckRing 的“身心准备度”为其 App 算法结果，SDK 未提供同名分数；“心理状态”为用户手工记录；“生理周期”为用户配置与预测并可下发戒指。当前 Saydian 云端没有三者的已确认互通契约，本轮不伪造数值、不冒用其他健康类型，也不擅自修改接口协议。

## 执行与验证记录

### 实施结果

- 新增 `HealthMetric.stress`，HR01 在真实功能位确认支持 HRV 后才开放压力；依据厂商 README“压力由 HRV 数据通过算法计算”，未额外猜测一个不存在的压力功能位。
- Android CoolWear 桥注册 `RCVD_STRESS_SHOW`，历史同步与手动测量都映射 `K6_StressStruct.time/stressValue`；仅接受 1–100，手动启停使用 SDK 的 `sendStressSwitch(OPEN/CLOSE)`。
- 压力进入现有 SQLCipher 健康记录、首页卡片、趋势/统计、手动测量和云同步队列；小程序兼容上传使用已部署 `POST /api/v1/member/daily-date` 的 `pressure` 字段，没有新增或猜测接口。
- 现场读取 LuckRing 压力详情，确认分级为放松 1–29、正常 30–59、中等 60–79、偏高 80 起；Say Ring 的卡片状态、详情分级和解读按该范围展示。
- 睡眠详情新增总睡眠、深睡、浅睡、体动、清醒次数；现场 LuckRing 会列出快速眼动，但当前 SDK 的 `K6_Sleep` 只有开始/深睡/浅睡/清醒/体动，没有 REM 类型，因此 Say Ring 显示“--（戒指未返回）”，不把浅睡冒充 REM。
- 首页新增“身心准备度”数据覆盖卡。现场 LuckRing 在数据不足时同样显示 `-- / 暂无数据`；Say Ring 只展示睡眠、HRV、压力和皮肤温度的基线覆盖数，不生成未经确认的专有评分。
- HR01 的温度名称改为“皮肤温度”，移除按 36–37.3℃核心体温判断高低的首页状态和详情解读；没有足够个人基线时不伪造“皮肤温度波动”。
- 八种现有语言均补压力与皮肤温度名称，并重新生成本地化代码。

### LuckRing 真机只读证据

- 手机解锁后启动 `com.kewo.coolring`，未写入资料、未清数据、未解绑戒指。
- 首页现场显示 HRV 40 ms、压力 44（正常），压力支持“立即测量”；压力详情包含最高值、最低值、平均值与四段分析。
- 心理状态现场显示 `--` 和“立即记录”，确认它是用户手工记录，不是 SDK 自动传感器结果。
- 皮肤温度波动现场显示 `--`；身心准备度现场显示 `-- / 暂无数据`，均支持未知状态。
- 睡眠概览现场列出总时长、深睡、浅睡、快速眼动和清醒；本轮按 SDK 实际字段展示，未添加 LuckRing 的助眠音乐/睡眠教练等非戒指能力。

### 过程中失败与修复

- 手机首次启动 LuckRing 时处于 AOD，UI dump 只能读取系统 AOD；用户解锁后重新执行只读检查成功。
- 新增准备度卡后，旧测试仍假定底部健康免责声明无需滚动即可构建，定向测试 1 项失败；测试改为在真实 `CustomScrollView` 内滚动到免责声明再验证位置，复测通过。未通过缩小或删除新卡片掩盖布局变化。
- 首次 `flutter build apk --debug --no-pub` 因当前 PowerShell 未设置 `ANDROID_HOME` 失败；显式设置到仓库既有 Android SDK 后 Debug 构建通过。
- Debug APK 覆盖安装时手机再次进入 AOD，华为安装器等待系统确认；等待期间没有安装结果，停止主机侧等待后保留原 App 与数据，未把本轮包写成已安装。真机压力闭环需在用户解锁确认后续测。

### 自动化与构建

- `flutter gen-l10n`：通过。
- `dart format`：通过。
- `flutter analyze --no-pub`：通过，0 问题。
- 定向 API/UI/健康测试：105 项通过；后续新增准备度与压力分级后相关定向测试继续通过。
- `TZ=UTC flutter test --no-pub`：870/870 通过。
- `TZ=Asia/Shanghai flutter test --no-pub`：870/870 通过。
- Android `:app:testDebugUnitTest :app:compileDebugJavaWithJavac --offline`：通过；压力映射单测包含有效值与越界值。
- Debug APK 与 QA Release APK 构建通过，包名 `cn.saydian.ring`，版本 `0.1.21 (1004)`。
- Debug SHA-256：`14EF135386B5E499B5A61255CBC1B2BD1C1724DABE989D2F03D0C39AC337DAA4`。
- QA Release SHA-256：`9C14B899E748519254EBC134A4B5AEF99E9D8B6EAC1063E36802C42E357D5A5C`。
- 两个 APK 都使用 QA 调试证书，证书 SHA-256 为 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`；QA Release 不是应用市场正式签名包。

### 保留边界

- 心理状态为用户手工记录，生理周期为用户配置/预测并可同步到戒指；当前 Saydian 云端没有两者已确认的 APP/H5 互通契约，本轮未做仅本地可见的孤岛功能。
- 身心准备度的 LuckRing 专有评分算法未由 SDK 提供；只保留未知值和基线覆盖，不复制不明算法。
- Windows 无法执行 iOS Debug/Profile 构建和 iPhone 真机验收，本轮不得写 iOS 已通过。

## Git 核对

- 修改前首次 `git fetch origin --prune` 因无法连接 `github.com:443` 失败；提交前重试成功。
- 重试后远端 `origin/codex/rebuild-from-handoff` 为 `eefa533f13cbe38a6b8d562b47ed4c0a209f57f2`，本轮修改前 HEAD 为 `70c2a81918d1cb9ed3ed235d0f0b00a5f18ee58e`；merge-base 与远端一致，本地原已 ahead 2，远端没有新提交或分叉。
- `git diff --check` 通过，仅有工作区 LF/CRLF 提示，无空白错误。

## 2026-09-23 HR01 真机压力补充验收

### 安装与连接证据

- 华为 JAD-AL00 已安装 `cn.saydian.ring` `0.1.21 (1004)`；从手机回读的 `base.apk` 与本轮 Debug APK 的 SHA-256 均为 `14EF135386B5E499B5A61255CBC1B2BD1C1724DABE989D2F03D0C39AC337DAA4`，确认不是旧包。
- 验收前关闭 LuckRing 后台进程避免 BLE 抢占；Say Ring 设备页显示 HR01 已连接、电量 100%，SDK 日志确认 device-info 握手完成，并返回 `heart=true, oxygen=true, hrv=true, temperature=true` 的真实功能位。
- 压力入口只在 HRV 功能位握手成功后开放，符合厂商“压力由 HRV 算法估算”的能力门禁，不以设备名称猜测支持情况。

### 压力实测结果

- 第一次在戒指历史同步尚未完成时开始压力测量，SDK 命令已经下发，但过程中连接短暂中断，页面明确提示“连接中断，测量已停止”；该次不计为通过，也没有生成伪造记录。
- 等待设备页恢复“同步数据”且 HR01 保持已连接后第二次测量；SDK 再次收到 `manual measurement command start: stress`，随后返回 1–100 范围内有效值，页面按 LuckRing 的 80–100 规则显示“偏高”。为避免在仓库保存用户真实健康数值，本记录仅保留范围与分级证据。
- 结束测量后，压力详情生成 1 条记录，平均/最大/最小和趋势图一致；强制停止并冷启动 App 后，首页压力卡仍显示同一分级与 1 条记录，确认 SQLCipher 本地持久化成功。
- 戒指在第二次结果回传后又短暂断链，约 11 秒后 SDK 日志出现 `vendor link recovered` 并自动恢复；结果未丢失，但链路抖动仍需列为稳定性观察项。

### 接口与保留边界

- 冷启动及手动同步后，`app.saydian.cn` 的后续健康读取请求返回 HTTP 200；当前保留日志没有捕获这条压力记录的上传 POST，不能据此单独确认云端已经接收该记录。
- 本轮可确认“真实戒指回传、页面分级、趋势统计、本机持久化、自动重连”；云端上传需要在可观察上传请求/服务端记录的条件下补充验收。
- 真机命令包括包信息与 APK 回读、UI Automator 页面检查、按应用 PID 的 Logcat 过滤、冷启动和手动设备同步；没有清除 App 数据、解绑戒指或修改用户资料。

### HRV 同机对照

- Say Ring 在同一功能位握手后真实下发 `sendRriHrvCmd(OPEN)`；佩戴并保持静止至 180 秒超时仍未收到有效 HRV，页面保留未知值并提示重新佩戴测量，没有生成占位记录，因此本次 HRV 真机结果不计为通过。
- 随后关闭 Say Ring、启动同机 LuckRing，对同一 HR01 执行“心率变异性 → 立即测量 → 下一步”；LuckRing 同样没有取得新结果，并提示调整身体状态、确认正确佩戴后再次测量。
- 厂商 1.4.0 Demo 的 HRV 命令与回调分别为 `sendRriHrvCmd(OPEN/CLOSE)` 和 `RCVD_DATA_TYPE_RRI_HRV`，与 Say Ring 当前桥接一致。由于参考 App 在相同现场也失败，本轮没有无证据替换命令或伪造结果；需在信号稳定、LuckRing 能先取得新 HRV 的现场再做双 App 对照。
- 对照结束后已关闭 LuckRing，首次返回 Say Ring 时保存设备未立即恢复，手动扫描可重新连接；随后在戒指空闲状态冷启动 Say Ring，保存设备又能自动重连并完成 device-info 与功能位握手。现场仍出现同步完成回调超时与约 10–30 秒的重连等待，最终设备页恢复“已连接/同步数据”，列为链路稳定性观察项，不写成持续稳定通过。
