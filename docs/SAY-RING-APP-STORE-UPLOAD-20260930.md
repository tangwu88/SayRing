# Say Ring App Store 构建上传记录

## 最新状态：新图标正式包 1.0 (1008) 已上传并完成苹果处理

- 已快进到最新图标提交 `05fdb66`；用户确认后，默认配置和 8 种语言均补齐准确 SDK 用途说明。39 项图标资源检查、静态分析、29 项发布检查及修复后双时区各 940 项 Flutter 测试通过。旧包和日志已保留。
- 新 `cn.saydian.ring` / `1.0 (1008)` 使用现有 Apple Distribution/profile 完成归档、导出、上传和 Apple 后台处理，已出现在可用构建列表。未新增音乐/语音功能或授权请求。
- 首次 `cn.saydian.ring` / `1.0 (1007)` 在 18:42 的文件传输成功；随后苹果后台处理为 `FAILED`，本次重传日志返回该结果，已不再是“处理状态未知”。
- 首轮 Delivery UUID `10031f38-7227-46df-9598-9ffb8007c6c0` 对应两个 `90683` 阻断：缺 `NSAppleMusicUsageDescription`、`NSSpeechRecognitionUsageDescription`。后台没有可用构建，不能提审或声称上传交付完成。
- 用户要求的第二次原包上传返回 `90168 Invalid package`；原始导出 IPA 和本次 GUI 临时 IPA 的 ZIP 完整性检查均通过，不能仅凭磁盘紧张认定文件在本机损坏。具体结果见末节。
- 本版显式关闭极光推送；商店资料、出口合规声明、审核构建选择、提交审核和 TestFlight 测试分发均未操作。
- 下文保留此前失败检查点，当前结果以本节和末尾重传记录为准。

## 第一轮范围与状态（历史检查点）

- 用户明确只上传正式构建，商店资料稍后自行填写。本轮不修改描述、截图、隐私/年龄/出口合规声明，不添加审核项目、不提交审核、不变更发布策略或启用测试分发。
- 目标为 Say Ring，Apple ID `6816549943`，固定 Bundle ID `cn.saydian.ring`。不得上传到同团队另一份 Saydian App。
- 修改前工作树干净；已检查 origin、fetch 并 `git pull --ff-only origin main`，基线 `8f705d3db7da9c0aeaa36502d0b0421a6a3f1665`。原始脏工作区和原始 SDK 附件未修改。
- **尚未 archive、export 或上传。** 本机缺少 Say Ring 独立极光 AppKey，正式发布检查仍会拒绝；已请求用户补充受保护配置。没有使用 QA 开关、测试 AppKey 或旧 Profile 包冒充正式构建。

## 修改原因与范围

- P1 打包阻断：`validate_xcode_release.sh` 继承旧包名 `cc.saidian.app`，拒绝用户指定的 `cn.saydian.ring`。
- 修复仅涉及 iOS Release 包名校验及对应 Python 测试，不改变 Dart、原生业务代码、接口、健康算法、商城开关或其他平台发布规则。
- 测试增加旧包名/其他产品 ID 拒绝，以及正确 ID 仍必须提供生产推送配置的回归。其他签名、HTTPS、生产 APNs、微信参数检查未放宽。

## 发行签名已准备

- 在已登录 Apple Developer 团队 `W7SXQ4A226` 下，为已有 App ID `W7SXQ4A226.cn.saydian.ring` 创建 `Say Ring App Store Distribution`，类型 App Store，平台 profile ID `D7RFCML674`。
- 使用本机已有 Apple Distribution 证书，SHA-1 `D5350EF7E1EFDCCB4749B8A29C41A49ED9636FDD`；未生成/导出私钥，未吊销或删除证书，未操作 Apple 密码。
- 网页点击下载未确认本地文件落盘；改用 Xcode 现有 `tech@mpcms.cn` 团队的 Download Manual Profiles，随后实际解析本机文件确认安装成功。
- profile UUID `133ab1c8-e232-4a1f-b856-57bd1f3246c9`，到期 `2027-09-24T08:59:19Z`；不限制设备，非开发调试 profile，`aps-environment=production`，支持 Associated Domains，内含证书 SHA-1 与本机身份相同。
- 只在 Git 忽略的 `ios/Flutter/Local.xcconfig` 增加 `[config=Release]` 发行证书和 profile 名称。Debug/Profile 签名不改，配置与描述文件不提交 Git。
- `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS -showBuildSettings -json`：通过 Ruby 白名单输出确认固定 ID、Manual 签名、正确团队/发行证书/profile、生产 APNs。微信 AppID 与 Universal Link 正确展开；不把编译参数正确等同于微信平台/线上链接/真机回跳验收。
- 同一白名单检查确认 `JPUSH_APP_KEY` 仍为空；工作副本、原 SayRing 配置和当前环境未发现已提供的独立生产值。不得复制另一产品密钥或在日志/Git 中保存真实凭据。

## 检查与失败记录

- `python3 scripts/release/test_release_gate.py`：23 项通过。日志中的模拟生产检查使用单测 fixture，不是实际发行包或供应商验收。
- `sh -n scripts/release/validate_xcode_release.sh`、`git diff --check`：通过。
- `env CONFIGURATION=Release SAIDIAN_PRODUCTION_RELEASE=true PRODUCT_BUNDLE_IDENTIFIER=cn.saydian.ring APS_ENVIRONMENT=production /bin/sh scripts/release/validate_xcode_release.sh`：预期返回 1，错误为缺少 `JPUSH_APP_KEY`，不再错误要求旧包名。
- `flutter analyze --no-pub`：通过，0 问题。
- `TZ=UTC flutter test --no-pub --reporter expanded`：939 项通过；日志 `build/sayring-app-store-flutter-utc.log`。
- 上海首轮相同命令在编译测试 dill 时出现 `No space left on device`，不能计为通过；随后向本次精确测试进程发送 SIGINT，未中断其他 App 的调试或构建。保留 `build/sayring-app-store-flutter-shanghai.log`。
- 清理后的第一次低并发重跑因 Flutter 生成的本地化文件被 Gradle clean 任务一并移除而编译失败；保留 `build/sayring-app-store-flutter-shanghai-retry.log`。停止该轮后执行 `flutter gen-l10n`，8 个生成文件全部恢复且与 Git HEAD 无差异，未手改翻译或删除源 ARB。
- `TZ=Asia/Shanghai flutter test --no-pub --concurrency=2 --reporter expanded`：第二次低并发重跑 939 项通过，61 秒；以退出码 0 且日志明确出现 `All tests passed!` 为准。日志 `build/sayring-app-store-flutter-shanghai-retry2.log`。

