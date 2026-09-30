# 2026-09-30 Say Ring 联系客服页面对齐

## 修改前检查

- 仓库基线为 `origin/main` 的 `d8eb123ec15805386b5f984500399297a65418a0`；已执行 `git status --short --branch`、`git remote -v` 与 `git fetch origin --prune`。
- 原工作区已有 `docs/SAY-RING-YOUTHFUL-LUCKRING-UI-20260928.md` 未提交改动，因此从同一远端基线建立独立工作树 `E:\SayRing-contact-support-20260930`，没有覆盖或暂存该改动。
- 已阅读 `AGENTS.md`、国际版交接、跨模块问题复盘、回归清单和最近的 R22、AI 显示、HR05/客服实施记录。

## 原因、范围与预期

- 用户要求 Say Ring 的“联系客服”页直接对齐 `E:\saydian\赛电app` 参考页面。
- 国际版继续只读取 `/global/api/saydian-app/v2/support/config` 的后台配置，不写死参考项目的国内客服电话或公众号。
- Flutter 与原生鸿蒙有效配置下均保留参考页的双联系卡片、电话拨号、公众号复制与隐私提示；拨号失败时明确显示当前后台号码，复制成功时显示当前后台公众号。
- 加载阶段只显示加载状态，避免把尚未返回误报成“未配置”；未配置、网络失败、联系方式不完整仍分别显示真实状态。
- 本轮不改设备能力、健康数据、登录、更新、推送或 SDK 逻辑。

## 验证记录

- 初次使用历史记录中的 `D:`/`F:` Flutter 路径，PowerShell 报命令不存在；改用本机实际工具链 `E:\saydian\.toolchains\flutter\bin`。首次带 `--no-pub` 运行定向测试时因新工作树尚无 `.dart_tool` 失败，先执行 `flutter pub get` 后恢复。
- `dart format lib/ui/prototype_pages.dart test/global_localized_pages_test.dart`：通过；复查无格式变化。
- `flutter test --no-pub test/global_localized_pages_test.dart`：24/24 通过，覆盖后台动态号码/公众号、双操作按钮和不回退国内固定联系方式。
- `flutter analyze --no-pub`：通过，无问题。
- UTC 与 `Asia/Shanghai` 时区分别执行全量 `flutter test --no-pub`：各 921/921 通过。
- `android\gradlew.bat :app:testDebugUnitTest --offline --console=plain`：通过，300 个任务；首次运行发现 Gradle 精确 transform 缓存损坏，停止本项目 daemon 后仅把该目录移至 `E:\saydian\.toolchains\gradle-quarantine\qring-transform-7d449599-20260930T034316Z`，未删除共享缓存或源码。
- Flutter Android Debug APK：构建通过，`158726052` 字节，SHA-256 `3CF89FFBECF0BDD1318CC6D002CF943244BA7046E7E60E4A5EDCC52D7FB39F2E`。
- Flutter Android QA Release APK：首次以既有 Gradle 4G JVM 配置构建时发生本机 Java 原生内存不足；临时将本次构建 JVM 调低到 2G/2 workers 后通过，并已把 `android/gradle.properties` 完整恢复，未纳入差异。产物 `70144686` 字节，SHA-256 `BDF27ACDA1E85A8ACE32E910BCF856E70EB15424C12C23680499FCDC4BED9BFB`。
- `apksigner verify --print-certs`：Debug 与 QA Release APK 均校验通过；两者均为同一 QA Debug 证书，SHA-256 指纹 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，不是应用市场正式签名。
- `node --test tool/test_native_log_privacy.mjs tool/global_auth_smoke.test.mjs tool/global_auth_account_qa.test.mjs`：87/87 通过。
- 原生鸿蒙新增公开客服配置解析、固定国际版接口、加载/错误/重试、拨号和剪贴板复制；`node --test harmony-native/tests/*.test.mjs` 最终 501/501 通过。首次全量运行因旧测试仍要求已移除的 `contact_feedback` 入口而 500/501，通过按新参考页行为改为检查 `contact_call`、`contact_copy`、`contact_retry` 后全量通过。
- 鸿蒙首次编译因新工作树尚无 `oh_modules` 导致供应商 SDK 无法解析；执行锁文件对应的 `ohpm install --all` 后，Debug 与 Release `assembleHap --no-daemon` 均构建成功。Release 未签名 HAP 为 `18384357` 字节，SHA-256 `C066FBE0DF3F7F3C6B1E5327E6D9830B70367B2AD166E28EB8AA36E39F5FAB89`；工程未提交发布签名配置，不能作为应用市场正式包。
- `git diff --check`：通过；只有仓库既有 Windows 行尾转换提示。

## 未执行与边界

- 当前 Windows 无法执行 iOS Debug/Profile 或 Xcode Archive；iOS 页面使用同一 Flutter 代码，但本轮不能写为 iOS 已编译或真机通过。
- 本轮未安装到手机，也未进行真实拨号、微信搜索或鸿蒙真机剪贴板验收；自动化与编译通过不等于系统应用联调通过。
- 线上公开客服接口当前仍可能返回 `configured=false`；页面已修复提示和重试，但实际联系方式必须由管理员在后台填写并公开后才会显示。
