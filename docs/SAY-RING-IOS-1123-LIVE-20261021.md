# Say Ring 1123 真机调试（2026-10-21）

## 范围与基线

用户要求开启苹果真机调试，沿用上一轮暖白图形化界面。工作区 `SayRing-native-mall-20261020`，分支 `codex/qring-visual-refresh-20261021`，起点 `f7aed32095c36e7d753d485b13ec32af065e9b3a`。开始工作区干净，fetch/ff-only已确认当前分支最新，无业务源码变化。

真实目标是已连接、wired、已配对且解锁的 iPhone 15 Pro Max（iOS26.6），开发者模式已开启。另有iPhone XR在线，但未对其安装、运行或更改。首次默认应用查询只列开发应用，未显示Say Ring；按帮助加 `--include-all-apps --bundle-id cn.saydian.ring` 后确认手机已装App Store版1.0.4（1120），不是应用缺失。

## 数据保护与明确授权

App Store版原生返回 `containerAccessible=false`，容器目录读取实际失败；没有找到该目标的Finder本机备份。先完成可安装候选的构建与签名检查，再依项目AGENTS.md的测试前备份要求询问用户。用户明确选择“允许跳过本次备份，直接原位覆盖安装（不卸载）”。该授权仅适用于本次覆盖，不自动取消后续测试的备份要求。

本次未调用uninstall、清库、解绑或退出登录。没有可用的安装前容器哈希，因此不能声明做过完整数据一致性比对或保证全部原文件未变。授权与设备/安装原始回执仅留本机忽略目录。

## 构建与签名

- 使用上一轮已通过本机双时区各1373项、双端构建的同一运行源码；本轮无业务源码修改，不重复声称重新执行全量测试。
- Flutter Profile config-only/no-codesign配置8.0秒退出0，参数 `--dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --build-name=1.0.5 --build-number=1123`。
- 首次将手工描述文件作为全局xcodebuild参数，导致Pods/framework被错误要求使用描述文件，3.6秒退出65；没有安装失败候选。保留日志后改为自动签名，用已存在的本机开发证书/描述文件，不修改依赖或签名门禁。
- 最终 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Profile -sdk iphoneos -destination id=<目标UDID> -derivedDataPath build/ios-live-1123-20261021/derived IPHONEOS_DEPLOYMENT_TARGET=15.0 SAIDIAN_DEVELOPMENT_TEAM=W7SXQ4A226 DEVELOPMENT_TEAM=W7SXQ4A226 CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY=Apple\ Development build`：46.7秒退出0，BUILD SUCCEEDED。
- 候选APFS clone冻结为 `verified-profile-1123.app`；深度/严格codesign通过。实际包名 `cn.saydian.ring`、1.0.5（1123），App ID/团队W7SXQ4A226匹配；描述文件有效并包含本次设备，get-task-allow=true，Profile无JIT kernel。
- 冻结Runner SHA256 `0928ff8523f02d38b5d2d8f617215f91bc15ae64e035358998b24773c4186224`；App.framework SHA256 `25b8ade11959ecddfe0af70f425e02fe70ac1d0d31d055b997285459d93b5461`。独立复验后才安装，不复用旧版二进制。

## 安装与当前调试

安装器重新核对目标原1120版本和冻结包签名/哈希，再调用 `devicectl device install app` 原位覆盖；原生安装回执退出0。再次按精确bundle查询，实际为1.0.5（1123），containerAccessible=true。未替换其它App，也未更改服务器或商店发布。

`devicectl device process launch` 激活Say Ring成功；原生PID5402与安装的新应用路径一致。`flutter attach --profile --machine --device-id <目标UDID> --app-id cn.saydian.ring --device-connection attached` 已报告app.started，目标为Profile。Profile支持运行/性能调试，不宣称热重载或Debug Widget Inspector可用。

核验期间手机切到了其它应用，Say Ring后台暂停：只读VM请求超时，DevTools本机服务已启动但未获最终可用连接证据。未把app.started单独等同完整实时可用；已请求用户保持Say Ring前台约1分钟继续核验。未抢占当前其它应用，也未分析其内容。当前屏幕等私有证据不进入Git。

本轮不运行flutter drive或卸载式集成测试；不发起手动健康测量、真实交易、AI报告上传或更改戒指设置。实际登录、历史记录完整性、蓝牙性能和新版全页面验收若未实测，仍保持待验。

日志、开发签名包、设备/安装回执、VM认证信息与截图均保存在权限收紧且Git忽略的 `build/ios-live-1123-20261021/`。另只读复查前轮源码CI39623058637，当时仍in_progress，未将其写为全部通过。

## 前台恢复与最终核验

用户确认已打开Say Ring并保持前台。原调试会话在后台期间已丢失连接，旧DDS已退出；没有把已退出的会话写为在线。随后重新attach，首次原生进程过滤误把URL字段用CONTAINS，CoreDevice拒绝该谓词；改用其支持的 `--search` 查实际路径，确认原应用仍存在。

手机实际截图确认新版首页已在前台，原登录资料和旧摘要可见；不据此替代全部健康数据一致性比对。截图中热量展示明显偏大，来源、单位及汇总口径尚未核对，作为后续数据问题保留；没有更改健康数值或算法。

在用户保持前台时只正常重启一次Say Ring进程，使已超时的VM服务重新建立；没有重装或卸载。新的原生PID5405与新安装应用路径一致；重新attach成功，真实Dart VM `getVM` 返回PID5405和main isolate，`_flutter.listViews`返回1个view。DevTools页面HTTP200且实际返回HTML，已用系统浏览器打开。

最终核验时间：北京时间2026-10-21 23:32:11。运行模式Profile；可独立启动，可作运行与性能调试；本轮不声称支持热重载。当前Flutter attach保留在线，不发送q/stop，不关闭应用。用户后续切后台、锁屏或拔线时可能暂停实时通讯，应重新核对后再续测，不误当崩溃。

本次启动目标完成：签名/精确设备核验、原位安装1123、新版实际首页、原生/Dart同进程与DevTools连通均有独立证据。蓝牙连接/同步耗时、全部历史记录保留、热量异常、睡眠详情和新测量并未在本轮完整验收。只提交验证记录，不修改运行源码、发布或生产配置；VM令牌/私有截图均不入Git。
