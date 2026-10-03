# Say Ring CoolWear 原包接入

## 原因和范围

- P1：HR01、HR05、K80、R7、R7Y、R7Pro 在 iOS 没有实际 CoolWear 原生桥接，单补名字不能搜索或握手。安卓名称修复已在 d89f28e。
- 修改前从 cd40514 干净分支 fetch、push、pull --ff-only 成功；只改 Say Ring，保留 cn.saydian.ring、最新图标、仅 iPhone 和现有账号/绑定/健康数据。不替换现有审核包。
- 独立解压只读原包，锁定 Framework 哈希。变更 Flutter 平台注册、iOS 桥接/校验、Xcode 签名嵌入、测试和来源记录；不改 Android SDK 二进制、QRing 或账号协议。

## 实施和边界

- 使用 SDK SearchPeripheral、F618/F818 服务扫描，识别确认型号和有限后缀。只连接本轮扫描的精确 UUID；SDK completed、真实信息和功能开关返回后才上报已连接。
- 手动心率/血氧按 manualHr/showO2 开启；真实数据还需校验数值、SDK 时间和当前测量代次。指令 ACK 不生成健康数据；不输出原始健康/设备日志。
- 超时/取消清理原生命令及连接，拒绝迟到回调。未确认断开前不允许下一连接；账号切换沿用 Flutter 清理门禁。厂商全安装历史自动重连关闭。
- iOS type 9 是混杂子包，不是历史完成。本轮不把未知睡眠/历史/HRV/运动及控制写成支持或同步成功。
- Word 说明用文档技能只读提取。依赖未提供 bundled LibreOffice，未渲染或修改原 DOCX；Header/Demo 交叉核对接口。技能影响仅限阅读原厂说明。

## 验证记录

- 首轮只读猜测 CEManager.h、Swift QRing 文件及旧脚本路径不存在，已用 rg 找实际文件。长清单/Word 提取截断后按相关章节和头文件分段读取。
- 首轮集成 patch 因记录索引标题不匹配而原子失败，核对工作树后重试，不覆盖历史日志。
- 本轮测试、1030 构建/签名和设备结果后补。尚未做六型号真实扫描/握手/有效测量，不标记完整设备验收。
- 首轮 Foundation 测试编译因 NSCAssert 宏遇到数组文字逗号而失败；只给测试表达式加括号，后续重跑记录。补蓝牙初始化等待、两服务扫描后按目标原服务连接、断开确认超时和单次错误回调门禁。
- Foundation 策略测试已通过；iPhoneOS arm64 原生桥接语法编译通过，原厂 Header 两项 nullability 警告保留。首次 Flutter 定向测试因共享 pub 缓存中 vector_math、flutter_lints 等依赖已缺失而加载失败，未运行用例；正在通过 pub get 恢复锁定依赖，不误报业务代码失败。

## 1030 初轮结果及防护复核

- pub get 已恢复锁定依赖，未升级 pubspec.lock。定向测试 34/34，UTC 和 Asia/Shanghai 全量各 1099/1099；分析无问题，格式化 180 个文件无变更。发布工具 31/31、原生日志隐私 9/9、CoolWear 原生策略和 7 项桥接契约、QRing 映射及 9 项 Framework arm64 检查通过。契约/合成测试不等于实物测试。
- iOS 1030 Profile/Debug 串行构建成功。Profile 深度签名验证通过，cn.saydian.ring、1.0.0 (1030)、UIDeviceFamily=[1]；从手机 1028 原位覆盖成功，启动 PID 34347，后续仍存活。未卸载或清理账号及健康数据，尚未逐页核对其显示。
- 复核发现潜在 P1：SDK 抛异常时旧分支可能先完成扫描再报错、挂起其他请求；小数功能开关会按 integerValue 误判。仅收紧已知 0/1 开关、保证每个回调最多一次、异常时明确失败和保留取消屏障；未映射的自动心率历史不暴露成已接入功能。修改前 fetch 成功，无远端新增；未拉取脏工作树，完整相关源码备份至 /private/tmp/sayring-coolwear-hardening-20261003.r5yPWB/source-before-hardening.tar.gz。
- 后续 1031 必须重建重测，不把 1030 安装结果当成修正版验收。Android 两项构建及原生测试仍在执行，本轮不操作其他 App 或 App Store 审核。
- Android 原生 39/39 已通过。1030 APK 首轮失败于 copyFlutterAssetsDebug 的文件 mode 复制；目标文件可写且没有 ACL/immutable flag，两个 Gradle 任务曾共用同一 Flutter 资源目录。结束原生测试后串行重跑 1031，原失败日志保留，不声称已构建成功。
- 1031 防护首轮 iPhoneOS 语法编译发现 block 与 NSNull 三目操作类型不兼容（4 项编译错误）。只替换为非空回调逐项添加；主动中止尚在编译的本轮 Profile 进程避免无效构建，未终止其他项目。后续使用新的重试日志，不覆盖首轮失败记录。

