# 2026-10-17 QRing 手势控制

## 原因和范围

用户要求 QRing 通道提供手势控制。复现：QRing 已完成真实握手后，设备页不发布 gesture_control 能力，Flutter 适配器和两端原生 read/writeDeviceFeature 仅接受 camera；已有手势页只按 LuckRing 模式展示。预期：按当前戒指实际能力展示并读写模式。等级 P2：功能入口缺失。

修改 Flutter QRing 适配器、共享手势页、iOS QRing 桥接、Android QRing 桥接及对应模式策略与测试。沿用当前账号的精确绑定目标、命令串行与连接代次；不改 API、原始健康数据、已上线版本或商店审核。

## 实现

- 按原厂 SDK 的 gesture/touch 能力发布手势入口；短视频、音乐、阅读、拍照、电话逐项按真实功能位开放。Android RT11 的当前 TouchControlReq 协议未支持，不能按名称补能力。
- App 模式 0/1/2/3/4/5 对应 QRing 原厂 0/2/1/4/5/6；穆斯林、游戏、测量和事件等其他原厂模式保留 rawMode，不能误标为关闭。
- 页面打开先读实际模式，显示回读勾选、刷新及系统配对说明；读取失败或连接改变时不显示可操作的假默认值。LuckRing 原有指令确认语义保留。
- 写入先重新读取并比较 expectedMode，保留强度及触控休眠参数，只修改选择的模式。写后等待 SDK 命令退栈，再全量读取核对；最多重读三次、不重复写入。ACK 不代替读回，未确认则本连接隔离、重连后再试。
- 与原相机控制共用操作槽、断连/换账号取消和连接代次校验；Photo UI 协议保持独立。

## 实施与验证记录

- 开工：main 与 origin/main 一致，基线 e66f2a37a66d09184a9308164dbe6bfbefd1704a；fetch/pull --ff-only 无新变更。
- 原厂依据：本地 QCBandSDK QCDFU_Utils.h 控制模式及能力字段，QCSDKCmdCreator.h 手势/触控读写声明；Android qring_sdk_1.0.0.76.aar 的 DeviceSupportFunctionRsp、TouchControlReq 与 TouchControlResp 原厂字节码。未改闭源 SDK。
- 首轮 analyze/定向测试失败：新 UI 用例误把 sdkSource getter 当成构造参数；改为由 qring: 标识推导。两个 if 的花括号提示一并修正。没有产品运行失败。
- 本机 Foundation 的 qring_gesture_policy_test.m 编译（-Wall -Wextra -Werror）并运行通过，验证模式转换、未知原始模式保留和参数保留。
- 真机测试前已退出本任务旧 Debug 会话，私有备份当前 App 容器：46 文件、32,579,123 字节。没有卸载、清理会话或解除绑定；后续仅用保数据 wrapper 和独立验签的新 Profile。

以下为随后实际执行的结果。原始日志、截图、回执仅在 Git 忽略的私有 build 目录保留。

- 主机首轮真机驱动虽退出码 0，但未进入测试：端口被另一个 iPhone 调试会话占用，DDS 返回 403。没有把退出码当作通过；只中断本轮驱动，不终止另一会话，换空闲端口后重跑。
- 1095 Profile 第二轮已通过全部 11 个阶段：实际绑定 QRing/R21 握手、真实设置读取、页面入口、关闭/短视频/音乐/阅读逐项写入与回读、完整恢复原模式与参数、最终页面回读。戒指实际仅支持 App 模式 0/1/2/3，原始音乐模式 1（App 模式 2）、强度 1；最终恢复确认。拍照/电话未上报，不展示。包含前后台等待共 2 分 54 秒，原生完整单次模式保存/回读约 3.6–4.9 秒。
- 首轮页面取证未保留截图：测试 finally 重新赋值 reportData 覆盖 screenshots；测试完成后系统截图只能得到测试结束页。修正为合并既有 reportData，追加实际 enabled 状态断言，并用最终原生代码独立重建 1097 Profile 再验证。意外捕获的系统切换画面已立即删除，未存入 Git。
- QRingGestureSnapshot 的 enabled 从原 camera helper 的“是否拍照”改为“原始模式非零”，不改变模式读写协议；Foundation/Android 原生策略新增对应断言并重跑通过。

