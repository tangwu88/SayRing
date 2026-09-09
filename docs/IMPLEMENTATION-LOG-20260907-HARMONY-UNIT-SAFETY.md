# 鸿蒙单位设置连带时制变更：根因与修复

## 02:00 后真机反馈与修改范围

- P1：W9S 原为 24 小时，测试公英制/温度单位切换还原后变为 12 小时；测试者没有操作时间同步。
- 预期：只修改用户选择的一个配置，时制和其他健康开关保持原值。
- 修改前完成远端 fetch，HEAD `06ec474`；工作区为同轮已知并行改动，按主线程授权隔离编辑，不 pull、覆盖或重置他人改动。
- 已阅读 AGENTS、修改索引、设备设置/前台通知记录及复盘/回归清单。原官方 HAR、示例与 SDK 文件只读。
- 本批文件：`DeviceSettingsTransactions.ts`、`VepDeviceSettingsAdapter.ets`、`VepWearableService.ets`；Index 仅单位方法/卡片/相应导入，与邀请卡和个人资料局部编辑分开。

## 已证实的 SDK 行为

锁定官方 HAR SHA-256：`60cdffa08076d7167e90736cd8ea433b62dbf562d295c5275acfc4bfcdd40bd2`。官方声明 `TimeFormatB8.HOUR_24=1`、`HOUR_12=2`，官方 UnitPage 选项一致；赛电摘要映射没有写反。

使用当前 DevEco 官方 `ark_disasm` 将已安装 HAR 的 `ets/modules.abc` 只读输出至标准输出，不修改 SDK、不猜广播协议：

1. `ConfigService.setUnitValue`：复制 `device.switchConfig`，修改指定字段，然后**无条件**用 `i18n.System.is24HourClock()` 重写 `timeFormat`，再调用 `setSwitchConfig`。
2. `setSwitchConfig`：直接从调用者提供的完整 32 字段构造两包 B8，依次发送，解析响应；没有调用系统时制或额外覆盖字段。
3. `getSwitchConfig`：发送 B8 读取请求、解析响应后更新设备缓存；不是只读缓存。`getCachedSwitchConfig` 才是缓存副本。
4. `setUnitValues` 没有上述系统时制覆盖，但仍依赖内部缓存；本批按完整鲜读快照显式使用 `setSwitchConfig`，避免隐藏关联写入。

因此不能用旧 `setUnitValue('timeFormat', 1)` 恢复，它仍可能把 1 覆回手机的 12 小时设置。

## 修复与安全边界

- 保存前完整读取当前 32 字段；缺字段、非整数字节或未知读取失败禁止写入。不把缺失字段默认成 0；已有未知合法字节原样保留。
- 复制鲜读快照，只改变用户明确选择的 `unitSystem`、`tempUnit` 或 `timeFormat` 一项；完整写入后再次读取，目标及其余 31 项全部一致才返回成功。
- 不使用 ACK 或 SDK 回传的输入对象代替真实回读。给 SDK 的写入对象与预期对比副本分离，避免 SDK 修改入参隐藏副作用。
- 不自动重试失败写入、不擅自批量回滚其他配置。回读不一致要求重新读取，不显示保存成功。
- 单位页增加实际 SDK 支持的时间格式；1 为 24 小时，2 为 12 小时。期望旧值从对应 `timeFormat` 获取，不能误用温度基线。
- SDK 两包发送之间含内部 await。`runDeviceCommand` 追踪实际未终结 Promise，账号切换及断开后的新连接先排空；超时不等于取消，不会清掉未结束命令后复用 SDK 给新表。
- 所有客户端 read/write/read 前后校验账号/连接/操作代次；旧回调不能释放新操作的锁。

## 安全恢复路径

安装本批新包后：设备 → 设备设置 → 手表单位 → 时间格式 → 24 小时。

以本轮真机已记录原值 `timeFormat=1` 为恢复依据；保存后应显示 24 小时，再返回父设置页重新读取。核对公英制、温度及其他 31 字段与保存前一致。此路径尚待主线程真机执行，不能写已恢复。

