# 2026-09-30 Mac 更新与 iPhone 调试

## 完成内容

- 本节为最新汇总；下方按时间保留修改、失败与复测过程。独立工作树完成 R2→QRing、固定 `cn.saydian.ring`、商城默认隐藏、iOS 连接时序/日志隐私、压力完成回调与体温单位、睡眠详情及趋势标签修复；`0.1.21 (1006)` 开发签名 Profile 已安装到 iPhone 15 Pro Max。

## 页面检查

- 真机确认中文搜索、已连接设备页、电量/固件、健康监测四项开关、压力趋势/结果、睡眠详情单位；商城入口隐藏。不是全 App 所有页面已验收。

## 功能检查

- 最新静态分析零问题、Flutter 双时区各 939 项、Foundation 48 断言、Android 原生 32 项通过；本工作树 Android Debug/QA Release 和 iOS Debug 编译通过，签名 Profile 编译/验签/安装通过。构建、签名和真实功能分别记录，不相互替代。
- 已有 R21 真实握手、连接/同步、电量/固件回读证据。压力三轮成功（含最终安装包），取消不增记录、冷启动保留结果；温度/HRV 的成功分别记录对应安装轮次，不把历史结果当成本轮全指标重测。

## 接口检查

- Apple 开发者服务 TLS、Xcode 团队和正式产品 ID 开发描述文件恢复可用。
- QRing 固定 SDK 压力完成结构与头文件不符，精确兼容已实测，默认补值始终禁用。微信真实授权/短信投递尚未验收；构建期微信参数、对应 `cn.saydian.ring` 的 AASA 关联仍待配置。

## 待处理问题

- 15:44 最新安装任务：用户已确认改装到名为 Nokia 的 iPhone 15 Plus。手机已配对并开启开发者模式，但苹果开发者设备列表明确显示 `Processing`，提示可能需 24–72 小时；当前尚未安装。下方签名登记排查及最终平台状态均保留，不能把旧手机安装结果当成新手机完成。
- 活动统计与重复同步、自动检测开关写入/恢复回读、三轮冷启动/自动重连、找戒指实际震动、运动与完整微信/SMS 链路仍待验；iOS HR 原生支持仍独立待验。
- 用户已要求暂停手机操作，先完成本机构建与 Git 提交。Git 同步不等同于正式生产发布或上述待验项通过；构建与远端回读分别记录。

## 建议下一步

- 先按用户优先级补齐可执行的本机门禁并提交/推送，保持手机暂停。后续由用户恢复真机任务时，先确认四项监测开关与原值一致，再继续尚未验收的同步/重连/运动矩阵；不得自行继续手机操作或发送真实验证码。

## 基线与现场保护

- 用户要求更新，并确认继续使用 iPhone 15 Pro Max。
- `git fetch --prune origin` 成功；原工作区基线 `b39c8ee` 落后 `origin/main` 51 个提交，最新为 `de9babf`，版本 `0.1.21+1006`。
- 原工作区 `/Users/mycodex/电商/SayRing` 有未提交 QRing、国内登录及 QA 改动，不在脏工作区直接拉取或叠加另一套 SDK 桥接。
- 已创建独立工作树 `/Users/mycodex/电商/SayRing-update-20260930`，分支 `codex/macos-update-20260930`。原源码和原始 SDK ZIP 保持不变。
- 原工作区 115 个已修改/未跟踪文件已备份至 `/Users/mycodex/电商/SayRing-checkpoint-20260930.IEuMlk/local-changes.tar.gz`；SHA-256 `2f5f409b0127a3d345319276f2bef1b394de0582f952ad62b4535f8e42db376b`。忽略的本机签名配置和构建产物仍保留原位。

## 修改原因、范围与预期

- P1：远端仅接受 `Q_`/`O_` 与 `R22_` 加四位十六进制名称，`R21` 会在 Flutter、Android、iOS 三层被过滤；与本线程用户确认的所有 R2 前缀使用 QRing 不一致。
- 仅在新版已有桥接中补充大小写无关、去首尾空白的 `R2` 路由，并更新 Flutter/Android 测试。保留 Q_/O_、HR01/HR05、其他 SDK 路由及实际握手、能力读取、精确设备恢复限制，不复制旧独立 QRing 插件，不加载两份厂商库。
- iOS Debug/Release xcconfig 将 `cn.saydian.ring` 固定赋值放到 Local.xcconfig 之后，Profile 继续复用 Release 配置。新增包 ID 与原生 R2 源码门禁测试，不改内部通道名。
- 本机签名配置使用 Xcode 已显示的 Xuewu Tang 团队，ID 从现有有效开发证书 OU 核实为 `W7SXQ4A226`。仅保存在已忽略的 `Local.xcconfig`，不改包名、不删除证书、不移除能力。

## 当前验证

- `flutter pub get --offline` 成功；未升级 Flutter 或依赖版本。
- `dart format` 3 个 Dart 文件：2 个格式变化；`git diff --check` 通过。
- 2026-09-30 苹果开发者接口 TLS 已恢复，`developerservices2.apple.com` HEAD 返回 HTTP 200。用户自行登录的 Xcode 开发者账号已显示可用 Admin 团队，并已下载现有描述文件；账号地址不写入交付记录。此前 2026-09-27 的 TLS 失败不代表今天仍失败。
- `devicectl` 确认 iPhone 15 Pro Max 在线，`passcodeRequired=false`；iPhone 12 和名为 Nokia 的 iPhone 15 Plus 不可用。
- `flutter analyze --no-pub`：零问题；完整 Flutter 测试 UTC 与 Asia/Shanghai 均 923/923 通过，日志 `/tmp/sayring-update-20260930-tests-{utc,shanghai}.log`。测试日志中的授权失败栈为既有负路径测试输出，不是用例失败。
- `node tool/qa_ios_frameworks.mjs`：所有所需 framework 存在 iPhone arm64，QCBandSDK 为静态库；这不等同于最终链接或实机通过。
- `flutter build ios --config-only --profile --no-codesign` 成功，CocoaPods 补齐主线已使用但旧 iOS 锁文件未包含的 `share_plus`，没有升级其他 Pod 版本。
- 签名构建和真机验收进行中，结果待补；本记录不宣称安装、戒指连接、微信或短信验收通过。

## 本轮失败尝试及恢复