## 磁盘处理

- 开始约 493 MiB 可用，测试中一度降至 197 MiB；不能在此状态下宣称归档空间充足。
- 只盘点当前 SayRing 构建目录，并通过进程列表、`lsof`、`realpath` 确认待清理 Android 中间文件没有活动构建占用。
- 直接 `rm -rf` 请求被工具拒绝，未执行删除；后续使用下列 Gradle 原生任务清理指定任务的生成输出，不删除整个 intermediates 目录。
- JDK 使用 `/Users/saydian/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home`；`GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=1'`。
- 先执行 `./gradlew :app:tasks --all --offline --console=plain` 确认任务，再执行 `:app:cleanStripDebugDebugSymbols :app:cleanStripReleaseDebugSymbols :app:cleanMergeDebugAssets :app:cleanMergeReleaseAssets :app:cleanCompileFlutterBuildDebug :app:cleanCompileFlutterBuildRelease --offline --console=plain`。成功，6 项清理任务执行；对应日志保存在忽略的 `build/`。
- Android intermediates 从约 643 MiB 降到 249 MiB，可重新构建。安装包输出保留约 520 MiB，iOS Products 保留约 544 MiB；未清理其他项目、用户素材、原始附件或钥匙串。生成本地化文件已按上一节恢复。
- 清理后实际校验原 Profile Runner SHA-256 仍为 `8b31d900e05189209b6ef58363c2b4c1c6f2c260fbcc4ec04e35755f0f3d0835`，原 QA Release APK 仍为 `2ccb84c38186c09b41f4161559bf42511f63e4b7cd6e9cc80a8d01e9cb3d9348`。
- 最终 `df -h /` 约 877 MiB 可用，仍未证明足够完成新 Release 归档和导出。

## 未完成与后续边界

- 缺真实 `JPUSH_APP_KEY`；用户可填入受保护本机配置或提供已保存配置的路径。不需要在聊天或源码中提供 Master Secret。
- 归档前仍需确保足够磁盘空间，核对唯一构建号及商店版本；拟对齐草稿 `1.0`，不能把源码 `0.1.21+1006` 旧 Profile 当作新正式包。
- 本轮未执行 Android Debug/Release、iOS Debug/Profile 全量重建或真机流程；未启动正式归档、IPA 验签/校验和上传。因此完整构建/提交门禁未完成，源码与本记录暂留本地，不宣称已提交 Git、已上传、已可提审或全功能已验收。
- 生产 AppKey 和空间条件满足后继续构建、校验实际签名/权限/版本，上传并回读 App Store Connect 构建接收状态。商店资料和审核仍留给用户。

## 后续明确请求：本版暂不启用极光推送

- 用户随后明确要求“极光推送先不管，直接上传包到线上”。本轮据此构建显式不启用 JPush 的正式 iOS 包，不再把推送 AppKey 作为这一版的必要输入；这不是 QA 模式，也不代表推送通过验收。其余商店资料与审核仍不操作。
- 修改前保留上轮本地变更和 Local.xcconfig 到权限受限备份 `/tmp/SayRing-appstore-checkpoint.NFRNkI/before-upload-no-push.tgz`，再 fetch。`HEAD...origin/main` 为 `0 0`，继续以 `8f705d3` 为基线；不覆盖脏工作树。
- `validate_xcode_release.sh` 增加 `SAIDIAN_IOS_PUSH_ENABLED=false` 显式选项。默认依然要求真实 AppKey；关闭模式同时要求原生 key 为空，并严格解码 `DART_DEFINES`，必须恰有一个空 `JPUSH_APP_KEY=`。非空、重复、缺失或损坏的编译参数一律失败；签名、固定包名、生产 APNs、微信/HTTPS 校验不跳过。
- 现有 `JPushAppNotificationService` 已按空 AppKey 关闭 setup、授权、注册 ID 读取和通知权限请求；仅补充行为回归测试，不改业务代码。iOS 插件注册本身不调用 SDK setup。
- 忽略的 `config/ios-app-store-no-push.json` 显式留空 AppKey，保留批准的 API origin、`/global` 更新路径、同源更新白名单及商城隐藏；Local.xcconfig 只为 Release 注入正式模式和上述关闭选项。未提供或写入虚假供应商密钥。

### 本轮检查

- `python3 scripts/release/test_release_gate.py`：26 项通过，新增关闭推送可构建、Dart/原生冲突拒绝及其余正式门禁不被跳过的测试。
- `dart format test/app_notification_service_test.dart`、`shellcheck scripts/release/validate_xcode_release.sh`、`sh -n` 和 `git diff --check`：通过。
- `flutter analyze --no-pub`：0 问题。
- `TZ=UTC flutter test --no-pub --concurrency=2 --reporter expanded`：940 项通过，71 秒；上海同命令 940 项通过，58 秒。两份日志为 `build/sayring-app-store-no-push-tests-{utc,shanghai}.log`。
- TestFlight 实时回读仍为 Say Ring / `6816549943`，无构建版本；选择 `1.0 (1007)`，未进入另一款 App，也未启用测试分发。

### 保留旧产物并释放编译空间

