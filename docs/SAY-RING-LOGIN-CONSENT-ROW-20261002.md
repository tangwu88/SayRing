# Say Ring 登录页勾选项与游客入口布局（2026-10-02）

## 基线与范围

- 用户确认将年龄确认与协议同意两个勾选项并排；随后明确本机入口文案改为“游客进入”，并删除按钮下说明文字。
- 修改前分支 `codex/macos-update-20260930`，HEAD `d144c8c40b0661403d1d90f0cf4b6f7522ab1d57`，工作树干净；`origin` 为 SayRing。`git fetch --prune` 与 `git pull --ff-only` 均完成，分支已与远端同步。
- 仅改 Say Ring 登录页和对应 Flutter widget tests；年龄/协议校验、两个勾选状态、本机连接行为、用户协议/隐私政策链接、账号登录接口均保持不变。不改服务端、账号或 App Store 审核资料。

## 修改

- `lib/ui/global_code_login_page.dart`：两个独立 `CheckboxListTile` 放入同一个响应式 `Row`，各自保留原控制器字段、校验和语义；游客入口改为“游客进入”，删除其下方的小字说明。
- `test/global_code_login_page_test.dart`：新增 390pt 手机宽度下两个独立勾选项处于同一行且无布局异常的用例；iOS 登录入口用例校验游客文案和说明文字移除；修正既有视口测试完整滚动/懒构建列表的可见性假设。

## 验证记录

- RED：新布局回归测试先于生产改动运行，按预期因 `code-login-consents-row` 不存在而失败。
- RED：游客入口测试先于文案改动运行，按预期因“游客进入”尚未出现而失败。
- 初次定向回归发现两项既有测试依赖默认 600pt 视口及列表缓存中的离屏控件；修正测试为显式完整可见和先断言顶部控件，再重跑。没有为测试问题改变生产业务行为。
- 定向 `flutter test --no-pub test/global_code_login_page_test.dart --reporter compact`：8/8 通过。
- `TZ=UTC flutter test --no-pub --concurrency=1 --reporter compact`：1044/1044 通过。
- `TZ=Asia/Shanghai flutter test --no-pub --concurrency=1 --reporter compact`：1044/1044 通过。
- `flutter analyze --no-pub`：No issues found。`dart format --output=none --set-exit-if-changed lib/ui/global_code_login_page.dart test/global_code_login_page_test.dart` 与 `git diff --check`：通过。
- `python3 scripts/release/test_release_gate.py`：30/30 通过，脚本还回报了发布 APK/manifest 检查通过；本轮没有生成或发布该 Android APK。
- `flutter build ios --debug --no-codesign --no-pub`：成功，`build/ios/iphoneos/Runner.app`。
- Profile 构建第一次未启动：执行器报告工作目录 `ENOENT`；核对目录存在后原命令重试成功。
- `flutter build ios --profile --no-codesign --no-pub`：重试成功，`build/ios/iphoneos/Runner.app`，约 71.5MB。构建警告仍包括部分插件不支持 SPM，以及微信框架不支持 Apple Silicon arm64 模拟器；本目标是 iPhone 真机设备架构构建。
- `flutter build apk --debug --target-platform=android-arm,android-arm64`：依赖解析后停在 Gradle included-build / plugin classpath 配置，没有新的构建输出；线程转储位于 Gradle `DefaultBuildControllers.awaitCompletion` 等待点，约 5 分钟无进展后手动中止。不是源码编译错误，也未产生本轮 APK 验收证据。Android Release 因同一前置 Gradle 插件解析阻断未运行，不能标记通过。
- 设备未安装/启动本轮构建；本轮无真机 UI 验收证据。

## 验收边界

- 当前验证覆盖 390pt 简体中文布局、登录门禁回归和 iOS 游客入口存在；不代表线上邮箱登录已解除服务端协议未发布阻断。
- 实际设备字体缩放、极窄屏和安装后的视觉效果仍待真机/模拟器复核。未操作或覆盖用户手机。
