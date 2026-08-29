# iOS 一次性移植验证记录（2026-08-13）

## 结论

iOS 原生桥接已覆盖 Flutter 当前公开的可穿戴能力，并通过 Flutter、Profile XCTest、开发签名构建、iPhone 安装和 ET488 真机读写回归。

ET488 真机连接状态为 `ready`，13 类健康指标和 12 项设备功能由 SDK 动态上报。本轮还接入了 W8 五型号的云创 SDK 自动路由；ET488 继续固定走 Veepoo，W8 只允许走云创。

## 已实现能力

- 健康数据同步、实时测量、自动测量开关、心率过高预警。
- 运动开始、停止、历史运动记录与同步进度。
- 查找手表、相机遥控、消息通知、联系人、闹钟。
- 双模蓝牙通话连接状态和系统配对入口。
- 天气、世界时钟、久坐提醒、辅助评估、屏幕亮度、亮屏时长、抬腕亮屏。
- 内置/已安装表盘读取切换、照片表盘裁剪和传输进度。

`integratedFeatures` 只返回已经接入原生调用的功能；具体功能仍按目标手表上报能力动态显示。

## 缺陷修复

- 修复添加关爱弹窗关闭后 `TextEditingController was used after being disposed`。
- 同步修复天气城市和联系人弹窗的同类控制器生命周期问题。
- 修正闹钟重复日 1–7 到协议 bit0–bit6 的日期错位。
- 通话页面移除 SDK 不提供写接口的“关闭媒体/自动连接”伪开关，改为真实状态和建立连接入口。
- 忽略 SDK 初次认证过程中的短暂断开事件，避免“已连接但状态机为 error”。
- SDK 自动重连并再次验证密码后，恢复 native 设备引用、Flutter `ready` 状态、能力集和后台同步。
- 设备功能页的首次读取延后到首帧结束，消除 `markNeedsBuild during build`。
- 运动记录异步回调增加销毁防护，避免退出后通知已销毁控制器。
- 所有 MethodChannel 设备操作增加 30 秒超时，健康和运动历史同步使用 3 分钟超时；原生 SDK 不回调时会释放队列，不再卡住后续功能。
- 设备同步状态与云端上传状态拆分；服务端批量接口未配置时，设备卡片仍保留“已同步”结果。
- 业务码 404/405 与 HTTP 404/405 统一映射为“批量健康同步接口未配置”，本地待上传记录继续保留。
- 云创与 HBand 共存时不再整库加载旧版杰理依赖；只保留两个位图兼容对象，并移除重复 ZipZap 链接。

## 自动验证

- `flutter analyze --no-pub`：0 issues。
- `flutter test --no-pub`：60 tests passed。
- `xcodebuild test -configuration Profile ... -only-testing:RunnerTests`：iPhone 真机 7 tests passed。
- `flutter build ios --debug --no-pub --no-codesign`：通过。
- `flutter build apk --debug --no-pub`：通过，无 Duplicate class。
- `flutter build apk --release --no-pub`：通过 R8 压缩，无 Duplicate class；云创未开放的可选升级模块仅使用精确 `-dontwarn`，未启用全局忽略。
- `flutter build ios --profile --no-pub`：开发签名 Profile 构建通过；真机安装、冷启动正常。

最终 Android Release APK 为 83.4 MB，SHA-256 为
`BEECBEA2360FC1157F20F2DC29CF2BF5494523A84E3EC9D9164A46F5A88517B3`；
APK v2 签名验证通过，仍使用 Android Debug 证书，仅供内部调试。

23:08 重新构建正常入口的 iOS Profile 包（48.4 MB），验签后覆盖安装并成功启动；
当前安装包不含临时 QA 探针。

签名包：

- Bundle ID：`cc.saidian.app.dev.v2a92w8qz2`
- Team ID：`V2A92W8QZ2`
- 类型：Apple Development / `get-task-allow=true`

## ET488 真机回归

