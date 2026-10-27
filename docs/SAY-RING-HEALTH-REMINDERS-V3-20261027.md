# 2026-10-27 健康提醒V3首版升级

## 授权与基线

用户明确要求按V3方案立即改进App，重点为异常心率及急症求助。修改前工作树干净，当前分支`codex/login-camera-r7ultra-1136-20261024`；`git fetch --prune origin`及`git merge --ff-only origin/codex/login-camera-r7ultra-1136-20261024`均成功，基线`4c5a079b1835aa6cea6ca10d72902f1a83f46ac5`，无远端新提交。已读项目约定、国际交接、复盘、回归清单和最新离线iOS回归记录。

## 本轮实施范围

- 健康提醒中心、无需登录或戒指连接的急症求助入口、用户主动拨号；不自动呼叫或联系他人。
- 本机加密、账号隔离的症状事件、知晓与拨号发起状态、真实来源和测量/接收时间、用户主动导出。
- 高/低心率事件引擎：来源、时间、质量、适用场景、样本窗口、断档、重复、乱序与事件去重。无已审阅适用规则时不自动判定，旧120bpm和5分钟不是医学兜底。
- 主要页面统一“健康提醒”命名；不输出心梗概率、排除心梗、全天监护或虚假送达。
- 保留现有活动/睡眠记录、绑定和SDK采集、iOS生理显示/手动测量边界及原睡眠AI授权；不改服务器或公开发布配置。

## 当前设备与证据边界

开始时`xcrun devicectl list devices`显示XR及15 Pro Max均unavailable，无新的iOS真机测试。本轮先执行源码、宿主与构建检查。原两类戒指桥均未实现心率报警写入；没有已审阅临床阈值/可靠连续采样和后台覆盖证明，不将读取心率等同生命风险监测。

## 过程与验证

实施和实际检查继续逐项追加；尚未运行的项目不记为通过。首次只读搜索使用不存在通配路径被zsh拒绝，改为读取实际路径，不是产品失败。

### 实施与失败修正

- 首轮`flutter analyze --no-pub lib test integration_test`发现23条问题：扩展内直接调用受保护通知方法、流程括号和移除旧评估后残留空循环等；通过类内通知包装、补齐括号、删除空循环修正。第二轮及完整回归前检查均零问题。
- `dart fix --apply --code=curly_braces_in_flow_control_structures lib`只修改两个新增文件的9处括号；之后对实际修改文件执行`dart format`，完整格式检查通过。
- 定向首轮`flutter test --no-pub test/heart_rate_reminder_engine_test.dart test/health_reminder_v3_test.dart test/ios_wellness_ui_test.dart test/global_localized_pages_test.dart --reporter expanded`为72通过、8失败：200%文字下英文求助按钮被说明挤出首屏，窄屏求助拨号按钮被延迟构建，以及测试夹具在fake-async区初始化真实应用轮询定时器。修正产品操作顺序（按钮先于长说明）、将夹具初始化放进`tester.runAsync`。第二轮80/80通过，未放宽按钮可点击断言。
- 新增SQL往返/重启/跨账号删除、排队删除归属和MethodChannel权限/最少通知载荷契约；5/5通过。FFI用实际生产SQL队列与表结构，但不代表真机SQLCipher加密验收。
- 首轮完整UTC测试为1545通过、2失败：新增入口令微信与单位设置需要滚动，旧脚本分别缺少滚动后刷新帧和滚动操作。补齐`ensureVisible`及`pumpAndSettle`，保留原按钮样式、可点击和目标页断言。
- 第二轮完整格式检查、静态分析通过；`TZ=UTC`和`TZ=Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded`各1547/1547通过。旧日志保留在私有build目录，新轮次使用独立`host-v2`目录。
- 新事件引擎补充重叠适用规则拒绝、上下边界、重复/乱序、无效质量、来源/归属、过期/未来、未知场景、窗口及多样本恢复测试；用合成工程夹具，不是临床性能验证。

### 交付行为与兼容性

健康提醒中心从首页和我的页进入；登录页有无需认证的急症求助。求助页地区由用户选择中国大陆120或美国911；不读定位，不自动呼叫，其他地区明确使用当地号码。测试使用注入拨号器，不拨打真实急救电话。新增说明按公开资料实现，仍需目标市场专业文案审阅后进行公开发布。