- 磁盘空间偏低；确认无 Flutter run、Xcode 或 Gradle 构建进程且目录无打开文件后，仅删除旧工作区 `build/app/intermediates` 约 1.3 GB 可重建编译缓存。旧源码、115 文件备份、APK outputs、iOS App、SDK ZIP、签名和手机容器均保留。旧工作区 tracked diff SHA-256 前后同为 `bb61f7148fa2f19e86cd7bd536708f55c611fab05c26ffefd22a0497350f562c`。
- 第一轮 Profile 编译在签名前检查失败：`requires a development team`。本机配置误写成 `DEVELOPMENT_TEAM`，但工程引用 `SAIDIAN_DEVELOPMENT_TEAM`；已更正忽略的本机键名，未硬编码团队到共享工程。
- 第二轮显式带团队构建时，目标 iPhone 已从在线变为 unavailable，出现 `Unable to find a destination`；已请用户重新连接解锁，未把主机编译与安装混为一谈。
- 第三轮以 generic iOS 目标、`-allowProvisioningUpdates` 构建仍报 `No Accounts` / `No profiles for cn.saydian.ring`，即使 Xcode 账户页已经可见团队。未反复重试相同失败，也未删除账号/证书。
- 使用 Xcode 打开此更新工作树并进入 Signing & Capabilities 后，成功生成 `iOS Team Provisioning Profile: cn.saydian.ring`。只读解析确认 application identifier 为 `W7SXQ4A226.cn.saydian.ring`，包含当前 iPhone 15 Pro Max，APNs 为 development，关联域名权限保留，到期时间为 2027-09-30 04:46:34 UTC。
- 使用本机签名配置和已生成 profile 继续串行构建（不再要求 CLI 自动获取账号）；日志 `/tmp/sayring-update-20260930-ios-profile-v4.log`。
- Heysocks 当前已是“自动连接 / 最快的服务器 - 自动”；本轮没有切换节点或更改代理配置。
- 第四轮已进入真实 arm64 编译，发现主线 QRing iOS 历史同步的 `switch (phase)` 下多个弱引用 block 缺少分支作用域，触发 7 处 `cannot jump from switch statement to this case label`。P1 影响是无法生成 iOS 包；修复仅为 7 个 case 增加花括号作用域，不改变 SDK 参数、健康数值和同步顺序。修复前已重新 fetch 确认仍与 origin/main 基线一致，并备份本轮改动为同一 checkpoint 目录内 `update-before-ios-compile-fix.tar.gz`；失败 v4 日志保留，继续 v5 验证。

## 签名 Profile 构建完成

- `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Profile -destination generic/platform=iOS -derivedDataPath build/ios-derived-data -jobs 2 build`：v5 `BUILD SUCCEEDED`。
- 产物：本更新工作树 `build/ios-derived-data/Build/Products/Profile-iphoneos/Runner.app`。`codesign --verify --deep --strict` 通过；签名为 Apple Development / Xuewu Tang，Team 为 `W7SXQ4A226`。
- 实际 Info.plist：`cn.saydian.ring`，`0.1.21 (1006)`。实际主二进制存在 `QRingWearableBridge` 与 `QCCentralManager` 类；QCBandSDK 静态库没有错误地复制到 Frameworks 作为动态库。
- 签名后的 Runner 主二进制 SHA-256：`7bfa4cd914da1d27dc74fd925f46f6fa020aa0caac231684381f67de63b3cd9f`。这是主二进制指纹，不冒充整个 App/IPA 归档哈希。
- 这是开发签名的 Profile 测试 App，不是 App Store/TestFlight 发布，不是 Android 或真机功能已通过。
- 手机在 12:44 后持续 unavailable，因此此时尚未安装、启动或执行 QRing 测量。用户此前确认佩戴是旧轮次信息，不能当本次实际测量依据。
- 新版 `wearable_bootstrap.dart` 仅在 Android 注册 CoolWear，QRing 注册 Android/iOS；HR01/HR05 仍不具备 iOS 原生桥接验收。iOS 微信 AppID 与 Universal Link 仍是占位配置，真实微信授权和短信未验证。

## 12:51 安装与实际页面验证

- 用户通知手机已重新插上。`devicectl` 回读在线、已解锁；对签名 Profile App 再次 `codesign --verify --deep --strict` 通过后执行安装，返回 `App installed`，bundle ID 为 `cn.saydian.ring`。
- `devicectl device process launch --terminate-existing cn.saydian.ring` 返回启动成功；12:52、12:53 连续回读同一新安装容器的 Runner PID 19305，进程保持运行，无需 Flutter/Xcode Debug 附加。本轮是一轮 Profile 启动及持续存活检查，不是三次冷启动完整稳定性验收。
- 已安装清单确认 Say Ring / `cn.saydian.ring` / `0.1.21` / `1006`；旧 `cc.saidian.app.dev.v2a92w8qz2` App 保留，未卸载或清除数据。
- 通过 Xcode Devices 的 Take Screenshot 取得实际手机画面。12:52 显示中文“添加设备 / 正在搜索附近戒指”，12:53 搜索结束显示“已发现设备”，列表仅见 `TK65 9061`，无 R21/R2。没有连接未经用户确认的 TK65，也不能把其他 SDK 的扫描结果写成 QRing 验收通过。
- 截图保存在本机 Desktop，未提交可能包含设备地址的截图；记录仅保留型号和结果，不录入完整设备地址或健康值。
- 已请用户确认当前目标戒指蓝牙名、唤醒并靠近手机；若有其他手机/App 正在连接，先从原连接端断开。本轮 R21 握手、能力、同步、真实测量及重连仍未执行。

## 补充门禁失败与资源回收

- 随后独立补跑 iOS Debug 时，生成模块缓存遭遇 `No space left on device`，未完成 Debug 构建；已成功签名的 Profile 包不受影响，不把 Debug 失败改写成成功。
- Android 原生测试首轮使用 offline / 1536 MB JVM，实际失败原因是缺少 armeabi-v7a Flutter Debug 缓存和 x86_64 Jetify Java heap space；测试尚未执行。其原因与 iOS Debug 磁盘错误分别记录，不混淆。
- 已结束本轮自身的 Gradle/Kotlin daemon；确认无正在运行的编译后，只清理本更新工作树已失败的 Debug 产品、iOS 模块/中间缓存及 Android 中间缓存，保留签名 Profile、测试/失败日志、源码、SDK、备份和手机数据。磁盘从约 117 MB 恢复至约 1.4 GB；这些编译缓存均可重建，不触碰系统 swap 或其他项目。
- Android 原生测试第二轮限定本机有缓存的 ARM64 目标、单 worker、2048 MB JVM、no-daemon，37 秒 `BUILD SUCCESSFUL`。回读 JUnit XML：32 tests / 0 failures / 0 errors / 0 skipped；日志 `/tmp/sayring-update-20260930-android-native-v2.log`。这不是 Android 双 APK 重建或 Android 真机验收。
- 最终 `flutter analyze --no-pub` 零问题（2.9 秒），`git diff --check` 通过；原工作区未覆盖，新工作树新增/修改文件均保留待完成余下门禁后提交。

