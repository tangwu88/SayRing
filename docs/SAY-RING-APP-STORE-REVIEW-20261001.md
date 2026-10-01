# 2026-10-01 Say Ring 拒审整改与重新提交记录

## 范围与先决条件

- 用户要求先完成仅 Say Ring 的服务器本地头像上线验证，再分析右侧 App Store Connect 拒审、构建新版本并重新提交审核。目标是尽量一次通过，不将审核决定当作可保证结果。
- 修改前 `origin/codex/macos-update-20260930` 与本地 HEAD 均为 `7daf53cca6b9d11a9d2229b56456bc1fce9cb009`，`git fetch --prune origin` 成功；工作树已有自动重连、睡眠、客服及头像专用接口等未提交改动，全部保留，不执行脏树 pull。
- 当前 App Store 审核中的 `cn.saydian.ring` 为 iOS App 1.0，已将原被拒的构建 1009 替换为已上传的 1013；审核状态仍为“已拒绝／问题未解决”，尚未回复 Apple 或重新提交。

## 拒审原文所需材料

- App Store Connect 提交 `adc6af1e-20e4-4aff-8fbd-ce27e514f8e1` 标记 2.1.0 Performance: App Completeness；Apple 实际消息标题为 `Guideline 2.1 - Information Needed - New App Submission`，未指认某个具体崩溃。
- Apple 要求：最新系统真机从启动开始的典型流程录屏；若适用，要包含注册、登录、账号删除、UGC 举报/屏蔽、付费功能。还需说明用途/用户、设置和主功能、可用审核账号或素材、核心外部服务、地区差异、适用的授权材料。回复审核消息，并在 App 审核信息备注保留同一套内容。
- 提交前须用新包在受支持实体设备完成 QA。录屏、附件、账号、线上服务和版本应彼此一致；截图必须展示当前真实 App，而不是已经隐藏的商城或旧页面。

## 当前核对到的独立风险

1. 版本页“需要登录”未勾选、审核备注为空；Release 没有 Debug 的快速体验入口，主流程需要账号。线上验证码登录只支持中国大陆号码，当前没有可向 Apple 提供的已验收审核账号。
2. 用户已确认从销售地区移除法国，并申报“标准加密算法、非专有算法；不在法国分发”。2026-10-01 在 App Store Connect 将法国取消勾选并保存；供应范围由 175 改为 174 个国家/地区，法国单项回读“未供应”。1013 构建元数据中“App 使用非豁免类加密”为“否”。
3. 线上 `auth/capabilities` 开启微信主账号登录；iOS 尚无符合 Apple Guideline 4.8 的等效隐私登录选项。已向用户询问保留微信时增加 Apple 登录，还是本次 iOS 暂时隐藏微信。
4. App Store 隐私标签目前公开显示“未收集数据”；实际 App 有账号、头像和健康同步服务。其隐私政策 URL 为通用“Saydian赛电”政策；App 内国际法律文档仍标为 `Pre-release`，内容称短信服务未启用，与线上能力不符。必须核对实际采集/用途并取得合规确认后更新，不写未经确认的声明。
5. 当前截图 A1 展示“Say Ring 商城”入口，但本版默认隐藏商城；应在新 iPhone 包上重新采集并替换所有过时截图。
6. App Store Connect 的 Mac 和 Vision Pro 兼容分发原本开启，与此前仅 iPhone 范围不符；本轮已关闭并回读“已保存”。175 个销售地区暂未更改。
7. 国际服务当前 `WORKER_OUTBOUND_PAUSED=true`。源码中到期注销由该 Worker 调度，暂停时不会执行。现有注销请求会立即停用账号并撤销会话，但七天后的实际数据删除尚未得到保障；不能以界面测试代替端到端注销验收，也不能为修复 Say Ring 而擅自启动其他 App 共用的全部后台任务。

## 隐私填报事实清单（草案，不可直接发布）

- 账号接口处理手机号或邮箱、会员 ID、昵称、性别、生日、身高、体重、头像；Say Ring 专用头像上传和公开 URL 读取在国际 API 上。实际线上开关/保存结果必须另验。
- `uploadHealthBatch` 将步数、距离、热量和睡眠、心率、血氧、血压、血糖、体温、HRV、压力等已取得的健康记录发送到账号所属国际 API；新的详细睡眠时间轴仍只在本机 SQLCipher 保存，不等于全部健康数据不出设备。
- App 可在用户主动请求天气时读取位置并请求天气服务；可在用户同意且功能配置有效时初始化 JPush。iOS 构建包含微信 SDK、JPush、地理定位和多个戒指厂商 SDK。是否在当前正式包中实际初始化、各 SDK 独立收集哪些数据及其用途，尚需逐一核实；不能据此勾选“没有收集数据”。
- 戒指蓝牙扫描与连接处理精确设备标识和能力信息；资料头像来自用户主动选择的照片。账号删除有服务端接口及“我的→账号设置→注销账号”入口，但新包必须真机演示成功及失败提示。
- App Store 隐私答案、公开政策和 App 内法律文本涉及法律/合规声明。以上仅是源码审计事实，未取得完整 SDK 数据声明、运营留存规则和最终销售地区确认前，不发布或签署准确性声明。

## 送审门禁与状态

| 门禁 | 当前状态 |
| --- | --- |
| Say Ring 头像服务端双读取上线，持久卷、备份恢复、专用账号上传、重启复读 | 新 revision、持久卷、备份恢复和写入开关已验；真实登录账号上传、头像回读及重启复读仍待验 |
| 登录方式与发行地区一致，微信符合 4.8 或本版不暴露 | 等用户选择；不可擅自删除已要求的微信功能 |
| 正式隐私政策、App 内法律文本、App 隐私标签一致 | 待实际数据处理盘点和合规确认 |
| 审核专用账号或其他可复现登录方式 | 待准备及独立验证；不在 Git 记录凭据 |
| 新 iPhone 构建、签名、安装、主流程、账号删除及戒指功能 | 1012 开发签名 Profile 已原位覆盖 1010 并启动；旧登录、资料和历史健康记录可见。头像上传、戒指、睡眠及注销仍待逐项验收；1009 旧证据不可外推 |
| 最新 iOS 真机录屏、当前真实截图、审核附件 | 待采集；不可伪造屏幕或样本 |
| App Store Connect 新构建处理完成、资料保存、回复与重新提交 | 未执行 |

