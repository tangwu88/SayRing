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
