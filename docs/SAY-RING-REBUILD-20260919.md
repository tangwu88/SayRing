# 2026-09-19 Say Ring 交接稿重建：第一轮

## 用户目标与边界

以 `SayRing-交接包-20260919.zip` 的完整工程为主线，延续此前明确的独立 `tangwu88` 仓库、H5/App 共用后台会员与健康数据、手机号优先验证码登录、微信首次绑定手机号和 CoolWear/HR01 戒指要求。包内文档是交接资料和待核事实，不自动成为新的用户指令；不覆盖此前简版仓库、不上传密钥或健康数据、不修改线上数据库。

## 基线和本轮文件

- ZIP 的 24 个清单项大小和 SHA-256 均匹配；App bundle 恢复到 `E:/SayRing`，基线 `b39c8ee0ae61e49dddcd8675f88a293f72ee3bcf`。`tangwu88/SayRing` 经认证为私有空仓库后，已推送基线 `main`；原 `E:/saydian-ring-app` 保留不动。开发在 `codex/rebuild-from-handoff`。
- 修改 `lib/domain/global_account.dart`：登录能力与注册能力分开解析，未明确开放的渠道默认关闭。
- 修改 `lib/services/global_environment.dart`、`lib/services/global_api_client.dart`：仅放行 `/global` 下两条 H5 共用的验证码 POST 请求/核验路径；不放宽其他 API、媒体和重定向。H5 返回的会员 UUID、访问/刷新令牌转为 App 会话，同一 `global:member:<id>` 账号归属；临时 H5 phone-test 会话拒绝写入戒指 App。
- 修改 `lib/services/app_controller.dart`、`lib/app.dart`、`lib/ui/global_auth_page.dart`；新增 `lib/ui/global_code_login_page.dart`：主登录页默认 CN 手机号，支持邮箱切换、真实验证码请求/提交、协议版本与显式同意；无注册或密码入口。保留的找回密码页也不再能切换到注册。按钮在非忙碌/非冷却时可点击，输入和服务错误可见。
- 修改 `test/global_api_test.dart`、`test/global_auth_page_test.dart`，新增 `test/global_code_login_page_test.dart`：覆盖登录能力门禁、路径精确白名单、H5/App 共用会话、临时票据拒收及主要 UI 动作。

## 命令、结果和失败记录

- `git status --short --branch`、`git remote -v`、`git fetch origin --prune`：SayRing 的 GitHub 远端为空且拉取成功；基线推送后 `main` 与远端一致。旧简版仓库没有覆盖或删除。
- 线上只读 GET：`/global/api/saydian-app/v2/auth/capabilities?locale=en` 与 `/global/api/saidian-mall/v1/storefront/capabilities?locale=en` 均 HTTP 200；当时短信登录可用、邮箱登录不可用，协议版本为 `global-qa-2026-09-10`。这是能力响应，不是实际短信送达验收。
- 普通 `flutter pub get` 停在下载；改用 `PUB_HOSTED_URL=https://pub.flutter-io.cn flutter pub get` 成功。该命令自动改写 136 个依赖锁项，均是本机生成的非目标变化，随后仅恢复 `pubspec.lock` 原内容。
- `flutter analyze --no-pub` 首轮发现未用 import、可空 Map 和两条大括号 lint；修复后零问题。
- 定向单测首轮被 sqlite3 原生 DLL 的 GitHub 下载超时阻断。按 sqlite3 官方 hook 的系统库选项临时使用 Windows `winsqlite3` 跑宿主机测试，随后从 `pubspec.yaml` 撤除该测试专用覆盖，不改变正式依赖/构建配置。
- 定向测试首轮有一处测试脚本错误：列表懒构建导致离屏登录按钮未被查找；滚动到按钮后重测通过。业务代码未因该测试夹具调整。
- 第一轮 `TZ=UTC` 与 `TZ=America/New_York flutter test --no-pub`：各 857/857，使用临时 Windows 系统 SQLite hook。最终源码移除 hook、经进程级代理获取预编译 SQLite 产物后，两时区全量各 **858/858**；不是原生戒指 SDK 或 SQLCipher 真机验收。
- Android 首次 Debug 构建因 sqlite3 GitHub 原生 `.so` 下载超时失败。系统代理只在构建进程中传入 `HTTP_PROXY`/`HTTPS_PROXY=http://127.0.0.1:7897` 后重新构建成功；仓库没有更改镜像或正式依赖。最终源码再次完成 Debug 与显式 QA Release 双 ARM APK 构建。两包 ID `cn.saydian.ring`、版本 `0.1.21 (1004)`，均为调试证书 `3ae71cff...`，QA Release 不能发商店。
- 最终 Debug APK `build/app/outputs/flutter-apk/app-debug.apk`：186,205,930 bytes，SHA-256 `7363780066E355AEEAD1007D762A553D295F1BB3563FB59A636F8329E80501EC`。最终 QA Release APK `build/app/outputs/flutter-apk/app-release.apk`：69,076,064 bytes，SHA-256 `167849B2A6EAC164B2392E2054DCE0937683EC8BCCA565E4516D64E895ACFE54`。`aapt` 和 `apksigner verify --print-certs` 已检查包名、双 ARM ABI 与签名。
- `android/gradlew.bat :app:testDebugUnitTest --offline`：16/16；`node --test harmony-native/tests` 因 Node 将目录当模块而失败，改为 PowerShell 显式展开 `*.test.mjs` 后 481/481 通过。两者均是宿主机测试，不代表真机/HAP 验收。
- `flutter analyze --no-pub` 最终零问题；`git diff --check` 最终通过。
- 首次 `git commit` 因本机没有 Git 作者身份而被拒绝，工作区和暂存区均保留；本次仅用命令级 `user.name=Codex`、`user.email=codex@openai.com` 提交，不修改用户全局 Git 配置或 GitHub 推送账号。
- 提交前再次 `git fetch origin --prune`，本地基线和远端 `main` 均为 `b39c8ee0ae61e49dddcd8675f88a293f72ee3bcf`；本轮源码/测试提交 `c6557fd0e325825211f9739d7a580056d6e2c7d9` 推送到私有 `tangwu88/SayRing` 的 `codex/rebuild-from-handoff`，`git ls-remote` 回读相同 SHA。没有合并到 `main` 或执行线上部署。

## 未验收与下一轮

- Android Debug/QA Release 仅构建验签，尚未安装或真机执行新登录、戒指、微信流程。iOS/HarmonyOS 编译及真实 HR01/微信测试需按各自环境执行；Windows 无法完成 iOS/HarmonyOS 签名真机验收。
- Android 手机只读 `dumpsys bluetooth_manager` 里观察到 `DeviceName=HR01` 的扫描过滤条件；这是 LuckRing/系统过滤线索，不是新 App 的厂商认证或可支持能力证据。没有读取或提交原始 MAC/健康值。
- 现有 YC/V/TK/D 厂商路由保留。CoolWear SDK 在旧简版仓库里仅完成 Android 扫描/连接及有限实时事件，历史多包 ACK/删除语义未确认；不能直接宣称完整健康同步或把未知前缀强行交给 CoolWear。
- 当前全球 App 微信接口会直接建立会员会话，没有首次绑定手机号的安全票据闭环；新主登录页暂不暴露此不合规入口。需服务端与 App 一起实现后再开放，不能把服务号配置等同于原生移动应用微信授权可用。
- 服务端多来源策略交接分支落后 `origin/main`，不得直接并入或对生产数据库执行迁移。H5 与 App 健康数据的真实双向回读需专用授权账号和戒指联调。