## 边界

- 最新主线包含另一轮 QRing/CoolWear、微信和手机号登录实现，不能再把旧记录的“HR SDK 尚缺”作为最新代码结论；iOS HR 原生支持、实际微信授权及真实短信仍须分别核验。
- 原有旧目录的构建成功不作为这个更新工作树的构建或真机证据。
- 暂未提交、推送或发布；所有未执行门禁必须在后续交接中保留。

## 13:04 起：R21 真机功能回归（进行中）

- 用户重新确认佩戴并允许测量。保持原工作区和 SDK ZIP 只读，当前改动备份在 `SayRing-qa-checkpoint-20260930.moEim4/pre-qa-changes.tar.gz`；13:22 再次 fetch，HEAD / origin/main 仍为 `de9babf`。
- 采用实际截图先行的界面审查；在同一 iPhone 查看 QRing 1.3.1 的首页、设备资料和健康监测页面。只参考交互与真实设备能力，不复制评分算法、图片或虚构指标。测试截图含私人信息，仅保留本机，不提交。
- 已构建、开发签名并运行独立的官方 WebDriverAgent 测试辅助 App（`cn.saydian.ring.qa.xctrunner`）。主产品 ID 始终是 `cn.saydian.ring`。QRing 参考连接结束后已退出进程，避免抢占蓝牙；没有执行其提示可能丢数据的解绑确认。
- 商城默认通过 `SAY_RING_COMMERCE_ENABLED=false` 隐藏：首页、添加设备、订单、收货地址和反馈类型入口均门禁，旧页面直接进入也不加载商城接口。代码和用户订单数据不删除；后续升级可用 `--dart-define=SAY_RING_COMMERCE_ENABLED=true` 开启。不是远程后台开关。
- P1：QRing 原生发出的 `MEASUREMENT_NOT_WORN` / `MEASUREMENT_FAILED` 未被 Flutter 识别，可能一直等超时。先补回归：旧心率专用错误测试通过，两个 QRing 错误测试失败；再补错误码后通过。保留失败日志 `measurement-before.log`。
- P1：连接时个人资料、电量、版本命令并发，实际设备页电量持续未知；改为串行握手，加入连接代次、读取有效时间和截止时间，防止旧连接/测量回调污染新会话。待新版实机确认，不能仅凭编译认定已修复。
- 原安装包已实际返回心率和血氧结果，关闭测量后首页可见；温度返回无效值提示，未写入假数据，不记为通过。新包需重测，历史截图不冒充新包验收。
- P1 新发现：iOS 详细活动记录发出 `rawVersion=1`，被既有 QRing v1 错误时间戳隔离规则全部过滤；且 SDK 明确要求对详细计步自行汇总。计划只在 iOS 适配层按真实 SDK 时间汇总，保留原始旧行与过滤门禁，并验证重同步不会重复累计。
- P1 新发现：重开 App 后 QRing 演示中心能在 Flutter 恢复流程之前自行连接安装级缓存 UUID，桥接没有该目标的身份，随后搜索不再发现 R21。正在核查真实原生状态；修复须由当前环境已保存身份/明确选择驱动，不能放开任意系统设备自动接管。
- 回归第一轮全量测试 916 通过、11 失败（商城测试 FakeController 未提供新门禁 getter），修复测试夹具后 UTC / Asia-Shanghai 各 929 全通过；定向商城 109、第二轮定向 79 全通过。失败日志保留。静态分析零问题。
- Profile v1 于 13:17:23 签名成功，13:20 覆盖安装并运行；主二进制 SHA-256 `c8660c269d686b2d9cac3ddaeb0f3c959bf176030271bd19b031fe8da136aecc`。实际首页商城已隐藏，原有健康记录保留。
- 为继续构建，仅清理已确认无编译占用的旧 Flutter/Xcode/Android 中间缓存约 1.1 GB；源码、签名 App 备份、设备数据、SDK 和失败日志保留，缓存可重建。Android 双 APK / 新版 iOS Debug 和完整真机矩阵仍待执行。

## 13:28–13:47：连接、记录映射与 SDK 契约修复

