# CoolWear 监测队列与 iOS 设备功能 1048–1051

## 结构与范围

- 基线 707f57e，修改前远端获取成功、工作树干净。仅 Say Ring iOS，包名、账号、绑定和审核不变；本轮严禁卸载，先备份当前容器。
- P1：健康监测切换后保存超时，单独刷新却能读到新值；预期保存必须获得明确、严格的回读确认。旧测试刷新前未断言保存状态，不能当成稳定通过。
- 原 SDK 只读检查：CESendObj finishCmdWithError 调用 sendCallback 后才置空当前命令 callback / curSendCmd，并 sendNext。同步 callback 内 enqueue 新命令会被随后的清理影响；这是从提供的二进制顺序与失败现象推断的原因，仍需实物验证。
- 将监测读写的 SDK completion 无条件 dispatch_async 到下一轮主线程，保留操作/连接代次与四字节完整回读屏障。Foundation 合成队列复现同步重入丢回调，并检查延后不会丢；不是实物验收。
- 查找设备继续核实原厂协议与实际能力，不按型号名强开，也不把 ACK 当成实际振动。健康监测/查找与睡眠为独立问题，不伪造丢失的睡眠分段。

## 执行记录

- 第一次 objdump 配合 sed 在 SDK 字符串处遇到 illegal byte sequence；设置 LC_ALL=C 后成功按方法筛选。素材未改，日志私有，不提交设备标识、健康值或会话。
- 后续测试、构建、安装和真实结果逐项追加。旧默认 drive 卸载造成的本机明细损失仍未确认恢复；本轮备份不是旧数据恢复证据。

## iOS 功能补齐（用户后续追加）

- 对照 Android CoolWearRingBridge：相机由 isHasGestureSupported 开启、sendPhotoSwitch 控制；Android 查找只有单次 sendFindDevice，没有停止 transport。共享页面改为单次动作六秒后可再次发送，iOS 保留真实开始/停止。
- 提供的 20260910 SDK 原文件只读；指南「拍照」「来电提醒设置」、CE_SendPhotoCmd、CE_GestureCmd、YD_SyncCallAlarmCmd、FuncType 和示例 DataReceiver 逐项核对。二进制确认原解析字段 gestureSupport、takePhoto 与 type 122 onoff；不把 Android 属性名直接套在 iOS。
- CoolWear iOS 的 camera / gesture_control 仅在实际握手 gestureSupport=1 时展示。相机调用 CE_SendPhotoCmd 0/1，实际 type 116 takePhoto=1 才转发 cameraShutter；限定已确认开启、当前连接及前台，复用原相机权限、快门防重及本机保存链路。没有上传照片或新增云接口。
- 手势对应 SDK 明确枚举 0关闭、1短视频、2音乐、3阅读、4拍照、5电话。CE_GestureCmd 指令必须 ACK，页面只显示本次连接确认过的指令；SDK 未提供可靠读取当前模式的方法，因此重连后不假设旧状态。系统控制效果、固件支持与配对实际待验，不承诺能控制任何第三方 App。
- 来电提醒只有真实 type 122 设置才出现入口。读取/写入均使用 RequestAllInfo 新回读；保存需要查询 ACK、新 onoff 回包及期望值一致。蓝牙通知授权取当前 CBPeripheral.ancsAuthorized，区别于 App 的推送权限；未授权提供 iPhone 蓝牙共享系统通知的指引，不伪报提醒有效。
- 所有新增控制串行排队并限制 28 秒，查找 22 秒；不与测量、同步、监测抢命令。断连/换环清空相机、手势、来电状态；操作与连接代次拒绝迟到回调。共享控制器和页面同时丢弃旧设备/旧账号读写结果与提示，避免换环页面沿用旧勾选。
- 查找缺少独立可选能力位：精确握手后仅发原厂停止查找 0 探测，应答后才展示。探测超时只取消可选命令，不造成无限重连；用户动作超时执行安全取消后继续账号恢复。ACK 只证明协议，文案为「指令已发送」，不声称戒指已经振动。
- 该轮新增 camera/gesture/call native transport 限 CoolWear iOS；QRing 仍仅展示其已接通且已确认的现有功能，没有按其他 SDK 或型号强开入口。Android 新枚举不会绕过其原能力门禁。

## 失败与校正（保留）

- 首轮新增双平台查找 UI 测试改了 debugDefaultTargetPlatformOverride，但 addTearDown 晚于 Flutter invariant 检查，导致两项失败；改为测试体 try/finally 复原，动作断言本身通过。
- 1049 全量测试因同一 fixture 问题失败；修复后不沿用该结果，重跑完整测试。
- 新分支 dispatch 格式改变使原单行 triggerDeviceAction regex 失败，改为限定正确 else 分支的跨行检查；没有删掉开始/停止、代次、超时断言。
- 共享页面 context 字符串变量遮蔽 BuildContext，Analyzer 报 argument_type_not_assignable，UI suite 编译失败；改名 contextKey 后重跑分析与测试。
- 两次 apply_patch 上下文/顺序匹配失败；工具未应用整份补丁，核对状态后按现有格式正确重试。
- 1050 Debug 编译通过后，为加入新设备/账号迟到响应门禁，主动取消等待中的 Profile（exit 130，无设备操作），最终编号递增为 1051。1050 两轮全量期间测试文件有新增，数量不同，均不作为最终同源门禁；最终冻结源码重新跑双时区全量。
- 1048 真机测试候选包构建成功，但 wrapper 仅等待手机连接。iPhone15pm 从本机离线、CoreDevice unavailable；安全取消等待，无安装/测试开始、更无卸载。1049 正常 main 的 Debug/Profile 串行构建及签名校验通过，也未安装。
- 查询 QRing 路径 sdk/qring_bridge/ios 与旧记录错误文件名失败；rg --files 后定位 ios/Runner/QRingWearableBridge.m 和正确文档。本轮未改 QRing SDK。

