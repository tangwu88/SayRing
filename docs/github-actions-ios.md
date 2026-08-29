# Windows 开发与 GitHub Actions iOS 测试包配置

## 已配置的构建方式

Windows 用于 Flutter/Dart 开发、Android 调试和提交代码；iOS 编译与签名由 GitHub Actions 的 macOS 26 构建机完成。工作流文件为 `.github/workflows/ios-test-ipa.yml`，使用 Xcode 26.5 和 Flutter 3.44.9，输出可安装到已登记 iPhone 的 Ad Hoc IPA。

工作流支持两种触发方式：

- 在 GitHub 仓库的 `Actions` 页面手动运行 `iOS Ad Hoc Test IPA`。
- 推送严格匹配 `ios-test-vX.Y.Z+BUILD` 的 annotated tag，例如 `ios-test-v0.1.0+2`。

签名任务必须绑定受保护的 `ios-adhoc` Environment。手动任务和标签指向的提交都必须已经包含在 `origin/main`，标签还必须是 annotated tag。

IPA 和 SHA-256 校验文件会保存为本次运行的 GitHub Actions Artifact，保留 14 天。P12、描述文件、临时钥匙串和解包校验目录会在上传 Artifact 前清理，并在任务结束时再次兜底清理。

## Release 构建门禁

iOS Release 默认拒绝执行，必须显式选择且只能选择一种模式：

- 本地或普通 CI 的无签名编译验证：`SAIDIAN_ALLOW_QA_RELEASE=true`。
- 已签名 Ad Hoc/生产配置构建：`SAIDIAN_PRODUCTION_RELEASE=true`，同时保持
  `SAIDIAN_ALLOW_QA_RELEASE=false`。

本工作流虽然输出 Ad Hoc 测试包，但使用真实 Distribution 签名、生产 APNs、正式 API、
JPush 和更新配置，因此按 Production 模式执行。QA 开关只用于无签名编译检查，不能用于生成可分发 IPA。

macOS 本地只验证 Release 编译时使用：

```bash
SAIDIAN_ALLOW_QA_RELEASE=true \
  flutter build ios --release --no-codesign
```

不设置模式、同时开启两个模式、拼错布尔值，或 Production 模式缺少任一签名/线上配置时，
Xcode 的 `Validate Release Configuration` 阶段会在 Flutter 编译前失败。

## 1. Windows 开发环境

安装并配置以下工具：

- Git for Windows
- Flutter 3.44.9（stable）
- Android Studio，以及项目所需 Android SDK
- Visual Studio Code 或 Android Studio 的 Flutter/Dart 插件
- 可选：GitHub CLI，用于从命令行配置 Secret 和触发工作流

在项目目录检查环境：