## 回归与构建

- flutter analyze --no-pub：0 问题。
- 全量 Flutter：TZ=UTC / TZ=Asia/Shanghai，各 1,259 项通过。
- Node：QRing 监测/相机/重连、iOS 活动睡眠策略、CoolWear 原生集成、日志隐私、保数据驱动共 37 项通过（包含实际 Foundation 91 条断言与 Swift 导入检查）。
- Android 原生 JUnit：53 项，0 失败/错误/跳过；最终原生辅助策略改动后再跑通过。
- Harmony 原生不提供 QRing；共享路由回归 20 项通过。release Python 回归 35 项通过。
- iOS 1095 集成 Profile：24,086,371 字节，SHA-256 d3192b458fe6b15e700ef5cfb96c81c508d15bf848f5d37485ff08fcc2c63b54，37.4 秒。
- iOS 正常 main 1096 Debug：57,955,830 字节，SHA-256 6f26d3459d1d1ea04ddca04d87b2ed582db316ba65b0aae3ead499a09d160a24，65.5 秒。
- iOS 正常 main 1096 Profile：23,838,514 字节，SHA-256 410f28c8c63e28eb74d4ee38a73009e121a241ab3a50f47ee4dca56ab9a789d4，59.9 秒。
- 两个 main iOS 包均独立严格验签，核对 cn.saydian.ring、1.0.1（1096）、原团队、开发调试 entitlement 与当前真机资格后冻结；原生编译串行，未清其他会话 DerivedData。
- Android 1096 Debug：158,820,265 字节，SHA-256 7ad19663913d7356b7defd37ff4a9a1a5bfd0f217fe80dd91b50c35ab3a567f1，17.2 秒。
- Android 1096 QA Release：69,832,751 字节，SHA-256 bc341aebb551475e2260c2de28fc00ea972e47e222fa92e1b5e5abbf58f9cab9，94.3 秒。两包签名、版本、双 ARM、16 KB 对齐核对通过；Release 仅为 QA 调试签名，不用于市场发布。

## 可复现命令

```sh
flutter analyze --no-pub
TZ=UTC flutter test --no-pub --reporter expanded
TZ=Asia/Shanghai flutter test --no-pub --reporter expanded
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation test/native/qring_gesture_policy_test.m -o build/qring-gesture-20261017/native-gesture-policy
build/qring-gesture-20261017/native-gesture-policy
node --test tool/test_qring_monitoring_integration.mjs tool/test_ios_activity_sleep_policy.mjs tool/test_qring_camera_integration.mjs tool/test_qring_reconnect_integration.mjs tool/test_coolwear_ios_integration.mjs tool/test_native_log_privacy.mjs tool/drive_ios_preserving_data.test.mjs
node --test harmony-native/tests/wearable.test.mjs
python3 -m unittest discover -s scripts/release -p 'test_*.py'
# android 目录，JAVA_HOME 为已安装 Java 17
./gradlew :app:testDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline --max-workers=1 --console=plain
# 先私有备份容器并独立构建、验签、核对当前目标资格；端口需先检查空闲
FLUTTER_BIN=flutter node tool/drive_ios_preserving_data.mjs --profile --keep-app-running --no-pub -d "$SAYRING_DEVICE_UDID" --target=integration_test/ios_qring_gesture_test.dart --driver=test_driver/ios_qring_gesture.dart --use-application-binary=.build/SayRing-1.0.1-1097-integration-profile.ipa --host-vmservice-port=53571 --dds-port=53572 --dart-define-from-file=config/ios-app-store-no-push.json
```

