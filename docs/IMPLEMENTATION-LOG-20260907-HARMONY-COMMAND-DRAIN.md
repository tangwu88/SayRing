# 鸿蒙旧设备命令迟到回调与统一排空

## 原因与修改边界

- P1：原 `findDevice` 等公开操作的无代次 `finally/endOperation` 可释放新手表的锁。r7/r8 只把新单位/闹钟事务纳入实际 Promise 跟踪，旧查找、刷新、历史、设置摘要及表盘尚未统一。
- 只读执行生产服务的延迟 SDK 夹具复现：A 查找未结束→显式断开→允许进入 B→B 保存单位持锁→A 回调结束使锁变空→心率测量被允许并发启动。输出依次为 `readyBeforeOldSettled=true`、`lockBefore=保存单位`、`lockAfter=''`、`secondMeasurementStarted=true`。
- 修改前已 fetch/prune，HEAD `06ec474`，保留同轮已知并行修改，不拉取覆盖。重读修改索引、复盘、回归清单及 r8 心电记录。
- 本批仅 `VepWearableService.ets`、生产服务执行测试及本记录；不改厂商 SDK、页面、账号关系或既有 ECG 规则，不操作手机。
- 预期：所有非测量设备命令使用同一串行跟踪；内部多步读写每个 await 校验会话；只有操作自身能释放锁；未终结的厂商 Promise 不因超时被当作排空；显式断开仍能完成并准确显示断开。

## 验证记录

- 修改前只读内存夹具明确复现，未写入真实账号/设备、未生成模拟健康记录。
- 定向、双时区全量与 Debug 编译结果待追加；r7 已通过的真实单位恢复及 r8 正常串行结果独立保留，不冒充本次跨代次回归。

## 修复与自动化结果

- 查找、刷新、历史同步、设备设置摘要、表盘读取/切换、时间同步、连接后初始化全部使用同一 `runDeviceCommand` 实际 Promise 跟踪；共有错误处理不再释放锁，无重复 `finally/endOperation`。
- 设置摘要在每一步读取后及可选读取失败后均校验会话，表盘列表读完后先校验才请求当前表盘；旧命令不得继续向下一台发后续请求。
- 全部 `beginOperation` 入口同时拒绝仍在执行的设备命令，即使意外的连接状态回调清掉界面占用名称，也不能开始测量抢占。
- 原测量代次、ECG 佩戴/255 门禁、健康 owner 与 32 字段完整配置事务不变；内部 helper 不重复申请公共锁。
- 显式断开不等待未终结的旧命令无限挂起，但必须在 5 秒内确认 SDK 已 DISCONNECTED/READY/UNINITIALIZED；未确认时显示错误并关闭后续连接入口，只有原生断开实际成功才恢复。下一次连接仍须排空旧命令 Promise。
- 首轮新增 26 个竞态反例后：生产服务 43/43，全量双时区各 370/370。
- 增加 8 个正常同会话成功正例后，双时区各 378 中 377 通过；`syncHistory` 测试夹具启用了 ECG 能力却没有实现 `getSavedId`，与死锁无关。补齐 SDK 空态回调，不改变生产能力或放松门禁。失败日志保留 `/tmp/saydian-harmony-r9-positive-fixture-failure-{utc,shanghai}.log`。
- 最终增加原生断开延迟/失败两例：直接执行生产服务 53/53，全量 UTC 380/380、Asia/Shanghai 380/380，失败/跳过均 0。日志 `/tmp/saydian-harmony-r9-command-targeted-final.log`、`/tmp/saydian-harmony-r9-utc.log`、`/tmp/saydian-harmony-r9-shanghai.log`。`git diff --check` 通过。

## 独立审计余项

- owner 数据库按 owner+record_id 主键及全部查询 owner 条件隔离，未归属旧表保留只读；同账号冷启动已入库记录不被新采集 cutoff 删除。上传响应后仍校验会话，标记使用 payload CAS，明确部分拒绝不标成功。
- Harmony 本地邀请只保存事件 ID/时间/已读状态，通知使用通用文案与 owner 路由边界；Flutter 持久通知模型丢弃用户资料和健康值。没有发现本批新增确定的跨 owner 数据读取。
- 变更及待加入的 107 个文件定向密钥/产物扫描：没有私钥、真实 Token、真实 registration ID 字面值或 `.hap/.apk/.ipa/.db/.log`、AX 调试脚本误入提交；唯一字面值命中为合成 `synthetic-refresh` 测试值。极光 AppKey/微信 AppID 属公开客户端标识，不冒称密钥。
- 已另告主线程：Android 现有 `JPushHelper` 仍直接打印 rId/完整 map（行号随并行修改变化），不受厂商 `setDebug(false)` 控制。本批不编辑 Android；该日志隐私问题需通知负责者处理，不能把本次静态扫描等同所有平台日志无风险。

## r9 冻结源构建与交付

- 正确同签名暂存工程 `/tmp/saydian_harmony_build_20260906_0952`，只同步源/资源，原本地 signing 未修改。
- Debug 编译通过（16.709 秒），Release 编译通过（14.406 秒）；两包均通过官方 `verify-app`，证书链与手机原 r2/r7/r8 逐字一致。
- Debug：`/tmp/saydian-harmony-session.5ERCEO/Debug-r9-command-drain-development-signed.hap`，SHA-256 `7721ba2ee9663d16256f494fa2894fee35deefd1397998a622a81fd0af8ce0c2`。
- Release：`/tmp/saydian-harmony-session.5ERCEO/Release-r9-command-drain-development-signed.hap`，SHA-256 `e56b95c0264ce978c12e5423665e98dd57cca4d620f3d1096b77bb9bb76a8989`。
- 构建/验签日志在 `/tmp/saydian-harmony-session.5ERCEO/`，文件名包含 `r9-command-drain` 或 `verify-*-r9`。仍为开发证书及 debug profile，不是正式商店发行签名。
- 源码已锁，`git diff --check` 通过。没有安装或操作手机，没有真实连接/查找/单位写入，没有提交或推送；实际跨代次复验交主线程，不能用本次自动化替代真机结论。