## 本轮追加验证与发布事故（2026-10-01）

- 客户端先执行 `flutter build ios --config-only --debug --no-codesign --no-pub --build-name=1.0 --build-number=1011 --dart-define-from-file=config/ios-app-store-no-push.json`，再串行执行 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/ios-derived-data -jobs 1 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`。两步成功；实际 Info.plist 为 `cn.saydian.ring`、构建 `1011`、`UIDeviceFamily=[1]`。这是无签名主机构建，尚未安装真机，也不能上传 App Store。日志：`.build/sayring-1011-ios-debug.log`。
- 构建前本机仅余约 1.6 GiB。核对无 Gradle/Flutter 构建和打开句柄后，删除本工作树 `.build/task-gradle-cache-20261001/caches` 约 5.2 GiB 的可重建缓存；源码、SDK、APK、归档未删除。`df -h /` 升至约 6.9 GiB，Debug 构建后约 4.9 GiB。该缓存不能从废纸篓恢复，重新构建 Android 时需重新下载。
- 国际服务发布分支快进后，服务器 `saydian-global-auto-deploy.service` 自动构建期间系统盘由 2.6 GiB 可用降至 0，旧版 `/global/health/ready` 仍返回 ready、revision `660cf1b70ad26eb1553751c0475084e12ae037cf`。为了避免持续满盘，停止该次服务，并暂时停止定时器；没有关闭现役容器或开启头像写入。
- 核对 Docker 镜像与容器占用后，删除数份未被容器使用的旧国际 API 镜像及无标签构建层；一次误选的 `daf00ce4c842` 实际被国内生产 API 使用，Docker 默认保护拒绝删除，未强制。随后 `docker image prune --force --filter until=1h` 只回收一小时前的无标签镜像，Docker 报告回收 1.612 GiB；最终 `df -h /` 显示约 7.8 GiB 可用。删除的镜像/构建缓存可从镜像仓库重新拉取或重建，未触碰卷、数据库或用户文件。
- 在容量恢复后，手动启动一次 `saydian-global-auto-deploy.service` 重新发布；本条记录时尚在构建中、定时器暂停。最终结果见下节，不能把推送代码当成上线完成。

## 发布与新增流程检查续记

- 重新发布最终成功：公网 `/global/health/ready` 返回 `ready`、revision `6ea9dd9de91c3f27a452efc1a23ad2f77e88a1b5`；专用头像上传路由匿名请求返回 401，国内健康检查仍为 200。生产头像卷、备份容器、一次测试文件恢复演练及清洁备份的 SHA-256 均已验证；仅国际环境的 Say Ring 本地头像写入已开启，定时器恢复 active/enabled。详细证据见 `SAY-RING-AVATAR-LOCAL-20261001.md`；真实账号头像上传未验。
- 账号删除界面测试先证实成功删除后仍滞留“账号设置”路由；修复为成功后清空路由返回登录页，失败则留在设置页并显示错误。两条界面测试通过，`flutter analyze --no-pub` 零问题，`flutter test --no-pub` 全量 1022/1022 通过。此前 iOS 1011 无签名 Debug 构建早于此修复，需重新构建、签名并真机验证，不能用于送审。
- 服务器当前剩余约 2.7 GiB；构建峰值曾写满，删除的旧镜像可从 GHCR 再拉取但不在废纸篓。后续新版本发布前仍需扩容或严格容量预检，不能以本次成功推断以后都可安全构建。
- 注销修复后重新配置 iOS `1.0 (1012)`，串行 Xcode Profile 无签名构建明确 `BUILD SUCCEEDED`；实际 Runner 为 `cn.saydian.ring`、构建号 `1012`、`UIDeviceFamily=[1]`，日志 `.build/sayring-1012-ios-profile.log`。发布脚本 30 项测试通过，`TZ=UTC flutter test --no-pub --concurrency=2 --reporter expanded` 1022/1022 通过，日志 `.build/sayring-1012-flutter-utc.log`。此产物仍不能安装或上传，正式归档和真机验收未做。
- 核实服务端注销契约后，将九种语言的注销提示改为“立即停用并退出，相关数据计划于七天后删除，依法须保留的除外”，避免再声称即时删除；新增中文文案断言。国际后台当前暂停通用 Worker，故七天后执行仍是发布阻断项，待明确限制范围后修复并验证。
- 2026-10-01 在修改后执行 `flutter test --no-pub test/qa_user_flows_test.dart --plain-name 'account deletion returns to login after confirmation'` 和失败分支同名定向测试，各 1/1 通过；`flutter analyze --no-pub` 零问题，`flutter test --no-pub --concurrency=2 --reporter compact` 全量 1022/1022 通过。此前一次以不存在的测试名 `deleting account` 过滤，返回 79 且没有执行测试，随后使用准确名称重跑成功。
- 串行 Xcode Release 归档 `.build/SayRing-1.0-1012-review-candidate.xcarchive` 成功，日志 `.build/sayring-1012-review-candidate-archive.log` 包含 `ARCHIVE SUCCEEDED`。归档实际 Bundle ID `cn.saydian.ring`、版本 `1.0 (1012)`、`UIDeviceFamily=[1]`；Apple Distribution 签名团队 `W7SXQ4A226`，`codesign --verify --deep --strict` 成功、`get-task-allow=false`。归档的 `Assets.car` 含 `AppIcon`，源图标最近一次 Git 提交为 `05fdb66` 且工作树中图标资源未改。这是候选归档，不等于 App Store Connect 已上传或审核已提交；尚未在 iPhone 上安装。
- 归档后再查公网国际 API 仍为 ready、revision `6ea9dd9de91c3f27a452efc1a23ad2f77e88a1b5`；`xcrun devicectl list devices` 中 iPhone 15 Pro Max 显示 `unavailable`，无法安装录屏。App Store Connect 登录会话到期，右侧只出现 Apple 登录页，已请用户自行重新登录；不读取或代填密码、验证码。
- 归档保存并验签后，`build/ios-derived-data` 为约 2.2 GiB、被 Git 忽略且没有进程打开；为预留 Android 构建空间，使用精确目录的 `find ... -depth -delete` 清除这份可重建的 Xcode 中间产物，系统可用空间由约 2.6 GiB 升至 4.7 GiB。签名归档、SDK、源码、APK 未删除；中间产物不能从废纸篓恢复，若再编译 iOS 会重新生成。曾尝试 `rm -rf`，命令工具拒绝执行，未造成删除。
- 基于最新 Flutter/注销文案代码，`GRADLE_OPTS=-Dorg.gradle.workers.max=1 flutter build apk --debug --no-pub` 成功，`SAIDIAN_ALLOW_QA_RELEASE=true GRADLE_OPTS=-Dorg.gradle.workers.max=1 flutter build apk --release --no-pub` 成功；两个 APK 均为 `cn.saydian.ring`、`0.1.21 (1006)`。QA Release 证书仍为 Android Debug，绝不可作为 Android 市场正式包。Debug SHA-256 为 `cb4fbc3bbbc12eea0582ca758b14471005e0ad05cfd37d5ded2bac871377e47b`，QA Release SHA-256 为 `ea467a1b180d5b5f6c493746d2c12d28fdb4cdbcca25ec3911c2945eb74609c6`。`./gradlew :app:testDebugUnitTest --offline --max-workers=1` 成功。构建出现 Flutter/Kotlin 插件未来兼容警告，不影响本次成功结果。
- 安卓 Huawei ELS-AN00 仍连接电脑，但前台是游戏/通知栏，用户之前要求稍后测试；本轮没有切换、安装或声称头像真机验收。iPhone 15 Pro Max 仍不可用。上述构建测试不能替代真实头像上传、戒指或 Apple 审核录屏。
- Android 测试后本机空间降到约 1.6 GiB。确认没有相关构建进程或打开句柄后，只清除被 Git 忽略的本工作树 `build/app/intermediates` 约 1.9 GiB；Debug 与 QA Release APK 均保留且 SHA-256 复核未变，可用空间回升约 3.6 GiB。此目录也是无法从废纸篓恢复、但可由 Gradle 重建的中间产物。
- 使用已有本机 App Store 导出配置（`destination=export`，不含上传）导出候选 IPA：`.build/SayRing-1.0-1012-review-candidate-export/Say Ring.ipa`。`xcodebuild -exportArchive` 明确 `EXPORT SUCCEEDED`，ZIP 完整性通过；包内仍是 `cn.saydian.ring`、`1.0 (1012)`、`UIDeviceFamily=[1]`。临时解包再验证签名，Apple Distribution 团队 `W7SXQ4A226` 且 `get-task-allow=false`；临时目录已清除。IPA SHA-256 为 `0bc05774b6044ee02c345a982186fc87e8ab211556a231bcc33a191a124f6375`。仅是本地候选文件，未上传 App Store Connect。

## 1012 iPhone 15 Pro Max 真机覆盖验收续记

- 2026-10-01 16:34（北京时间）前再次 `git fetch --prune origin`，本地和远端分支均为 `7daf53cca6b9d11a9d2229b56456bc1fce9cb009`；工作树已有他人/前序未提交改动，未执行脏树 pull、重置或清理。`devicectl` 读取目标 iPhone 15 Pro Max 为 connected、iOS 26.6、开发者模式可用；安装前同一包名版本为 `1.0 (1010)`。
- `TMPDIR=/private/tmp flutter build ios --config-only --profile --no-codesign --no-pub --build-name=1.0 --build-number=1012 --dart-define-from-file=config/ios-app-store-no-push.json` 成功；随后单独串行执行 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Profile -destination 'id=<目标 iPhone CoreDevice ID>' -derivedDataPath build/ios-profile-1012-derived-data -jobs 1 -allowProvisioningUpdates FLUTTER_BUILD_NAME=1.0 FLUTTER_BUILD_NUMBER=1012 build` 成功，日志 `.build/sayring-1012-device-profile-build.log` 包含 `BUILD SUCCEEDED`。未把 App Store 分发 IPA 当作真机测试包。
- 产物 `build/ios-profile-1012-derived-data/Build/Products/Profile-iphoneos/Runner.app` 实际为 `cn.saydian.ring`、`1.0 (1012)`、`UIDeviceFamily=[1]`；`codesign --verify --deep --strict` 成功，Apple Development 团队 `W7SXQ4A226`、`get-task-allow=true`，嵌入的同包名开发描述文件包含目标 iPhone。Runner SHA-256 `41946618e5dfb25d493ad6fd70bc404969ac5bb3b7d6f6df52a34d74e61990b3`。
- `xcrun devicectl device install app --device <目标 iPhone CoreDevice ID> <Runner.app>` 在未卸载 1010 的情况下成功；设备回读 `1.0 (1012)`，`device process launch --terminate-existing cn.saydian.ring` 成功且独立进程仍存活。现有登录会话、资料和历史健康记录在真机页面可见；这只证实原位升级后的可用性，不等于全部本地数据逐条校验。
- 复用此前已安装的开发签名 WebDriverAgent 辅助 App，真机 `/status` 为 ready；仅将真机截图保存在 `/private/tmp`，没有将账号、健康数值或相册照片写入 Git。进入个人资料页后打开系统照片选择器；为了避免代选私密照片，已请求用户亲自选择愿意公开作头像的非敏感照片，保存及回读待后续记录。