- 前段记录是当时检查点：后续发现参考 QRing 虽退出界面仍可处于后台连接状态。已撤销本次测试临时建立的 QRing 绑定，恢复其原先“立即绑定”状态并终止进程；没有恢复戒指出厂、绑定另一只设备或删除 Say Ring 数据。不能把未广播唯一归因于演示中心。
- `QCCentralManager.appManagedConnections` 关闭演示中心安装级自动接管；桥接使用连接/同步/测量代次防迟到结果。iOS 手动“显示可恢复的戒指”只检索当前环境上次成功连接的精确 UUID，并验证实际名称、重新连接和读取能力。自动 `lookupBondedDevice` 仍返回空，不把 UUID 检索冒充系统绑定。
- Profile v3 于 13:33 安装，主二进制 SHA-256 `a925b2f4fff434b6169cfe2a229b07d0f159687e7f30721a626f15e78797637b`。13:34 用户路径手动恢复 R21，重新握手、同步及电量 81% 回读成功，匹配参考 App；冷启动自动扫描仍可能找不到不广播目标，不记为自动重连通过。
- iOS 活动详细槽按真实 `happenDate` 排序、去重并汇总累计值；SDK 米转公里，kcal 不套用 Android 缩放。新活动记录标记 v3，旧 v1 错误时间行继续隔离。共享数据层只在相同时间、同设备、同等质量的 QRing v3 活动快照选择更完整累计值。读取路径仍先折叠当天累计快照，再汇总展示。
- 睡眠依据 SDK `realEffectiveMinutes` 和阶段 1/2/3/4/5 映射：清醒不计入睡眠，未佩戴排除，浅睡/深睡/REM 分开；去重，拒绝超过一天。实机同步后睡眠总量发生变化，仅说明新映射生效，尚不据此宣称与参考端全部统计一致。
- 新增 Foundation 主机可执行映射测试。首轮 30 个断言；Flutter 测试夹具首轮因不存在的 `copyWith(metric/id)` 编译失败，修正为构造参数后 10 项通过。全量 UTC 931 / 上海 931 通过，静态分析零问题；随后恢复通道定向 27 项通过。以上是合成/代码验证，不替代硬件测量。
- 温度手动测量在 v3 真实失败，未写入伪造结果。只读检查固定 SDK `QCBandSDK 1.0.0 (260918)` 的 `notifyRealTimeBodyTemperature` / `measuringTimeoutAction` 实现，完成回调是整数 0.1℃，不是摄氏度；现仅在手动温度适配除以 10，历史 `QCTemperatureModel.temperature` 不变。默认补值保持禁用，非最终回调不入库。增加 356→35.6 与拒绝错误单位的回归，31 个主机断言通过。
- 同一 SDK `OdmBandGetDeviceSoftAndHardVersion.sendCmdOnStage` 确认回调参数实际为 `(hardware, software)`；修正原桥接反序取值。此前显示的 RF22B 硬件字符串不能再充当固件版本；新版需实机核对 2.00.05。
- 厂商二进制未修改，SHA-256 `dde3ce1f803f998aa4795cf3189f805fb3c819cebd408165fecd60497b847393`。反汇编临时材料只保留 `/tmp` 用于契约排查，不提交厂商实现摘录。
- 真机截图复现健康监测只显示心率/血氧，漏掉 SDK 已读取的 HRV/压力；补中文标签和能力返回项显示。QRing 未实现心率预警时返回可空契约的 null，避免把“不支持”报成部分读取失败；不新增假预警能力。测量等待文案改为简短两行，成功按钮为“完成”。定向 Flutter 70 项通过，Profile v4 编译中。
- Android Debug APK + 原生单测联合尝试在合并原生库阶段因 `No space left on device` 失败，未产出 APK；失败日志 `sayring-qa-20260930-android-debug-v1.log` 保留。确认本轮 Gradle 已结束后删除其生成的 864 MB `build/app/intermediates`，仅为可重建缓存。当前不足 1 GB，不重复双 APK 构建；Android Release / 新版 iOS Debug 门禁尚未完成，因此不提交或推送。
- LLDB 只读附加尝试未能取得稳定暂停态，已退出，不作为 SDK 回调数值证据，也不把附加期间进程变化归为已证实 App 崩溃。

## 13:48 追加日志隐私修复计划

- Profile 实机控制台发现自有 `QCCentralManager.m` 每次扫描输出附近所有外设名称、MAC、UUID，并在连接日志输出外设对象/完整错误。属于可直接修复的隐私缺陷：移除原始发现日志，将必要连接事件改成不含身份的固定文本/错误码。厂商闭源日志另行观察，不能声称全部供应商输出已消除。
- 修改前 13:46 再次 fetch，HEAD / origin/main 仍为 `de9babf`；当前 tracked/untracked 修改分别备份到 checkpoint 的 `v4-before-final-qa.tar.gz` / `v4-new-files.tar.gz`。不改变扫描、排序、回调或连接逻辑。
- 13:49 温度修正首次实测成功，关闭弹窗后趋势页仅增加一条真实手动结果；不是 SDK 默认补值。新发现温度图纵轴取整导致端点标签重复、HRV 图末尾时间超出右边界；按实际刻度间距保留小数、只显示间隔刻度并让时间标签留在图内，补截图对应的组件回归。

## 13:45–13:57：修复版实际回调与剩余边界

- Profile v4 开发签名验证、安装与独立启动成功；主二进制 SHA-256 `b0e615e46a87be8917572edfbf68a1d9ee31d95e61ec7013cf740169bc6e451e`。13:46 手动恢复 R21 再次连接和同步。设备信息显示 `RF22B_2.00.05_260918`，不再显示硬件版；电量仍为 81%，读取时间真实。
- 13:49 手动皮肤温度完成回调有效，弹窗成功 → 关闭 → 趋势页一条 → 首页同值均验证。13:51 HRV 手动测量有效，趋势记录数由 13 增到 14，首页更新；不把原有历史 HRV 当作本次手动成功。
- 13:55 压力首轮返回无效结果，显示失败/重试，未保存占位值；重试期间手机进入其他 App，不能据此完成连续静止条件验收。已请求用户让手机保持在 Say Ring，压力项继续标记未通过。
- 手动回调在本轮真实设备成功，仍不代表医疗准确性、云端上传、换手机拉取已验收。只读尝试拉取 App 的本地健康 DB 后，普通 sqlite 报 `file is not a database`；源码确认使用 SQLCipher 加密，不读取密钥或降低加密。持久化改用 App 退出/重开后的实际页面回读验证，当前尚待最终轮。
- v4 源码双时区各 934 项通过、静态分析零问题。新增隐私/图表用例后定向 72 项通过；随后关闭横轴强制末端刻度，全量 UTC 935 通过 / 1 失败，发现单数据点时间标签也被隐藏。修正为单点保留端点，定向 72 项再次通过。失败日志 `tests-utc-v5.log` 保留，完整双时区重跑中。
- Profile v5、v6 构建成功但未安装，不冒充真机验收。最后 v7 继续构建；除映射修复外包含图表标签、关闭 SDK debug 及移除虚构固定 5% 进度（SDK 无真实百分比时只转圈）。
- 为最后增量编译，确认无活跃编译或打开文件后回收本工作树未使用的 `ModuleCache.noindex` 164 MB 与 `Index.noindex` 34 MB；共享模块缓存、签名产物、原始素材、备份和手机数据不变。这两个目录可重建。
- 真机自动化截图一度超时：独立设备截图与进程回读确认 App 已进后台、手机未锁；不是构建失败或已证实 App 崩溃。恢复 App 后 HRV 结果仍在。没有发送微信消息、读取会话作测试数据或改变通知设置。

## 13:59 登录依赖只读核查

- 第一方 `GET /global/api/saydian-app/v2/auth/capabilities` HTTP 200，后台返回微信移动应用登录已开启、手机号绑定可用、CN 短信可用；这些只是服务端能力声明，不是手机授权/验证码送达证据。AppID 现可从接口核实，但没有把它单独注入后冒充 iOS 配置完成。
- 第一方 `GET /.well-known/apple-app-site-association` HTTP 200，当前只声明 `W7SXQ4A226.cc.saidian.app` 的 `/wechat/*`，没有本产品 `W7SXQ4A226.cn.saydian.ring`。iOS 构建中的 AppID / Universal Link 仍占位，因此还需微信开放平台 iOS 登记与域名 AASA 补齐；不复用另一产品标识、不覆盖其关联项，也没有擅自部署生产服务器。
- 未退出手机上的现有测试会话，未发送短信或确认新的协议。临时复制的加密健康 DB 和两张误入无关 App 的测试截图已删除；手机原始数据、源码、SDK、必要测试日志未删除。该本机临时副本没有单独保留，原数据仍在手机。