- 先将整个旧 `build/ios-derived-data/Build/Products` 归档到忽略的 `.build/sayring-preserved-ios-products-20260930.tgz`（约 179 MiB），`gzip -t` 通过；从压缩包抽取 Profile Runner 重新计算 SHA-256，与上轮一致。旧 Debug/Profile 产品可从该归档完整恢复。
- 确认没有其他 iOS 构建后，执行本项目 `xcodebuild ... -configuration Debug -derivedDataPath build/ios-derived-data clean`，`CLEAN SUCCEEDED`；Xcode 清除了该工作副本整个 Build 的可重建产物/中间文件，归档和原始附件不受影响。
- `cmp` 确认 `outputs/apk` 和 `outputs/flutter-apk` 两份 Debug/Release APK 字节一致后，用 `cp -cp` 转为 APFS 写时复制副本，再次 `cmp` 一致。四个路径均保留，安装包内容不变，可用空间升至约 1.7–1.9 GiB。

### 发行构建参数与实际归档

- `flutter build ios --config-only --release --no-codesign --no-pub --build-name=1.0 --build-number=1007 --dart-define-from-file=config/ios-app-store-no-push.json` 成功；这里只生成配置，没有生成无签名发行包。记录了既有 SQLCipher/宇程插件 SPM 和微信模拟器 arm64 支持警告，未擅自升级 SDK。
- Flutter 把 `1.0` 配置规范化为 `1.0.0`，因此实际 Xcode 命令显式设置 `FLUTTER_BUILD_NAME=1.0 FLUTTER_BUILD_NUMBER=1007`，与商店草稿保持一致。
- 从 `xcodebuild -showBuildSettings -json` 获取实际 Runner 设置并直接送入发布检查，结果通过：`cn.saydian.ring`、Release、`CODE_SIGNING_ALLOWED=YES`、Manual、正确 Apple Distribution/profile、生产模式 true、QA false、推送 false。
- 归档命令：`xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS -derivedDataPath build/ios-derived-data -archivePath .build/SayRing-1.0-1007.xcarchive -jobs 2 -allowProvisioningUpdates FLUTTER_BUILD_NAME=1.0 FLUTTER_BUILD_NUMBER=1007 archive`。日志 `build/sayring-app-store-archive-1007.log`；实际 `ARCHIVE SUCCEEDED`，归档约 247 MiB。
- 导出设置在忽略的 `.build/sayring-app-store-export-options.plist`：`method=app-store-connect`，`destination=upload`，manual 固定团队/证书/profile，不自动改构建号，上传符号，不限制为内部测试。只有核对真实归档后才执行上传。

### 实际产物与上传账号阻断

- 归档 App 严格深层验签通过；实际 Bundle ID `cn.saydian.ring`，版本 `1.0`，build `1007`，SDK `iphoneos26.5`，签名 Authority 为 `Apple Distribution: Xuewu Tang (W7SXQ4A226)`。
- 内嵌 profile 不限制设备；签名 entitlements 为正确 app/team、`get-task-allow=false`、生产 APNs 与 `applinks:app.saydian.cn`。没有临时包名、开发证书或 QA 模式替代。
- 归档 Runner SHA-256 `6e4ee0e7da35895f0a69d470d254c093ab4493fd6c552d5dab872802acbd95cc`；Flutter AOT App 二进制 SHA-256 `97fb91484b8497f1ac09bdd4224ac3dd5923af5ff05c23a45c2351d10b675bca`。
- `xcodebuild -exportArchive -archivePath .build/SayRing-1.0-1007.xcarchive -exportOptionsPlist .build/sayring-app-store-export-options.plist -exportPath .build/SayRing-1.0-1007-upload -allowProvisioningUpdates`：返回 70，`Failed to Use Accounts`。苹果工具在上传前未找到拥有 `W7SXQ4A226` App Store Connect 访问权的可用 Xcode 账号；没有上传成功回执。
- 详细日志仅在本机：`/var/folders/_m/xxdk99194t10rxdtxtr47v540000gn/T/Runner_2026-09-30_18-31-57.255.xcdistributionlogs`。只读取匹配失败信息，不复制账号会话/认证数据到 Git。
- App Store Connect 网页实时账号菜单确认是 `tech@mpcms.cn`，与 Xcode 已登记账号一致；浏览器登录不等于 Xcode 上传授权可用。需要在 Xcode 刷新/完成账号授权，而非新建账号或更换团队。
- Native UI 报 Mac 锁定，自动解锁失败；已请求用户手动解锁，若 Xcode 再提示密码/验证码由用户在 Xcode 自行输入。后续一次状态检查仍报锁定；未读取密码、导出凭据、创建新 API key 或绕过锁屏。
- 为保留可交付包，仅将导出目的地改为本机 `export`（单独忽略 plist），再次 `xcodebuild -exportArchive`：`EXPORT SUCCEEDED`。这不是上传成功。
- 正式 IPA：`.build/SayRing-1.0-1007-export/Say Ring.ipa`，40,145,528 字节，SHA-256 `373a43d5619d4be1603158a5fa86285178caf65cc139c55de418a9c136fd989f`。`unzip -t -q` 无错误；解包到 `/tmp/SayRing-ipa-verify.gieGIA` 后再次严格深层验签，实际固定 ID、版本和构建号均正确。
- 当前等待 Mac 解锁后继续刷新上传授权、重试并回读苹果构建记录。未填写商店资料、选择供审核构建、提交审核或开启测试分发；本轮也未进行新的手机操作及 Android/iOS Debug/Profile 全矩阵重建。变更与记录仍保留工作区，尚未宣称 Git 提交门禁完成。

## Mac 解锁后的实际上传