用户主动症状记录沿用本机SQLCipher健康库的账号隔离提醒表，以可选schemaVersion=1元数据兼容旧记录，无数据库版本提升。记录、知晓、拨号发起和手机通知请求的时间独立；不会写成异常已解除、已接通、已获救或已经送达。并发知晓/拨号不相互覆盖；导出只处理用户选择的单条，CSV有公式注入防护；删除仅当前账号当前记录，并取消对应手机通知。没有扩大健康上传或服务端接口。

Android/iOS新增第一方本地通知通道，泛化通知内容，不把读数或症状放到锁屏载荷。进入页面只读取权限；申请权限由用户点击。换号清理上一账号本地通知；点击结果须再次核对当前owner、现有事件和权限边界。此通道不等于新的后台采样、APNs开通或通知实际送达证明。

当前普通生产工厂不提供自动心率规则，实际适配器也没有可验证的静息场景合同。因此自动心率提醒明确显示未启用；不会用测试规则、旧默认120或用户自己改阈值开启。iOS保留固定生理与手动测量上限，健康求助/主动症状记录独立可用。旧记录保留；Android旧事件折叠为历史，iOS原未获准生理提醒历史保持关闭。

本轮对应V3方案的H03求助、H05事件记录、H06可用性状态、H07隐私/导出基础及H01/H02规则引擎工程底座。H01/H02实际生理提醒、戒指离线报警/后台覆盖、医学阈值、血氧/心律/心梗算法、联系人联动尚未验收，未开放。女性周期和外部血压的后续模块按规划保留，本轮未宣称完成。

### 最终文案复核与回归

复核发现旧全局提醒浮层仍建议先休息复测，与新方案严重症状优先求助的要求冲突。更新8种语言资源（含中文变体），不再要求等待再次测量；同时补齐旧提醒记录、设备心率提醒和泛化通知的中文名称。点击“查看提醒与求助”先收起原浮层，避免遮挡目标页；收起不表示已恢复或救援完成。生成本地化资源后，对最终源码再次执行格式、静态分析及双时区完整Flutter测试，仍各1547/1547；最终Android Debug构建通过。首个正式构建先保留，文案更新后的产物另存`android-v2`，只交付后者。

原生与工具检查（相同最终原生源，第二轮记录）：`node --test tool/*.test.mjs tool/test_*.mjs`为140通过、1跳过（Windows ACL检查不适用于本机）；`TZ=UTC`与`TZ=Asia/Shanghai node --test harmony-native/tests/*.test.mjs`各525通过；`python3 -m unittest discover -s scripts/release -p test_*.py`35通过；Android Debug/QA Release双ARM构建通过，`JAVA_HOME=.../jdk17 ./gradlew :app:testDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline`62/62通过。Harmony结果为宿主契约测试，不是Harmony新功能或HAP实机交付。

### 1.0.7（1152）构建与现场状态