- 扫描、连接、个人信息同步和能力读取通过；连接后 `ready`、无错误。
- 健康历史同步通过；心率实时测量启停通过；户外跑步开始/结束通过。
- 查找手表开启/停止通过；相机遥控进入回调较慢，但在 20 秒限制内成功，退出通过。
- 联系人空列表、闹钟 1 条、世界时钟空列表、天气配置、屏幕配置均读取成功。
- 表盘返回 5 个位置，当前为已安装市场表盘；照片表盘为 466×466 圆形，准备状态正常。
- 屏幕和天气按原值重写成功；通知完成“微信开启 → 恢复关闭 → 回读确认关闭”。
- 双模蓝牙开启指令已再次从真实 Flutter→MethodChannel→SDK 链路发出；多次回读均为 `enabled=true`、`paired=false`、`audioEnabled=false`。
- App 切到系统设置后，30 秒和 60 秒均保持同一 Runner PID；本次 17:02 后的会话没有生成新 Runner 崩溃报告。
- 17:00 前产生的最新报告位于 Flutter Debug 的 `VSyncClient`/调试运行栈；它们对应脱离 Flutter 工具直接启动 Debug 包或调试连接异常，不是本次 60 秒后台业务运行崩溃。
- 签名 Profile 包于 17:20 冷启动后进入后台约 83 秒，Runner PID 1537 持续存活；延长观察期间没有生成新的 Runner 崩溃报告，进一步排除业务包稳定性问题。
- Profile 冷启动及再次回到前台时，SDK 两次均输出 `BT status: 0`；这与应用回读的 `paired=false` 一致，确认通话蓝牙仍阻塞在 iOS 系统配对层，不是 Flutter 页面状态未刷新。
- 用户确认配对后于 18:02、18:03 再次真机冷启动、重连并发起通话连接；普通 BLE 已连接 ET488，但 SDK 仍输出 `BT status: 0`。项目 SDK 头文件定义 0 为“未连接”，App 回读仍为 `enabled=true`、`paired=false`、`audioEnabled=false`，需以 iOS 蓝牙列表显示的实际连接状态继续区分系统 HFP 未连接与厂商 SDK 状态异常。
- 20:47 使用独立 Profile 真机探针再次冷启动并调用官方 `veepooSDK_openDeviceBTSwitch()`。ET488 认证、电量 84% 和通话地址 `<MAC 已脱敏>` 读取正常，12 秒后最终状态仍为 `enabled=true`、`paired=false`、`audioEnabled=false`、`connectionStatus=disconnected`。
- 同期 iOS `bluetoothd` 显示 ET488 `classicPaired=1`、`lePaired=1`，但连接集合仅为 `BLE`，没有 `HFP`。这说明系统保存了经典蓝牙配对信息，但通话服务未实际建立；Flutter 状态与厂商 SDK、iOS 系统日志三方一致。
- 21:03 在 iOS 蓝牙列表点按 ET488 重新连接后，系统进一步上报 `classicPaired=0`、`lePaired=1`；仍未出现 HFP 路由。由此确认当前只保留低功耗蓝牙配对，系统列表的“已连接”不能等同于通话蓝牙已连接。
- 21:39 覆盖安装正式 Profile 包并冷启动，ET488 自动恢复为“已连接”，正式首页健康数据和设备能力页渲染正常；临时 HFP 探针已从源码和安装包移除。
- 22:59 在生产双 SDK 路由下再次自动回归：扫描返回 `veepoo:<原生ID>|ET488`，连接状态 `ready`，同步 250 条，云端状态“批量健康同步接口未配置”，`error=null`。临时探针随后删除，23:00 已恢复安装正常 Profile 包。

## W8 云创双 SDK 路由

- 云创插件固定到官方提交 `5ca3050d7170509d386f548fcae7d5f8b457febf`，未使用浮动分支。
- 精确识别 W8、W8S、W8 Pro、W8 Ultra、W8 Ultra-R；W80 与 W8 Pro Max 不匹配。
- 双 SDK 并行扫描，展示 ID 添加 `veepoo:` 或 `yucheng:` 前缀；连接后所有操作锁定同一 SDK。
- 云创连接后再次查询正式型号，不在白名单时立即断开并返回 `YUCHENG_MODEL_MISMATCH`。
- 健康、运动、能力和实时事件按官方字段映射；SDK 不支持或无读取接口时返回 `FEATURE_UNSUPPORTED`，不伪造值。
- 本轮没有 W8 真机，W8 的扫描、连接、健康同步和交互仍需目标设备到场后实测。

## 接口验证

- 健康百科列表、单页内容和商城首页接口均返回 HTTP 200 / 业务码 200。
- 未登录调用关爱列表返回 HTTP 200 / 业务码 401，符合当前服务端包装协议。
- 客户端现会把业务层 4xx/5xx 码写入 `ApiException.statusCode`，避免 HTTP 200 掩盖鉴权失败；对应回归测试已通过。

## 未执行的破坏性测试

- 未上传测试照片表盘，避免覆盖用户当前表盘。
- 未新增/删除联系人、闹钟和世界时钟；已验证读取链路和 native 单元映射，没有向手表留下测试数据。

## 外部阻塞

- 已从交付的小程序源码找到授权和风天气 Key，城市、24 小时和 7 日接口均验证成功；Key 只通过 `--dart-define` 注入本地 Profile 包，没有写入仓库。
- ET488 普通 BLE 工作正常，但 HFP 服务仍未连接；重新点按后 iOS 当前仅保留 `lePaired=1`。应用侧开启指令和真实状态回读均已验证，需排除手表经典蓝牙被其他手机占用或固件未开放 HFP，并由厂商确认 ET488 当前固件的双模蓝牙行为。
- 云创插件的 iOS 二进制不支持模拟器完整编译，因此原生 XCTest 改用 iPhone Profile 配置；Flutter 纯 Dart 测试仍在本机完整执行。
- 真机冷启动还有 CoreBluetooth `willRestoreState` 未配置 restore identifier 的运行时告警；仓库业务源码没有实现该回调，相关符号仅存在于多个厂商二进制 SDK，当前连接和自动重连实测正常，不对闭源二进制做破坏性修改。
- `app.saidian.cc` 先前的 DNS 失败本轮未复现；iPhone 日志显示网络路径满足并解析到服务地址。正式业务接口仍需使用有效账号和服务端数据做验收。
- `sqflite_sqlcipher` 与 `yc_product_plugin` 尚不支持 Flutter iOS Swift Package Manager；当前 CocoaPods 构建正常。
