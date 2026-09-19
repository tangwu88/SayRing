# 2026-09-19 Say Ring 视觉、微信入口与功能清单

## 原因与范围

用户要求整体风格接近手机上的 LuckRing、增加微信授权，并把此前确定的戒指 App 功能清单纳入当前工程。现场只读查看 LuckRing 的首页、睡眠、运动、我的四页；只借鉴深色底、圆角卡片、四栏节奏与信息层级，不复制其图片/图标/代码。用户健康值、头像、设备标识和截图不入 Git。

修改前 `E:/SayRing` 工作区干净，分支 `codex/rebuild-from-handoff`，HEAD `7b950148ee1589f9f0efe2cab2445af4559fa5e5`，本地远端跟踪 SHA 相同。`git fetch origin --prune` 因 GitHub 连接重置失败，不能声称已同步远端。服务端仓库只读检查：其当前分支 `codex/global-api-foundation`，fetch 亦因连接失败，未修改或发布服务端。

## 修改文件与影响

- `lib/ui/ring_shell.dart`、`lib/app.dart`：国际版使用原创深色四栏主界面；首页显示真实/未知健康值，睡眠和运动独立入口；旧健康详情、关爱、运动记录、设备页和设置继续可进入。国内/兼容 `AppShell` 未替换。未计算未验证的准备度分数，也未强行开放无能力的运动模式。
- `lib/ui/global_code_login_page.dart`、`lib/domain/global_account.dart`、九份 ARB 与生成的本地化文件：验证码登录页改为戒指专用深色风格；微信入口受 `login.wechatApp.enabled` 显式能力控制，未声明时显示不可用说明。现有服务端没有该能力字段，国际微信 App 端点当前拒绝请求；本轮没有把旧自动建会员会话的接口接到新登录页。
- `docs/SAY-RING-FEATURE-MATRIX-20260919.md`：按账户/设备/健康/睡眠/运动/云端互通/我的列出目标、当前实现和实物/服务端验收门槛。
- `test/ui_shell_test.dart`、`test/global_code_login_page_test.dart`、`test/global_api_test.dart`：四栏、未知值、2 倍字号、微信能力默认关闭等回归。

## 逐次检查与失败修复

1. `flutter analyze --no-pub` 首次发现新页面漏引入 `global_locale_controller.dart`，导致 `context.l10n` 47 条错误；补全 import 后零问题。
2. 新四栏 390×844 Widget 测试首次发现首页固定高度概览卡溢出 6 像素；高度调整到 264 后通过。375×812/2 倍字号测试首次溢出 120 像素；按字级放大卡片高度后通过。
3. `flutter gen-l10n` 成功；`dart format` 格式化本轮 Dart 文件。
4. 登录/主界面定向测试通过。UTC 全量第一次为 860 通过、1 失败：新微信按钮在懒构建列表视口外，测试脚本直接查找不到；改为滚动定位后登录定向测试通过。无业务代码因该夹具错误回退。
5. `TZ=UTC flutter test --no-pub -r expanded`：**861/861 通过**；`TZ=America/New_York flutter test --no-pub -r expanded`：**861/861 通过**。
6. 线上只读 `GET /global/api/saydian-app/v2/auth/capabilities?locale=zh-Hans`：`realm=global`、短信登录 `true`、邮箱登录 `false`、`wechatApp` 字段不存在、协议版本存在。此项只是能力探针，不代表实际短信送达或微信联调。
7. Android Debug 构建首次停在依赖下载，人工停止后改用 `--no-pub`。随后因临时 `JAVA_HOME` 指向 JDK 父目录而立即失败；改为实际子目录后，Gradle 又因直接连 Google Maven 长时间等待。核对本机 `127.0.0.1:7897` 代理可到达依赖源，仅本次命令注入 `JAVA_TOOL_OPTIONS` 中的 Java HTTP(S) 代理配置后，Debug 在 166.2 秒构建成功。仓库未写入代理设置。
8. 同一锁定依赖和国际 API 配置的显式内部 QA Release 在 102.3 秒构建成功。两包均为 `cn.saydian.ring`、`Say Ring`、`0.1.21 (1004)`、minSdk 26、ARMv7/ARM64，签名 SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`；QA Release 仍为调试证书，不能上架。
   - Debug：186,236,810 字节，SHA-256 `02571162E3D8B2ABEE22705C9BEC12A6A9C9B3062260A6ED9ED5CC3F37E2DFF3`。
   - QA Release：69,125,432 字节，SHA-256 `F5E12010DBF3D63B3D82E36E36027B0A79889EB23B5B192634BA261415B7C842`。
9. Android `:app:testDebugUnitTest` 首次命令工作目录重复加 `android/`，命令找不到；修正路径后 `--offline` 因 x86_64 Flutter 测试引擎未缓存而失败。只给测试命令注入 Java HTTP(S) 代理后正常执行，4 份 XML 共 **16/16**，失败/错误/跳过均为 0。Kotlin 插件及 Gradle 10 弃用提示仍待后续升级。
10. 本轮 `dart format --output=none --set-exit-if-changed` 修改文件 0 个待格式化；最终 `flutter analyze --no-pub` 零问题、`git diff --check` 通过。
11. `node --test harmony-native/tests/*.test.mjs` 以 PowerShell 显式展开文件后 **481/481** 宿主测试通过；不代表 HAP 编译或鸿蒙真机验收。
12. 尝试用 `adb install -r --no-streaming` 把新 Debug 包覆盖安装到已授权华为手机：186,236,810 字节已推送，手机转入 AOD/锁屏后安装器一直等待；提示用户解锁确认后仍未完成，本轮主动终止等待。随后在手机上只读 `sha256sum` 已装 `cn.saydian.ring` 的 base.apk 仍为旧包 `7363780066e355aeead1007d762a553d295f1bb3563fb59a636f8329e80501ec`，因此**新界面未安装、未做真机页面验收**。没有卸载、清数据或改动 LuckRing。
13. 提交前改用本机已验证的单次 Git HTTP 代理执行 `git fetch origin --prune` 成功；本地与 `origin/codex/rebuild-from-handoff` 均仍为 `7b950148ee1589f9f0efe2cab2445af4559fa5e5`，无远端分叉。`git diff --check` 返回 0（仅 CRLF 转换警告）。

## 未完成与上线门禁

- 当前微信入口默认不可用：缺移动应用 AppID/Android 正式签名/iOS 回跳配置，国际服务端无 App 微信首次绑定手机号票据闭环。公众号已绑定开放平台不等于移动应用能力；不能把按钮出现当作登录成功。
- HR01/CoolWear 真戒指、H5↔App 健康数据双向联调、Android/iOS 各三轮连接及生产服务端多来源策略仍待授权样机与联调。LuckRing 原 App 和旧简版 App 均未卸载/清数据。
- Windows 无法执行 iOS Debug/Profile 构建或 iPhone 真机验收；HarmonyOS HAP 未在本轮编译。不能把 Flutter/宿主测试写成真机或供应商验收。
- 未请求生产发布；没有数据库迁移、远端合并、正式签名或线上部署。