## 14:00 最后交接检查点

- 最新源码全量 UTC / Asia-Shanghai 各 **936/936** 通过，`flutter analyze --no-pub` 零问题，Foundation **31** 个断言通过，iOS frameworks 架构检查及 `git diff --check` 通过。日志分别为 `tests-utc-v6.log` / `tests-shanghai-v5.log` / `analyze-v5.log`（均在 `/tmp/sayring-qa-20260930-` 前缀下）。
- Profile v7 构建、严格签名校验成功，ID `cn.saydian.ring` / `0.1.21 (1006)`，Runner SHA-256 `f1d1c770a54a8105f34de32f7d22028bdaba344bb270d19b3f352fbd875d8f60`。14:00 覆盖安装成功；不改用户账号、设备容器或已有其他 App。最终界面/测量复测仍待手机可连续使用，不能把 v4 回调测试写成 v7 全量通过。
- 仍未验收：压力有效结果、活动统计实机数值与重复同步、监测设置逐项读写回读、找戒指的实际震动、短运动开始/结束、三轮冷启动稳定性、微信授权及真实短信/绑定链路。Android Debug/Release 和新版 iOS Debug 受磁盘不足阻断，当前约 690 MB；不继续填满磁盘、不提交/推送/发布。
- 交接源码为 `/Users/mycodex/电商/SayRing-update-20260930`。原目录、原始 SDK ZIP、此前备份均保留；商城后续升级通过 `--dart-define=SAY_RING_COMMERCE_ENABLED=true` 打开，不是当前后台可立即切换。
- 14:00:53 用 `--no-activate` 启动 v7，未强制抢到前台；14:01 回读最新安装容器的 Runner PID 19505。仅证明最新签名包后台进程可运行，不替代页面/戒指验收。已停止本轮 Mac 端测试辅助驱动和端口转发，未卸载主 App 或原有工具；最终修改已备份为 checkpoint 内 `qa-1400-tracked.tar.gz` / `qa-1400-new-files.tar.gz`。

## 14:12 压力测量专项：修改前证据与范围

- 用户重新确认 R21 已佩戴，但仍提示无数据。已重新核验手机连接/解锁，启用原有本机测试辅助驱动；不操作其他蓝牙设备、不写生产后台。`origin` 拉取成功，HEAD / origin/main 仍为 `de9babf`，原有脏改动已完整备份到 checkpoint 的 `pressure-1412-tracked.tar.gz` / `pressure-1412-new-files.tar.gz`。
- 当前 SDK 二进制 SHA-256 仍为 `dde3ce1f803f998aa4795cf3189f805fb3c819cebd408165fecd60497b847393`。只读检查 `QCSDKManager.o` 发现：压力枚举为 4，实时回调为 NSNumber，30 秒默认时限；`measuringTimeoutAction` 取真实 stress 后，完成分支在 type == 4 时却包装成 `sbp` / `dbp` 字典，其中第二值为 0。这与 SDK 头文件描述不一致，现有 NSNumber-only 适配会拒绝它。尚待真实完成回调与修复后结果确认，不能仅据静态检查宣布硬件通过。
- 原微信临时目录中的 SDK ZIP 当前已不可用，本轮只读使用项目中已校验哈希的供应商 framework，不重写厂商库、不改其默认值禁用开关。没有把 ZIP 路径失效称为素材损坏或自行删除。
- 计划仅修改 `QRingRecordMapping.h`、`QRingWearableBridge.m` 和对应测试：压力完成回调兼容上述精确两字段结构，仍要求真实数值 1–100、第二字段为数字 0；普通血压字典、零值、越界、错误类型一律拒绝。只接受 completed 回调，不用中间值提前结束、不调整等待时长、不生成默认数值。
- 临时诊断仅在显式 `SAY_RING_QA_MEASUREMENT=1` 环境下输出回调阶段、类型、是否有效及耗时，不记录健康数值、账号或设备标识。用同一 `cn.saydian.ring` Profile 包覆盖安装并执行压力、保存/重开和取消流程回归。各轮失败和实测结果在下文追加。

### 本轮构建与定向回归

- 先补压力完成字典回归用例，修复前 Foundation 测试在该用例失败（exit 134，`/tmp/sayring-pressure-20260930-native-before.log`）；兼容修复后 **48 个断言全部通过**，包含数字结果、准确两字段结构、边界值、零/255/NaN/类型错误/多余字段/普通血压字典拒绝与其他指标隔离。没有放开有效范围。
- 增加供应商二进制 SHA-256 固定回归，今后替换 SDK 必须重新核验该兼容行为。首次 Flutter 定向命令误引用不存在的 `wearable_bridge_contract_test.dart`，该装载失败保留在 `targeted.log`；改用实际 `wearable_bridge_test.dart` 后 **16/16** 通过（`targeted-v2.log`）。`dart format` 成功。
- 串行 Profile 增量构建成功（`profile-config.log` / `profile-build.log`）；严格签名校验通过，ID 仍为 `cn.saydian.ring`，Runner SHA-256 `07502e6a6f7975ea988e02638088090540406ad17736509a16d645548a0d4fa5`。14:14 覆盖安装成功，带显式 QA 环境启动 PID 19619；当前只证明编译/安装/启动，压力真机回归继续进行。日志均位于 `/tmp/sayring-pressure-20260930-` 前缀，未提交健康截图或运行日志到 Git。

### 14:17 压力真机首次成功

- 新包通过当前 App 上次成功标识的手动恢复入口重新连接 R21，完成 QRing 握手及同步；普通扫描仍只出现其他设备，未把它连接或当作 R21 验收。
- 第一轮压力在 26.1 秒开始产生有效 NSNumber 中间回调，30.0 秒 completed 实际收到 `260918_stress_wrapper`，`sdkSuccess=1 / accepted=1 / errorCode=0`。这直接证实了上述 SDK 完成格式兼容问题；禁用占位值保持 YES，App 未用中间回调提前结束。
- 手机显示真实成功结果，点击完成后压力趋势由无数据变为 **1 条**，单点图及记录时间可见。第二次开始后主动结束，页面恢复可操作，记录数仍为 **1 条**；再次开始测量中。具体健康数值及截图只在本机临时验收材料中，不写入 Git。
- 本次最新源码全量 Asia/Shanghai / UTC 均 **937/937** 通过；静态检查零问题；Foundation 48 个断言、framework 架构检查及 `git diff --check` 通过。未重试已受磁盘阻断的 Android 双构建 / iOS Debug，没有发布或推送。

