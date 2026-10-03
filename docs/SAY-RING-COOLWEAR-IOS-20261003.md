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