## 1031 修正版验证和交付

- `dart format --output=none --set-exit-if-changed lib test`：180 文件、零变更；`flutter analyze --no-pub`：零问题。`TMPDIR=/private/tmp TZ=UTC flutter test --no-pub` 与 Asia/Shanghai 再跑全量，各 1099/1099。34 项定向证据在 1030，全量覆盖相同定向用例。
- `xcrun clang -fobjc-arc -framework Foundation test/native_coolwear_policy_test.m ...`：确认型号/能力/数值及回调最多一次策略通过；iPhoneOS arm64 `-fsyntax-only` 重新通过。`node --test tool/test_coolwear_ios_integration.mjs`：8/8；`node --test tool/test_native_log_privacy.mjs`：9/9。QRing Foundation 映射和发布 Python 31 项原有测试通过；非本轮修改文件，无假造设备/服务测试。
- Android `./gradlew :app:testDebugUnitTest`：39/39，零失败/错误/跳过。1031 APK Debug 和显式 `SAIDIAN_ALLOW_QA_RELEASE=true` Release 串行构建通过，均为 cn.saydian.ring、1.0 (1031)、两种 ARM ABI；内部 QA Release v2 签名、16 KiB ZIP 对齐验证通过，不是 Android 商店正式签名包。当前 ADB 无手机，不标记安卓安装通过。
- iOS `flutter build ios --profile/--debug --no-pub --build-name=1.0 --build-number=1031 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=` 串行通过。Profile 为 cn.saydian.ring、1.0.0 (1031)、仅 iPhone；深度签名验证通过，Runner 链接并嵌入 BluetoothLibrary。原 ZIP 和仓库 SDK 二进制哈希仍与来源记录一致。
- 使用已核对 WorkspacePath 的本仓库 DerivedData 串行 `xcodebuild ... -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build-for-testing`：TEST BUILD SUCCEEDED，RunnerTests.swift 实际编译。只编译，不是完整 XCTest/页面 UI 执行；原厂 Header/dSYM/插件警告未删改。
- 1031 Profile 原位覆盖 iPhone 15 Pro Max 成功，未卸载、清账号或健康数据。三轮独立冷启动 PID 34400 / 34402 / 34404，分别在约 39 / 22 / 35 秒后的进程检查仍存活。手机镜像提示设备正在使用，未锁定用户手机或接管界面，登录/绑定/健康显示及六型号真实扫描/握手/测量继续待验。
- 构建期间磁盘不足 1 GiB。强制删除命令被工具拒绝，未执行；改用非强制删除仅清理本仓库已结束的 `build/ios/Debug-iphoneos`、`build/ios/Release-iphoneos` 和 Android `merged_native_libs/debug`，释放约 1.4 GiB 可用空间。安装包/日志/原 SDK/源码与手机数据保留；中间产物可重建。未清理其他项目或用户原始归档。
- SDK 强制纳入 Git 后原厂 Header 空白导致完整 `git diff --cached --check` 报告。为保持厂商签名资源字节不变，只给该包 Headers 配置 whitespace 属性；第一方文件照常检查，未改全局配置或原厂文件。属性修改前 fetch 无分叉，Git source checkpoint 为 c6f430d3888075acba3c8d828f7f04a07fb2bf4b。
- 生产睡眠服务 4abbcb4 已部署且两个 ready/API/Worker/后台版本一致；原报告不再无限分析，实际终态仍 FAILED / aiGenerated=false / 无正文，safe code 为 sleep_ai:invalid_content。后台只读页面确认“生成失败”，仅状态截图本机留存、未进 Git。服务端正用合成输入继续定位解析/校验原因；没有重置、手动重试原报告或代改授权。

### 本机测试包

- `.build/SayRing-1.0-1031-Profile.app`：已原位安装，桌面独立启动使用此 Profile，不使用脱离工具的 Debug。
- `.build/SayRing-1.0-1031-android-debug.apk` SHA-256：15695f043ab8848e782c93112ee5e8fbc600b099b1eb1606b0cabf4538819ff7。
- `.build/SayRing-1.0-1031-android-internal-qa.apk` SHA-256：152ca3804fee6c33d1daaea1b75b8cd722548a66946c3aa38c52e6b3c593914d。
- 日志统一本机 `.build/coolwear-1030-*` / `.build/coolwear-1031-*`；不提交设备清单、账号、原始健康值、照片、截图或安装包。远端 Git 与新 CI 结果后续追加；没有上传/替换/撤回现有 App Store 审核。

## 远端和补充验证（19:56 CST）