```powershell
flutter --version
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Windows 无法安装 Xcode，因此不能在本机生成或验证 IPA。所有 iOS 编译、CocoaPods 安装、签名和导出步骤均在 GitHub 的 macOS 构建机执行。

## 2. 准备 Apple Ad Hoc 签名材料

需要有效的 Apple Developer Program 团队，并在 Apple Developer 后台完成：

1. 注册 App ID，Bundle Identifier 必须是 `cc.saidian.app`。
2. 登记所有测试 iPhone 的 UDID。
3. 创建 `Apple Distribution` 证书。
4. 创建 `Ad Hoc` Provisioning Profile，选择上述 App ID、Distribution 证书和测试设备。
5. 下载 `.mobileprovision` 描述文件，并把带私钥的证书导出为 `.p12`。

如果只有 Windows，可以用 OpenSSL 创建私钥和 CSR：

```powershell
openssl genrsa -out ios_distribution.key 2048
openssl req -new -key ios_distribution.key -out CertificateSigningRequest.certSigningRequest
```

将 CSR 上传到 Apple Developer 后台创建 Distribution 证书，下载 `distribution.cer` 后转换并导出 P12：

```powershell
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -inkey ios_distribution.key -in distribution.pem -out ios_distribution.p12
```

妥善保管 `.key`、`.p12` 及其密码。项目已经忽略 `*.p12` 和 `*.mobileprovision`，不要把签名材料提交到 Git。

## 3. 配置受保护的 `ios-adhoc` Environment

在 PowerShell 中把二进制文件转为单行 Base64：

```powershell
$p12Base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path '.\ios_distribution.p12')))
$profileBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path '.\Saidian_AdHoc.mobileprovision')))
$p12Base64 | Set-Clipboard
```

打开 GitHub 仓库：`Settings` → `Environments`，创建 `ios-adhoc` Environment。配置指定审核人、部署分支或标签限制，并关闭管理员绕过后，再在该 Environment 内配置 Secrets 和 Variables。

不要把签名材料配置为普通 Repository Secret。Environment 未建立保护规则时，不得启用签名工作流。

Environment Secrets：

| 名称 | 内容 |
| --- | --- |
| `IOS_P12_BASE64` | P12 文件的 Base64；先用上面的 `$p12Base64 \| Set-Clipboard` 复制 |
| `IOS_P12_PASSWORD` | 导出 P12 时设置的密码 |
| `IOS_PROVISIONING_PROFILE_BASE64` | 描述文件的 Base64；用 `$profileBase64 \| Set-Clipboard` 复制 |
| `JPUSH_APP_KEY` | Bundle ID `cc.saidian.app` 对应的极光 AppKey |

Environment Variables：

| 名称 | 要求 |
| --- | --- |
| `SAYDIAN_API_BASE_URL` | 正式 HTTPS API 根地址 |
| `SAYDIAN_UPDATE_MANIFEST_URL` | 公网 HTTPS 清单，必须以 `/app-update.json` 结尾 |
| `SAYDIAN_UPDATE_ALLOWED_HOSTS` | 必须包含清单主机和 `apps.apple.com` |

工作流不再为这些正式地址提供默认值。缺失、非 HTTPS、保留测试域名或主机白名单不匹配时会直接失败。

`Build signed IPA` 步骤会显式设置 `SAIDIAN_PRODUCTION_RELEASE=true` 和
`SAIDIAN_ALLOW_QA_RELEASE=false`；不要在 Environment 中把 QA 开关设为 `true`。

截至 2026-08-29 的只读审计结果：仓库为私有仓库，GitHub 当前为 `0 Environments / 0 Variables / 0 Secrets`。因此 `ios-adhoc` 签名任务目前属于外部配置阻断，不能写成已可生成正式测试 IPA。

工作流会从 Provisioning Profile 自动读取 Team ID、Profile 名称和 UUID，并检查：

- Profile 的 Bundle ID 是否为 `cc.saidian.app`
- 是否包含测试设备
- 是否确实为 Ad Hoc 而非 Development Profile
- Profile 是否仍在有效期内
- P12 是否包含可用的 Distribution 签名身份
- Profile 是否由该 P12 中的证书创建
- 最终 IPA 的 Bundle ID、版本号、构建号和 embedded profile 是否一致
- 最终签名证书是否与 P12 一致，`aps-environment` 是否为 `production`

## 4. 生成 IPA

### GitHub 网页手动运行

1. 先将待构建提交合入并推送到 `origin/main`。
2. 打开 `Actions` → `iOS Ad Hoc Test IPA` → `Run workflow`。
3. 可填写版本号和构建号；构建号留空时使用 GitHub Run Number。
4. 构建成功后，在任务页面的 `Artifacts` 下载 `saydian-ios-adhoc-<运行号>`。

### 用 Git 标签自动运行

```powershell
git tag -a 'ios-test-v0.1.0+2' -m 'iOS Ad Hoc 0.1.0 build 2'
git push origin 'ios-test-v0.1.0+2'
```

标签中的 `X.Y.Z` 和 `BUILD` 会直接成为 App 版本号和构建号。标签必须指向已经位于 `origin/main` 的提交，否则工作流在读取签名材料前停止。

## 5. 安装到测试 iPhone

Ad Hoc IPA 只能安装到 Provisioning Profile 中已登记 UDID 的设备。

- Apple Configurator：在 macOS 上连接 iPhone，将 IPA 拖入设备。
- Xcode：打开 `Devices and Simulators`，选择设备后安装 IPA。
- 第三方企业内测分发服务：上传 IPA 并按服务指引安装；确认服务的安全与合规要求。

如果需要 TestFlight，必须改用 App Store Connect 分发证书/Profile，并把导出方法改为 App Store Connect；当前工作流专门生成 Ad Hoc 测试包，不会上传 App Store Connect。

## 6. 常见失败原因

- `Missing required GitHub Actions secret`：对应 Secret 未创建、名称拼错，或 Secret 不在当前仓库可用范围。
- `Release builds require exactly one explicit Production or QA mode`：Release 未选择模式，或 Production 与 QA 同时开启。
- `Production iOS Release requires ...`：正式模式缺少签名、JPush、API 或在线更新配置；不得改用 QA 开关绕过。
- `Signed Ad Hoc builds must use a commit already contained in origin/main`：手动选择的 ref 或标签提交尚未进入 `main`。
- `iOS test tag must be ios-test-vX.Y.Z+BUILD`：标签格式错误，或使用了旧的 `-build.N` 格式。
- Environment 等待或拒绝：检查 `ios-adhoc` 审核人和部署分支/标签保护规则。
- `Provisioning profile is for ...`：Profile 的 App ID 与 `cc.saidian.app` 不一致。
- `contains no test devices`：使用了 App Store Profile，或 Ad Hoc Profile 没有勾选设备。
- `valid Apple Distribution signing identity`：P12 不含私钥、密码错误、证书过期或类型不是 Distribution。
- 安装提示设备不受支持：测试 iPhone 的 UDID 没加入 Profile；添加后必须重新生成并替换 Secret。
- `pod install` 失败：先确认 `ios/Podfile` 与 `pubspec.lock` 已提交，再重试任务；依赖源临时故障也可能导致失败。
- Veepoo SDK 编译失败：确认 `ios/Runner/Vendor` 下七个 framework 均已提交，且工作流仍使用 macOS 26 / Xcode 26.5。