- 用户确认“已解锁”后，先将已有相关变更备份到 `/tmp/SayRing-upload-resume.PtF6WQ/before-upload-result.tgz`；安全 fetch 后 `HEAD...origin/main` 仍为 `0 0`。未覆盖本地变更、原始工作区或其他产品工程。
- Xcode 当前账号与团队可用。通过 Organizer 打开本项目 `.build/SayRing-1.0-1007.xcarchive`，选择 Custom → App Store Connect → Upload，成功获取 Say Ring 的 App Store Connect 记录。不再使用前一轮失败的命令行上传，也未并行发起重复上传。
- 选择既有 `Say Ring App Store Distribution` profile；上传前再次核对正式签名、团队 `W7SXQ4A226`、固定包名、`1.0 (1007)`、arm64、生产 APNs、Associated Domains 和不可调试 entitlement。保留上传符号/剥离 Swift 符号，不自动更改版本/构建号，不选择仅内部 TestFlight。
- 无须退出账号或重新输入 Apple 密码；没有读取/导出登录凭据、私钥或创建新的 App Store Connect API key。
- 18:42:22 ContentDelivery 返回 `UPLOAD SUCCEEDED with no errors, 1 warning`，Delivery UUID 为 `10031f38-7227-46df-9598-9ffb8007c6c0`。Xcode UI 随后显示 `Upload completed with warnings`，不再是上轮账号授权阻断。
- 当前轮原始日志仅存本机 `/var/folders/_m/xxdk99194t10rxdtxtr47v540000gn/T/Runner_2026-09-30_18-37-47.364.xcdistributionlogs`；只在本记录保存白名单结果，不将认证字典或临时签名上传 URL 写入 Git。
- Xcode 提示 14 个第三方 framework 缺少对应 UUID 的 dSYM：ABParTool、GRDFUSDK、JLAV2Lib、JLAudioUnitKit、JLBmpConvertKit、JLDialUnit、JLLogHelper、JLPackageResKit、JL_AdvParse、JL_BLEKit、JL_HashPair、JL_OTALib、RTKLEFoundation、RTKOTASDK。符号上传不完整，但没有阻止本次 App 二进制上传；未伪造 dSYM 或修改厂商二进制。
- 另有 deployment target 警告：本包最低 iOS 13.0，上传工具提示从 2027 年 4 月起需至少 iOS 15.0。它是本次非阻断警告，未擅自缩减当前设备兼容范围。
- 本地导出 IPA 的校验值仅证明本地文件；GUI 对同一已验证归档重新打包上传，不把本地 IPA 的 SHA-256 冒充 GUI 上传文件的哈希。
- 18:43 刷新正确 App 的 TestFlight 网页仍为“无构建版本”；继续只读核对平台接收记录，不重传同一构建、不填写合规声明或开启测试。
- 18:45 关闭完成提示后，Organizer 仍记录 `cn.saydian.ring` / `1.0 (1007)` / `Uploaded with warnings` / `Today at 18:42`；18:46 再次刷新网页尚未显示构建。交付结论为“上传成功，苹果网页处理结果待确认”，不是已发布或已可供审核。
- 本轮未再修改业务代码、安装手机包或重跑 Android/iOS Debug/Profile 全构建矩阵；发布检查、测试和记录变更仍保留本地，不声称 Git 提交门禁或整体验收完成。

## 19:24–19:31 后台复核与独立校验

- 用户反馈 App Store Connect 看不到包后，重新打开正确团队及 App 的 TestFlight、iOS `1.0` 版本页；二者均未出现可用构建，TestFlight 显示“无构建版本”。未修改或保存商店资料。
- 首轮 ContentDelivery 的目标 App ID 精确为 `6816549943`，版本为 `1007`，最终回执确实为传输成功；不是传到另一份 Saydian App。
- Xcode Organizer 对同一归档单独运行 Validate App → Custom，保持固定版本、App Store 类型与原发行 profile；19:29 返回 `Validation completed with warnings`，日志为 `VERIFY SUCCEEDED with no errors, 1 warning`。这一次是独立校验，不是第二次上传。
- 校验仍提示最低 iOS 13.0 的未来要求和 14 个厂商 framework 缺少 dSYM；没有新增阻断错误。原始日志保留在本机 `Runner_2026-09-30_19-26-43.656.xcdistributionlogs`，不将会话或临时签名 URL 写入仓库。
- 苹果开发者系统状态页当时显示 App Upload、App Processing、TestFlight 可用；这只能排除已公告的整体故障，不能证明本 App 的后台处理通过。
- 19:31 再次刷新仍为空，已请用户提供 Apple 针对 `1.0 (1007)` 的处理通知或 ITMS 错误，原因暂未确定；未把“没有错误详情”写成“仍在正常处理”。

## 用户明确要求重传：第二次上传准备

- 用户随后要求“重新上传试试”。仅重传同一正式 `1.0 (1007)`；不改代码、图标、推送开关、版本号、商店资料或审核设置。若苹果返回构建号重复，停止连续重试并保留其原文，先核对服务端接收状态。
- 操作前重新 fetch，`HEAD...origin/main` 为 `0 0`；已有 5 项本地变更保留并备份到 `/tmp/SayRing-upload-retry.f4rJ7U/before-retry-records.tgz`。本轮只追加记录，不覆盖此前代码/测试修改。
- `codesign --verify --deep --strict --verbose=2` 再次通过；本地 IPA、归档 Runner 与 Flutter AOT App 的 SHA-256 均与上文一致。原始归档、SDK 附件及本地导出 IPA 不变。
- 重传前刷新正确 App 的 TestFlight 仍无构建。通过 Organizer 的 Distribute App → Custom → App Store Connect → Upload，关闭自动管理版本号，不选择内部 TestFlight 专用，使用既有 `Say Ring App Store Distribution`。
- 上传前审核页再次确认 `1.0 (1007)`、`W7SXQ4A226.cn.saydian.ring`、arm64、Apple Distribution、生产 APNs、Associated Domains 和 `get-task-allow=false`。等待本次上传结果后再登记回执及网页接收状态。

### 重传结果与首次拒收根因