- Android：用Git外既有生产环境及`--dart-define-from-file`、原PKCS12正式证书重新构建，非QA重签。临时`android/key.properties`仅构建时600权限创建，finally删除，未覆盖已有配置；密码、推送配置、证书均未进入Git或命令行。
- 最终APK：`build/health-reminders-v3-20261027/android-v2/SayRing-1.0.7-1152-health-reminders.apk`，72,063,451字节，SHA-256 **fbf046c672c66fe2e80fecb08b32e874f25d0b5d3bb8e1583d538ebc0ee72b28**。`apksigner verify --verbose --print-certs`、`aapt dump badging`及`zipalign -c -P 16 -v 4`成功，包名`cn.saydian.ring`、版本1.0.7/build1152、非debuggable、双ARM；证书SHA-256 **81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de**与手机现装1144一致。
- 用`apkanalyzer manifest print`与`aapt2 dump resources`获得实际产物清单，以`release_gate.py apk-manifest`检查包名/版本、权限、组件及生产推送配置成功；以当前Gradle `releaseRuntimeClasspath`依赖报告和`pubspec.lock`执行`release_gate.py apk-abis`通过，包括已有明确版本的JPush单arm64库受控例外。没有以这些结果声称推送业务送达。
- iOS：串行执行`flutter build ios --debug/--profile --config-only --no-codesign --no-pub --target=lib/main.dart --build-name=1.0.7 --build-number=1152`，固定生产API根、商城编译开关与空JPush key，再分别`xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug/Profile -sdk iphoneos -destination generic/platform=iOS ... IPHONEOS_DEPLOYMENT_TARGET=15.0 DEVELOPMENT_TEAM=W7SXQ4A226 SAIDIAN_DEVELOPMENT_TEAM=W7SXQ4A226 CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY='Apple Development' build`，两次均`BUILD SUCCEEDED`。继承的第三方SDK/Swift导入警告保留，不是零警告结论。
- 普通iOS Profile已复制到`build/health-reminders-v3-20261027/ios/normal-profile-1152.app`；实际Info.plist为`cn.saydian.ring / 1.0.7 (1152) / iOS15.0`，TeamIdentifier为W7SXQ4A226，`codesign --verify --deep --strict --verbose=2`通过。可执行文件SHA-256 `529c12276c78d24eda3592371dc5b200bb8d9edf1c2c9e72277fe2eda97b9f5c`。这是开发签名Profile测试构建，不是发行IPA或商店上传。
- 最终运行源码快照：基线4c5a079加39个已记录运行文件blob，快照SHA-256 `559e6e6a256c30a51fe09d90f58ffb33a03513c521dde98925d5e8cba9353687`；私有build目录保留各轮完整命令、日志、原始产物与实际签名证明。之后提交需逐blob复核，避免把旧包充作最终源码。

Android在线为华为PPA-LX3/Android10。先私有保留原1144 APK并确认原发行证书，截图显示既有登录和本机记录仍在；不导出或承诺已备份不可调试应用的数据容器。初次APK核验误在ADB拉取完成前启动，报ZIP尾部缺失；等待拉取完成后重新验签成功，原文件未损坏。首次Flutter页面uiautomator dump未产生XML，改用私有设备截图；后续原生安装器XML正常可读。若干只读候选路径不存在，已改为按`rg --files`实际清单定位；不是产品失败。

执行`adb install -r <最终APK>`，没有卸载或清数据。当前华为安装器停在“风险提示→继续安装”；ADB点击该按钮未生效，实际package仍为1144，已通过会话问题请求用户亲自在手机确认。**1152安装和新页面真机验收当前待确认，不能记为通过。**安装进程及窗口保留，未绕过系统提示。XR和15 Pro Max再次检查仍unavailable，iOS安装、戒指采样、通知展示与物理效果均未执行。构建通过不代表这些项目通过。

本轮没有更新公开下载页、App Store/TestFlight、服务端部署/功能旗标或销售地区。当前分支用于可独立验证的开发交付，未把未验收的健康提醒方案提升为生产医学功能基线。

Git本机源码提交为`d8790ef9231b79027377c81f99176ebce2e8a558`。再次fetch成功且远端仍为4c5a079，运行文件blob与构建源码逐项一致；命令行push实际失败：`could not read Username for https://github.com: Device not configured`。现有已连接GitHub应用已读到正确仓库和相同分支头，将通过该连接同步同一文件树；必须核对tree SHA、使用原分支头前置检查及非强制更新。本机原提交应保留为本地备份，最终远端身份和CI以GitHub回执为准，不能将原命令行失败写成成功。

## 内容依据

- [NHLBI心梗诊断](https://www.nhlbi.nih.gov/health/heart-attack/diagnosis)：不能由心率或单次读数诊断、排除心梗。
- [AHA心梗警示症状](https://www.heart.org/en/health-topics/heart-attack/warning-signs-of-a-heart-attack)：警示症状出现后不等待再次测量。
- [国家卫健委急救电话说明](https://www.nhc.gov.cn/xcs/c100122/202405/f251e896a50a49ff8c632b4b3da93126/files/1734001844015_12363.pdf)：中国大陆120。
- [911.gov](https://www.911.gov/calling-911/)：美国911；地区由用户明确选择，不推测位置。
- [Apple本地通知](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)、[Android通知权限](https://developer.android.com/develop/ui/views/notifications/notification-permission)：系统权限及请求不等同实际展示，后台采集能力另验。
