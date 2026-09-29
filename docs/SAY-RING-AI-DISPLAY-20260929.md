# 2026-09-29 Say Ring 后台 AI 内容显示开关

## 修改前检查

- 修改前 `HEAD=de5ff796626a1ebec5674db43e62f39cc31e863b`，开发分支 `codex/home-health-device-update-download`；已执行 `git status --short --branch`、`git remote -v`、`git fetch origin --prune`。
- 既有 `docs/SAY-RING-YOUTHFUL-LUCKRING-UI-20260928.md` 空行改动保留，不覆盖、不纳入本次提交。
- 已阅读 `AGENTS.md`、国际版交接、变更日志最新记录、跨模块复盘与回归清单。

## 原因、范围与预期

- 用户要求后台新增控制前端 AI 内容的开关，**开启表示隐藏 AI 内容**。
- 国际接口 `GET /global/api/saydian-app/v2/support/app-display?product=say-ring` 返回标准 envelope，data 为 `{product:'say-ring',hideAi:boolean}`。只接受本产品与布尔值。
- Flutter 范围：API 客户端、隔离配置缓存、控制器、首页和个人中心 AI 入口、AI 问答/健康档案/AI 报告和购买页面。普通健康指标、运动、设备生成的 ECG 结果与普通健康百科保留。
- 启动与回前台刷新；首个有效值前隐藏，读取失败保留已接受配置；已打开 AI 页面在开启隐藏时退出，禁止新的 AI 请求/报告/购买。
- 通知当前白名单只允许关爱、预警、系统收件箱，没有 AI 深链。

## 验证记录

- 主代理 UTC 全量首跑 911 项通过、3 项失败；使用 `flutter test --no-pub --reporter expanded` 将输出保存在系统 Temp 诊断日志后复现。失败均为 `global_localized_pages_test.dart` 三个健康分析法律授权用例：`_GlobalPageController extends Fake implements AppController` 未实现新增的 `hideAiContent` getter，抛 `UnimplementedError`。
- 修复仅在该法律文档测试替身显式返回 `hideAiContent=false`，对应“功能可用时验证协议版本和授权”的原测试前提；不改产品逻辑、不减少原断言。三个用例分别为未发布协议禁用新分析、显示已审文本并传明确版本、版本改变时拒绝授权。
- 修复后串行全量：`TZ=UTC flutter test --no-pub --reporter expanded` **914/914 通过**（43 秒）；`TZ=Asia/Shanghai flutter test --no-pub --reporter expanded` **914/914 通过**（46 秒）。诊断输出保存在系统 Temp，不提交 Git。

- 主代理首轮 `flutter analyze --no-pub` 在 `app_controller.dart` 的四个新增多行 AI 代次检查发现 `curly_braces_in_flow_control_structures`，退出码 1，尚未运行全量测试；已给四处条件补齐大括号，重新分析结果见后续记录。
- 补齐四处大括号并格式化后，`flutter analyze --no-pub` 通过：`No issues found! (ran in 17.1s)`。
- 再次搜索 Flutter 全部 UI、全局路由与通知实现中的 AI、健康管家、运动管家、AI 问答、健康档案/权益入口，所有可达 AI 页面均已受开关控制；普通 ECG 页面只展示设备测量数据，继续保留。未找到额外 AI 深链。

