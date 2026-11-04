# 15 Pro Max / R8 手势说明对照及 1239 验证（2026-11-04）

## 基线和问题

当前分支 codex/integrate-latest-20261031，修改前与 origin 同为 9e9d520，工作树干净；已 fetch。此前 1238 的实际短视频失败记录保留在 [上一轮记录](SAY-RING-15PM-GESTURE-1238-20261104.md)，不能用模式 ACK 或回读代替实际控制。

本轮范围：按用户要求参考同一台 iPhone 15 Pro Max 的原厂 QRing 手势说明，补齐 Say Ring 的只读使用引导；保留账号、绑定、健康记录和戒指设置，不修改 SDK、模式编号、连接策略、服务端、权限或健康算法。问题等级 P2：用户完成短视频模式确认后，界面缺少原厂要求的 iPhone 操作条件，难以独立完成设置。

## 原厂依据和用户对照

- 已在同一台 15 Pro Max 查看已安装的原厂 QRing 1.3.1（2）“手势说明”页，保存并检查该页真实截图。只对看见的说明页作结论，不声称审查了原厂全部流程；未复制原厂图片或执行佩戴校准（SDK 明确该校准会清数据）。
- 原厂说明：用佩戴戒指的手指敲击；iPhone 需要开启辅助触控、执行触控手势，并将跟踪灵敏度调到最高；阅读 App 可能还需开启音量键翻页。原厂没有提供适用于全部固件的单击／双击映射。
- 用户确认系统蓝牙已连接，随后确认上述三项设置均已完成；又确认同一枚 R8 在原厂 App 可控制短视频。不能仅凭这些确认断言原先故障一定由某个设置导致。
- 原生控制元数据成功取回：gesture=true、touch=false；独立快照 rawMode2、strength1、duration0、sleeping=false，无读取错误。原厂对照后在 Say Ring 再次读得相同模式和参数，未发现模式编号或灵敏度差异。

## 客户端改动

- ring_gesture_guide.dart：增加紧凑的 iPhone 短视频设置卡，给出真实系统路径、三项需要核对的条件、佩戴手指敲击提示；使用说明补充对应条件和阅读翻页提示。
- ring_gesture_panel.dart：仅当前真实敲击控制、iOS、模式支持且已独立回读确认短视频时显示专属卡；其他场景保持原三步引导。忙、断线、未知／未确认状态不展示可立即使用的假确认。
- device_features.dart：只按当前真实 SDK 控制类型与回读状态传入引导类型，不凭蓝牙名称开放能力，不把说明推广到另一通道或触摸固件。
- 所有引导为只读文本；没有伪造系统开关完成状态、私有设置跳转、自动配对、权限申请或戒指参数写入。保留原场景写入保护、参数保留及两次独立回读逻辑；消费界面无供应商名称。
- 中文注释说明展示依据与不能将 ACK／回读视为系统条件或物理效果的原因。

## 回归和构建

| 项目 | 本轮结果 |
|---|---|
| dart format（4 个修改文件） | 通过；首次格式化 2 文件变化，夹具纠正后另格式化 1 文件 |
| 新版界面首轮专项 | 9 通过、3 失败；测试平台覆盖量在 tearDown 才复原，晚于 Flutter 不变量检查。改为 finally 在用例结束前复原；保留失败日志，没有改变产品逻辑绕过检查 |
| 修正后两个界面测试文件 | 全部 12 项通过；含 320px／双倍字号、系统条件只读及不支持／未确认状态 |
| flutter analyze --no-pub | 0 问题，6.52 秒 |
| 完整 Flutter / Asia/Shanghai | 2002 项全通过，60.57 秒 |
| 完整 Flutter / UTC | 2002 项全通过，62.65 秒 |
| 手势／原生协议 Node | 33 项通过，2.87 秒；含实际 Foundation 策略编译 |
| Android 原生 JUnit | 97 项，0 失败／错误／跳过 |
| Android 正常 main Debug / Release | 原签名双 ARM，20.32／63.07 秒，构建通过；本轮未安装安卓或发布 APK |
| iOS 正常 main Debug / Profile | 签名构建 32.14／56.23 秒；配置各 69.00／69.15 秒，串行，无并发清理 |

构件均明确 1.0.11（1239）；iOS cn.saydian.ring、原团队 W7SXQ4A226、15 Pro Max 设备资格、严格深层签名、Debug／AOT 区别已核对。正常生产 API 仍为 app.saydian.cn/global，未加入 QA 入口或供应商名称；构建生成配置已恢复。当前本机 Xcode 的 iOS 15 目标覆盖只表示本机可构建，不冒充仓库默认 iOS 13 的设备兼容性验证。