- 第二次明确执行 Upload 后，Xcode 显示 `Upload failed with errors`。苹果返回 `90168 Invalid package. The uploaded package is corrupt.`，ContentDelivery 最终为 `UPLOAD FAILED with 1 error`；没有本轮上传成功回执，也没有构建号重复错误。
- 本次日志目录：`/var/folders/_m/xxdk99194t10rxdtxtr47v540000gn/T/Runner_2026-09-30_19-34-57.535.xcdistributionlogs`。只解析 JSON 中公开的构建 ID、版本、状态、错误码与错误说明；不输出认证头、assetToken 或临时签名 URL。
- 关键新证据：此日志第 182 行起的 `buildUploads` 返回首轮 ID `10031f38-7227-46df-9598-9ffb8007c6c0`，`cfBundleShortVersionString=1.0`、平台 IOS、`state.state=FAILED`，上传时间 `2026-09-30T03:42:20-07:00`。因此首次 Xcode 的传输成功并未转化为后台构建处理成功。
- 该首轮记录的 `state.errors` 明确列出两个 `90683`：缺少媒体资料库用途 `NSAppleMusicUsageDescription` 和语音识别用途 `NSSpeechRecognitionUsageDescription`。另有缺后台定位用途 `NSLocationAlwaysAndWhenInUseUsageDescription` 的 `90683` 警告，以及未来最低 iOS 版本 `90068` 警告；错误与警告分别记录，不能混为同等阻断。
- 源码 `ios/Runner/Info.plist` 确实没有这三个键。对正式 Runner 二进制执行 `xcrun nm -u`，发现 `MPMediaQuery`、`SFSpeechRecognizer`、`SFSpeechURLRecognitionRequest` 等引用，与苹果扫描结果一致；本次未确认所有引用的具体 SDK 对象来源，不猜测必须启用新功能。
- 第二次 GUI 临时 IPA 为 `/var/folders/_m/xxdk99194t10rxdtxtr47v540000gn/T/XcodeDistPipeline.~~~6s2Xc6/Packages/Say Ring.ipa`，40,145,691 字节，SHA-256 `45b7d5077f6a26027aba9263e203c837eb801d60c5d6bb0ccaee3dc05f918828`。该临时 IPA 与原始本地导出 IPA 各自执行 `unzip -t -q` 均无压缩数据错误；GUI 重新签名/打包后的哈希不应直接与原导出文件相等。
- 开始重传前磁盘约 390 MiB，可用空间在准备完成后约 220 MiB；磁盘紧张是风险，尚不能据此确认 `90168` 的唯一原因。没有删除源文件、归档、IPA、SDK 附件或其他项目内容。
- 本轮没有新增或编造隐私用途声明，没有为了消除错误启用媒体、语音或后台定位功能，没有改动业务代码或重新提交审核。应先确认实际 SDK/API 需求，移除不需要的引用或补充真实准确的用途配置，再生成并验收新包；继续重复上传原包无法消除已确认的首轮 `90683`。
- 本轮只修改本记录及索引，`git diff --check` 通过；此前发布脚本和测试修改仍保留本地，未声称 Git 全矩阵提交门禁完成。

## 使用 Git 最新图标重新打包：准备记录

- 用户明确要求使用 Git 已更新的图标重新打包上传 App Store Connect。目标仍为 `cn.saydian.ring` / Say Ring / `6816549943`，拟使用新的 `1.0 (1008)`；保持本版不启用极光、商城隐藏，不修改商店资料、合规选项或提交审核。
- fetch 后确认 `origin/main` 新增 `05fdb66d2fe2f9384fc80391c9d38486b3034999`（`feat: replace Say Ring app icon`）。先把既有 5 项发布修复/记录备份到 `/tmp/SayRing-new-icon-upload.0i4tmt/before-icon-sync.tgz`，并保留精确 stash `7c6503369f1a9e3d00ddbff1953d8f0df299a534`，再对干净当前分支执行 fast-forward。恢复 stash 时仅索引顶部冲突，已保留新图标与上传两条记录并解除冲突，未丢弃旧修改或 stash。
- 本机视觉检查确认 1024 图标是白底黑色戒指和 Saydian 字样，不是旧图标。`java scripts/GenerateLauncherIcons.java --check` 通过，39 项资源一致；源图 SHA-256 `2db9100a4cc9544d057ce555e54dd87456119f991f9e2b356afd9c9296b56238`，master SHA-256 `136fab869f84fc132ab1d2a04c240c5a8e1fa2fb242800add8d448ce86875f16`。这仅证明源资源，尚未声称新归档或平台构建已验证。
- 进一步二进制定位发现媒体/语音引用来自玉成 `DFUnits.framework` 与 `YCProductSDK.framework`；第一方代码未发现媒体资料库或语音识别授权请求/入口。未修改厂商二进制或新增虚构功能。已请求确认保留 SDK、只补充真实 SDK 接口用途说明的方案，批准前不写入相关隐私文案。
- 本机锁定的 `geolocator_apple 2.3.14` 支持 `BYPASS_PERMISSION_LOCATION_ALWAYS=1`；其 iOS 源码在宏开启时仍保留前台定位请求，排除 Always 分支。当前仅有前台位置声明，后台模式只包含蓝牙；不通过添加未经需求确认的 Always 声明开启后台定位。

### 本轮缓存清理与保留

- 清理前检查没有正在编译的 Flutter、Xcode 或 Gradle 进程。对本项目执行 `xcodebuild ... -configuration Release -derivedDataPath build/ios-derived-data clean`，`CLEAN SUCCEEDED`；可用空间从约 219 MiB 仅升至 553 MiB，仍不足以安全归档。
- 将 `build/app/outputs`、`build/reports` 和已有全部顶层 `.log` 移到忽略目录 `.build/preserved-before-icon-1008-20260930/` 后，执行项目原生 `flutter clean --scheme Runner`，成功清除本工作副本可重建的 `build/`、`.dart_tool/` 和生成配置，可用空间升至约 2.7 GiB。旧日志路径应在该保留目录查找，旧 APK 位于其中 `android-outputs/`。
- 旧 `1007` xcarchive、正式 IPA、旧 Debug/Profile 归档及原始 SDK 均未删除；其他项目未清理。没有重复使用被工具拒绝的 `rm -rf`，也未通过其他删除 API 绕过限制。
- `flutter pub get --offline` 成功恢复生成配置；`pubspec.lock` 和本地化文件没有产生 Git 差异。本轮缓存可由项目构建重新生成，安装包和原始素材无需恢复。