构建命令统一 --no-pub、--target=lib/main.dart（集成包则为对应 integration_test 入口）、--build-name=1.0.1、--build-number=1096（集成 1095/1097）、--dart-define-from-file=config/ios-app-store-no-push.json；iOS 分别 flutter build ios --debug / --profile，Android 分别 flutter build apk --debug / --release --target-platform=android-arm,android-arm64，QA Release 显式 SAIDIAN_ALLOW_QA_RELEASE=true。私有覆盖配置指定原开发团队及已接受的 iOS 15 最低目标，无签名配置提交到 Git。

实物动作控制其他 App、触控款/RT11、Android QRing 实机尚未逐项验收；不能用模式保存/回读替代系统配对与实际手势动作。没有上传新商店包、提交审核、发布下载或生成/上传健康 AI 报告。

- 1097 真机增加 enabled 类型断言后失败：iOS NSNumber 将 C 比较结果装箱为 int 1，MethodChannel 传成数字而非布尔。失败发生在初次只读断言，尚未改戒指模式；原始音乐模式仍保留。修正为显式 @YES/@NO，并在 Foundation 用 CFBooleanGetTypeID 核对类型，再构建 1099 真机重测。
- 1098 main 曾完成 Debug/Profile 构建验签，但发现上述类型问题后不作为最终交付。另补取消/断连后的重试引用释放；最终正常 main 改为 1100，必须在真机回归通过后从最新源码独立重建。

- 最终 1099 Profile 严格验签/开发资格核对通过：24,086,931 字节，SHA-256 5778581ba797f5e29f3fd157bc54c2fd31cfa966784b3f71d53d2c90937f4ebf，24.4 秒。以最终桥接代码完成全部 11 个真机阶段，25 秒通过；初始 enabled 为真正的 true，关闭后 false，其余模式 true，原音乐模式、强度和时长恢复一致。
- 1099 的截图已回传到私有目录，但图像为全黑，不能作为视觉验收证据。真实页面入口、按真实能力出现的模式、刷新与勾选行为由设备测试和 Widget 测试验证；不把截图 API 成功等同于有效画面。
- 最后一次 analyze 0 问题；原生相机关联 Node 三项再次通过。仓库匿名 GitHub 元数据回读 private=false、visibility=public、默认 main。

- 最终 main 1100 Debug 构建 33.6 秒，57,956,012 字节，SHA-256 cbdb13599455cad1e421bc2c3cf2dbcb48cff021851493a60e125d98874d2a28；Profile 构建 47.1 秒，23,838,511 字节，SHA-256 ba62737724195581c487f28269a8dd81ce65dfbadf747bc4c353e3aa72a11950。两包均由最终源码串行编译，严格验签、Bundle/版本、原团队/开发 entitlement、真机资格核对通过；早先 main 1096/1098 均为中间验证，不用于本轮最终安装。

- 正常 main 1100 Debug 已原位覆盖安装并附加 Flutter/LLDB；CoreDevice 回读 cn.saydian.ring、1.0.1（1100），安装/启动 25.1 秒、文件同步 94 ms。没有卸载、解绑、清理登录或替换健康数据库。
- 最终只读 VM：一个 main isolate、一个 AppController、root package:saydian_app/main.dart、Resume；已登录、启动完成、QRing/R21 真实连接/能力 ready，gestureVisible/gestureReady 均 true。睡眠 AI 配置和原活动数据仍可用，通用 AI 与生理指标入口仍关闭。
- 热重载实际 Reloaded 0 libraries in 302ms；随后没有 Lost connection / 未处理异常。CoreDevice 对正常 main 的截图可正常显示产品首页，进一步区分了集成截图全黑与正常 App 渲染；截图私有保留，不提交用户画面。
- 用户已收到音乐播放器实物动作确认请求；若尚无反馈，跨 App 实际动作保持待验，不把设置回读代替 HID/系统配对效果。

本轮 Git 交付包含源码、测试、回归清单和本文；不含安装包、签名材料、用户数据、原始 SDK 日志、设备唯一标识或 VM 链接。公开 main 的远端接收回执留在本机忽略目录，最终同步状态另经 fetch 核对。