## 待证据补齐后填写的英文审核答复结构

> This is a companion app for compatible Saydian smart rings. It helps ring owners connect their device and review personal wellness measurements, activity and sleep trends. It is not a medical diagnosis or treatment service.
>
> Reviewer access: [填写经真机验证的公开可用登录方式或专用审核账号；不要填个人账号]。
>
> Walkthrough: launch the app, accept the published terms and privacy notice, sign in, allow Bluetooth, select the demonstrated compatible ring, wait for the SDK handshake, then open the health, sleep detail, device and profile screens. Account deletion is under [真机核对路径] and is shown in the attached physical-device recording.
>
> Core external services: [按最终包及线上配置核对第一方国际 API、实际启用的厂商蓝牙 SDK、微信/Apple 登录等；未启用的支付、AI 和推送不写成活动服务]。
>
> Regional availability and feature differences: [与最终销售地区、验证码、语言和账号方式一致填写]。
>
> Protected material/regulated service: [核对实际厂商授权和医疗定位后填写；没有证据不声称已获得授权]。
>
> The attached recording was captured on [真机机型/iOS 版本] from launch through [已实际录到的流程]. The current screenshots correspond to the submitted build [新构建号].

以上只是事实框架，方括号是待证据项，不能原样提交 Apple。

## 1013 上传、地区与真机续记

