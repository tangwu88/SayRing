# HR05 / iPhone 15 Pro Max 断连恢复排查（1263 候选）

实施日期：2026-11-07（Asia/Shanghai）。

## 结论与边界

用户报告 HR05 与 iPhone 15 Pro Max 一直在一起却反复断连、寻找戒指。本轮用户明确选择「暂时无法连接，先查代码」。已修复三处可复现的 iOS 原生恢复缺口，但尚未取得这台手机本次自然断连的日志，不能将代码缺口直接认定为该次无线断连的唯一原因，也不能宣称持续连接实物验收通过。

本轮不安装/卸载手机 App，不解绑、不忽略设备、不清空健康数据、不重置或改写戒指提醒/监测设置。不操作 TestFlight、App Store 或下载页；此前 1261 的审核和手动发布设置不变。

## 基线与 SDK 依据

- 修改前工作树干净；`git fetch --prune origin` 后，当前分支与远端同为 `d07936cc0a3c04b94392246d124e349beb39dcc1`，`git merge --ff-only origin/codex/ios-six-fixes-1259-20261106` 返回 Already up to date。另开 `codex/hr05-ios-recovery-1263-20261107`。
- 基于 1261 的六项 iOS 修复代码；远端另有 `codex/ring-sync-control-recovery-1262-20261106` 的 Android/共享控制更新，其 iOS 原生桥接没有本次变更。没有以切换/覆盖分支方式丢弃现有 iOS 修复，也不将本轮安卓编译称为该独立分支的交付。
- 实际随包原厂 `BluetoothLibrary` SHA-256：`f56c39605abded5f57b7ab28f245d67218b9df9e8edbb7fe037755b8cd3ca624`。按公开头文件及本机该二进制的方法实现核对，未替换、改写框架。
- `CEProduct lastConnectUUId`：属性为 nil 时，按 SDK 类名从 `NSUserDefaults` 惰性加载；setter 仅改内存。`peripheralDidDisConnected:connect:` / `peripheralConnectionError:peripheral:` 在无缓存 UUID 时发布 `ProductStatus_none`，有缓存时另起原厂自动连接。
- 不能用空串假装禁用：SDK `startAutoConnect` 仅判断指针非 nil，后续 `reconnectWithUUid:` 未在构造 UUID 数组前检查解析结果。保留完整私有核对材料，不把反汇编全文或手机身份/健康记录提交公开 Git。

## 已修复

| 缺口 | 原行为 | 新行为 |
| --- | --- | --- |
| 原厂旧缓存重载 | 仅赋 nil，原厂可能重读安装级旧目标，与账号恢复并行 | 仅移除 SDK 类名这一项旧恢复缓存，再清内存；不读取/收养旧目标，不动 App 账号绑定与健康库 |
| 真实断连返回 none | 只处理 powerOff/disconnected，旧 target 留在内存，后续恢复一直让行 | none 同时满足真实目标已 Disconnected 时，复用原有取消流程；none 单独出现不能取消仍连接/正在连接的外设 |
| 状态迟到/丢失 | 旧 target 或结束短轮询的 cancelling 永久挡住续试 | 续试再次核对真实关闭状态；未完成握手仍让行，SDK 或目标任一仍存活时保留原取消屏障，不以时间到强行放行 |

没有新写入/校准/恢复出厂/提醒振动指令，也没有缩短握手超时后强行重连。有效的 owner/context/精确 UUID 校验、真实能力握手和现有历史完整性判定继续使用。

## 可重复验证

新增 `tool/coolwear_ios_recovery_session.test.mjs` 从生产 `.m` 提取恢复、状态处理、失败及取消完成方法，编译 Foundation 宿主夹具。仅替换 CoreBluetooth、Flutter 和 SDK I/O；原厂惰性 getter 的夹具语义来自上述实际二进制。本机宿主测试不等于在手机执行原厂二进制或无线验收。

- 同一套 12 项用例对旧基线执行：7 通过、5 失败；失败包括缓存复活、none 断连残留、状态遗漏、取消屏障路径未进入及关闭迟到后不再检查。原失败日志保留。
- 修复后 12 项均通过，Debug / 非 Debug 各执行一次；验证仍连接/正在连接、未完成握手、旧代次、撤销目标和仍存活 SDK 外设不能被误打断/放行。
- 初次关联专项暴露两项测试设施问题：旧隐私断言禁止一切 UserDefaults API；改为只允许这一条精确 SDK 缓存删除，禁止其他读取/写入。既有 QRing 恢复夹具漏提取当前生产 `resetSportReception`；补齐真实方法与夹具属性，没有关闭检查或修改 QRing 生产代码。初次失败不抹去。
- 关联原生专项修正后：79 / 79，通过；包含 SDK 原件哈希、HRV 会话、恢复、配对能力与拍照状态。
- 额外核对只读同步、提醒设置、iOS 指标投影及原生日志隐私：`node --test tool/coolwear_reminders.test.mjs tool/coolwear_sync_reception.test.mjs tool/test_ios_activity_sleep_policy.mjs tool/test_native_log_privacy.mjs`，14 / 14，通过。
- `flutter analyze --no-pub`：通过。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter=compact`：2060 / 2060。
- `TZ=UTC flutter test --no-pub --reporter=compact`：2060 / 2060。
- `xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation test/native_coolwear_policy_test.m` 后执行：通过。
- iOS 1.0.11（1263）Debug / Profile 正常 `lib/main.dart`：同源码编译、开发签名、包名及团队验证通过。Profile 没有 Debug HRV 诊断标识；构建配置已还原。当前工具链本地沿用已记录的 iOS 15 编译覆盖，不冒充默认 iOS 13 兼容验收。
- iOS 构建时四次可选递归扩展属性清理超过 5 秒，原流程将这些可选子进程终止后继续；保留原属性，没有删除数据或源码。最终两种构建均成功。
- Android 1.0.11（1263）Debug / Release 正常入口编译通过；Release 原发行签名、Debug 预期调试签名、`cn.saydian.ring` 和双 ARM ABI 校验通过。原生单元测试 108 / 108、21 个套件无失败/跳过；临时签名配置已移除。仅为本轮跨端回归，没有安装、发布或更新安卓下载。

详细命令、首次失败和原始构建证明私有保存在 `build/hr05-ios-reconnect-20261107-5cdya4cp/`，不入公开仓库。iOS 两种构建的运行源码指纹均为 `69a2366729e18d48f99933b6d99b7b5ac3cf232446711f3b47d266fdbe45b4b6`。

Git 交付：本机普通 HTTPS push 因没有命令行认证返回 `could not read Username`，没有写入任何远端提交；随后改用已连接 GitHub 工具的 blob/tree/commit 与 expected-SHA 分支更新，并在本地 fetch 后核对提交树。仅更新本轮修复分支；本机全量通过不当作远端 CI 或手机实测通过。

## 必须继续的实物验收

待用户连接原 iPhone 15 Pro Max / HR05 后，先备份并核对同账号原记录，再原签名覆盖安装测试；不得用当前 XR/R8 或另一枚 R7 Ultra 的结果替代。

分别核对前台静置、锁屏/后台、主动断连恢复、蓝牙开关恢复及真实距离恢复，记录每次首个断连原因、App 是否主动清理、恢复耗时、能力就绪、自动活动/睡眠同步与原记录/戒指设置保留。现在没有本次现场日志，初始掉线原因与真实稳定性均保持待验证。