### 新图标基线验证结果与当前边界

- `flutter analyze --no-pub`：0 问题。`python3 scripts/release/test_release_gate.py`：26 项通过。`shellcheck scripts/release/validate_xcode_release.sh`、`sh -n`、`git diff --check` 均通过；Python 输出中的发布参数来自 fixture，不是实际生产服务结果。
- `TZ=UTC flutter test --no-pub --concurrency=2 --reporter expanded`：940 项通过，54 秒；上海同命令：940 项通过，43 秒。日志分别为 `.build/sayring-icon-1008-tests-utc.log` 和 `.build/sayring-icon-1008-tests-shanghai.log`。这些结果验证当前最新图标基线与原有发布修复，不代表尚未实施的用途说明已验收。
- 清理后重新校验原 `1007` IPA SHA-256 仍为 `373a43d5619d4be1603158a5fa86285178caf65cc139c55de418a9c136fd989f`，保留目录中的原 QA Release APK 仍为 `2ccb84c38186c09b41f4161559bf42511f63e4b7cd6e9cc80a8d01e9cb3d9348`。
- 正确团队 / Say Ring 的 TestFlight 刷新后仍提示提交构建版本以开始测试，没有可用构建。本轮未再重传已确认失败的旧包；待用户确认用途说明方案后，再实施、校验实际新归档图标/签名、上传并回读处理结果。
- 当前未执行新 Android Debug/Release、iOS Debug/Profile 或手机流程；按用户要求继续暂停手机操作。新归档、IPA、App Store 后台处理与 Git 全矩阵提交门禁均不得标为完成；现有发布代码和完整记录继续保留在本地工作树，未强推或覆盖远端。

## 用户确认后的 1008 修复与上传

- 用户明确确认保留 SDK、仅补充真实用途说明、不新增功能或授权请求，再使用新图标打包上传。商店资料、出口合规、审核和测试分发仍不操作，手机操作仍暂停。
- 修改前再次检查 status、remote 并 fetch；`HEAD` 与 `origin/main` 均为 `05fdb66d2fe2f9384fc80391c9d38486b3034999`，无新增远端提交。此前 5 项本地变更完整备份到 `/tmp/SayRing-icon-1008-confirm.BGNREU/before-privacy-fix.tgz`，未覆盖脏工作树。
- P1：Apple 后台扫描已链接的玉成媒体/语音 API 后，以缺少用途说明 `90683` 拒绝处理。预期新包具备准确、非空的两个键，且与本版实际未开放相关功能的边界一致。
- 拟仅修改 `ios/Runner/Info.plist`、8 个 `InfoPlist.strings` 和对应发布回归测试，保留所有 SDK 二进制、路由、业务/健康逻辑和现有权限请求代码。后台定位目前仅为警告，本轮不增加 Always 定位声明或后台能力。
- 两项说明明确“集成的设备 SDK 包含相关接口，本版未开放这些功能，用户可以拒绝授权”，不把未实现的音乐/语音功能写成已开放。实际系统授权仍由既有调用决定，添加用途键本身不触发权限请求。

### 配置修复与回归

- 先增加 3 项发布回归测试，旧配置运行出现预期红灯：2 个默认键及 8 种语言的 16 个键均缺失，共 18 个子断言失败；保留 `.build/sayring-1008-privacy-red.log`。后台权限未扩张的测试原本通过。
- 在默认 Info.plist 与 8 个已有语言文件补齐说明后，`python3 scripts/release/test_release_gate.py` 全部 29 项通过（`.build/sayring-1008-privacy-release-green.log`）。测试检查描述非空、SDK/未开放功能/可拒绝的真实边界、英文默认一致及不新增 Always 定位/麦克风/后台模式。
- `plutil -lint ios/Runner/Info.plist ios/Runner/*.lproj/InfoPlist.strings` 的 9 个文件通过。ShellCheck、shell 语法和 `git diff --check` 通过；Java 图标工具再次确认 39 项资源与 `05fdb66` master 一致。
- 本次没有修改 Podfile、厂商二进制、权限调用或功能页面。新增配置的 Apple 后台接收结果仍须等实际上传后验证，单元测试不能替代。
- 修复后 `flutter analyze --no-pub` 再次 0 问题；UTC / 上海低并发完整 Flutter 测试各 940 项通过，分别 42 / 44 秒。日志 `.build/sayring-1008-privacy-analyze.log` 与 `.build/sayring-1008-privacy-flutter-{utc,shanghai}.log`。
- `flutter build ios --config-only --release --no-codesign --no-pub --build-name=1.0 --build-number=1008 --dart-define-from-file=config/ios-app-store-no-push.json` 成功，只生成配置；保留既有插件 SPM 和模拟器架构警告，未升级依赖。Podfile.lock、SDK 与源本地化生成文件无新差异。
- 以实际 Xcode Runner build settings 执行发布检查，退出成功；已确认 ID、`1.0 (1008)`、正式证书/profile、Manual、codesign 允许、production true、QA false、push false。归档串行执行，指定 `.build/SayRing-1.0-1008.xcarchive`，不覆盖旧 1007 归档。

### 1008 实际归档与 IPA

