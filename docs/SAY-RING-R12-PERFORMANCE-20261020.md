# iOS R12 靠近重连与同步响应优化

## 基线与问题

用户反馈 App Store 下载版连接 R12，戒指离开后再次靠近，连接和同步均慢。2026-10-20 修改前分支 `codex/native-mall-android-1121-20261020`、HEAD `845e3bc556846f1b501d453fea930a251cf33e15`，工作树干净；fetch、ff-only 无新提交。另建 `codex/r12-reconnect-performance-20261020`，不提升仍有硬件待验的 main。

P2 体验问题的源码复现：QRing 真正断开后，桥接固定等待 2 秒才重新向 CoreBluetooth 提交已验证精确目标；连接内每次电量轮询还重复读取固件；健康同步虽先读当天活动，但这些活动记录直到七天所有允许指标结束后才整体返回。用户看到活动更新会被剩余历史读取拖延。

预期：真实断开后尽快安排一个精确目标恢复；同一连接只复用成功读取的固件，电量照常刷新；当天真实活动先显示，完整七天历史仍保留。上述源码行为不是本次用户现场时延的唯一根因，不能用超时上限推算实测耗时。

## 修改计划与边界

涉及 `ios/Runner/QRingWearableBridge.m`、实际 Objective-C 方法夹具与 Flutter 事件回归。保留新连接的真实 SDK 能力握手、资料写入、电量读取、相机 ACK 探测和串行命令。正常断线移除固定 2 秒等待后仍异步回到主队列，旧代次不得重新武装；握手/连接失败仍保留 2 秒冷却，Dart 恢复、回前台和蓝牙回调均不能绕过，避免失败时快速循环。固件只在本次连接成功读取后复用；断连清空、失败可重试。当天活动最多提前发出步数、距离、热量各一条原始累计记录，使用现有 `healthRecord` 通道，最终全量保留原全部记录与完成/失败状态，不提前宣称同步成功。

不改厂商 SDK、广播/连接参数、超时协议、账号/环境绑定、健康算法、服务器、商城或线上发布配置。App Store 旧二进制不会因本机源码变更自动生效。

## 检查记录

- 修改前 `xcrun devicectl list devices`：iPhone 15 Pro Max unavailable；已询问可否重新连接，不进行卸载或用旧真机结果代替性能验收。
- 首轮 rg 使用不存在的 `lib/controllers/app_controller*`，被 zsh glob 拒绝；定位到实际 `lib/services/app_controller.dart` 后继续。读取只读服务时两次猜错单复数文件名，随后用 rg 确认 `lib/services/read_only_health_service.dart`；未修改文件。
- 开始时尚未执行新修改验证；格式、分析、定向/全量回归、双端构建、硬件结果按实际完成追加。

## 第一轮回归（北京时间 10 月 20 日至 21 日跨日）

