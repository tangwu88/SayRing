# Say Ring 登录注册恢复与 iPhone 调试（2026-10-02）

## 范围与基线

- 用户要求简化实际流程、启用登录注册并启动 iOS 真机调试；只改 Say Ring，不操作 App Store 审核或另外两款 App。
- 修改前工作树干净，HEAD `a6ff0bbc33b72e4035ef2845bd38d94256a2cddd`；已执行 `git fetch origin --prune` 和当前分支 `git merge --ff-only origin/codex/macos-update-20260930`，结果已同步。
- 保留 `cn.saydian.ring`、登录主入口、单一游客入口、iOS 微信隐藏及现有数据。iPhone 原位覆盖，不卸载或清库。

## 问题、预期与修改范围

- P1：主登录页没有注册入口。预期使用服务端已开放的注册渠道；本轮复用现有账号表单，新增入口，不绕过服务端开关。
- P1：注册 UI 和请求缺少 `ageConfirmed`，服务端对 Say Ring 新账号要求该字段。新增独立、默认未勾选的年龄确认，和协议同意并排，并传递真实选择；密码找回不新增年龄要求。
- P1：iOS 账户登录的协议链接固定跳转旧本机版，和登录提交的协议版本不一致。有已发布专属协议时使用产品/版本校验页面；仅服务不可用时保留游客的公开协议入口。
- 影响文件：`lib/ui/global_code_login_page.dart`、`lib/ui/global_auth_page.dart`、`lib/services/app_controller.dart`、`lib/services/global_api_client.dart` 及对应测试。设备 SDK、健康数值、账号隔离与其他产品不变。

## 线上与环境事实

- 本轮早先缺少产品协议的状态已发生变化。22:22 左右生产 capabilities 回读有 Say Ring 协议版本、注册能力与短信登录能力；`login.email=false` 表示邮箱验证码投递关闭，不等同于密码登录关闭。
- 已用用户指定的专用演示账号请求生产邮箱密码登录，HTTP 201 / 业务 code 200，随后个人资料读取 HTTP 200；未输出或保存凭据、Token、资料或健康值到 Git。真实注册尚未执行。
- iPhone 15 Pro Max / iOS 26.6 已连接、开发者模式 enabled；安装前设备回读 Say Ring `0.1.21 (1006)`。无并行 Flutter/Xcode 构建；系统可用空间约 8.6 GiB。
- 已按用户授权协调现有服务端任务核对开关和简化公开文案；其部署、协议状态以线上回读为准，不把派发协作写作完成。

## 验证记录

