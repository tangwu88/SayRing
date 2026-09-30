# 2026-09-30 Say Ring 新图标与 Android 覆盖安装

## 修改前检查

- 用户提供 1254×1254、白色不透明背景的黑色戒指与 `Saydian` 字标 PNG，并要求替换 App 图标、打包最新版安装到手机。
- 新建独立工作树 `E:\SayRing-icon-install-20260930`；执行 `git fetch origin --prune` 后以 `origin/main=8f705d3db7da9c0aeaa36502d0b0421a6a3f1665` 创建 `codex/app-icon-install-20260930`，没有覆盖其他工作树。
- 已阅读 `AGENTS.md`、国际交接、最近实施记录、跨端复盘和回归清单。手机为已连接的华为 JAD-AL00 / Android 12，现装 `cn.saydian.ring` 版本 `0.1.21+1006`，本轮使用同包名覆盖安装并保留数据。

## 原因、范围与预期

- 原因：三端 Launcher 仍使用旧版红色人物图标，与用户确认的新黑白戒指图不一致。
- 范围：只更新图标母版、Android/iOS/鸿蒙派生资源、跨平台机械生成脚本和图标契约；不修改登录、会员、健康、设备、运动、推送或接口逻辑。
- 预期：Android 桌面普通、圆形、Adaptive 与 themed icon 使用同一新图；iOS 全套 AppIcon 和鸿蒙桌面图标同步；Android 最新测试包可同签名覆盖安装。

## 实施与验证记录

### 18:40 修改前现场

- 原图 SHA-256：`2db9100a4cc9544d057ce555e54dd87456119f991f9e2b356afd9c9296b56238`。
- ADB：`L2E0222510006851` 在线，型号 JAD-AL00，Android 12；现装 App 正在前台。
- 结果：通过。未卸载 App、未清数据、未操作戒指或健康记录。

### 图标生成与检查

- 以用户提供的原始 PNG 为唯一母版，生成 Android 普通/圆形/Adaptive/单色图标、iOS 全套 AppIcon 与鸿蒙桌面图标，共 39 个派生资源。
- `java scripts/GenerateLauncherIcons.java --check`：通过；母版 SHA-256 为 `136fab869f84fc132ab1d2a04c240c5a8e1fa2fb242800add8d448ce86875f16`。
- Android Adaptive 前景保留安全边距，背景沿用白色；iOS 1024 图与各尺寸均为不透明 RGB PNG。
- 人工查看母版、圆角版和 Adaptive 前景：通过，黑色戒指与 `Saydian` 字标保持完整。

### 自动检查

- `flutter analyze --no-pub`：通过，无问题。
- Flutter 全量测试：UTC 939/939、中国时区 939/939 通过。
- 鸿蒙 Node 契约：UTC 501/501、中国时区 501/501 通过，其中包含新图标源文件与母版哈希契约。
- `git diff --check`：通过，仅有 Windows 行尾提示。
- 首次 Flutter 测试因 GitHub 下载超时、Windows 临时目录文件被清理而中断；配置代理并把 `TEMP/TMP` 固定到工具链目录后重跑通过，未把中断记录为成功。

### Android 构建记录

- 首次 QA Release 构建在 `mergeReleaseNativeLibs` 被损坏的 QRing SDK Gradle transform 缓存阻断；将报错缓存目录移动到工具链隔离目录后重新生成。
- 第二次构建期间 Kotlin daemon 重启，Gradle 自动回退编译并最终成功：`build/app/outputs/flutter-apk/app-release.apk`，约 65.9 MB。
- 用户随后明确要求本轮只同步最新图标到 Git，因此停止 APK 验签、手机覆盖安装、冷启动和桌面图标真机检查，也不再补跑 Android 原生测试或 Debug 构建。

## 未验收事项

- Windows 未执行 iOS Xcode 构建，也未编译或安装鸿蒙 HAP；本轮仅验证两端图标资源及契约。
- APK 未按用户最新指令安装到手机；手机仍保留原安装版本与原数据。