- `xcodebuild ... FLUTTER_BUILD_NAME=1.0 FLUTTER_BUILD_NUMBER=1008 archive` 返回 0，日志 `.build/sayring-1008-archive.log` 明确 `ARCHIVE SUCCEEDED`；归档签名时间为 2026-09-30 20:03:33。
- `codesign --verify --deep --strict --verbose=2` 通过。实际包为 `cn.saydian.ring` / `1.0 (1008)` / arm64 / `iphoneos26.5`，Authority `Apple Distribution: Xuewu Tang (W7SXQ4A226)`；内嵌既有 profile UUID `133ab1c8-e232-4a1f-b856-57bd1f3246c9`，没有设备列表，`get-task-allow=false`、生产 APNs 与 `applinks:app.saydian.cn` 均正确。
- 归档默认 Info.plist 与编译后的中文 InfoPlist.strings 都实际包含新的两项说明。Runner SHA-256 `3d317a03afdcb9ff54066008a5f67833ad34732d36053eafc8f342f98d6d0125`；Flutter AOT App SHA-256 `37675b32e497d1960d5b5e9b72448ae1a06ede02aa09050dd5b3fe7c827b8784`。
- 直接预览 iOS 优化 PNG 时工具不支持 CgBI 格式；没有改动归档资源，而是用 Xcode `pngcrush -revert-iphone-optimizations` 生成忽略目录下的检查副本。Java ImageIO 对该副本和 Git `Icon-App-60x60@2x.png` 的每个 ARGB 像素比对完全一致，120×120；人工查看也是白底黑色戒指与 Saydian 字样。
- `assetutil --info` 确认实际 Assets.car 的 iPhone/iPad/marketing AppIcon 齐全、Opaque=true，包含 1024×1024 商店图标。没有仅检查源码后就宣称包内图标正确。
- 本地导出命令使用既有 `.build/sayring-app-store-local-export-options.plist`，输出 `.build/SayRing-1.0-1008-export`，返回 `EXPORT SUCCEEDED`。IPA 40,555,754 字节，SHA-256 `8c4be7142896ddca834137f45ff7bdc2119a8c912ac9e4663fba8a785631022c`。
- `unzip -t -q` 无错误；解包到 `/tmp/SayRing-1008-ipa-verify.uali8m` 后再次严格深层验签通过，Info 版本/ID/用途键正确，IPA 内 Assets.car 与已检查归档逐字节相同。GUI 上传将对相同归档重新打包，不能把本地 IPA 哈希冒充传输文件哈希。
- Xcode 文件选择器首轮点选误打开了一个空构建日志，立即只关闭该窗口、未改文件；随后用“前往”精确定位新归档，Organizer 回读明确 `1.0 (1008)`、`cn.saydian.ring`、arm64，旧 1007 仍单列为 Upload failed。
- 上传选择 Custom → App Store Connect → Upload；关闭自动管理版本号，未选择 internal testing only；使用既有发行 profile。上传回执与后台处理结果后续单列，不以归档或导出成功替代。

### 1008 上传回执与后台状态

- Xcode 上传前审核页再次确认 Team `Xuewu Tang`、Apple Distribution、Say Ring App Store Distribution、arm64、`1.0 (1008)`、生产 APNs、Associated Domains 及 `get-task-allow=false` 后才执行 Upload。
- 20:12 左右 ContentDelivery 返回 `UPLOAD SUCCEEDED with no errors, 1 warning`；Delivery UUID / build upload ID 均为 `d92a5b0a-e772-4f95-a650-ebd42a1673ef`。Xcode 显示 `Upload completed with warnings`，本次未再出现 90168 或缺用途说明 90683。
- 非阻断警告仍是从 2027 年 4 月起最低目标需 iOS 15，以及 14 个闭源厂商 framework 缺 dSYM；未伪造符号文件或在本版擅自提高最低系统版本。
- 正确团队、正确 Say Ring App 的 TestFlight `构建版本上传` 已出现 `1.0 (1008)`，创建时间 2026-09-30 20:12；随后实时刷新确认状态由“正在处理”变为“完成”。同页旧 `1007` 仍明确为“失败”。
- 版本 1.0 可用构建区已显示构建 `1008`，上传日期为 2026-09-30 20:14；因此本次不只取得传输回执，也确认苹果后台处理完成并生成可用构建。
- 构建当前提示“缺少出口合规证明”。用户此前明确只上传包、其他资料后续提交，因此本轮未点击“管理”、未填写出口合规或其他商店资料，也未建测试群组、选择审核构建或提交审核。

### 提交前跨平台构建门禁

- 上传完成后继续按仓库门禁串行构建，不对手机做操作。iOS 无签名 Profile 和 Debug 均使用 `1.0 (1008)`、固定 ID 与当前源码成功，日志分别为 `.build/sayring-1008-profile-build.log`、`.build/sayring-1008-debug-build.log`，均明确 `BUILD SUCCEEDED`。
- 每次 iOS 构建后使用 Xcode/Flutter 原生 clean 清理本工作副本可重建缓存，避免磁盘耗尽；正式归档、IPA 和忽略目录下日志均保留。未清理其他项目或设备容器。
- Android Debug 首轮 55 秒失败，任务 `:app:mergeDebugAssets` 报 Gradle `9.1.0` 的精确 transform 缓存 `7d449599654a801d656c79251a8c1bc3` 被外部修改；不是源码编译错误，日志 `.build/sayring-1008-android-debug.log` 保留。
- 确认无 Gradle/Java 进程占用后，仅将该 49 MiB 的损坏、可重建缓存移动到可恢复备份 `/tmp/SayRing-gradle-transform.dC9mFx/`，未删除整个 Gradle 缓存或绕过失败；随后以同一命令重跑。最终 Debug/Release 结果在完成后追加。
- Android Debug 同命令重跑 158 秒成功，实际 APK 为 `cn.saydian.ring` / `0.1.21 (1006)`，SHA-256 `6118273aaad9583b1c52ce055ea8ad74723ee31cd3fe1d33322c132a4f69dec0`。这是提交门禁产物，不是本次 iOS `1008` 上传包，也未安装到手机。
- `./gradlew :app:testDebugUnitTest ...` 41 秒成功；8 份 XML 合计 32 tests / 0 failures / 0 errors / 0 skipped。既有 Kotlin/Gradle/SDK XML 版本警告保留，不借本次上传任务升级工具链。
- Android QA Release 使用显式 `SAIDIAN_ALLOW_QA_RELEASE=true`，254 秒成功；实际 `cn.saydian.ring` / `0.1.21 (1006)`、双 ARM，APK SHA-256 `42abf1eb2e16433e5da4150345753837020d096591de44023f24488848452bd1`。v2 验签、16 KiB zipalign 通过，清单不含后台定位、读取电话状态或查询全部应用权限；它是 QA 签名门禁包，不是 Android 商店正式包。
- 本轮手机操作仍按先前约定暂停，没有把编译结果写成真机通过。App Store 正式上传的唯一目标仍为已处理完成的 iOS `1.0 (1008)`。