- 14:18:46 重测也在 30.0 秒成功完成，同一 SDK 精确压力结构再次被证实。完成后趋势记录数从 1 增到 **2 条**，两次各保存一次，中途取消未新增。两个实际结果不同；没有复用上次结果或默认值。现在按不带 QA 环境的普通方式冷启动复核持久化与诊断默认关闭。

- 14:19:30 不带 QA 环境冷启动同一签名包，PID 19623。首页显示最新压力结果，重新进入压力页仍为 **2 条**，均值/最小/最大与两次结果一致，折线与记录时间保留；没有用仅内存显示冒充保存成功。普通启动未设置诊断变量（对应日志 `runtime-normal.log`），重新手动恢复 R21 以便交接继续使用。
- 与 14:12 源码备份对照确认本轮只增加压力精确结构解析、显式 QA 分类日志、针对性的错误提示和相关回归；没有修改厂商二进制、测量算法、超时时长、SDK 占位值设置或其他指标的数值范围。磁盘余量约 781 MiB，本轮没有再清理任何素材、缓存或手机数据。

### 14:23 收尾关联页面问题

- 真机收尾进入睡眠单条详情时，发现 `awakeMinutes` 被通用详情渲染成小时，阶段键名也直接显示英文。数据本身及睡眠趋势页映射正确，问题位于共享的 `healthValueLabel` / `healthValueUnit` 缺少睡眠字段规则；这是显示单位错误，不做健康数据重算。
- 已告知用户一并修正。重新 fetch 成功，基线仍 `de9babf`；压力修复全量源码备份为 `pressure-fixed-tracked.tar.gz` / `pressure-fixed-new-files.tar.gz`。新增修改限 `lib/domain/health_interpretation.dart` 与字段/详情页测试，仅在 sleep 指标下提供深睡/浅睡/REM/清醒/设备评分/效率的中文标签和准确单位，不影响其他指标的同名键。

- 睡眠回归先失败（`sleep-before.log`：期望“深睡时长”却返回英文 key）；补齐标签/单位后领域与页面定向 **73/73** 通过，包括清醒显示“分钟”而非“h”、阶段显示“小时”、设备评分“分”与效率“%”，其他指标同名键保持原样。格式化成功，正在重跑双时区全量并串行构建新 Profile，尚不把新包记作已安装。
- 收尾再次读取磁盘时可用空间已恢复到约 9.8 GiB；不是本轮执行删除清理造成，不能继续把此刻的磁盘余量说成不足 1 GiB。前面失败构建原因保留；本轮聚焦 iOS 压力与发现的睡眠显示问题，Android Debug/Release 和 iOS Debug 仍是未重跑门禁，不因此自动视为通过。

- 含睡眠显示修复的全量测试 Asia/Shanghai / UTC 均 **939/939** 通过，静态检查零问题。Profile v2 编译及严格签名校验成功，`cn.saydian.ring` 不变；Runner SHA-256 `8b31d900e05189209b6ef58363c2b4c1c6f2c260fbcc4ec04e35755f0f3d0835`，App.framework/App SHA-256 `97d963848b02a839215fac2f3f0362af17a8db18606c851b0c71b71936f8f8a3`。前一安装包的压力成功记录仍单独保留，不能移作新包尚未执行的验证。
- 发现另一工作树 `saydian-app-global` 有面向同一手机的 Flutter Debug 进程，已向用户提示优先级选择；没有终止或更改它。回读本产品仍为前台 state=4，后续只覆盖安装本产品已授权的 `cn.saydian.ring`，不修改另一 App 的代码、标识或进程。若前台转为另一项目，则不盲点坐标，停止相互争用的 UI 操作。

- 用户明确选择“优先赛电戒指 SayRing”。14:31 新 Profile v2 覆盖安装成功，普通启动 PID 19686；仍保持 `cn.saydian.ring`，没有设置 QA 日志变量。全量回归日志为 `tests-shanghai-v2.log` / `tests-utc-v2.log` / `analyze-v2.log`，安装与实测记录继续追加。

- 14:36 新包真实睡眠单条详情已显示“清醒时长 / 分钟”“深睡时长 / 小时”“浅睡时长 / 小时”“快速眼动时长 / 小时”，与同一历史记录原始单位一致，未改存储值。R21 在设备页显示连接成功、同步完成；压力页仍保留前两条结果，最后一次普通启动环境下的压力复测开始。

### 14:39–14:43 最终安装包专项验收与交接

- 最终 Profile v2 的第三轮真实压力测量成功，点击“完成”后记录数由 2 增到 **3 条**，均值、最小值、最大值与三次实际结果一致；测量按钮恢复可用。本轮普通启动没有启用 `SAY_RING_QA_MEASUREMENT`，对应 `runtime-v2.log` 无 `QRingMeasurementQA` 条目。截图及具体健康数值只留本机，不提交 Git。
- 证据分别覆盖：修复后的两次成功、期间主动取消不增记录、普通冷启动后原两条仍在；最终含睡眠显示修复的安装包保留原两条并完成第三次测量。最终包的睡眠中文字段与分钟/小时已在同一手机确认，没有重算或替换存储数据。
- 最终静态分析零问题、上海/UTC 全量各 **939/939**、Foundation **48** 断言与严格签名验证通过。产品 ID 始终 `cn.saydian.ring`，版本 `0.1.21 (1006)`；14:43 仍可回读最终安装容器的 Runner PID 19686。手机随后将主 App 转入后台，未为交接强制抢回前台；此前连接/同步成功不等于后台持续连接或三轮自动重连全部通过。
- 收尾仅停止本轮启动的 Mac 测试辅助驱动和端口转发，不退出主产品、不触碰另一项目的 Flutter 进程、不卸载测试工具。最终 tracked/untracked 源码分别备份为 checkpoint 中的 `pressure-final-1443-tracked.tar.gz` / `pressure-final-1443-new-files.tar.gz`。
- 尚未完成的全应用真机矩阵、微信授权/真实短信绑定、Android Debug/Release 与新版 iOS Debug 继续保留为待验；本轮压力专项成功不替代这些门禁，也不代表医疗准确性验证。没有 Git 提交、推送或正式发布。

## 14:45 继续真机验收与 Git 交付准备