## 验证记录（持续追加）

- 初次尝试把 HAR 当 ZIP 列表失败；实际为 gzip TAR，未改变原文件。随后读取已安装 SDK 声明及官方字节码成功。
- 首次字节码文本过滤在无关模块遇到多字节转换错误；改用 `LC_ALL=C` 后只读提取目标方法成功，未复制/提交厂商字节码。
- 并行任务在本批中间态执行两时区全量：各 320 项中 316 通过，4 条旧单位夹具因仅含两个字段而被新完整性门禁拒绝。保留 `/tmp/saydian-harmony-inviter-identity-utc.log` 与 `...-shanghai.log`；本批随后更新完整夹具，没有放松生产门禁。
- 纯事务 + 直接执行生产 adapter：24/24 通过。包括复现旧 SDK 随手机改时制、逐一检测 31 个非目标字段变化、逐一缺失 32 字段、真实时制恢复路径、写入入参被 SDK 修改、前读/写 ACK/后读迟到。
- 直接执行生产 Vep 服务：12/12 通过。新增双包内部 await 时下一连接不得越过、账号切换排空、重复超时仍保留未终结命令、失败实际终结后可重连四类反例。初轮因真实 post-connect 计时器等待约 12 秒；仅测试夹具改用可控计时器，生产时序不变。
- 新增生产 Index 单位提交方法执行测试与时制标签/入口检查；全量双时区及 Debug/Release 编译待下节追加。

## r7 冻结源验证与开发签名产物（02:19–02:20）

- 相关定向测试 39/39；全量 UTC 339/339、Asia/Shanghai 339/339，失败、跳过均为 0。日志分别为 `/tmp/saydian-harmony-r7-utc.log` 和 `/tmp/saydian-harmony-r7-shanghai.log`。
- 全仓 `git diff --check` 通过。本批没有提交或推送，交主线程整合门禁。
- 在原同签名暂存工程 `/tmp/saydian_harmony_build_20260906_0952` 冻结 r7 源，未覆盖本地签名配置；包含已锁定邀请身份与资料常驻标签，不包含随后开始的 r8 心电状态修改。
- Debug 构建通过（17.394 秒）；Release 构建通过（16.707 秒）。两包都由官方 `hap-sign-tool verify-app` 验证成功，证书链与 r2 真机已有签名逐字一致。
- Debug：`/tmp/saydian-harmony-session.5ERCEO/Debug-r7-unit-safety-development-signed.hap`；SHA-256 `4c8a413dc4031f4793be13eed4ecee3721ec63b4ec1779b5d6c0510c00bf0228`。
- Release：`/tmp/saydian-harmony-session.5ERCEO/Release-r7-unit-safety-development-signed.hap`；SHA-256 `adba2f7da330df6b10023e14255fc245f76b794a82e49c446e548c3212c61696`。
- 两包仍使用开发证书及 debug profile，仅用于已登记设备验证；Release 优化构建不等于 AppGallery 正式发行签名。没有安装手机或执行手表写入；Debug 路径已交主线程优先恢复原 24 小时时制。

## r7 真机恢复与非目标字段复核（主线程实测追加）

- 已用同签名 r7 在 W9S 恢复 `timeFormat=1`，即原 24 小时制。
- 距离单位 `1→2→1`、温度单位 `1→2→1` 均显示“已保存到手表”；此成功提示必须经过 32 字段真实回读一致门禁，每次重新读取的时制始终为 1。
- 最后返回父设置页实际回读：公制、24 小时、消息提醒 1/12、暂无闹钟；原表盘 3 此前已恢复。本次由主线程操作，非自动化替代真机。

## 尚未通过的验收

真实时制恢复及重复单位切换已按上节通过；换号中断或 SDK 超时恢复尚未真机验证。本批没有修改厂商 SDK、CRC、健康校准、闹钟或账户数据。最终独立审计另发现旧公开 SDK 操作未纳入统一跟踪，现转入 r9 专项，不将该边界记为已通过。
