# App 在线更新配置

> 2026-09-04 起，App 运行时统一以服务端
> `GET /api/v1/site/version?v={当前构建号}&platform={android|ios}` 为版本来源。
> `SAYDIAN_UPDATE_MANIFEST_URL` 不再决定客户端检查地址。本文后半部分的
> `app-update.json` 内容仅保留为现有发布流水线资料，不是 App 的运行时接口。

## 接入方式

App 启动、回到前台以及“关于我们 → 检查更新”都会通过
`SAYDIAN_API_BASE_URL`（默认 `https://app.saidian.cc`）请求版本接口。
客户端会自动传入当前 `versionCode/buildNumber` 和当前平台。

服务端返回 `data=null` 表示当前已是最新版本；返回版本对象时，客户端使用：

- `version`：最新构建号。
- `version_code`：展示版本号。
- `title`、`description`：更新标题和说明，说明中的 HTML 会转为纯文本。
- `force`、`lowwer`：强制更新开关和最低兼容构建号。
- `android_type`：`0` 为外部平台跳转，`1` 为 App 内下载 APK。
- `android`、`ios`：对应平台的 HTTPS 下载或商店地址。

如需覆盖默认接口地址，可在构建时设置
`SAYDIAN_UPDATE_API_URL=https://正式域名/api/v1/site/version`。

## 旧发布清单说明

本地验证清单解析时，只能显式生成不可发布的 QA Release：

```bash
SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release \
  --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://downloads.example.invalid/app-update.json \
  --dart-define=SAYDIAN_UPDATE_ALLOWED_HOSTS=downloads.example.invalid
```

上述域名只是文档占位，不能原样发布。QA Release 使用测试签名和禁用推送配置，
只验证构建与页面行为，不能用于线上分发。

所有普通 Release 默认失败。正式包必须由受保护工作流设置
`SAIDIAN_PRODUCTION_RELEASE=true`、`SAIDIAN_ALLOW_QA_RELEASE=false`，并同时注入
正式签名、JPush、API、清单地址和允许主机；两个模式不可同时开启。

未配置时，页面会明确显示“在线更新服务暂未配置”，不会回退到私有 GitHub Release 或伪造检查成功。

## 正式清单格式

```json
{
  "schema_version": 1,
  "channel": "production",
  "releases": [
    {
      "schema_version": 1,
      "platform": "android",
      "channel": "production",
      "latest_version": "1.0.0",
      "latest_build": 100,
      "minimum_supported_build": 99,
      "release_notes": "经审核的用户可见发布说明",
      "published_at": "2026-01-01T00:00:00Z",
      "destination": {
        "type": "android_apk",
        "url": "https://downloads.example.invalid/android/Saydian-1.0.0+100-release.apk"
      },
      "sha256": "64 位小写十六进制 APK SHA-256"
    },
    {
      "schema_version": 1,
      "platform": "ios",
      "channel": "production",
      "latest_version": "1.0.0",
      "latest_build": 100,
      "minimum_supported_build": 99,
      "release_notes": "经审核的用户可见发布说明",
      "published_at": "2026-01-01T00:00:00Z",
      "destination": {
        "type": "app_store",
        "url": "https://apps.apple.com/app/id0000000000"
      }
    }
  ]
}
```

`latest_version`、`latest_build`、`minimum_supported_build`、`release_notes`、`published_at` 和 `destination` 必填。

Android APK 目标还必须提供与公网文件完全一致的 SHA-256。清单和下载地址必须使用 HTTPS，且主机必须出现在 `SAYDIAN_UPDATE_ALLOWED_HOSTS` 中。

## 发布约束

禁止手工先替换清单、再上传 APK。这会使用户看到不存在或不完整的安装包。

Android 正式发布必须使用 `.github/workflows/android-release.yml`。工作流会先上传并公网校验 APK，最后原子替换清单；清单公网验证失败时恢复上一版。

直接执行 `flutter build apk --release` 或 `flutter build appbundle --release` 会被门禁拒绝。
本地编译验证必须显式使用 QA 开关；正式工作流必须显式使用 Production 开关并关闭 QA。

完整配置见：

- [Android 正式发布门禁](release/ANDROID-PRODUCTION-RELEASE.md)
- [正式发布阻断清单](release/PRODUCTION-RELEASE-BLOCKERS.md)
- [清单示例](templates/app-update.production.example.json)

## iOS 说明

iOS 正式版不能在 App 内下载并自行安装新版。

`ios.destination` 必须为 `app_store`，且 URL 必须是实际 `apps.apple.com` 产品页。在 App Store ID 尚未取得时，不得把文档中的占位 ID 发布到正式清单。

iOS 无签名 Release 编译验证使用
`SAIDIAN_ALLOW_QA_RELEASE=true flutter build ios --release --no-codesign`。
签名 Ad Hoc/生产配置构建必须使用 Production 模式，不能借 QA 开关绕过签名和线上配置门禁。