- 首次 `flutter test --no-pub test/app_display_config_test.dart` 编译失败：测试替身的 `getAiMessages` 漏写接口已有的 `page` 命名参数；已补齐，属于新测试夹具问题。
- 第二次定向运行 9 项通过、首页用例失败：新测试宿主未初始化中文日期数据。加入 `initializeDateFormatting('zh_Hans')`，生产 UI 日期逻辑未变。
- `flutter test --no-pub test/app_display_config_test.dart test/health_reports_page_test.dart test/health_report_payment_controller_test.dart test/ui_shell_test.dart test/global_api_test.dart`：102 项通过。覆盖隐藏/显示、首次失败、缓存与重启、回前台、协议校验、AI 请求/报告/购买阻断、迟到回复以及当前页及弹窗关闭；现有健康与支付回归保持通过。
- 只清理当前 AI 会话展示，不删除本地健康数据、报告历史或服务端权益；原隐私协议、普通健康免责声明和既有支付结果核验不受隐藏开关影响。
- 最后补充购买请求返回后再检查显示开关，避免隐藏后迟到的创建订单响应仍调起外部支付；增加我的页面重新开启显示断言。`flutter test --no-pub test/app_display_config_test.dart test/health_report_payment_controller_test.dart` 13 项通过。
- 添加 `integration_test/app_ai_display_test.dart` 的两项受控配置真机 UI 测试，使用内存会话/存储与不可调用的设备替身，不初始化生产账户或蓝牙；覆盖首页、我的和已开 AI 页关闭。执行结果由主代理记录，不等同线上后台开关端到端验收。
- 导航审查补充 `route.isActive` 校验，避免多个嵌套 AI 页同时关闭时，已退栈页面再次执行返回导致连带关闭此前普通页面；增加对应回归。最终 `flutter test --no-pub test/app_display_config_test.dart` 11 项全部通过。

## 主代理构建与发布记录

- `node --test tool/test_native_log_privacy.mjs tool/global_auth_smoke.test.mjs tool/global_auth_account_qa.test.mjs`：87/87 通过，均是离线安全回归，未创建生产账号。
- 发布 Python 回归首次被 WindowsApps Python 占位程序阻断，`py` 指向已失效的 I 盘解释器；切换已有 Codex Python 后实际执行 22 项，15 项通过、7 项因 Windows 无 POSIX 执行/路径语义报错。给当前进程添加 Git Bash 后仍有 `/bin/bash` 与 Unix 绝对路径要求，未修改既有发布脚本以掩盖跨平台限制；这 7 项留给 Linux CI，不能写作全通过。
- 后台主仓 `37ff0faa4eaca64ee270c0bf4d804a816ab26f14` 与国际分支 `9e29aedff3620f14dae213e941e8f68e9468e9da` 已分别提交推送；主仓发布工具的接口目录、工具、类型、全量测试和构建均通过。此条仅证明 Git 状态，部署与接口需另外核对。
- 手机安装前：Huawei JAD_AL00，已装 Say Ring 0.1.21 (1004)，首次安装时间 2026-09-19 13:41:28；本轮使用覆盖安装，不卸载、不清除账户或健康数据。
- 原生鸿蒙也是 Say Ring 独立产品，额外同步实现见 `SAY-RING-AI-DISPLAY-HARMONY-20260929.md`；Flutter 没有 WebView AI 旁路。
- Android 构建、受控配置真机、最终包恢复与线上核对进行中，以下继续记录实际结果。