- 2026-10-01 对 1012 真机看到的睡眠时间轴起止标签靠左问题，改为两端对齐并加入正常及 2 倍字号的 Widget 回归。针对性 2/2、整文件 21/21、Flutter 全量 1024/1024、`flutter analyze --no-pub` 零问题；发布门禁测试 30/30。构建仅串行执行。
- 以生产 API 配置和 `1.0 (1013)` 制作 App Store Release 归档 `.build/SayRing-1.0-1013-review-candidate.xcarchive`，`ARCHIVE SUCCEEDED`、`codesign --verify --deep --strict` 均通过。实际 Bundle ID `cn.saydian.ring`、`UIDeviceFamily=[1]`、Apple Distribution 团队 `W7SXQ4A226`、`get-task-allow=false`；Runner SHA-256 `eaa02c9ae96608bb17fc3313a1caf3a66f742d830f73df0ae62c2da30cf85d82`。
- 命令行上传因 Xcode 账号服务返回 `Failed to Use Accounts` 未完成；随后在 Xcode Organizer 对同一归档执行 App Store Connect 分发，界面显示 `Uploaded with warnings`。警告为未来最低 iOS 版本要求与部分厂商闭源框架 dSYM 缺失；上传未被阻止。
- App Store Connect 的 1013 构建 UUID 为 `01fbed8c-6581-49a8-b79e-f547af84d206`，上传时间 17:20，二进制状态“已验证”，Bundle ID `cn.saydian.ring`、设备系列 iPhone、构建号 1013。版本页已将被拒构建 1009 替换为 1013 并保存；原审核仍为“已拒绝／问题未解决”，不是“已提交审核”。
- 经用户明确确认，将法国从供应地区取消并完成 App Store Connect 的确认步骤；回读 174 个国家/地区、法国“未供应”。App Store Connect 提示地区更改可能在 24 小时内生效。1013 构建元数据回读“App 使用非豁免类加密：否”；尚未把弹窗中未实际保存的选择冒充为独立申报成功。
- 从同源码串行构建开发签名 Profile `1.0 (1013)`，签名为 Apple Development、Bundle ID `cn.saydian.ring`。在不卸载、不清除 1012 的条件下原位覆盖 iPhone 15 Pro Max；`devicectl` 回读已安装 1013、启动成功。原登录仍在，首页旧健康记录及真实睡眠明细仍可访问；这不等于健康数据逐条比对。
- 在 1012 上用户亲自选图并保存头像后，首页和“我的”显示同一头像，杀进程重开后仍在；设备 R21_4F5F 曾从等待靠近恢复到已连接并继续同步一次。没有完成要求的三轮受控远离/靠近、锁屏后台和蓝牙开关验收，不能称自动重连全通过。1013 的睡眠详情 17 段时间轴可访问，起止与阶段值来自真机戒指记录；未取得真实小睡样本。
- Apple 2.1 信息请求要求最新系统实体设备录屏，从启动覆盖典型流程，含适用的注册、登录、注销；并要求用途/受众、设置和主功能、审核账号、核心外部服务、地区差异及必要授权说明。当前 1013 只有上传和绑定证据，没有完整录屏、专用可复现审核账号。版本页“需要登录”仍未勾选，备注为空；现有截屏含当前 App 已隐藏的商城入口。
- App 隐私页现仍公开显示“未收集数据”，与账号资料、头像和健康摘要上传事实不符；旧技术支持 URL `https://app.saidian.cc/sdys.html` 实际标题为“赛电APP隐私政策”，不是客服页。已把版本页简体中文描述改成基于当前功能的非医疗说明，并把技术支持 URL 改为用户提供的企业微信客服链接，保存回读成功。登录方案、准确隐私披露、审核访问、真实截屏与注销到期任务核验尚未闭环，故未点击“更新审核”或“重新提交至 App 审核”。
- 用户授权联络既有“导入-app服务端”任务，要求仅为 Say Ring 审计并准备独立隐私政策；现行通用政策的主体写“广州领科网络科技有限公司”，而 App Store Connect 账号界面显示“Mpcms Beijing Xuewu Tang”，两者不能未经核实就认定一致。用户随后明确答复 Say Ring 的个人信息处理者为 `Xuewu Tang`；公开隐私联系邮箱仍未提供，不猜填。已把确认结果和用户提供的企业微信客服链接发给服务端任务；其他关键事实未确认前只准备草稿、不公开发布。
- 1013 真机睡眠详情的阶段图和 23:55／07:14 两端标签已目视核对，修复后的起止标签分别靠左右边缘；画面不含姓名和头像。用户明确允许把这台 iPhone 的真实睡眠/健康数值作为公开 App Store 截屏；未经授权的首页姓名/头像和设备精确标识未上传。
- 用 iPhone 15 Pro Max 的 1290×2796 原始真机截屏，在 App Store Connect 的 6.9 英寸栏上传睡眠详情、心率分析、健康监测设置三张，顺序如列；Apple 官方截屏规格将该尺寸列为 iPhone 15 Pro Max 可接受规格。旧 6.5 英寸 A1–A4 四张先从页面可见原图完整备份到 `/Users/mycodex/电商/SayRing-appstore-screenshots-backup-20261001`，每张为 1242×2688 且 SHA-256 已记录，再从页面删除。回读 6.9 英寸 3/10，6.5 英寸“使用 6.9 英寸显示屏文件”，不再显示旧商城图。
- 1013 血氧详情页当天显示“该时间段暂无数据”；切换到前一天后可见与首页相同的真实记录和时间点，故不是数据读取丢失。实际问题是首页“健康数据”标题旁标当天日期，下面卡片却按各指标展示跨日最新值，容易误认为旧值在当天测得。已将该标题改为本地化的“近期数据”并加入 Widget 回归；此改动尚未进入已上传的 1013，必须提高构建号重新打包上传后才可送审。
- 用户已确认 Say Ring 个人信息处理者 `Xuewu Tang`，公开隐私联系邮箱 `kf@saydian.com`，已转交既有服务端任务。公开政策及 App Store 隐私披露仍须在事实审计后回读核对。
- 用户选择本次 iOS 暂时隐藏微信授权登录，保留现有手机号验证码登录，以避免在尚无等效隐私登录时触发 Apple 4.8 风险；Android 微信入口保持后台能力控制。已修改两处 iOS 登录页面及回归测试，同时用 `SaidianWechatEnabled=false` 阻止 iOS 原生 SDK 在启动时注册及通过方法通道发起微信登录/支付。此改动不在已上传的 1013 内，须随下一构建验收。旧服务端政策草稿中“1013 可选微信”仅描述旧包，最终政策要以新包实际可见功能为准。
- 以 1.0 (1014) 和生产 API 配置串行生成开发签名 Profile 真机包。`xcodebuild` 返回 0，实际 Runner 为 `cn.saydian.ring`、`UIDeviceFamily=[1]`、`SaidianWechatEnabled=false`，Apple Development 团队 `W7SXQ4A226`；严格深层验签通过。未卸载旧 App，直接覆盖安装到 iPhone 15 Pro Max 并启动；设备回读构建号 1014，原登录仍在，首页可见“健康数据／近期数据”。这只验证首页改动及原位安装，不等于新登录页的真机登出/重登验收；目前仅 Widget 测试证明 iOS 隐藏微信、Android 保留。
- 1014 目前是开发签名测试包，**尚未制作或上传 App Store Distribution 归档**；App Store Connect 仍绑定已上传的 1013。公开隐私页仍指向旧通用政策，App 隐私仍显示“未收集数据”，未修正前不提交审核。
- 1014 客户端改动复跑 `flutter analyze --no-pub` 零问题，`TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact` 1023/1023 通过。iOS 原生 Profile 真机编译返回 0；闭源厂商框架仍输出缺失开发者本机 `.pcm` 的调试符号警告，非本次 Swift 语法错误。
- 服务端任务已生成独立但明确“禁止发布”的英文 Say Ring 政策草稿，未部署；其审计发现 1013 没有 `say-ring` 法律能力标识、注销 Worker 未清理邮箱和微信 OpenID/头像文件、第三方穿戴 SDK 数据行为与保留期限仍需核实。已请服务端继续实现产品隔离接口及精确注销清理，客户端待其给出契约后接入。不能用这份草稿 URL 代替线上正式隐私政策。