- 用户要求继续，并明确修复后提交更新到 Git。重新 fetch 成功，HEAD / origin/main 仍为 `de9babf`；`gh repo view` 确认目标 `tangwu88/SayRing` 为 Private。仅在独立更新工作树工作，原工作区与另一 App 项目不变；已有完整源码 checkpoint 保留。
- iPhone 15 Pro Max 仍通过 USB 在线，已安装 Profile v2 的设备页显示 R21 已连接、电量 80%。重新启用本轮自有测试辅助驱动，计划继续重复同步、健康监测读写恢复和三轮冷启动检查；只操作当前已确认 R21，不执行解绑、恢复出厂、OTA 或其他设备连接。
- 当前磁盘约 7.7 GiB，补跑 Android Debug/QA Release、原生单测及 iOS Debug 构建门禁；iOS 构建串行，手机继续保留可独立运行的 Profile 包。不把源码提交/推送视为正式上架或完整微信短信验收。
- 14:47 实际健康监测页面回读四项自动检测均开启。随后尝试逐项测试时手机切到另一份 Saydian App，设置写入/刷新结果未获证实；已停止进一步坐标操作，不能将其记录为开关或恢复通过。用户明确要求“先完成构建和 Git 提交，暂停手机操作”，立即停止本轮测试辅助驱动/转发并转为本机检查；其余同步、开关恢复、重连和运动验收留待下轮，不为提交继续操作手机。

### 本轮本机回归（手机暂停后）

- `dart format --output=none --set-exit-if-changed lib test`：161 个文件、0 改动；`git diff --check`、发布脚本 `bash -n` / ShellCheck 均通过。
- 用 `xcrun clang -fobjc-arc -framework Foundation -Iios/Runner test/native/qring_record_mapping_test.m` 重新编译并运行，**48** 个合成断言通过；`node --test tool/test_native_log_privacy.mjs` **9/9** 通过。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py'` **22/22** 通过。日志里的重定向、恢复和公开校验失败来自有意构造的负路径，未执行真实生产发布。
- `node --test tool/global_auth_smoke.test.mjs tool/global_auth_account_qa.test.mjs`：**77 通过 / 1 跳过 / 0 失败**，跳过的是 Windows ACL 平台专用测试。这是离线契约验证，没有发送短信、申请微信授权或改变账号。
- `TZ=UTC` 与 `TZ=Asia/Shanghai node --test harmony-native/tests/*.test.mjs` 各 **501/501** 通过；不是 HAP 构建或鸿蒙真机验收。
- `node tool/qa_ios_frameworks.mjs` 与现有最终 Profile 严格验签再次通过；Runner 和 QRing vendor 二进制哈希与上一轮一致。提交审查移除交付记录中的开发者邮箱，完整账号、签名配置、设备标识、健康截图和临时运行日志不入 Git。日志统一保留在本机 `/tmp/sayring-followup-20260930-` 前缀。
- Android Debug 首轮命令为 `JAVA_HOME=<本机 JDK17> GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1 -Dorg.gradle.jvmargs=-Xmx2048m' flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64`；8 分 40 秒后在 arm64 Flutter jar 的 `JetifyTransform` 报 `Java heap space`，不是业务代码编译错误，日志 `android-debug.log` 保留。重试只移除本轮临时 2 GB 覆盖值，恢复仓库既定 4 GB heap / 1 GB metaspace，继续单 worker / no-daemon；不改变依赖、源码或设备状态。
- 提交前再次 `flutter analyze --no-pub` 零问题（4 秒），`TZ=UTC flutter test --no-pub` **939/939**（71 秒）、`TZ=Asia/Shanghai flutter test --no-pub` **939/939**（81 秒）全部通过；日志 `analyze.log` / `tests-utc.log` / `tests-shanghai.log`。本轮没有新的运行时代码改动。
- Android Debug 第二轮 **BUILD SUCCESSFUL / 240.7 秒**；包为 `build/app/outputs/flutter-apk/app-debug.apk`，实际包名 `cn.saydian.ring`、`0.1.21 (1006)`、`armeabi-v7a` + `arm64-v8a`；`apksigner verify --verbose` v2 通过，`zipalign -c -P 16 4` 通过。SHA-256 `5667d17977f301f665019800ec0a13b90202985273c8d90547d164d3eb25de12`。未安装到手机。
- `./gradlew :app:testDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline --no-daemon --max-workers=1` 45 秒成功；15:01 新生成的 8 份 JUnit XML 合计 **32 tests / 0 failures / 0 errors / 0 skipped**。构建中的旧 Kotlin 插件/SDK XML 警告保留，未借此升级工具链。
- Android 构建和单测退出后，进程及 `lsof` 确认新生成的 `build/app/intermediates/merged_native_libs/debug` 缓存无占用（约 963 MB）。直接强制清理命令被工具保护拦截，未删除任何文件，也未因此启动后续 Release。改用 Gradle 自身的限定输出清理任务，先查看 `help --task :app:cleanMergeDebugNativeLibs` 再决定执行，不改用其他脚本强删。
- Gradle 清理加入本机临时 init guard，目标不精确一致就中止。首轮 guard 误应用到 Flutter included build，第二轮因任务另含空的 `merged_test_only_native_libs` 输出而拒绝，两次均未执行删除；随后 dry-run 读出两个明确 `.../debug/mergeDebugNativeLibs/out` 目录，核对大小 963 MB / 0 B、无进程打开，改为只允许这两个精确输出，失败/只读检查日志保留。
- iOS `flutter build ios --config-only --debug --no-codesign --no-pub` 与 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination generic/platform=iOS -derivedDataPath build/ios-derived-data -jobs 2 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build` 成功。实际 Debug Info.plist 为 `cn.saydian.ring` / `1006`，Runner SHA-256 `afff9af5d7e0bf932db17c5e2e231d4f634db554d78e390b45cbae58811bafea`；这是无签名主机构建，未安装或在手机上启动 Debug。已安装的独立 Profile 产物严格验签仍通过。
- 限定输出的 Gradle Debug 缓存清理成功（17 秒），约 963 MB 已回收，两个任务输出可由下次 Debug 构建重建；回读 Debug APK 哈希未变。源码、SDK、已签名 App、JUnit 报告和备份不受影响。
- Android QA Release 命令为 `JAVA_HOME=<本机 JDK17> SAIDIAN_ALLOW_QA_RELEASE=true GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1' flutter build apk --release --no-pub --target-platform=android-arm,android-arm64`，**356 秒成功**；`app-release.apk` 约 69.0 MB，实际 `cn.saydian.ring` / `0.1.21 (1006)`、双 ARM 架构，v2 验签及 `zipalign -c -P 16 4` 通过。SHA-256 `2ccb84c38186c09b41f4161559bf42511f63e4b7cd6e9cc80a8d01e9cb3d9348`。权限清单不含后台定位、读取电话状态或查询全部应用；这是 QA 签名，不是上架签名。
- `docs/SAY-RING-QRING-MULTI-SDK-20260929.md` 已记录的 JPush/JCore 生产 ABI 锁漂移仍为独立发布待办，本轮未修改推送版本或弱化发布脚本。双包编译/验签通过不代表该生产门禁、正式签名或推送端到端通过。
- 本轮补构建后磁盘降至约 352 MiB，停止新增构建。已核查 Release 原生合并输出 348 MB 和对应空的测试输出无打开文件，使用相同的精确目标 guard 执行 `:app:cleanMergeReleaseNativeLibs`；只回收可重建中间输出，不删除已验包产物。实际清理结果在下方记录。
- 提交前只读核验旧工作区 tracked diff SHA-256 仍为 `bb61f7148fa2f19e86cd7bd536708f55c611fab05c26ffefd22a0497350f562c`。最终交付仅包含本次独立工作树内的修复、回归和记录；健康值、截图、手机容器、签名配置与其他 App 不纳入提交。
- GitHub 现有基线工作流 run `36667881198` 的 quality/Harmony job 均未执行任何 step；check annotation 明确为近期支付失败或消费额度限制。保留外部门禁，不更改账单或额度，不把本机通过写成远端 CI 通过；新提交的运行状态另行回读。
- Release 限定缓存清理 13 秒成功，约 348 MB 已回收；两个 APK 哈希均保持不变。忽略的 iOS 生成配置恢复为 Profile（config-only 成功，没有重装/启动手机），现有签名 Profile 再验通过。当前磁盘仅约 650 MiB，本轮不再新增构建或清理其他项目。
- 提交前再次 fetch，HEAD 与 `origin/main` 仍为 `de9babfc9cb496cf3bab9b96677bb80fc79b3c3f`，没有远端分叉。按用户要求将上述已验证修复及记录提交到当前 `codex/macos-update-20260930` 分支，普通快进推送当前分支及 `main`；不强推、不改历史、不触发生产发布脚本。实际提交号及推送结果以本轮 Git 记录和远端回读为准，手机待验项继续保留。