### 1008 iPhone 15 Pro Max 覆盖安装与启动验证

- 用户随后明确要求将最新版重新安装到当前 USB 连接的苹果手机。执行前再次 fetch，当前分支、`origin/codex/macos-update-20260930` 与 `origin/main` 均为 `113b2223bc6563b0c70f6631d50ba012999992d2`，工作树干净；目标只选中连接中的 iPhone 15 Pro Max，不触碰其他已配对或不可用设备。
- 手机上原有 Say Ring 是 `cn.saydian.ring` / `0.1.21 (1006)`。App Store Distribution IPA 没有设备列表，不能当作真机安装包；因此基于同一当前源码和同一 `1.0 (1008)` 版本，生成单独的 Profile 设备包，不更改 ID、商店版本、上传状态或审核资料。
- 为留出构建空间，先确认没有 Flutter/Xcode/Gradle 编译进程，再仅执行本项目原生 `flutter clean --scheme Runner` 和离线 `flutter pub get --offline`；可用空间从约 1.0 GiB 升至约 4.0 GiB。既有 App Store 归档、IPA、SDK 和其他项目均未删除。
- `flutter build ios --config-only --profile --no-codesign --no-pub --build-name=1.0 --build-number=1008 --dart-define-from-file=config/ios-app-store-no-push.json` 成功；随后以目标设备执行 `xcodebuild ... -configuration Profile -allowProvisioningUpdates ... build`，日志 `.build/sayring-1008-profile-device-{config,build}.log`，结果 `BUILD SUCCEEDED`。
- 设备包 `Runner.app` 严格深层验签通过：`cn.saydian.ring` / arm64 / `1.0 (1008)`，`Apple Development: Xuewu Tang (9K5C433U49)`、Team `W7SXQ4A226`，内嵌 `iOS Team Provisioning Profile: cn.saydian.ring`（UUID `3ba4cada-8e17-4e61-892d-211b4ca649b8`，`get-task-allow=true`）。这是仅用于已注册真机调试的设备签名，与已上传的 App Store Distribution 正式包（`get-task-allow=false`）分开记录。
- `xcrun devicectl device install app` 覆盖安装成功；随后 `xcrun devicectl device process launch --terminate-existing cn.saydian.ring` 成功。安装后设备清单回读为 Say Ring / `cn.saydian.ring` / `1.0 (1008)`，进程列表仍可见新安装路径的 `Runner.app/Runner`，证明安装与启动均已完成。
- 本轮仅验收签名、覆盖安装、版本回读与冷启动，不将此结果扩展为登录、微信、蓝牙扫描、R21 连接或健康测量通过；这些需要保持戒指在旁的单独真机功能验收。

### 用户确认取消 iPad 支持后的 1009 归档与上传

- App Store Connect 对原 `1008` 的审核页强制要求 13 英寸 iPad 截屏；用户明确决定“不提供 iPad 版本，提交审核上架”。这项选择改变已发布二进制的受支持设备范围，因此不把 iPhone 截图伪装为 iPad 截图，也不复用仍声明 iPad 的 `1008`。
- `Runner` 的 Debug/Profile/Release `TARGETED_DEVICE_FAMILY` 全部改为 `1`，并移除 `UISupportedInterfaceOrientations~ipad`；保留 iPhone 竖屏声明、固定 ID、蓝牙能力、微信/SDK、商城隐藏与此前的隐私用途说明。没有修改 SDK 二进制或健康业务逻辑。
- 新增发布门禁 `test_ios_targets_iphone_only`：读取 Info.plist 断言无 iPad 方向键，并解析 Xcode 项目中全部设备族设置只为 `1`。`plutil -lint`、`python3 scripts/release/test_release_gate.py`（30 项）与 `flutter analyze --no-pub` 均通过。
- 使用同一 App Store 发布配置构建 `1.0 (1009)`。`xcodebuild ... archive` 成功，归档为 `.build/SayRing-1.0-1009-iphone-only.xcarchive`；深层验签通过，实际为 `cn.saydian.ring` / arm64 / `Apple Distribution: Xuewu Tang (W7SXQ4A226)` / `get-task-allow=false`。编译后 Info.plist 的 `UIDeviceFamily` 仅为 `1`，iPad 方向键不存在。
- 本地导出的 IPA 位于 `.build/SayRing-1.0-1009-iphone-only-export/Say Ring.ipa`，压缩校验通过，SHA-256 `75352d6eb29862e898dad7b7243eca6dce5cabfac9819c1a46dca1c3c28f7918`。
- 通过 Xcode Organizer 选择 App Store Connect 的推荐上传方式，上传完成且无错误。非阻断警告仍为未来 iOS 最低版本要求，以及 14 个闭源厂商 framework 缺少 dSYM；没有伪造符号文件或在本次提交中擅自升高最低系统版本。App Store Connect 构建列表已出现 `1.0 (1009)`，当前由苹果后台处理；处理完成、选择 1009 与点击“添加以供审核”另行记录，不能提前标为已提交审核。
