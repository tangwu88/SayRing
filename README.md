# Saydian 赛电 App

赛电健康管理 App 的 Flutter 双端工程。Android 通过 Kotlin、iOS 通过
Swift/Objective-C 适配 Veepoo SDK；Flutter 层共享页面、状态机、健康数据模型、
加密本地存储、离线同步和现有赛电后台 API 适配。

## 当前可用范围

- 账号登录、注册和安全会话存储
- 首页、健康、AI、设备、我的五栏导航及原型/小程序对应页面
- 健康页跑步、步行、骑行、徒步和运动记录，Android 直连 Veepoo 运动模式
- AI 健康/运动管家、健康百科、订单、目标、个人资料、地址和权限管理接口
- 设备扫描、连接、能力读取、同步和测量的统一 MethodChannel 契约
- SQLCipher 本地健康数据库与 200 条/批的幂等补传队列
- 远程关爱隐私默认模型：未接受、未逐项授权时不共享
- Android 8+ 与 Android 12+ 蓝牙权限配置
- iOS 13+ 蓝牙用途说明和 `bluetooth-central` 后台模式
- 单元测试、Widget 测试、Android/iOS CI

Veepoo 合作客户授权已确认，小程序源码和官方 Android/iOS SDK 已锁定到工程。
双端原生桥已实现扫描、连接、密码校验、个人信息同步、能力识别、历史健康数据同步及
心率、血氧、血压、体温手动测量，并支持运动记录与自动检测开关；指标按设备实际能力
动态开放。具体版本及调用顺序见接入说明。

关爱模块已支持现有 `GET /api/v1/member/care` 和
`POST /api/v1/member/care`（Bearer + multipart `mobile`）。审核、逐指标授权、
撤销和审计仍以服务端后续契约为准。

## 本地开发

```powershell
$flutter = 'F:\Codex\home\tools\flutter\bin\flutter.bat'
& $flutter pub get
& $flutter test
& $flutter run --dart-define-from-file=config/dev.json
```

首次使用时复制 `config/dev.json.example` 为 `config/dev.json`。配置文件、签名材料、
Token 和密码不得提交到代码库；合作方 SDK 二进制仅随本私有 App 仓库锁定。

每次修改前必须先同步远端、检查是否存在并发 Xcode/Flutter 构建，并按
[修改与回归检查清单](docs/REGRESSION-CHECKLIST.md) 完成影响面、全量测试和真机门禁。
本轮跨端问题的共同根因与防复发约束见
[2026-08-29 跨端问题修复复盘](docs/BUG-RETROSPECTIVE-20260829.md)。

## 构建

```powershell
& $flutter build apk --debug '--target-platform=android-arm,android-arm64'
& $flutter build apk --release '--target-platform=android-arm,android-arm64'
& $flutter build appbundle --release '--target-platform=android-arm,android-arm64'
```

手表 SDK 同时包含 32/64 位 ARM 库，所以交付包必须显式构建
`android-arm,android-arm64`。设备定向调试留下的 Gradle/Flutter 缓存可能使默认
构建只保留当前设备架构；发包前应确认 APK 同时存在
`lib/armeabi-v7a/libflutter.so` 和 `lib/arm64-v8a/libflutter.so`。

iOS 必须在 macOS/Xcode 环境执行：

```bash
cd ios && pod install && cd ..
flutter build ios --release --no-codesign
```

`flutter run --debug` 安装的 iOS Debug 包只能在 Flutter 工具或 Xcode 保持连接时运行；
断开调试后从手机桌面启动，系统会因无法创建 Debug FlutterEngine 而终止进程。需要交给测试人员
从桌面独立启动时，请安装已签名的 Profile、Ad Hoc 或 Release 包，例如：

```bash
flutter run --profile -d <iPhone-UDID> --no-pub --no-resident
```

### Android 在线更新

App 默认从 GitHub Releases 的最新版本检查 Android APK。发布新版本时先更新
`pubspec.yaml` 中的版本号，再创建形如 `android-v0.1.18+22` 的 Git 标签。
`.github/workflows/android-release.yml` 会运行分析和测试、使用正式签名构建 APK，
并发布到 GitHub Release。仓库需要配置以下 Actions Secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

可用仓库变量 `SAYDIAN_API_BASE_URL` 覆盖生产 API 地址。正式签名必须长期保持一致，
否则手机无法在已安装版本上直接升级。

Windows 开发机可通过 GitHub Actions 生成已签名的 Ad Hoc IPA，证书、描述文件、
触发方式及安装步骤见 [Windows 与 GitHub Actions iOS 打包说明](docs/github-actions-ios.md)。

正式签名、TestFlight 和商店提交需要另行配置 Apple Developer、Android 商店签名、
隐私政策、用户协议和推送/支付材料。

## 接入闸门

- [最新开发交接说明（2026-08-12）](docs/HANDOFF-20260812.md)
- [上一版开发交接说明（2026-08-11）](docs/HANDOFF-20260811.md)
- [历史开发交接说明（2026-08-05）](docs/HANDOFF.md)
- [Veepoo 原生 SDK 接入说明](docs/veepoo-integration.md)
- [现有后台 API 缺口](docs/api-gap.md)
- 小程序源码已提供；目标手表型号/固件和双端量产样机实测仍待完成
- 正式内测前必须替换线上空白隐私政策和占位用户协议

所有健康结果仅供健康管理参考，不用于诊断或治疗。