## 当前验收边界

- 实物当前 unavailable；没有把新增 UI/桥接/合成队列测试当作 HR01 物理拍照、手势、来电或振动通过。监测四字节保存修复也仍缺本轮实物回读验证。
- 没有 HR01 闭合夜睡/小睡样本，空状态仍正常保留。旧本机-only 睡眠明细没有恢复证据。
- 不卸载、不清空数据、不换包名，不进入 App Store Connect、不更换/撤回审核构建。最终验证包仅生产 main + 生产 API 的开发签名 Profile，不是上架 IPA。

## 最终同源检查与产物

- `dart format` 所有变更 Dart / `git diff --check` 通过；`flutter analyze --no-pub` 零问题。UI/通道定向完整两文件 97 项通过；新增迟到读写/action 测试不允许覆盖新设备缓存或清理其 busy 状态。
- 冻结生产源后，`TZ=UTC flutter test --no-pub` 1174 项/81 秒、`TZ=Asia/Shanghai flutter test --no-pub` 1174 项/85 秒，均通过。测试中预期的 unavailable/授权失败日志不作为线上接口故障。
- Foundation：`clang -fobjc-arc -fblocks -framework Foundation test/native_coolwear_policy_test.m` 与 `test/native/qring_record_mapping_test.m` 均执行通过；覆盖重入队列、监测四字节、模式枚举非法值、相机三条件组合、缺少/关闭快门回包及未知来电值。均为合成输入，不是真实动作。
- `node --test tool/client_package_contract.test.mjs tool/measure_ios_bundle.test.mjs tool/test_coolwear_ios_integration.mjs tool/test_native_log_privacy.mjs tool/drive_ios_preserving_data.test.mjs` 34 项通过。`python3 -m unittest discover -s scripts/release -p 'test_*.py'` 31 项通过；原厂 framework SHA 合同未变。
- 1051 生产入口构建参数固定：`--no-pub --target=lib/main.dart --build-name=1.0.0 --build-number=1051 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=`。iOS `flutter build ios --debug --no-codesign` 30.4 秒，再串行 `flutter build ios --profile` 109.9 秒/60.0 MB，通过。
- 独立签名产物 `.build/1051-profile/Payload/Runner.app` 及 `.build/1051-profile/Runner.app.dSYM` 保留。`codesign --verify --deep --strict` 通过，ID cn.saydian.ring / build1051 / team W7SXQ4A226 / UIDeviceFamily仅1；开发描述文件允许目标 iPhone、get-task-allow=true。二进制与符号 arm64 UUID 同为 ACBA2FD7-9661-3B79-B9C8-E8201173932B；Runner SHA256 ca4ca0ed14abb482bbde91a28b7943a12496e8899556fe0aa81507b5d835d104。
- Android Debug 29.9 秒、内部 QA Release 62.9 秒/69.4 MB，通过。产物 `.build/SayRing-1.0.0-1051-debug.apk` / `...-qa-release.apk` 均 cn.saydian.ring /1051/1.0.0，apksigner verify 与 zipalign `-c -P 16 4` 通过；QA 签名不得用于正式应用市场。本轮未安装安卓。
- 原生 Android `./gradlew :app:testDebugUnitTest --max-workers=1` 40 tests、0 failures/errors/skips；最终共享源/QA Release 后再次执行 7 秒通过，XML 汇总仍 40/0/0/0。最终 Analyzer 再查 4.4 秒零问题。构建保留现有 SwiftPM、WechatOpenSDK 模拟器 arm64 与 Kotlin 插件迁移警告，实机 Debug/Profile 编译不受阻；未声称模拟器可用。
- APK SHA256：Debug b705029a1f39f79e72e73efb3c2e9052c581c5582ddf989438f22ad272ae0ad3；QA Release 68bb5b675dbd0b11fb1f4833580bbb97fcf9ba6600e4f5f939cf2a4d6f3c780c。
- 构建前后 `df -h` 检查可用空间约 0.5–1 GiB，未删源码、SDK、签名、归档、APK 或设备健康数据。签名配置/描述文件、测试日志、旧容器备份均留在忽略私有目录，不进 Git。
- 最终 CoreDevice 再查仍 iPhone15pm unavailable，1051 未安装、未启动真机测试。没有进行其他手机安装或 App Store 操作。仅推送工作分支，不将待验版本提升为 main 验收基线。
