# 2026-09-19 Say Ring 页面回退与重新安装

## 原因与范围

用户明确要求取消刚安装的深色四栏新界面，恢复上一个版本页面并重新安装。本轮仅回退 `d48c698` 引入的 App 页面、微信入口能力扩展及其测试/本地化资源；保留 `c6557fd` 的国际版手机号优先验证码登录、原三栏页面和所有既有设备/健康逻辑。历史实施记录与功能清单不删除，功能清单改写当前状态。微信原生授权此前尚未打通，本轮不宣称可用。

修改前分支 `codex/rebuild-from-handoff` 工作树干净；本地与经命令级代理 `git fetch origin --prune` 后的远端均为 `c17bb6f85e3ea39505de3da60c3402e4d2f46651`。Git 远端为 `tangwu88/SayRing`，未碰其他仓库。已阅读 `AGENTS.md`、国际版交接、最新实施记录及回归边界。

## 修改文件与预期

- `lib/app.dart`、`lib/ui/global_code_login_page.dart`、删除 `lib/ui/ring_shell.dart`：国际版已登录主界面恢复原 `AppShell`（健康/设备/我的），登录页恢复改版前验证码页。
- `lib/domain/global_account.dart`、`lib/l10n/`、`test/`：撤回只服务于该新界面/微信可见入口的能力字段、文案与测试；旧的手机号/邮箱验证码登录和现有设备/健康测试保持原样。
- `docs/SAY-RING-FEATURE-MATRIX-20260919.md`、`docs/CHANGE-TEST-LOG.md`、本记录：保留历史与未完成事项，明确当前页面已回退。

预期源码 `lib/`、`test/` 与改版前提交 `7b950148ee1589f9f0efe2cab2445af4559fa5e5` 完全一致，再生成同包名 APK 覆盖安装，不卸载、不清数据、不修改 LuckRing。

## 执行与验收

- 回退命令 `git revert --no-commit d48c698` 对后来追加的历史记录产生预期的 modify/delete 冲突；仅将三份文档恢复到本轮 HEAD 保留历史，`git revert --quit` 保留已应用的源码反向补丁。`git diff 7b950148 -- lib test` 为空，证明业务源码和测试已精确回到改版前内容；没有丢弃用户改动。
- `flutter analyze --no-pub`：零问题；`TZ=UTC flutter test --no-pub` 与 `TZ=America/New_York flutter test --no-pub`：各 **858/858** 通过。`node --test harmony-native/tests/*.test.mjs`（PowerShell 显式文件展开）：**481/481** 通过；这不代表 HAP 真机构建。
- `android/gradlew.bat :app:testDebugUnitTest`：`BUILD SUCCESSFUL`，本次该测试任务为 `UP-TO-DATE`；现存 4 份测试 XML 共 **16/16**、零失败/错误/跳过，并非本轮强制重跑。Gradle 报告 Kotlin 插件未来兼容性与 Gradle 10 弃用警告，未阻断本轮。
- 同一锁定依赖与 `config/dev.json.example` 分别运行 `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --dart-define-from-file=config/dev.json.example` 和相同参数的显式内部 QA Release（`SAIDIAN_ALLOW_QA_RELEASE=true`、`--release`）：均成功。Debug APK **186,204,756** 字节，SHA-256 `F1C4C476498A37663D5F28B702160FE814AAE170E50917157671E60C79A901A2`；QA Release APK **69,076,064** 字节，SHA-256 `167849B2A6EAC164B2392E2054DCE0937683EC8BCCA565E4516D64E895ACFE54`，与改版前记录的 QA Release 哈希一致。两包均为 `cn.saydian.ring`、`0.1.21 (1004)`、minSdk 26、ARMv7/ARM64，证书 SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`；QA Release 仍是调试证书，不能上架。
- 已连接的华为 Android 上执行 `adb install -r --no-streaming build/app/outputs/flutter-apk/app-debug.apk` 返回 `Success`；手机 `cn.saydian.ring` 的 base.apk SHA-256 与本次 Debug APK 完全相同。`dumpsys package` 为 `0.1.21 (1004)`；`am force-stop` 后重新 `am start`，`pidof` 非空且前台焦点为 Say Ring 主 Activity。未卸载、清数据或修改 LuckRing。
- 本机实际使用 `build-tools/36.0.0` 的 `aapt`/`apksigner` 核对包名、版本、ABI 与签名；两包 `apksigner verify --verbose` 均返回 `Verifies` 且 v2 签名为 `true`。`git diff 7b950148 -- lib test` 为 0 行，`git diff --check` 通过（仅有 CRLF 转换警告）。
- 首次补暂存文档时把已由 Git 反向补丁暂存删除的 `lib/ui/ring_shell.dart` 再当作存在文件传给 `git add`，得到 `pathspec` 不存在；没有丢失文件或改动，改为只显式暂存三份文档并复核总暂存区。

## 尚未验收

- 真机仅证明安装包一致、进程可启动；未逐页点击或验证登录后数据、微信原生授权、首次绑定手机号、真实短信、HR01 戒指和 H5↔App 健康双向同步。这些能力不因页面回退而自动完成。
- Windows 无法执行 iOS 构建和 iPhone 真机验收；生产签名/发布不在本轮范围。