- 新增 3 项原生接线/实际方法回归先在原源码失败：固定等待尚在、当天活动无提前通知、缺少提前发布方法。原有 4 项通过，不把新增红测当作现场故障。
- 第一条 Node 命令因 shell 没有 `node` 报 127；使用本机已有 `/Users/saydian/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node` 后执行有效红/绿测，没有另装运行时。为查运行时而调用 Node REPL 的 `process` 不存在，`node:process` 导入被工具拒绝；停止该方式，改为普通文件路径查询。
- 实际 `readDeviceDetailsWithCompletion:`、当天活动发布、恢复安排三个生产方法注入 Foundation 合成 SDK 夹具，最终 33 项断言通过；覆盖电量更新、连接内固件复用、新连接重读、失败重试、迟到/超时/旧代次隔离、正常立即安排/失败冷却、精确三条活动原记录与全历史不变。去掉固件缓存条件的负向变体实际执行失败；原取消路径 48 项断言与缺协调负向变体仍通过。7 项 Node 原生回归全部通过。这些不是无线设备耗时证据。
- 新增 Flutter 活动提前展示/保存、全量去重、超时保留且不报成功、其他设备/断连迟到拒绝场景。首轮夹具误用 `HealthRecord.copyWith(id:)` 不存在参数，编译失败；改为用原构造器生成合成旧记录，不改生产 API。定向 5 文件共 33 项全部通过。
- `dart format test/app_controller_exact_recovery_test.dart` 后再次 `--output=none --set-exit-if-changed` 零变化；`git diff --check` 通过；`flutter analyze --no-pub` 零问题（4.5 秒）。
- UTC `flutter test --no-pub --concurrency=1 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 全量 1350 项通过（82.9 秒）。上海全量及后续检查结果另续，不用 UTC 替代双时区。

本轮关键限制：未缩短 CoreBluetooth 或厂商协议超时，未减少七天读取。立即恢复可避免原生路径的固定等待，但前台 Dart 原本也能先行安排恢复，因此不声称用户现场必然快 2 秒。活动先展示提升首次可见速度，完整历史完成速度尚需 R12 实测。

## 完整主机回归

- 上海相同全量命令：1350/1350（82.1 秒），与 UTC 两套均退出 0；最终 Dart 生产源码未修改，新增三项控制器事件回归均包含在全量中。
- `node --test tool/*test*.mjs` 对实际匹配的 12 个测试文件运行：128 项中 127 通过，Windows ACL 1 项按平台跳过，失败 0（1.6 秒）。包含最新正常恢复/失败冷却的实际方法夹具、既有 iOS 只读/手动原生策略 136 断言、相机/手势串行、保数据测试驱动和包边界。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py'`：35/35（6.1 秒）。日志中的其他产品域名、签名/发布成功文案来自合成发布夹具，不是本轮生产调用。
- Harmony 主机契约 UTC、上海各 503/503（1.5/1.3 秒），未编译或安装 Harmony 包。QRing Foundation 相机、取消、手势、名称、记录映射五个实际测试均用 `xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation` 编译运行退出 0；数据算法没有改变。
- 2026-10-21 构建前复核无其他 Flutter/Xcode/Gradle 编译，随后按同一脚本串行执行 Android Debug/QA Release/原生任务和 iOS Debug/Profile。候选构建参数为 1.0.5（1122），原工程/Pods iOS13 配置不改；本机 iOS 用命令行 `IPHONEOS_DEPLOYMENT_TARGET=15.0`、关闭签名构建。实际回执待构建结束追加。

私有/忽略证据目录为 `build/r12-performance-20261020/`，保留每次红测、夹具错误与最终结果；`run_checks.py`、`run_builds.py` 保存精确命令和环境差异，JSON 保存退出码/耗时，日志不进 Git。没有调用生产 OTP、支付或健康上传来做性能测试。

## 双端构建与 Android 检查续结

- Android 双 ARM Debug 25.2 秒、显式 QA Release 66.9 秒退出 0；均为候选 1.0.5（1122），不是新正式发布包，不替换既有正式 1121。
- 首轮 `./gradlew :app:testDebugUnitTest` 在 `compileDebugKotlin` 后等待依赖。针对本任务 Gradle daemon 的只读线程诊断实际落在 HTTPS artifact download；独立核对 wrapper PID/参数属于本目录后，仅向本次客户端发送 SIGINT，136 秒退出 130，中断不算通过，未停止其他项目或清缓存。
- 使用与前两包一致的 `./gradlew :app:testDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline` 复跑，18.2 秒退出 0。实际 XML 12 个 suite、53 项、失败/错误/跳过均 0；`testDebugUnitTest` 任务真实执行，301 项中 8 执行、293 up-to-date。没有改变依赖版本、签名门禁或源码。
- 本轮涉及的五份生产蓝牙文件与 App Store1120 运行基线 `c82b027d176018cbd5ea6daabfdfdae9ac053dbe` 在修改前完全一致（`git diff c82b027 HEAD -- <五文件>` 空差异），本次针对的是旧版已有连接/同步路径，而非只在1121才出现的新代码。
- iOS 配置阶段保留既有 Swift Package Manager/模拟器 arm64 提示；本轮目标为通用物理 iOS 设备，实际编译与产物结果另续。没有为通过构建修改工程最低版本或厂商 framework。

### iOS 与候选产物完成

- iOS Debug 配置 7.1 秒、编译 26.9 秒；Profile 配置 6.3 秒、编译 40.8 秒，均退出 0、实际日志 `BUILD SUCCEEDED`。使用本机 Xcode 通用 iOS SDK、同一 DerivedData 串行完成，签名关闭，不是可安装的开发签名或商店归档。
- 两份实际 Info.plist 均独立核对为 `cn.saydian.ring` / 1.0.5（1122）/最低 iOS15。Android 两份实际 APK 为相同包名/版本，双 ARM、min26/target36；QA Release 不可调试、验签通过，但证书确为本机 Debug 身份 `7ed73f5a951a031f80fbc20c94b242000edea9e5b420aefb88c589508bedab46`，不得当作原正式签名或线上升级包。
- 原正式 1121 APK 仍为 71,832,499 bytes、SHA256 `61834ff3058d056ead83e1f55358d25e11d3c56ee86dac7f4e259c8fe85f4fe3`；冻结正式产物保留，没有更新 `/down2`、TestFlight、App Store 或后台开关。
- 构建后 CoreDevice 复查同一 iPhone15pm 仍 unavailable，未收到 USB 已连接的确认；本轮没有安装、卸载、解绑、清库或运行物理测试。还需用新签名 Profile 保数据覆盖，在 R12 上分别测量无线恢复、握手完成、第一条活动、完整历史，并覆盖前台/后台及失败恢复。未宣称实际延迟降低多少秒或完整同步已经更快。

实现与本机回归完成，可提交验证分支；真实无线验收、新版本签名和商店发布分开处理，不提升 main。原用户数据、七天历史、睡眠数据、测量和手势逻辑均保持原协议与能力门禁。