可复现命令（本机路径／原签名私有配置不入 Git）：

```sh
dart format lib/ui/widgets/ring_gesture_guide.dart lib/ui/widgets/ring_gesture_panel.dart lib/ui/prototype/device_features.dart test/ring_gesture_panel_test.dart
flutter analyze --no-pub
TZ=Asia/Shanghai flutter test --no-pub --reporter=expanded
TZ=UTC flutter test --no-pub --reporter=expanded
node --test tool/qring_camera_policy.test.mjs tool/test_coolwear_ios_integration.mjs tool/test_qring_reconnect_integration.mjs tool/test_qring_camera_integration.mjs
# 两个 Android 模式分别构建，均为 lib/main.dart、原私有生产配置、双 ARM：
flutter build apk --debug --no-pub --target=lib/main.dart --build-name=1.0.11 --build-number=1239 --target-platform=android-arm,android-arm64 --dart-define-from-file=<private-production-defines>
flutter build apk --release --no-pub --target=lib/main.dart --build-name=1.0.11 --build-number=1239 --target-platform=android-arm,android-arm64 --dart-define-from-file=<private-production-defines>
# android 目录，已安装 Java 17：
./gradlew --offline :app:testDebugUnitTest --no-daemon --max-workers=2
# iOS 分别以 --debug / --profile 配置后串行 xcodebuild 开发签名，明确 build 1239。
```

## 15 Pro Max 实物和数据保留

- 1238 诊断重启一次因 15 Pro Max USB 离线未启动；没有回退为旧包冒充新构建。手机恢复后只读诊断正常 main；后台调试查询超时单独记录，不能判为 BLE 断线。
- 1239 安装前私有完整备份 51 个文件、31,726,989 字节和逐文件哈希；原签名原位覆盖，未卸载、解绑、改账号或重置。系统实际回读 cn.saydian.ring / 1.0.11（1239），真实 VM 已接入。
- 核验同一正式登录账号、同一保存／连接目标 SD_RING_R8、capability ready、手势能力可用。原厂对照后、1239 实测前与最终回读均为界面短视频1／原厂2、strength1、duration0，实际支持关闭／短视频／音乐／阅读；本轮不因说明改动重复写模式。
- 用户首次对 1239 反馈“仍然没有效果”，随后在最新消息中改为“能控制短视频”。保留两个反馈；以最新反馈记录本轮用户确认可控制，不能冒充工具独立观察到每个动作、全部目标 App 或锁屏／长期后台验收。
- 最终同账号界面载入114条；最初107个ID与显示列表比较有3个不在当前投影中，故不据显示条数宣称数据丢失或全部保留。继续读取同账号原始存储 recent 得166条，原107个ID全部存在，缺失0；说明展示去重／选择与持久数据需分开核对。未改健康值、ID、算法或存储代码。
- 本轮私有辅助纠正：新启动尚未保留完整枚举时，最初只取16个实例未找到目标，扩大特定枚举采样；设备页仍有挂载外路由，最初引用采样40条不足，扩大后定位。辅助失败、后台超时及早期未连接状态均保留，不通过移除产品保护绕过。

## 结论与边界

已修复可确认的使用引导缺项；本轮用户最新确认 15 Pro Max / R8 可控制短视频，模式及参数回读正常，原107条记录在存储中全部保留。没有新的手势协议修复证据，也不能把最终成功唯一归因于某项系统设置；不声称音乐、阅读、其他手机或长期后台均已实物通过。

1239 是本轮本地验证版本；没有上传新 TestFlight、提交 App Store 审核、更新下载页或修改供应地区。私有构件、签名、容器、账号／设备标识、原始截图、VM端点和控制日志保存在忽略的 build/ios-15pm-gesture-1239-20261104 及上一轮私有目录，不上传公开 Git。

## 后续并入1240

用户随后要求今日活动去掉热量并缩小高度，已在保留本轮引导的基础上构建1240，并在同一15 Pro Max再次核验原107个ID全部保留、R8原短视频模式及参数相同。详见[1240记录](SAY-RING-TODAY-ACTIVITY-COMPACT-1240-20261104.md)。1239未上传为新TestFlight，公开Git记录保留先前失败与最新用户确认；当前手机使用1240正常main Debug并保持调试附加。