- `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/app_ai_display_test.dart -d <connected Huawei> --dart-define-from-file=config/dev.json.example`：Debug 构建成功，按系统界面完成覆盖安装；真实手机执行 **2/2** 业务用例通过（驱动另计 setup/teardown，总输出 +4）。验证首页/我的在开启隐藏与恢复显示时切换、普通运动/百科/客服保留、已打开 AI 页面关闭、会话展示清空。使用内存合成配置，不访问真实账号/蓝牙，不等同线上管理员开关端到端验收。
- 最终普通 App 将用 `--build-number=1005` 构建以区别此前 1004 包；不改变服务端在线更新清单，不触发公开市场分发。
- 普通 Android Debug 与显式 QA Release 均构建成功：`flutter build apk --debug/--release --no-pub --target-platform=android-arm,android-arm64 --build-number=1005 --dart-define-from-file=config/dev.json.example`，Release 仅设置 `SAIDIAN_ALLOW_QA_RELEASE=true`，未绕过正式签名门禁。`gradlew.bat :app:testDebugUnitTest --console=plain` 31/31 通过。
- QA APK：`build/app/outputs/flutter-apk/app-release.apk`，70,144,622 字节，SHA-256 `c7dc69c7c9b14ab3a268064fed8bd82bc0cbdb5525fea632d5ecf3b6a4c0b333`；包名 `cn.saydian.ring`、版本 `0.1.21 (1005)`、arm64-v8a/armeabi-v7a。`apksigner verify --print-certs` 通过，仍为 Android Debug/QA 证书，SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，不是市场正式签名。
- `adb install -r` 已成功安装普通 QA Release（不是 integration target），但验收发现首次安装时间变为 2026-09-29 21:12:54，未能保留原应用数据，撤回此前仅凭覆盖安装成功的保留判断。
- 调试事故：`flutter drive` 默认在结束时调用 `drive_service.dart` 的 `stop()`，其中执行 `uninstallApp`。本轮未指定 `--keep-app-running`，导致同包名测试目标结束后自动卸载原应用。随后正常 QA 包实际为重新安装而非保留数据的覆盖升级。已即时告知用户，检查本地可恢复备份和当前登录状态；未删除云端数据、未对戒指发解绑/清数据命令。后续设备测试必须使用独立测试包名，或预先审查生命周期并显式保留应用；不能只按测试夹具的内存存储判断工具链无副作用。
- 重新打开正常 QA 包确认处于登录页；已请求用户用原身份重新登录，不代替用户重新同意协议，不尝试用假会话恢复真实身份。本地未同步健康记录与绑定偏好不能声称已恢复。测试源文件已加驱动卸载行为警告；后续安全命令须加 `--keep-app-running` 并优先使用专用 QA 设备。
- 正常 QA 包启动进程持续存活；仅检查该 PID 近期日志的异常计数，`FATAL EXCEPTION/ANR` 与 Flutter 未处理异常/布局溢出均为 0。登录页微信授权入口可见。未完成重新登录后的真实会员配置联动，不把受控内存测试写作生产账号端到端通过。
- 提交前显式格式检查 9 个修改的 Dart 文件，0 项需格式化；最终 `flutter analyze --no-pub` 零问题（36.9 秒），`git diff --check` 通过，重新 fetch 后 origin/main 与开发分支均仍为基线 `de5ff796`。保留既有无关 UI 文档空行改动，不暂存。
- iOS Debug/Profile/真机未执行：本机 Windows 无 Xcode/iPhone 工具链。鸿蒙显示实现验证见独立日志；无签名与设备，不声称原生鸿蒙安装成功。
- 已推送 App 源码 `d829b81b4e12112f8ed855c887fa766031d0b5ab` 到 origin/main 与开发分支，两者远端 SHA 核对一致；GitHub API 确認 `tangwu88/SayRing` 仍为 Private。
- App 云端 Actions `36573922061`（main）与 `36573921901`（开发分支）失败关闭；check annotations 明确是账号付款/额度限制，quality 与 Harmony jobs 未开始（steps=[]），Android/iOS skipped。不能称 App 云端 CI 通过，也未自行调整计费、权限或开放仓库。本机验证结果与云端限制分别保留。

## 线上等待交接（2026-09-29 21:42 中国时区）

- 后台 CI `36572298288` 的验证与镜像构建成功；发布 job `109421602679` 仍为 `in_progress`，当前步骤 `Deploy through constrained SSH receiver` 从 21:09:35 开始。尚无成功或失败结论，未取消或重复发布。
- 公网最后确认国内为 `3dab610c447ad2ce92e63b73ed65c3781580b46b`、国际为 `ef2f64323df46ddfe6ffeb415795429d3ed3e37e`，均 ready；新 app-display 接口此前仍 404。**不能称后台开关已上线**。
- 国际手工流程尚未派发。继续时必须先核对上述国内任务最终结果和 main 版本，再按 `deploy-production.yml` 已审输入使用国内 `37ff0faa4eaca64ee270c0bf4d804a816ab26f14` 与国际 `9e29aedff3620f14dae213e941e8f68e9468e9da`；远端有变化时重新协调，不盲目重发。完成后核对双域 ready、公开 app-display 和实际 `/admin/settings` 资源。
- 运行中日志 REST 返回 404，公开 job 页要求登录，本机无可用服务器 SSH 身份，无法确认具体等待阶段。已有 `Export runtime images` 不能让当前 `deploy-ci.sh` 跳过镜像拉取；未改接收器、维护状态、数据库或服务器服务来绕开限制。
- 正常安卓测试版已安装，但原账号重新登录与线上配置端到端仍待用户/服务器状态恢复；本条保留未验收状态，不宣称全部任务完成。