## 1015 候选变更：公开只读演示及单一区域

- 用户选择在正式 App 提供无需审核账号的公开只读演示，且首版仅在中国大陆供应。App Store Connect “管理供应情况”中先选择“无”，再只勾选“中国大陆”，关闭未来地区自动供应；确认弹窗明确显示将移除其他 173 个地区。保存回读“供应情况（1 个国家或地区）”，中国大陆“App 发布时供应”、法国及其他地区“未供应”；Apple 提示变更可在 24 小时内生效。此前 1013 二进制仍为当前绑定包，没有因此提交审核。
- 新登录页增加“无需手机号，查看只读演示”。演示页仅由本机静态、明确标注的虚构数据构成，包含健康指标、可展开的睡眠阶段与小睡、设备连接流程及资料/注销说明。演示路由不持有 API、账号、数据库或蓝牙桥接；演示模式不声称已连接真实 R21。退出只改变内存中的展示状态，不清理真实登录和健康数据；登录账号不能进入演示模式。
- 修改文件：`lib/ui/global_code_login_page.dart`、`lib/app.dart`、`lib/ui/review_demo_page.dart`、`lib/ui/sleep_detail_widgets.dart`、`lib/services/app_controller.dart` 及对应 Widget 测试；范围为 Say Ring 国际入口 iOS/Android 共享 UI，真实健康 SDK 算法和云协议未改。睡眠组件的真实模式文案未改，演示模式另用“示例”标识，避免把虚构时间轴写成 SDK 实测。
- 首次定向测试因新页误把非 const `ListView` 写成 `const` 而编译失败；移除 `const` 后 `flutter test --no-pub test/review_demo_page_test.dart test/global_code_login_page_test.dart --reporter compact` 全部通过（6/6）。`flutter analyze --no-pub` 零问题；`flutter test --no-pub test/qa_user_flows_test.dart test/login_page_test.dart --reporter compact` 全部通过（62/62）。全量测试、原生构建、真机与正式上传仍须按后续记录判定。
- Apple 当前 [App Review Guidelines 2.1(a)](https://developer.apple.com/app-store/review/guidelines/) 对用内置演示代替审核账号写有“需事先获 Apple 批准”及展示完整功能的条件。新只读演示虽提供核心页面和时间轴，不能替代实体戒指握手/测量；正式审核说明必须请求 Apple 接受该审核方式，并附真实硬件录屏，不可称已获事先批准。
- 一次 `TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact` 在运行到 258 项时与服务端本机 Colima 镜像构建同时遭遇系统盘仅余约 101 MiB，停留在 `old registration response cannot clear a new pending marker`；主动中止，**不计为全量通过**。服务端任务随后仅清理其本轮创建的 Colima 虚拟磁盘，系统可用空间回升至约 5.6 GiB。同名单测独立执行 1/1 通过。待产品专属法律接口改动完成后重新运行全量测试。

## 1015 产品协议与构建验证续记

- 服务端候选契约见 `/Users/mycodex/电商/赛电APP服务端/docs/say-ring-legal-client-contract.md`，仍未合并部署。客户端能力 GET 显式增加 `product=say-ring`，只接受响应 `data.product=say-ring`，法律文档路径只允许 `say_ring_user_agreement` 与 `say_ring_privacy_policy`；共用验证码、注册/重置和 Android 微信三步同意请求显式带产品，适用请求带语言与当前协议版本。修改 `lib/domain/global_account.dart`、`lib/services/global_api_client.dart`、`lib/ui/global_legal_page.dart` 和相关测试；跨产品返回时拒绝继续同意，旧通用协议不被冒充为本 App 协议。
- 产品协议定向回归第一次因旧测试桩仍返回通用协议且未包含产品字段而失败，修正为专属契约并增加通用协议拒绝断言；补重置密码语言字段及测试。`dart format lib/services/global_api_client.dart test/global_api_test.dart` 无格式变化；`flutter test --no-pub test/global_api_test.dart test/global_legal_page_test.dart test/global_auth_consent_test.dart test/global_joint_device_diagnostic_test.dart --reporter compact` 为 83/83 通过，`flutter analyze --no-pub` 零问题。
- 2026-10-01 重新执行 `TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact`，**1028/1028 通过**。`git diff --check` 无空白错误。这个结果不替代尚未部署的服务器契约和真机验证码/戒指验收。
- Android 原生测试 `./gradlew :app:testDebugUnitTest --offline --max-workers=1 --console=plain` 首次因本机离线缓存缺少 `org.gradle.kotlin.kotlin-dsl:6.2.0` 在配置期失败。改用在线解析后，Gradle 进入远端依赖元数据读取但长时间无响应；线程栈位于 HTTPS 响应头读取，主动中止，退出码 130。尚无 Android 原生单测通过或 APK 构建结论，待网络/缓存恢复后重跑。
- `TMPDIR=/private/tmp flutter build ios --config-only --release --no-codesign --no-pub --build-name=1.0 --build-number=1015 --dart-define-from-file=config/ios-app-store-no-push.json` 成功；随后**串行**运行 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/ios-profile-1012-derived-data -archivePath .build/SayRing-1.0-1015-review-candidate.xcarchive -jobs 1 -allowProvisioningUpdates FLUTTER_BUILD_NAME=1.0 FLUTTER_BUILD_NUMBER=1015 archive -quiet` 退出码 0。归档实际 `cn.saydian.ring`、`1.0 (1015)`、`UIDeviceFamily=[1]`、`SaidianWechatEnabled=false`；`codesign --verify --deep --strict` 通过，Apple Distribution 团队 `W7SXQ4A226`、`get-task-allow=false`。第三方 SDK 的弃用和预置 dSYM 模块缓存警告仍存在，未冒称消除。
- 归档原件保留在 `.build/SayRing-1.0-1015-review-candidate.xcarchive`，另复制到 Xcode Organizer 归档目录供上传；Organizer 可见 1015。当前 iPhone 15 Pro Max 仍装 1014，1015 是 App Store 分发签名归档，**未拿它直接覆盖真机**。上传及 App Store Connect 后台处理结果在后续条目单独记录。
- 用户确认首版最低年龄 13 岁，13–17 岁可在监护人同意后使用；已转交既有服务端任务。用户要求自行核对腾讯云合同，签约主体、备份与安全日志保留期限仍需以合同/配置证据查实，不从公开材料推定。隐私政策草稿禁止发布；App Store 隐私标签现有“未收集数据”尚未更正，未经核实不点击重新送审。
- Xcode Organizer 对 1015 归档选择 App Store Connect 分发，回执为 `Upload completed with warnings`，随后归档列表显示 1015 `Uploaded with warnings`（18:50）。警告包括从 2027 年 4 月起最低 iOS 15 的未来要求（当前实际目标 iOS 13）及 14 个闭源厂商框架 dSYM 缺失；本次上传未被阻断。App Store Connect TestFlight→“构建版本上传”回读 `1.0 (1015)` 于 18:50 创建、状态“正在处理”；**版本页仍绑定 1013，未把 1015 处理中的状态写成已验证或已送审**。
- 2026-10-01 18:50 后直接读取公开生产 `GET https://app.saydian.cn/global/api/saydian-app/v2/auth/capabilities?locale=zh-Hans&product=say-ring`：HTTP 200 但 `data.product=null`，返回旧通用 `user_agreement`/`privacy_policy` 和版本 `global-qa-2026-09-10`。因此 1015 客户端会按设计拒绝将通用协议当作戒指协议，**线上验证码登录在服务端专属契约/已审文档部署前不可用**；公开只读演示不依赖该 API。绝不能将现时 1015 提交审核或上线给用户。
- 既有服务端任务只读核对发现：腾讯云控制台的预设合同甲方为“微销通(北京)科技有限公司”，但合同记录为 0，不能称已签署合同或直接写成当前分包服务商主体；数据库备份仓库配置保留 30 天、Restic 源码策略为 14 个日备份/8 个周备份/12 个月备份，尚无生产运行值证明；安全日志期限未知。穿戴 SDK 的独立网络行为和供应商主体仍无证明。13 岁用户在中国大陆属于不满 14 周岁，现有客户端缺少监护人同意留痕；已向用户询问首发改为 14+ 或补监护人核验流程。法律、隐私标签及最终上架仍待事实和实现闭环。
- Android 原生单测第二次离线重试已通过 Flutter Gradle 插件配置，但在 `camera_android_camerax` 配置期缺多项 AGP/Kotlin 依赖缓存而失败；在线重试需要补齐依赖，尚无 Android 构建通过证据。本轮 iOS 上传不等于 Android 回归通过。
- 之后使用仅置于 `/private/tmp` 的 Gradle 初始化脚本，给各项目 buildscript 增加阿里云 Google/Central/插件镜像，执行 `./gradlew -I /private/tmp/sayring-gradle-mirrors.init.gradle :app:testDebugUnitTest --max-workers=1 --console=plain -Dorg.gradle.internal.http.connectionTimeout=15000 -Dorg.gradle.internal.http.socketTimeout=15000`，耗时约 5 分 34 秒，`BUILD SUCCESSFUL`，300 项任务中 25 项执行、275 项最新。首次初始化脚本试图设置 project.repositories，因仓库集中管理模式失败；移除该设置后才通过。此项纠正了上一条“尚无 Android 原生单测通过”的中间状态，不等于当前源码新 APK 已生成。
- 随后 `GRADLE_OPTS=-Dorg.gradle.workers.max=1 flutter build apk --debug --no-pub` 在 Maven Central 获取 `org.jetbrains.kotlin:kotlin-gradle-plugin-api:2.3.20` 时遇 TLS 握手失败；Flutter 自动重试持续等待，已主动终止。原 `build/app/outputs/flutter-apk/app-debug.apk` 时间戳仍为 15:59，不能当作本轮新包。为回收构建空间，仅在确认无进程句柄、签名归档另存后删除被 Git 忽略的 `build/ios-profile-1012-derived-data`（约 1.4 GiB）；签名归档、源码、SDK、旧 APK 均保留。该中间目录可重建，但不能从废纸篓恢复；余量回到约 2.6 GiB。
- 1015 在 App Store Connect 的后台处理已完成。首次回读为“缺少出口合规证明”，随后按用户此前确认的事实，在 1015 加密问卷申报“标准加密算法、非专有算法”及“不在法国分发”并保存；TestFlight 回读构建 `1.0 (1015)` 为“准备提交”。此前已核对正式供应地区仅中国大陆。**App Store 版本页仍绑定 1013，1015 未绑定版本、未提交审核，更未上架。**
- 2026-10-01 19:07 再执行 `git fetch --prune origin`，本地与 `origin/codex/macos-update-20260930` 同为 `7daf53cca6b9d11a9d2229b56456bc1fce9cb009`；大量在途改动仍在工作树，未对脏树 pull、reset 或覆盖。用户指示自行查腾讯云合同：控制台只有预设甲方、合同记录为 0，不能认定签署主体；生产备份及安全日志实际期限、穿戴 SDK 数据披露也不能推断，政策仍未发布。

## 1015 后台验证、Android 回归与审核沟通续记

- App Store Connect→TestFlight→1015“构建版本元数据”回读二进制状态“已验证”，`1.0 (1015)`、`cn.saydian.ring`、设备系列 `iPhone`、非豁免类加密“否”、Apple Distribution entitlement `get-task-allow=false`；这比“上传完成”进一步证实服务器处理结果，但不代表 App Store 版本已改绑或审核通过。
- 采用前述临时镜像脚本执行 `./gradlew -I /private/tmp/sayring-gradle-mirrors.init.gradle :app:assembleDebug --max-workers=1 --console=plain -Dorg.gradle.internal.http.connectionTimeout=15000 -Dorg.gradle.internal.http.socketTimeout=15000`：1 分 13 秒，`BUILD SUCCESSFUL`，384 项任务中 38 项执行。新 `build/app/outputs/apk/debug/app-debug.apk` 时间戳 19:09:14，SHA-256 `9daa0e76fdcec2e50397359babbfd99ac4effa0dc876efe71f182131624b7969`；包名 `cn.saydian.ring`、`0.1.21 (1006)`、minSdk 26、targetSdk 36，ZIP 完整性通过。这个是新 Gradle 输出，不以较早的 `outputs/flutter-apk` 副本代替。
- Debug 构建一度将系统盘压到约 145 MiB，构建结束后回收部分临时空间至约 2.1 GiB。为保证下一步回归，核实 `build/app/intermediates` 被 Git 忽略、无打开句柄且新 Debug APK 已验后，仅删除这 1.3 GiB 可重建的 Gradle 中间目录；没有删除 APK、签名归档、源码或 SDK。该中间目录不能从废纸篓恢复。
- 使用 `SAIDIAN_ALLOW_QA_RELEASE=true ./gradlew -I /private/tmp/sayring-gradle-mirrors.init.gradle :app:assembleRelease --max-workers=1 --console=plain -Dorg.gradle.internal.http.connectionTimeout=15000 -Dorg.gradle.internal.http.socketTimeout=15000`：2 分 20 秒，`BUILD SUCCESSFUL`，656 项任务中 67 项执行；`verifySaidianReleaseMode` 明示 `QA RELEASE - NOT FOR DISTRIBUTION`。新 `build/app/outputs/apk/release/app-release.apk` 时间戳 19:14:05，SHA-256 `3f3799fea5e84137e779084d53f5125c684bc9c5f2f2164f7ac1fc3baf4ea63c`；包名 `cn.saydian.ring`、`0.1.21 (1006)`，ZIP 完整，`apksigner` 证书为 Android Debug。**不能作为 Android 商店正式包。** R8/JPush/微信闭源包的栈映射警告仍在，但本次构建返回 0。
- QA Release 验证后确认无构建进程/打开句柄，仅清除再生成的 `build/app/intermediates` 约 623 MiB，系统盘约 1.6 GiB 可用；Debug/QA Release APK 和 1015 iOS 分发归档保留。中间目录可重建、不能从废纸篓恢复，后续构建前仍须预留更多空间。
- App Store Connect“App 隐私”实查仍指向旧 `https://app.saidian.cc/sdys.html`，公开标签“未收集数据”；与账号、头像、健康摘要上传事实不符，**尚未修改或发布新的合规声明**。既有 2.1 拒审仍显示“问题未解决”，已提交项目依旧是 `1.0 (1013)`。
- 19:15 通过原拒审会话的“回复 App 审核”向 Apple 如实询问：1015 拟提供的明确标注只读虚构数据演示及完整真机录屏，是否可替代审核账号；如不行，是否需要审核账号、实体戒指或两者。页面回读消息数由 1 增至 2，显示我方英文询问全文。**这只是询问，不是批准或重提审核**；Apple 答复仍待到达。苹果 [2.1(a) 指南](https://developer.apple.com/app-store/review/guidelines/)要求无法提供演示账号时，内置演示模式取代账号需事先获 Apple 批准且展示完整功能，当前只读模式不自认满足。
- `python3 -m unittest scripts/release/test_release_gate.py` 为 30/30 通过。针对刚生成的 QA Release APK，首次 `apk-manifest` 因未设置供 QA 对比用的 `JPUSH_APP_KEY`/`JPUSH_CHANNEL` 环境值退出，未把这次失败写成通过；按构建脚本的禁用推送占位符 `debug-disabled`／`developer-disabled` 重跑后通过。基于 APK 实际 manifest 和 aapt2 资源表核对包名/版本、权限与安全配置。
- 同一 QA Release 的 `:app:dependencies --configuration releaseRuntimeClasspath` exit 0、报告无 `FAILED`，解析为 JPush 6.2.0／JCore 5.5.2；报告 SHA-256 `e666939ac5a4958f8c7cdcf42ec16bcf06b59155073156303a0a48343e81801a`。用该报告、`pubspec.lock` 和实际 APK 跑 `apk-abis` 通过：仅双 ARM，并只接受被精确锁定的 ARM64 `libjutils.so` 例外。`zipalign -c -P 16 4` 和 `apksigner verify --verbose` 也通过，签名为 v2 调试证书。上述 QA 门禁不改变“不可正式分发”边界。
- 19:16 再次只读请求公开生产能力接口，仍返回 `data.product=null` 与通用协议；`/global/health/ready` 为 ready、revision `6ea9dd9de91c3f27a452efc1a23ad2f77e88a1b5`。服务器专属协议仍未部署，1015 正式登录仍被安全拒绝；不把苹果后台“已验证”误当成用户可登录或可送审。
- Git 提交前通过 `gh repo view` 与 `gh api repos/tangwu88/SayRing` 双重只读核实：当前 `origin` 对应仓库 `private=false`／`visibility=public`，与仓库 `AGENTS.md` 的私有仓库约束冲突。先保留本机改动，不将这批代码推到公开远端；已询问用户是否允许恢复私有。`git ls-remote` 核实远端 `main` 与当前工作分支均仍为 `7daf53cca6b9d11a9d2229b56456bc1fce9cb009`。

## 1016 年龄门槛与送审门禁续记

- 用户确认继续自行排除剩余问题；先通过 GitHub 仓库设置将 `tangwu88/SayRing` 恢复为私有，随后双重回读 `private=true`／`visibility=private`，提交并推送上一轮已验证的 1015 客户端改动到 `origin/codex/macos-update-20260930`，提交 `a41aa4f`。未修改 `main` 或任何其他 App 仓库。
- Bug 名称：首发最低年龄与中国大陆未满 14 周岁监护人同意缺口。复现：旧登录页未询问年龄，服务端旧通用登录也未记录年龄确认。预期：首发仅已满 14 周岁可创建 Say Ring 账号；更低年龄须有可核验监护人流程。实际：旧流程无法证明此条件。影响等级 P1（法律与送审）。本轮按 14+ 首发保护实现年龄确认，不伪造监护人核验；13 岁用户暂不开放注册。
- 与服务端候选契约 `/Users/mycodex/电商/赛电APP服务端/docs/say-ring-legal-client-contract.md` 对齐：验证码、Android 微信登录／手机号绑定增加 `ageConfirmed`，客户端未勾选则本地拒绝发送认证请求，提交 JSON 时为 `true`；登录页展示中英双语“已满 14 周岁”确认，切换能力时清除旧勾选。接口实现不代替线上部署；服务端候选仍在独立功能分支、未部署。服务端仅在新建账号时要求该确认；客户端每次登录均显式确认，偏保守但不伪造出生日期。
- Apple App Store Connect 中已将本 App 年龄问卷的健康／医疗相关题目按实际功能更新，并保存与回读首发评级 `16+`（旧系统显示 `17+`）。本机核对截图 `/private/tmp/sayring-app-age-16plus-20261001.png`，仅证明后台设置，不代表审核通过。销售地区仍限中国大陆。
- App 隐私表单已暂存 11 类可从源码直接确认的数据类别，但它们仍是**未发布的待完善选择**；公开商品页仍显示“未收集数据”，旧通用隐私政策 URL 未改。健康数据用途和关联性虽已开始填写，但在闭源穿戴 SDK 独立网络行为、供应商主体、生产备份／日志留存与法律文本发布事实未核实前，没有作出公开的最终隐私准确性声明。私有服务端政策草稿明确禁止发布，`Xuewu Tang` 与 `kf@saydian.com` 为用户确认事实；腾讯云控制台合同记录为 0，不能将预设甲方冒充签约主体。
- `dart format` 已执行，`flutter analyze --no-pub` 零问题；定向 `flutter test --no-pub test/global_api_test.dart test/global_code_login_page_test.dart --reporter compact` 32/32；`TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact` 全量 1029/1029，日志 `.build/sayring-age-full-flutter-test.log`。之后将 API 发送字段由恒真三元表达式机械简化为字面量 `true`，再跑静态检查及定向 32/32 均通过；此次简化不改变请求内容。
- 以同一源码和生产 API 配置串行构建开发签名 Profile `1.0 (1016)`，`xcodebuild` 退出 0，日志 `.build/sayring-1016-device-profile-build.log`。实际 App 为 `cn.saydian.ring`、`UIDeviceFamily=[1]`、`SaidianWechatEnabled=false`，严格签名检查通过，Apple Development 团队 `W7SXQ4A226`、`get-task-allow=true`。没有卸载 iPhone 旧版，直接覆盖安装 1016 并成功启动；设备应用列表回读 1016，进程仍存活。未做真实退出／重登、R21 三轮重连、头像重开回读或健康数据逐条验收，不将安装启动当作这些功能通过。
- 再读生产 `auth/capabilities?locale=zh-Hans&product=say-ring`，仍是 `data.product=null` 的旧通用协议响应；客户端按设计拒绝将其作为戒指专属协议。1016 只是开发签名真机候选，**尚无 1016 分发归档或 App Store Connect 上传**。App Store Connect 1015 虽已验证，但版本页仍绑定 1013；原 2.1 拒审尚未重新提交。Apple 关于只读演示能否替代审核账号的问题尚无批准回执。上述线上登录、隐私声明和审核访问未闭环前，不点击重新送审。
- 字面量简化后再次执行 `TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact`，最终 1029/1029 通过，日志 `.build/sayring-age-full-flutter-test-final.log`。Android 原生 `:app:testDebugUnitTest` 本轮重新启动，前一次命令的日志路径误写为 `android/.build` 而立即失败，纠正为 `../.build` 后才真正开始。此次 Gradle 在第 279 项任务 `:app:compileDebugKotlin` 时将系统盘余量压至约 195 MiB；为防主机写满，主动向本轮 Gradle 进程发中断和终止信号，最终退出码 130。**本轮当前源码的 Android 原生单测未完成，不能沿用上一版 1015 的通过记录。**
- 为恢复主机空间，确认相关构建／测试进程已退出、目录被 Git 忽略且没有打开句柄，先用 Xcode `clean` 清除 1016 的部分 DerivedData，再仅删除本轮生成、可重建的 `build/test_cache`、`build/app/intermediates`、剩余 `build/ios-profile-1016-derived-data`、`.build/task-gradle-cache-20261001`、`.build/task-pub-cache-20261001`。保留源码、Git、既有 APK、1015 分发归档、测试日志与手机已安装 1016；这些缓存不能从废纸篓恢复，未来构建需重新生成。系统盘余量回升至约 1.5 GiB；没有继续冒险启动 Android 打包或 iOS 分发归档。
