# R7 Pro迟到功能信息后的自动补读1306

2026-11-14，北京时间。用户在空记录排查后明确要求修复。只处理已可执行复现的安卓 CoolWear 功能信息迟到恢复，不把两位客户未知的本机状态认定为相同原因。

## 基线与范围

- 独立 `tangwu88/SayRing`，`codex/u19s-android-connect-20261111`，开始时工作树干净，联网 fetch 后本地/同名 origin 均为 `d0072691305319ee4f57a142f94b95a090cdfee1`。已阅读 AGENTS、handoff、最新排查/构建记录、回归清单和复盘。
- 修改 `lib/services/app_controller.dart`，新增 `test/coolwear_late_capability_sync_test.dart`，本记录及索引随源码提交。没有改厂商 SDK、清理指令、首绑决定、服务器或客户数据，没有新增自动诊断上报。

## 修复行为

- 原生首次读取明确返回 `_capabilities=not_received` 时，保存当前账号会话、精确设备、同步代次和当时的历史指标目录；不把普通失败、空历史或未知功能当作恢复依据。
- 随后的真实功能事件扩充了历史指标目录，且同一账号/设备/代次仍有效时，自动补读一次。重复功能回包不会重复派发；第二次失败保持失败，手动同步仍可用，没有轮询、重连或重置循环。
- 等待首次健康/运动读回与本机保存都完成，前台空闲且初始化已通过后才开始；测量、运动、设置读写、功能操作和设备详情读取进行中均延后。相应操作结束或回到前台时恢复待办；手动新读取会取代旧待办。
- 断连、退出账号、目标更换及原代次失效时废弃待办，不向其他目标读取，不将“已连接”视为初始化完成。缺失原清理 ACK 的状态仍保留保护，不重复清空、不导入归属不明的历史。
- 真实读回继续使用既有过滤、本机保存、首页缓存刷新和云端逐条确认；不伪造测量值或成功状态。iOS、QRing及U19不启用此安卓 CoolWear 自动恢复分支。

## 红测、纠错和验证

- 原源码执行新增首轮12用例：7项通过、5项失败，分别复现迟到目录不补读、首次两阶段结束后不补读、前台恢复不补读、运动结束不补读及恢复读不发生。不是编译失败冒充红测。
- 初次修复后12项通过。扩充云上传/ACK、初始化保护、测量互斥、目标切换等用例，首轮90项中89通过、1失败：夹具直接从已连接态连接另一目标，违反现有先断开再选设备的状态机。补夹具的正常断开步骤，未改产品状态机或弱化目标隔离断言。随后90项通过。
- 再补设备详情异步读取互斥，并增加在详情完成后释放待办的生产钩子。一次补丁因格式化后上下文不匹配未应用，核对实际文件后重试成功，无半完成改动。最终定向17项，连同 `first_ring_initialization_regression_test.dart`、`device_connection_reporting_test.dart`、`cloud_upload_queue_regression_test.dart` 合计91项通过。
- 定向命令：`TZ=Asia/Shanghai flutter test --no-pub --concurrency=1 --reporter=expanded test/coolwear_late_capability_sync_test.dart test/first_ring_initialization_regression_test.dart test/device_connection_reporting_test.dart test/cloud_upload_queue_regression_test.dart`。
- 格式、静态、双时区全量、Android Debug/Release及正式包校验按实际完成结果追加；日志/脚本和制品位于 Git 外 `E:\SayRing-r7pro-capability-fix-1306-20261114`。沿用1305原生依赖报告用于ABI门禁：原生/SDK未改变，134项原生结果来自本日已通过的1305，不冒称本轮重新执行。

### 完整回归

- `dart format --output=none --set-exit-if-changed lib test`：通过。`flutter analyze --no-pub`：零问题。
- `TZ=UTC`、`TZ=Asia/Shanghai` 分别运行 `flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`：各2,397项全部通过。
- Android正常主程序Debug构建通过。正式Release及包校验继续执行，最终结果单独追加；未把Debug成功作为Release验签通过。

### 最终构建与交付

- 全部构建阶段成功，正常 `lib/main.dart` Release为 `cn.saydian.ring`、`1.0.14 (1306)`、非debuggable。`apksigner verify --verbose --print-certs`、`aapt dump badging`、`zipalign -c -P 16 4`、生产清单/极光配置、双ARM ABI及QRing SDK副本校验通过。临时签名配置已清理。
- 原发行证书SHA-256：`81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。APK为 `E:\SayRing-r7pro-capability-fix-1306-20261114\SayRing-1.0.14-1306-release.apk`，74,454,129字节，SHA-256 `72B175BF99E61379169ED4A676103932804A6C66DB7D2B095680931C61A25C71`。额外比较1305与1306的arm64 libapp.so摘要，确认重建后的Dart运行代码不同，没有复用旧1305运行二进制。
- 沿用的43个ELF中2个既有32位供应商库仍低于16KB LOAD对齐；本轮未改供应商二进制，ZIP对齐及正式签名不等于所有市场已批准。`git diff --check`通过。

## 验收边界

本机没有客户手机，未取得对应实物回包；测试只证明上述代码恢复路径、保存和上传替身结果。客户仍需升级后验收，初始化、佩戴/监测设置、无线链路等其他原因不能由本轮宣布解决。Windows没有Xcode，iOS Debug/Profile未执行。正常Main原证书1306包已生成，未更新线上下载配置、服务器或应用市场，未安装手机。

## 用户随后要求安装到当前手机

- 2026-11-14 14:38（北京时间），检测到一台已授权USB调试的华为安卓手机，安装前为1.0.12（1283）。重新核对1306 APK的SHA-256与上述正式制品一致后，执行指定设备的 `adb install -r <1306正式APK>`，返回Success。
- 安装后系统读回 `cn.saydian.ring`、versionName=1.0.14、versionCode=1306，最后更新时间14:38:18；firstInstallTime仍为当天09:44:17，确认是保留数据的覆盖安装。当前前台为Say Ring正常MainActivity。
- 没有执行卸载、清除App数据、解绑、重置、测量或修改手机设置。本次仅安装核对，不能据此宣称R7 Pro客户的同步问题已完成真机验收。线上下载配置仍未修改。