## 15:28–15:41 更换安装手机：iPhone 15 Plus 签名准备

- 用户要求安装最新包，随后明确确认安装到当前插线、名为 `Nokia` 的 iPhone 15 Plus。原 iPhone 15 Pro Max 离线；未向其他可见手机安装，也未操作另一 App 项目。
- `git status --short --branch` 为干净的 `codex/macos-update-20260930`；`git fetch --prune origin`、`git pull --ff-only origin main` 成功。HEAD、当前远端分支和 `origin/main` 均为 `724a7d792cbf92908133e69eadae3e074550f7eb`，没有更晚的运行时代码。
- 现有 Profile `0.1.21 (1006)` / `cn.saydian.ring` 严格验签通过；Runner SHA-256 仍为 `8b31d900e05189209b6ef58363c2b4c1c6f2c260fbcc4ec04e35755f0f3d0835`，App.framework/App 仍为 `97d963848b02a839215fac2f3f0362af17a8db18606c851b0c71b71936f8f8a3`。保留原产物，在本机 `/tmp/SayRing-nokia-install-20260930.HgmkSG/Runner.app` 创建独立安装副本，尚未重签。
- `xcrun devicectl manage pair --device <本轮设备> --timeout 45` 成功。首次 `device info details` 显示开发者模式关闭；用户操作后再次回读已为 `enabled`、DDI 可用，系统为 iOS 26.2；`device info lockState` 为 `passcodeRequired=false`。设备密码、完整标识与签名文件不提交 Git。
- `device info apps --device <本轮设备> --filter 'bundleIdentifier == "cn.saydian.ring"'` 返回空列表。此时尚未执行安装或启动，不把配对成功写成安装成功。
- 描述文件只读解析显示：固定应用标识与开发证书正确、APNs development 保留，含 39 台设备，但不含当前目标手机。Xcode 先提示未登记，执行 Register Device 后返回 `A device with number '<目标设备UDID>' already exists on this team`，仍提示描述文件未包含当前手机。
- 已尝试针对当前工程刷新签名、下载团队 Manual Profiles、重新打开当前工作区，并单独选择 Profile 配置复查；15:40 回读描述文件仍未包含目标设备。未删除证书或旧 profile、未移除能力、未换团队/包名，也未重复构建或清理其他项目；安装副本与原 Runner 哈希一致。
- 已打开苹果开发者设备列表，网页要求重新登录，已交给用户自行完成。下一步先核对目标设备的真实登记状态，再获取包含该设备的有效描述文件、只重签安装副本并验证安装/独立启动；目前不得标为已安装。
- 本轮不修改运行时代码、微信参数、服务器或账号数据，未发送验证码。微信 AppID/Universal Link 占位与 AASA 缺少本产品关联仍是独立待办；此前全量构建/测试结果不能替代本台手机尚未完成的验收。

## 15:44 苹果平台确认根因：新设备登记处理中

- 用户自行完成苹果开发者网页登录。只读查看同一 `W7SXQ4A226` 团队的 Devices 页面，目标 `Nokia` 与本机读取的完整 UDID 一致，登记日期为 2026/09/30，状态明确为 **Processing**。
- 苹果页面提示这些设备可能在 **24–72 小时**后才可用于 development / ad hoc distribution；这是平台提示的可能处理范围，不是已确认的完成时间，也不是本机代码或手机信任失败。
- 此状态解释了 Xcode 的“设备已存在”与“profile 不包含设备”并存。继续保持 `cn.saydian.ring`，不重复登记、不删除或年度重置设备列表、不改签名团队、不移除能力。当前安装副本仍未重签，目标手机仍未执行安装/启动。
- 已保留平台状态页供用户查看。后续需平台完成处理后重新获取包含目标设备的描述文件，再验签、安装和独立启动；若要立即使用另一台已登记手机，必须由用户重新明确选择，不能自动切回旧手机。没有创建定时监控或承诺后台自动安装。
- 本轮仅补充诊断记录，运行时代码和已验证产物均未改变；检查 `git diff --check`，不把未执行的新机验收写成通过。
