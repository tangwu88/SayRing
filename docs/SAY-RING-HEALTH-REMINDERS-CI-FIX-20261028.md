# 2026-10-28 健康提醒iOS兼容与CI复核

## 现场与基线

用户回复目前无法操作华为手机。保留1152覆盖安装待系统确认状态，不重复点击、卸载或清理数据；不把未安装的新页面计为真机通过。修改前当前分支干净，`git fetch --prune origin`及`git merge --ff-only origin/codex/login-camera-r7ultra-1136-20261024`成功，基线`04325f2a64d91de9f638313dff74522386b811fd`。既有本机备份分支`codex/health-reminders-v3-local-de58370`保留。已读项目约定、最新健康提醒V3记录、CI配置和回归边界。

## Bug与修正范围

- Bug：新本地通知未完整处理iOS13可用性，P1构建门禁问题。
- 复现：GitHub运行[40535928012](https://github.com/tangwu88/SayRing/actions/runs/40535928012)，`ios`任务`flutter build ios --debug --no-codesign`失败；日志为`'banner' is only available in iOS 14.0 or newer`，位于新健康提醒前台通知代码。`quality`、Android、UTC和Asia/Shanghai两组Harmony任务均success。
- 预期：仓库默认iOS13目标可编译；只有当前账号拥有的本地事件才能展示，其他通知继续转交原代理。
- 根因：本地上一轮使用显式`IPHONEOS_DEPLOYMENT_TARGET=15.0`编译成功，未覆盖CI采用的项目默认13.0。
- 依据：Xcode本机原始`UNUserNotificationCenter.h`标注banner从iOS14可用、alert为iOS10至14的旧选项；`UNNotificationSettings.h`同时标注ephemeral从iOS14可用。
- 修正：只修改`ios/Runner/AppDelegate.swift`健康提醒桥。iOS14及以上使用banner，低版本使用alert；拒绝不属于当前账号的通知时只回调空选项一次。ephemeral权限判断同样显式置于iOS14可用性分支，未知状态仍返回unavailable。未提高项目最低系统版本，未改医学规则、通知内容、Android或Dart业务、健康上传及设备采样。

## 验证记录

正在按CI默认目标执行实际编译；每轮结果及失败保留到私有`build/health-reminders-ci-fix-20261028`，未执行项不写通过。

本机执行同一`flutter build ios --debug --no-codesign`退出1，原因是本机唯一Xcode27.1/iOS27.1 SDK不接受低于15.0的deployment target（`Target Integrity`），在项目及Pod目标阶段被阻断，并非原banner错误已验证通过。`xcodebuild -showsdks`及Xcode安装清单已核对，没有可供切换的26.5。保持仓库13.0设置和CI的Xcode26.5选择不变；不修改Apple SDK、不下载或安装另一套Xcode。低目标兼容性由新提交的原CI验证，本地继续验证iOS15支持目标及跨模块回归，两种结论分别记录。

本轮完整本机回归再次通过：离线lockfile约束pub get、格式、静态分析零问题；`TZ=UTC`与`TZ=Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded`各1547/1547；Node工具140通过、1跳过（Windows ACL非本机平台），Harmony宿主两时区各525/525，发布Python35/35。Android Debug/QA Release双ARM构建通过，JUnit62/62。完整命令、各步时长及日志保留在私有`host-v1`，没有覆盖上一轮结果。Dart与Android源码未变，10月27日原签名正式1152 APK仍保留原哈希，未触碰待确认安装或公开下载配置。

iOS支持目标的本机验证完成：先按原1.0.7（1152）主入口参数执行Debug/Profile config-only，再串行`xcodebuild ... -configuration Debug/Profile -sdk iphoneos -destination generic/platform=iOS IPHONEOS_DEPLOYMENT_TARGET=15.0 ... CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY='Apple Development' build`，均成功。新增Swift源码blob为`ca1657234f39affb2b68361d35610c3f6b72a470`。普通Profile另存`build/health-reminders-ci-fix-20261028/ios-signed/normal-profile-1152.app`，真实包名/版本为`cn.saydian.ring / 1.0.7 (1152)`，minimum15.0、团队W7SXQ4A226；`codesign --verify --deep --strict --verbose=2`通过，可执行文件SHA-256 `f5f229bb7de682bcc89609f03e342d5de66b0984d764e7e1ad45b3aa243c5a0b`。

同时执行CI已有Objective-C宿主策略测试：`xcrun clang -fobjc-arc -framework Foundation test/native_coolwear_policy_test.m -o <私有输出>`编译和运行均退出0；`xcodebuild ... -configuration Debug -sdk iphoneos -destination generic/platform=iOS IPHONEOS_DEPLOYMENT_TARGET=15.0 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build-for-testing`得到`TEST BUILD SUCCEEDED`。这只表示RunnerTests编译成功，没有在手机执行XCTest，也没有新戒指/通知物理验收。

本轮只提交iOS兼容修复、失败/验证记录和防复发清单。命令行HTTPS身份缺失已知，继续使用既有GitHub连接同步同一文件树，核对前置SHA和非强制更新；本机原提交保留在备份分支。仓库默认13.0目标及原云端26.5流水线保持不变，其新运行结果独立于本机15.0构建报告。