- a6ad89217e8ac2b570d7055a49308f6901e484b5 已普通推送至 origin/codex/macos-update-20260930，fetch 后本地/远端 SHA 一致、工作树干净。没有强推、改仓库可见性或提升成已经实环验收的 main 基线。
- 新 CI [37120753039](https://github.com/tangwu88/SayRing/actions/runs/37120753039) 的质量及双时区 Harmony 契约已通过；远端 Android/iOS 构建仍在执行，不能记为整个新 CI 已通过。
- 只读比较原包 Android 1.4.0 AAR 和仓库现用 AAR，二者 SHA-256 均为 ad482d5d69b99941d906038794165c1d479e5e038713954d9ca22059083d0f5f，无需再次替换或更改 Android SDK。
- 补做本机 iOS unsigned Release 首轮被既有 Production 签名门禁正确拒绝：Local.xcconfig 的 Release 仍指定 Production=true / QA=false，Shell QA 环境不能覆盖 Xcode build setting。未改本机正式签名文件或放宽脚本；改用 xcodebuild 明确参数 SAIDIAN_PRODUCTION_RELEASE=false / SAIDIAN_ALLOW_QA_RELEASE=true / CODE_SIGNING_ALLOWED=NO，内部 QA Release BUILD SUCCEEDED，日志明确 non-production QA，cn.saydian.ring / 1031 / UIDeviceFamily=[1]。此包未签名、未安装、未上传 App Store；手机仍为已验证的签名 Profile。
- 服务端用明确标注的最小合成睡眠输入实际调用当前 glm-5.3-flash，一次 HTTP 200、约 16.7 秒，JSON 和生产解析器 ACCEPTED。没有调用真实健康数据、没有修改原 FAILED 报告、尝试次数或授权；现阶段未复现参数/解析器缺陷。服务端继续在独立分支补充固定枚举的失败类别日志，不输出内容/健康值/凭据，测试和发布另计。

## CoolWear 与 QRing 健康名称统一（20:07 CST）

- 用户补充：CoolWear 类设备参考 LuckRing，HRV 为心率变异性、温度为皮肤温度，页面沿用 QRing 标准。修改前 c64f219 工作树干净，fetch/pull --ff-only 成功；原 ZIP、Framework、健康数据和其他 App 保持不动。
- P2 复现：同一戒指的健康首页/趋势已经显示皮肤温度，但自动检测、提醒及报告缺项仍显示体温；HRV 标题只有缩写或使用另一种排版。预期为统一名称和单位，不能让用户误认成核心体温或压力。
- 涉及域模型显示名、中文本地化资源、健康详情/趋势/报告、设备自动检测与新提醒文案及相应测试；只变展示，不改 wireName、SQLCipher 数据、服务端参数、单位换算、阈值或算法。
- HRV 统一主标题为“心率变异性（HRV）”，单位仍为 ms；皮肤温度为 ℃，无足够个人基线不生成“温度波动”。压力是独立设备算法值，不把 HRV 数字直接充当压力或准备度分数。
- 远程关爱仍保留原接口的标题键和跨产品温度语义，不将来源未知的其他设备体温擅自改成皮肤温度。紧凑心电摘要保留 HRV 缩写，详细指标使用完整名称；旧已保存提醒不重写。
- 只读复核 [LuckRing](https://apps.apple.com/cn/app/luckring/id6472891975) 和 [QRing](https://apps.apple.com/cn/app/qring/id6473672621) 公开页面；公开说明不能证明某型号能力。使用此前已记录的用户 LuckRing 视频/真机与本次原 SDK 交叉核对，不复制专有评分或猜测未映射 iOS HRV/温度/历史协议。
- 此轮拟构建 1032；静态、完整 Flutter、双端构建和原位安装结果后补，1031 的测试不冒充新版验收。
- 原包接入 a6ad892 的远端 CI 37120753039 最终全部通过（包括 Android Debug/Release/39 项原生测试和 iOS 三模式/RunnerTests 编译）；不代表新标签源码已经通过。
- 标签首轮定向测试中 10 项通过、两个测试文件加载失败，分析同时发现报告页缺少域模型导入。补齐明确 import 后使用新的 retry 日志重跑，首轮日志保留；没有把编译失败写成业务功能通过。
- 修复导入后定向 87 项通过，新增的两项窄屏流程测试点击发生在滚动后的布局帧更新前，坐标仍在屏外，未进入趋势页；不是设备/页面验证通过。测试补滚动后的 pumpAndSettle 和实际趋势路由断言再跑，未降低溢出检测或静默忽略 tap 警告。
- 后一次定向 88 项通过，窄屏两项已实际进入趋势页，但测试错误地期待不含“分析”后缀的标题；改为当前趋势页 AppBar 内验证完整指标名称，保留实际路由、点击与异常断言。
- 窄屏空数据夹具不会构建仅有真实记录时才显示的温度解释卡；测试改为核对实际“该时间段暂无数据”，不为满足断言加入伪造健康记录。皮肤温度非核心体温的语义仍由既有域解释测试覆盖。

### 1032 本机回归和安装

- `flutter gen-l10n` 生成中文资源；`dart format --output=none --set-exit-if-changed lib test`：181 文件、零变更；`flutter analyze --no-pub`：零问题。最终定向测试 90/90，新增 5 项名称/单位/协议契约及 HR05、R21 合成窄屏大字流程、报告摘要用例；合成设备不能作为实环能力证据。
- `TMPDIR=/private/tmp TZ=UTC flutter test --no-pub`：1107/1107。首轮 Asia/Shanghai 停在 +1093，主测试进程和编译器无 CPU 活动，未查明原因；确认 PID 和日志归属后只对本轮进程发 SIGINT。它退出 0 并输出 +1094 / All tests passed，但用例不足，明确不接受为全量通过，原日志保留。
- `TZ=Asia/Shanghai flutter test --no-pub test/global_localized_pages_test.dart` 隔离复核 24/24；双端构建结束后串行重新执行完整 Asia/Shanghai 测试：1107/1107，约 62 秒。版本变更的授权负例仍正确拒绝，未修改或放宽授权逻辑。
- Android 1032 Debug 和显式内部 QA Release 两种 ARM ABI 构建成功；QA Release v2 签名和 `zipalign -c -P 16 -v 4` 通过，aapt 核对 cn.saydian.ring / 1.0 (1032)。Debug SHA-256 为 c42b2f1b76333f9cff7b161fcb303b778470682b582df27f81e8eba776763005；QA Release 为 b24f849384fd1df1f2ea4045c94b1d1b7c36c10058d5ecbe2cc34d3a5550b5e1，不是商店正式签名包。构建结束后串行 `cd android && ./gradlew :app:testDebugUnitTest`：39/39，零失败、错误或跳过。
- iOS 1032 Profile、Debug 按生产 API 配置串行构建成功；签名 Profile 为 cn.saydian.ring / 1.0.0 (1032) / UIDeviceFamily=[1]，深度签名验证通过。使用 devicectl 从 1031 原位覆盖成功并回读安装列表确认 1032；没有卸载、改包名或清除数据，没有操作 App Store。
- 核对保存包的 UIDeviceFamily 时，一次 `plutil -extract ... json` 遗漏 `-o -`，改写了本机生成包的 Info.plist。立即从同次 Profile 构建的原 Info.plist 恢复，cmp 字节一致，深度签名再次通过，后续只读提取均显式输出 stdout。发生在安装之后，源码和手机内已安装包未受影响，未重新签名掩盖错误。
- 三次独立冷启动均产生本应用 PID；分别在约 53 / 50 / 72 秒后仍存活，执行路径为已安装 1032 Profile。镜像仍提示 iPhone 被使用而超时；未锁定或接管用户手机，真实界面、账号/绑定显示和六型号新 SDK 扫描/测量继续待验。
- Foundation CoolWear 策略通过；`node --test tool/test_coolwear_ios_integration.mjs tool/test_native_log_privacy.mjs`：17/17，发布 Python 工具 31/31。原 ZIP、Framework 二进制哈希与来源记录一致；pubspec.lock、图标和其他 App 未变。
- 1032 构建期间仅清理已结束的本仓库 Debug/旧 Release 及 Android native-lib 中间目录，均可重建，保留原 SDK、源码、既有包和全部失败日志；释放空间用于重跑，不将磁盘压力未经证实地当作停滞根因。日志为本机 `.build/coolwear-1032-*`，不入 Git。

### 1032 远端核对（20:29 CST）

- 标签源码与上述验证记录提交 e35e9c856cb99597fc76ccf97ffb709e977f57c6，普通推送至 origin/codex/macos-update-20260930；fetch 后本地/远端 SHA 一致，工作树干净。追加记录前再次 fetch/pull --ff-only 为 Already up to date，未更改 main、仓库可见性或现有 App Store 审核。
- [新 CI 37122947611](https://github.com/tangwu88/SayRing/actions/runs/37122947611) 已针对精确源码 SHA 启动，当前 in_progress，尚不能标记为远端全通过；本机完整测试/双端构建与 iPhone 安装独立通过。
- iOS CoolWear 当前仅扫描、元数据/功能握手、电量、手动心率/血氧通路已实现；HRV、皮肤温度、历史及睡眠等高级数据链路尚未接入验证，继续 fail closed。本轮统一名称不表示这些通路或六型号实物验收已经通过。

## iPhone 实际界面调试与历史同步入口修复（20:45 CST）

- 本轮基线 544ab63ce0bdee4e231137da441d393b93570ede，工作树干净，fetch/pull --ff-only 成功。仅 Say Ring，保留登录、绑定和健康数据，不卸载、不操作 App Store。
- P2：设备页 HR01 已连接时点击“同步数据”，实际提示“设备已连接，但历史数据同步失败”；预期是未实现的历史通路不开放操作、不误报读取失败。原包 iOS 历史映射仍未实现，本次不伪造同步成功或健康记录。
- 涉及 DeviceCapabilities、CoolWearPolicy、控制器和设备页：增加独立于后台能力的显式历史同步标志，iOS CoolWear 返回 false，既有旧桥接保持原前台同步契约。控制器在命令前阻止不支持的历史调用；设备页显示未开放的禁用入口，手动心率/血氧不变。补字段往返、初次连接/手动操作和 UI/原生回归。
- 镜像可用后已查看真实健康首页、心率趋势、设备及设备信息；当前 HR01 真实名称/电量/固件/SDK 地址可见。此前已有实际心率记录，不把该记录当成本轮新触发测量；未取得新的六型号扫描和高级数据验收。设备页面和运行日志仅本机保留，不提交地址、照片、账号或健康值。
- 首次 `flutter run --profile --no-build` 仍触发 Xcode 编译且沿用 pubspec 默认 1006，确认进程归属后取消，未安装；`flutter attach --profile` 等待 VM 服务未连接，随后取消，旧 App 数据未动。改将已验证的 1032 开发 Profile 包成 IPA，使用 `flutter run --profile --use-application-binary=...`，明确跳过编译并原位覆盖；实际取得 Dart VM Service/DevTools，调试器连接成功。
- 本次拟构建 1033；全量检查、签名、修正版原位安装和现场复核后补。未完成的验收继续标待验。
- P2 新复现：HR01 实际已连接，权限页却显示蓝牙“未允许”。核对当前 permission_handler_apple 源码和 Pod 构建，权限策略宏默认关闭，状态读取退化为默认 denied。修改 Podfile 只启用已声明实际用途的蓝牙、使用期间位置、相机及通知策略，不添加相册/联系人/麦克风/始终定位权限，不请求新的系统授权；通过真实系统状态读取复核。再次 fetch 无新增，脏源码仅本机完整备份后继续，未覆盖其他修改。
- 首轮定向 90/90、静态零问题；第一轮 UTC 全量 1108 通过、3 失败，均为既有 Fake 控制器没有实现新增 UI 读取的 capabilities getter。补齐测试夹具 null 未知能力，保留原重连、解绑、无新数据的行为断言，重新完整运行，不降低生产门禁。
- 本轮心率指令正常进入测量，75 秒未取得有效值，显示贴合手指后重测提示且可关闭。没有写入替代结果，当前佩戴及实际新结果未确认，不能标记本轮心率测量成功。
- 权限定向首轮 111 通过、1 失败，测试误写 locationWhenInUse 通道编号 4，实际插件枚举为 5；修正合成夹具的编号和说明，不修改生产映射。已开始的无效全量重跑单独取消，保留日志，再使用新日志执行。
- 权限状态断言修正后均成立，但第二轮在 Flutter invariant 检查时仍因平台 override 仅在 addTearDown 重置而失败；改为与既有 iOS 用例相同的 try/finally，在用例返回前还原，不忽略测试异常。
- 最终定向 112/112，静态零问题，Foundation 策略通过，Node 原生/隐私 19/19；Podfile Ruby 语法检查通过，Podfile.lock 仅 Podfile 校验和变动，插件版本不升级。发布 Python 首轮实际 30 通过、1 失败，日志为 fixture 文件改名失败 No space left on device；外层命令最后执行 grep 退出 0 不能替代 unittest 结果，明确更正初次统计，释放缓存后独立重跑。
- 1033 开发签名 Profile 构建 58.8 秒通过，cn.saydian.ring / 1.0.0 (1033) / UIDeviceFamily=[1] / 深度签名通过。原位安装并回读 App 清单确认 1033，实际 Dart VM Service/DevTools 已连接。首页旧账号、绑定及既有记录保留；HR01 重新显示已连接，历史同步入口明确禁用，点击不产生失败；权限页读取蓝牙“已允许”、位置“未允许”，没有代开位置授权。状态截图仅本机保存。
- 1033 Debug 第一轮明确失败于 macOS No space left on device，未覆盖手机 Profile。同期 UTC 全量停在 +164、进程无 CPU 活动，未完成，不接受为通过；只取消本轮进程并保留日志。清理本仓库可重建的 Flutter 构建缓存及失败 Debug 中间目录后改为串行重跑，不清除原 SDK/安装包/源码/手机数据；不将停滞原因未经验证归因于磁盘。
- 标签基线 e35e9c8 的远端 CI 37122947611 最终各项 success（质量、双时区 Harmony、Android、iOS）；新 1033 源码仍以本轮新测试和构建结果独立验收。
- 释放已结束且 WorkspacePath 精确匹配本仓库的 Xcode 中间缓存，Debug 重跑 35.1 秒通过、cn.saydian.ring / 1033 / 深度签名通过，未安装 Debug 替换独立可启动的 Profile。发布 Python 重跑 31/31，静态零问题，串行 UTC 1112/1112、Asia/Shanghai 1112/1112 均通过。未删除任何其他项目缓存或原始文件。
- Android Debug 1033 构建通过。随后 QA Release 首轮 stripReleaseDebugSymbols 明确 No space left on device；保留失败日志，先保存已验证的 Debug APK，再清理已结束的 Android debug native-lib 中间产物，串行重跑 Release 和原生测试。不绕过 APK ABI、签名或隐私门禁。
- 个人资料只读加载成功，未替换当前头像或代保存；关于页无重复说明，客服外部 launchUrl 本轮返回失败，页面提供明确复制回退。外部浏览器/微信最终打开仍未验收，不用自动测试的 mock 成功冒充现场通过。

### 1033 最终验证与留存（21:08 CST）

- 新增 5 项回归；最终 `dart format --output=none --set-exit-if-changed lib test` 为 181 文件、零变更；`flutter analyze --no-pub` 零问题；UTC 和 Asia/Shanghai 完整 Flutter 各 1112/1112。定向 112/112、Foundation CoolWear 策略通过、Node 原生/日志隐私 19/19、发布 Python 工具 31/31；均保留此前失败及中断记录。
- 1033 Android QA Release 重跑 49.5 秒通过；`./android/gradlew :app:testDebugUnitTest -p android` 39/39、无失败/错误/跳过。两 APK 为 cn.saydian.ring / 1.0 (1033)、arm64-v8a + armeabi-v7a；内部 QA Release v2 签名及 16 KiB ZIP 对齐通过。未安装到安卓、未作为正式商店签名提交。
- `.build/SayRing-1.0-1033-android-debug.apk` SHA-256：71339b182376faf2ce05ee0f7dcf7d209ff3955d7887e071f7703df1d7a8dbcb；`.build/SayRing-1.0-1033-android-internal-qa.apk`：5ceacc89f95f81342e4c6847fbd20d13f0236991b0766f84083b77eb6b3b6976。只留本机，未入 Git。
- `.build/SayRing-1.0-1033-Profile.app` 和开发签名调试 IPA 已留存，手机仍是 1033 Profile、原数据保留；活动 VM 本机只读 getVM 实际返回 VM / 1 个 isolate，调试器持续在线。未关闭 VM 验证、开放远程端口、卸载或清数据，也未变动现有 App Store 审核。
- 现场查看首页、心率趋势/超时弹窗、设备和信息、我的、个人资料、关于、权限、客服、远程关爱及睡眠空状态；远程关爱没有重复标题。没有真实睡眠样本，未生成睡眠/AI 假数据，未代改授权、关爱成员或个人头像。头像保存、真实新心率/血氧值、睡眠时间轴及三轮物理距离重连不标记本轮通过。
- 源码及记录按现行分支普通提交/推送，原厂 SDK 和原 ZIP、pubspec.lock、图标及其他 App 未变；不把尚未六型号实环验收的 SDK 升级为已接受 main 基线。新 CI/远端 SHA 核对后续追加。
- 源码提交 71a95214479471012f356afd98b01cba44ff0a82 已正常推送 origin/codex/macos-update-20260930；再次 fetch 后本地/远端一致、工作树干净。新 CI [37125186964](https://github.com/tangwu88/SayRing/actions/runs/37125186964) 为该精确源码 SHA、当前 in_progress，未声称远端所有构建已通过。追加记录前 pull --ff-only 为 Already up to date；末次活动 VM 仍在线，保留调试会话供继续验收。

## 待处理问题续验（21:20 CST）

- 基线 06907c0，干净工作树 fetch/pull --ff-only 成功；继续仅 Say Ring，原包和手机已有登录、绑定、记录保持不动。首次只读检查旧本机 VM 端口已关闭，curl 连接失败，后续 JSON 解析亦失败；手机 Profile App 界面仍正常，不能把调试端口不可用写成 App 崩溃。将以新预构建 Profile 恢复调试。
- HR01 本轮从页面分别启动心率和血氧，均收到新 SDK 有效结果，点击完成后记录数增加、趋势及首页可见；不提交实际数值、设备地址或账号。上轮 75 秒无结果保留，尚不能确认其原因，不因本轮成功而删除超时记录。
- P2 复现：联系客服外部系统打开仍返回失败，只出现复制提示；增加同一精确 HTTPS 地址的系统内置浏览器回退，外部成功时不重复打开，两种方式均失败仍提供复制。复制反馈应替换旧失败横幅，不排队掩盖复制结果；保留后台电话、公众号和链接常量，不代拨电话或发消息。
- P2 复现：CoolWear iOS 明确禁用历史同步，但首页和睡眠空页仍提示佩戴后同步；修改 pages.dart、sleep_detail_widgets.dart 的提示，在已完成能力握手且历史同步为 false 时说明未开放，已有缓存仍显示，读取失败仍明确报告。未知能力与已集成 QRing/Android 的正常引导不变，不伪造睡眠成功。
- 用文档技能只读核对原厂 DOCX、旧 Markdown 和 Header。旧 HRV heartNum 的具体语义由设备决定；新 RRI 扩展类型仅声明而未给完整结果/单位映射；皮肤温度 tempNum 已是摄氏度，不应再除十；sleepInfos 为状态变化和分包，只发一次。没有本轮真实睡眠样本、确认结束/分包持久化通路前不开放全部历史，后续仍需独立实现验收。未改原文档，未交付新 DOCX；本机依赖没有 bundled LibreOffice，不对文档排版作验证结论。
- 只读命令一次猜测不存在的睡眠文件、一次 shell 通配无匹配而失败，均改用 rg 定位；DOCX 首轮提取范围过大被截断，后续按实际相关段落读取，没有将截断内容当完整协议。
- 本轮拟构建 1034；测试、构建、安装和现场浏览器结果后补。现有 App Store 审核不动；服务端 AI 诊断发布由原任务唯一 Actions 处理，不并行手动发布、重置或重试真实报告。
- 1034 首轮定向 104 通过、2 失败：新增首页断言尚未滚动到懒加载睡眠卡；已保存睡眠值在总计和结构各显示一次，测试误期待仅一处。只修正测试可视流程及准确数量，保留实际页面/提示断言。静态首轮另报新增测试单行 if 缺花括号，已修正；原日志保留，重跑不覆盖。第一次修正 patch 因格式化后的 if 行不匹配而整体未应用，核对后重试。
- 第二轮定向 105 通过、1 失败：滚动找不到目标，核对实际入口后更正上述初步归因——新增夹具错误使用“全部健康数据”HealthPage，而首页实际是 DashboardPage。改为真实页面并限定其滚动器，不改生产路由。过早启动的本轮 UTC 全量仅运行部分用例，确认进程归属后 SIGINT 停止，保留记录，不计通过。静态重跑已零问题。
- 最终定向 106/106；格式化 181 文件、零变更；静态零问题；串行 UTC 1119/1119（49 秒）、Asia/Shanghai 1119/1119（40 秒）通过。新增 7 项涵盖外部成功不重复开浏览器、失败/异常回退、页面销毁不再跳转、两次失败精确复制且反馈替换、未开放睡眠的首页/空页/缓存保留和真实读取错误。首次只读猜测旧 workflow 文件不存在，改用现行目录定位，不改 CI。
- 本机 Node 原生/隐私 19/19、Foundation CoolWear 策略通过、发布 Python 31/31。只删除本仓库已结束的 Flutter AOT 缓存和 Android release native-lib 中间目录，约 752 MiB，可重新构建；保留 1031–1033 安装包、日志和原始 SDK，空闲空间恢复约 2.5 GiB 后串行开始 1034 iOS Profile。没有清理手机或其他项目。
- 1034 iOS Profile 68.1 秒、Debug 36.7 秒串行通过，深度签名有效；cn.saydian.ring / 1.0.0 (1034) / UIDeviceFamily=[1]，开发签名 get-task-allow=true、团队与 Associated Domains 保持不变。Profile 独立留存并包装开发调试 IPA，SHA-256：1b44ae9ac854dec2cc975356df7821ed31b4f6e7a3266c0671399b4ea62c7532。首次 codesign --entitlements - 输出不是 plist，管道解析失败；改为 --entitlements :- 正确读取，不修改签名。Debug 未安装，手机仅覆盖 Profile；预构建 flutter run 不重新编译，App 清单确认 1034，VM/DevTools 已连接，登录、精确绑定与 4 条健康记录仍在。
- 客服真机：点击官方链接后内置系统浏览器显示 work.weixin.qq.com，并出现打开微信确认；进入微信后实际到达赛电客服会话。没有发送消息、拨号或上传健康数据，含私人消息的界面不保存入 Git。此前外部打开失败保留，本轮回退路径已实测；离开客服时镜像工具发生 timeoutReached，随后镜像显示正在重新连接，不将其归因于 Say Ring 崩溃。
- Profile/Debug 完成后核对 Xcode info.plist 的 WorkspacePath 精确属于本仓库，无其他 iOS 构建；清理其 652 MiB 中间缓存及 228 MiB 本仓库 Flutter 缓存，都是可重建产物，保留已签名 App/IPA、所有日志和手机数据。开始串行 Android 1034 Debug/内部 QA Release。1033 源码 CI 37125186964 已全部 success，仅作为旧基线证据，不代替 1034 本轮门禁。
- Android 1034 Debug 23.7 秒、显式内部 QA Release 60.6 秒串行通过，均为 cn.saydian.ring / 1.0 (1034)、arm64-v8a + armeabi-v7a；两包签名验证通过，QA Release v2 签名与 16 KiB ZIP 对齐通过。原生 `JAVA_HOME=...temurin-17.jdk/Contents/Home ANDROID_HOME=.../Android/sdk ./android/gradlew :app:testDebugUnitTest -p android` 16 秒通过，XML 汇总 39/39，无失败、错误或跳过；bash -n、shellcheck、actionlint 均退出 0。本轮没有安卓安装，不把内部 QA 签名当正式商店包。保存 Debug APK 后，仅清理已结束的本仓库 debug native-lib 中间产物约 1061 MiB，Release 构建未因磁盘失败。
- Debug APK SHA-256：60fdf3a337011628424c108727296da44cfbcfb4ad06c8c23a75d9d8c7a10804；内部 QA Release APK：de4320f275e01158d860e96ca92bb1a95d69f44ecbf6565f9c6e71e6291ae9b2。两者仅保存在 .build，不入 Git。
- 1034 现场复验：客服可返回 Say Ring，复制链接立即显示新反馈；HR01 自动恢复连接、真实电量与能力返回，未点重连，连接后不出现重连按钮。首页和睡眠空页均显示同步暂未开放，而不是要求执行不可用同步；原账号、绑定、既有 4 条健康记录保留，重新打开趋势确认旧测量已加载，没有丢数据。此过程不等同三轮物理距离或后台锁屏重连验收。
- 首个 Flutter 会话实际记录 Lost connection to device，旧端口 curl 不可达，未加错误门禁的 JSON 解析再次失败；iPhone 仍 connected、当前 Say Ring 进程仍在，镜像恢复后 App 界面可操作。独立 `flutter attach --profile -d ...` 仅等待连接，确认本轮 PID 后 SIGINT 取消，不计附加成功。使用同一验证过的预构建 1034 开发 IPA 恢复运行，覆盖安装 13.9 秒，未重新编译/卸载/清数据；新 VM 的只读 getVM 实际返回 VM、1 个 isolate。DevTools 打开工具返回 queued，仅确认调试器在线，不伪称面板已经显示，也不把连接中断未经证据写成 App 闪退。
- 21:36 CST 对服务端仅做只读检查：唯一 Actions 37124706014 的 verify/resolve 成功，deploy 仍在镜像接收；线上 /global/health/ready 为 ready，revision 4abbcb4。未重启服务、并行部署、改变授权或重试真实睡眠报告；诊断提交 d67a232 尚不能写成已上线或原报告已成功。
- 最终 1034 在活动调试会话中分别新发起心率、血氧，均收到有效 SDK 返回并点击完成；心率记录从 3 增至 4，血氧从 1 增至 2，趋势和首页同时更新。没有用旧读数冒充新测量，Git 不记录真实读数、账号、地址或私人截图。原 SDK ZIP/Framework SHA-256 再次一致。1034 当前仅开发 Profile 安装/调试验证，不更新 App Store 审核包；头像真实选择保存、真实睡眠/小睡、六型号逐一验收及三轮物理距离/锁屏/蓝牙开关重连仍待验；上轮测量超时原因未确认，不能写成已定位修复。

### 1034 可重复命令及留存

- iOS Profile、Debug 严格串行：`flutter build ios --profile --no-pub --build-name=1.0 --build-number=1034 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=`；相同参数将 `--profile` 换为 `--debug`。日志分别为 `.build/coolwear-1034-ios-profile-20261003.log`、`...-ios-debug-...`，均退出 0。
- Android Debug、QA Release 严格串行：`flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0 --build-number=1034 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=`；Release 改 `--release` 且显式 `SAIDIAN_ALLOW_QA_RELEASE=true`。JAVA_HOME 指向本机 Temurin 17、ANDROID_HOME 指向本机 Android SDK；没有放宽正式签名门禁。日志分别为 `.build/coolwear-1034-android-debug-20261003.log`、`...-android-qa-release-...`。
- `dart format --output=none --set-exit-if-changed lib test`、`flutter analyze --no-pub`、`flutter test --no-pub test/say_ring_recovery_sleep_support_ui_test.dart test/ui_shell_test.dart`；最终定向为 retry2 日志。`TMPDIR=/private/tmp TZ=UTC flutter test --no-pub`、`TMPDIR=/private/tmp TZ=Asia/Shanghai flutter test --no-pub` 分别为 UTC retry、Shanghai 日志，各 1119；初轮失败/取消日志均保留。
- 原生与发布：`node --test tool/test_coolwear_ios_integration.mjs tool/test_native_log_privacy.mjs`、`xcrun clang -fobjc-arc -framework Foundation test/native_coolwear_policy_test.m -o .build/coolwear-1034-policy-test` 后执行该二进制；`python3 -m unittest discover -s scripts/release -p 'test_*.py'`；`bash -n scripts/release/*.sh`、`shellcheck scripts/release/*.sh`、`actionlint`；APK `aapt dump badging`、`apksigner verify --verbose`、`zipalign -c -P 16 -v 4` 和 iOS `codesign --verify --deep --strict` 均通过。本机 Python/Node 使用已配置用户运行时，原生 UI 测试不冒充真实样本验收。提交前按实际目录更正初稿隐私测试文件名，不将不存在的文件名作为已运行证据。
- 实机预构建调试命令：`flutter run --profile --no-pub --use-application-binary=.build/SayRing-1.0-1034-Profile-debug.ipa -d <已验证 iPhone UDID> --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=`。独立终端会话日志、App 清单与只读 VM JSON 仅在 .build，真实设备标识不写入版本文档。主分支不提升为已完成高级 SDK 验收的基线，提交推送当前工作分支，远端 SHA 后补。
