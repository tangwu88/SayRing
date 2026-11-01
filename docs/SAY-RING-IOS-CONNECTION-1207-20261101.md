# iPhone 连接专项与缓存优先 1207

## 范围与基线

2026-11-01，用户要求停止其他测试，优先检查连接；原有缓存连接标识优先。当前分支 `codex/integrate-latest-20261031`，干净基线 `c477554407c3ff543b5b58dbefa3913ee7cc586d`。修改前重新 fetch/pull --ff-only，仍为最新；已读交接、回归及最近 1205 实施记录。

只处理连接链路。Android 构建、测量与睡眠专项暂停；不改服务端、公开开关、商店审核，不清戒指或云端数据。手机本地备份恢复按用户最新指令不作为前置。

## 原因与修改

设备搜索页已有 iOS 缓存入口及失败后扫描，但路由先等待系统设备列表，再准备保存的 UUID，未真正优先缓存。当前绑定和系统候选查询还缺少完整的异步上下文检查，账号切换/取消后的迟到结果可能回写候选。

`lib/services/wearable_routing.dart` 改为先准备精确当前绑定及同账号近期缓存；命中则直接返回，未命中才读取系统候选。仍由用户选择后完成真实 SDK 握手；不自动采用历史候选，解绑仍清除绑定，不能按名字或其他账号恢复。显式搜索其他设备保持可用。

查询结果在完成前保存在局部集合，校验查询代次、账号上下文、连接和扫描代次后一次发布。停止搜索、账号切换或新的连接使迟到结果失效。缓存失败保留正常查找路径。

## 验证记录

- `dart format lib/services/wearable_routing.dart test/wearable_exact_recovery_test.dart`：两文件已格式化；`git diff --check` 通过。
- 定向 `flutter test --no-pub test/wearable_exact_recovery_test.dart test/wearable_routing_test.dart --reporter compact`：62/62，含新增 6 项缓存优先、缓存缺失/异常、账号切换及取消后的迟到结果反例。
- `flutter analyze --no-pub`：零问题，3 秒。
- `TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact`：1728/1728，1 分 40 秒。均为宿主回归，无真实测量、睡眠或 AI 命令。
- `node --test tool/qring_recovery_state.test.mjs tool/qring_capability_handshake.test.mjs`：15/15，宿主合成协议测试，不替代实物验收。
- 同一生产 API、普通 `lib/main.dart`、1.0.8（1207）：签名 Profile 构建 46.7 秒，61.7 MB；串行 Debug 构建 42.3 秒。均深度验签，固定 `cn.saydian.ring`、W7SXQ4A226、iPhone-only，描述文件含当前手机。Profile 符号 UUID 匹配，Debug JIT kernel 存在；Android 按用户要求未构建。
- 第一次冻结 Debug 的私有检查在构建结束前执行，识别到旧 Profile 产物而明确拒绝（Wrong Flutter runtime mode）；没有冻结或安装错误包。等待 Debug 构建完成后重新检查通过。

## 实物现场与失败边界

目标为 iPhone 15 Pro Max / iOS 26.6、R21_C280，固件 RF22B_2.00.12_261028。完整 UUID、真实健康值、账号、截图、符号及调试端点仅在忽略目录 `.build/ios-ring-acceptance-20261101-hltgZw` 私有留存。

此前普通 1206 的连接专项实际完成过：同 UUID 重开自动恢复；用户解绑后重新搜索并握手成功；一次前台恢复同目标。不能把这些算作 1207 的自然远离三轮。此前心率首次原厂 -3 提示佩戴错误，调整佩戴并重绑后收到新的真实测量；该结果只属停止指令前，HRV、血氧及睡眠专项已暂停，没有继续触发。

1207 Profile 已原位安装，普通 main 启动 PID 1346，VM 与系统进程/安装路径匹配；没有卸载、恢复旧数据或替换登录。进入设备页仍为无绑定；缓存查询返回空，正常扫描未发现目标。用户确认再次充电唤醒后两轮扫描仍无候选，未把空列表宣称为连接修复通过。App 蓝牙权限实读已允许，控制中心显示蓝牙已连接；没有更改系统蓝牙或其他 App。

WDA UI 测试进程多次在读取元素位置时退出，普通 Say Ring 进程仍存在；仅重启了本任务 QA runner，未把自动化宿主故障记作 App 崩溃。LLDB 原生只读诊断的远程连接/本地转发均未完成 debugproxy 握手，未附加 App、未得到原生广播证据；停止本任务失败的诊断连接。随后切换同源码已验签的普通 Debug 调试，不并行运行 WDA 与 Flutter 调试。

1207 缓存恢复、真实断开重连三轮仍须以本版本同目标的新握手验收，不能沿用 1206 的结果。

## Debug 连接专用通道

普通已验签 Debug 1207 通过 `flutter run --debug --machine --no-pub --no-build --no-uninstall-first --device-connection=attached --use-application-binary=<冻结包>` 原位启动；未用 integration_test 或默认 flutter drive。当前明确的 iPhone 15 Pro Max、安装路径及 VM PID 1362 一致，app.started、DevTools 和热重载 code=0 可读，main 前台且无测量/同步操作。Debug 只在附加状态判断稳定，不作为独立桌面冷启动保证。

界面自动化不可靠后，私有 VM 助手只调用正常 AppController.scanDevices，不修改账号、候选、SDK 返回或绑定，不读取/触发测量、睡眠或恢复出厂命令。实际重新扫描仍为空，未把 VM 方法返回 started 当作发现或连接成功。已请求用户在系统设置重开蓝牙，后续结果待记录。

## 蓝牙重开与原生扫描证据

用户确认在系统设置重开蓝牙后，首个 VM 读取因后台暂停超时；使用 devicectl 正常激活同一 Say Ring 进程后恢复，PID 仍为 1362，调试宿主未收到 app.stop/Lost connection。没有将后台 VM 暂不可达当成业务崩溃，也未替换账号或修改绑定。

再次通过正常 controller 扫描仍无候选。使用 `pymobiledevice3 syslog live --udid=<本机已核验目标> --pid=1362 --regex=CoreBluetooth|centralManager|QRing|scanForPeripherals|didDiscoverPeripheral` 保存当前进程原生连接日志；真实 XPC 请求包含 QRing 服务和无过滤扫描，未发现原目标 UUID 回包。系统服务查询返回一个已有连接，其 UUID 和名称都不是原 R21_C280，未采用该设备。

这只能证明本轮 App/原生请求和观察到的结果；日志不保证包含所有空中广播，不能据此断言戒指硬件故障或其他手机占用。未静默采用另一设备、关闭其他 App、清空戒指、改权限或编造缓存绑定。需要目标实际可被发现后继续正常握手及缓存恢复验收；自然远离三轮、锁屏后台恢复仍待验，所有测量/睡眠专项保持暂停。

## 交付状态

本轮仅精确缓存候选优先与迟到结果隔离修正；普通 Debug 1207 已安装并保持实际附加。宿主回归/签名/安装通过，当前 R21 重新发现与本版本自动重连尚未通过。Android 构建、服务器开关、下载页及商店上传/审核均未操作。源代码与本记录一起提交当前分支，不提升 main 为已验收基线。