- `dart format` 本轮 9 个 Dart 文件，3 个格式化；新增真机 smoke/driver 2 个文件另行格式化。两次 `flutter analyze --no-pub` 均为 No issues found。
- 登录、注册、同意、API、账号会话定向测试 91/91 通过：`flutter test --no-pub test/global_code_login_page_test.dart test/global_auth_page_test.dart test/global_auth_consent_test.dart test/global_api_test.dart test/app_notification_controller_test.dart --reporter expanded`。
- `TZ=UTC flutter test --no-pub --concurrency=2 --reporter expanded` 与 `TZ=Asia/Shanghai` 同命令各 1046/1046 通过。日志分别为 `.build/sayring-auth-full-utc-20261002.log`、`.build/sayring-auth-full-shanghai-20261002.log`。
- `python3 scripts/release/test_release_gate.py` 30/30 通过；其旧 APK 夹具输出不是本轮 Android 构建或发布证据。Android/Harmony 按用户优先级后置，没有运行本轮 APK 或原生测试。
- 首次真机命令未执行：前置 `ps | rg` 没有匹配进程而返回 1，`&&` 阻止了 `flutter drive`；检查源码无问题后直接重跑 drive。未把无日志的这次尝试算作真机测试。
- `flutter drive --no-pub --driver=test_driver/ios_auth_smoke.dart --target=integration_test/ios_auth_entry_smoke_test.dart -d <已连接 iPhone> --keep-app-running --dart-define-from-file=config/ios-app-store-no-push.json`：Debug 编译 25.7 秒，安装启动 21.6 秒，真实用例 1/1（加 teardown）通过。测试不发送 OTP、不新增账号、不修改登录会话或健康数据。
- 真机实际验证：生产协议/注册能力、邮箱密码入口、两份专属协议加载、注册表单、并排且初始未勾选的年龄/协议选项、注册按钮可用、返回主登录及单一游客入口；iOS 无微信入口。测试前后会话 owner 相同。截图 `.build/sayring-ios-login-20261002.png`、`.build/sayring-ios-register-20261002.png` 已目视检查，不含真实账号或健康值。
- 对已确认存在的用户指定测试账号，生产 `/auth/register` 在年龄未确认时 HTTP 400、确认后 HTTP 409；没有新建账号。该结果证明路由已响应校验而非此前 503，不等同于真实新用户完整注册验收。未做真实 OTP 送达或密码找回。
- 串行 `TMPDIR=/private/tmp flutter build ios --profile --no-pub --build-name=1.0 --build-number=1022 --dart-define-from-file=config/ios-app-store-no-push.json` 成功，71.5 秒，65.3MB。实际 Info.plist 为 `cn.saydian.ring`、`1.0.0 (1022)`、`UIDeviceFamily=[1]`；Apple Development / Team `W7SXQ4A226`，`codesign --verify --deep --strict` 通过。已保存 `.build/SayRing-1.0-1022-Profile.app` 供独立启动使用。
- Profile 1022 未卸载原 App 即覆盖安装成功，`devicectl device process launch --terminate-existing cn.saydian.ring` 启动成功。
- 随后同参数 `flutter build ios --debug` 串行构建成功，47.4 秒；签名与 Info.plist 复核通过。`flutter run --debug --no-pub --use-application-binary=build/ios/iphoneos/Runner.app -d <已连接 iPhone> --dart-define-from-file=config/ios-app-store-no-push.json` 安装启动 20.9 秒，已输出 iPhone Dart VM Service 和 Flutter DevTools 地址并保持附加。
- 设备回读为 `Say Ring / cn.saydian.ring / 1.0.0 / 1022`。启动日志显示认证会话恢复及资料、图片等请求 200；原测试不替换账号。未逐条比较原健康库，不能扩展为全部旧数据完整性验收。
- 提交后的交付复核发现首个 Flutter 调试会话出现 `Lost connection to device`，设备仍为 connected；未确认断开根因，不能将首次附加等同于持续稳定性。使用同一个已签名 Debug 二进制、相同 `flutter run --use-application-binary` 命令重新覆盖启动；再次完成文件同步、Dart VM Service 和 DevTools 附加，未重编译、卸载或清除数据。
- Xcode/Flutter 仍提示 `sqflite_sqlcipher`、`yc_product_plugin` 暂未迁移 SPM，以及微信框架缺模拟器 arm64；本轮目标为 iPhone 真机，以上未阻止构建。没有声称原生 XCTest、全部硬件测量、注册投递或 App Store 通过。

## 协议处理边界

- 本轮检查时，后台原有两份 `say-ring-cn-2026-10-draft-1` 已被设置为 reviewed/active，但公开正文仍含“未发布”及内部核对清单；本轮未执行该旧版本激活操作。
- 服务端任务提供了实现核对记录；其中邮箱验证码能力与密码登录的区别已反馈纠正。新文本按共享账号、实际登录云同步、头像专用本地卷及注销排队/实际处理流程简化，不编造自动清理或单独敏感数据授权已实现。
- 后台明确要求新版本经过法律审核后才启用，已审核内容不可原位改写。本轮整理配对新稿，不删除旧文档、不伪造法律审核完成。登录和调试的成功不等同于全部法律合规或苹果审核通过。
- 两份 `zh-Hans / say-ring-cn-2026-10-02-v2` 已通过后台保存并回读，用户协议记录时间 `2026-10-02T14:42:50.616Z`、隐私政策 `2026-10-02T14:45:36.226Z`；列表均为“已审核：否、启用：否”。后台“发布时间”列在草稿创建时也会出现时间，不作为已发布证据。
- 随后的独立后台变更把 v2 两份均切换为“已审核：是、启用：是”，并停用了旧版；本轮没有执行这项后台状态变更。生产只读 `GET /global/api/saydian-app/v2/auth/capabilities?locale=zh-Hans&product=say-ring` 回读 HTTP 200 / code 200、product `say-ring`、consentVersion 和用户协议/隐私政策版本均为 v2。服务器状态是其审核标志的证据，不代表法律意见或 Apple 审核结果。
- 当前同一响应显示注册 email/SMS 均 enabled，`verificationRequired=false`；登录 capabilities 为邮箱密码入口关闭、短信登录开启。iOS 主登录保留注册与游客入口，WeChat 不在 iOS UI 暴露。本轮没有更改注册验证、认证或安全开关，也没有更改其他产品文档。静态 `/say-ring/privacy` 和 `/say-ring/terms` 仍待与动态版本对齐；客户端本轮的登录协议入口读动态 v2。
