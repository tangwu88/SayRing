# Android 正式发布门禁

## 1. 发布结构

Android 正式包只由 `.github/workflows/android-release.yml` 发布。

工作流顺序固定为：

1. 校验标签、版本递增、发布说明和最低支持版本。
2. 校验正式签名证书指纹，拒绝 Android Debug 证书。
3. 在一次性 CI 工作区写入 JPush 及已明确启用的厂商通道配置。
4. 运行 Flutter 静态分析、全量测试和 Release APK 构建。
5. 验证包名、签名指纹、APK v2 签名、JPush 占位符、禁止权限和双 ARM `.so` 对称性；`libjutils.so` 例外必须匹配锁定的 JPush/JCore 组合。
6. 生成 SHA-256 和候选更新清单。
7. 先上传不可变的 APK，再从公网下载并核对 SHA-256。
8. APK 验证成功后，在同一服务器文件系统中使用 `mv` 原子替换 `app-update.json`。
9. 从公网重新读取清单并语义校验；失败时恢复上一份清单。
10. 公网发布通过后，才在私有 GitHub 仓库创建内部归档 Release。

GitHub Release 只是内部归档。当前仓库为私有仓库，其资产 URL 不是 App 可无鉴权访问的公网 APK URL。

## 2. GitHub 生产环境

创建名为 `production` 的 GitHub Environment，建议开启指定审核人和防止管理员绕过。

下列变量必须配置在该环境中：

| Variable | 要求 |
| --- | --- |
| `SAYDIAN_API_BASE_URL` | 正式 API HTTPS 根地址 |
| `SAYDIAN_UPDATE_MANIFEST_URL` | 公网 HTTPS 地址，必须以 `/app-update.json` 结尾 |
| `SAYDIAN_ANDROID_APK_BASE_URL` | 公网 APK 目录，工作流会追加版本化文件名 |
| `SAYDIAN_UPDATE_ALLOWED_HOSTS` | 逗号分隔，必须包含清单和 APK 主机名 |
| `SAYDIAN_ANDROID_MINIMUM_SUPPORTED_BUILD` | 自动标签发布时的最低可用 build，不得大于新 build |
| `SAYDIAN_MANIFEST_BOOTSTRAP_ALLOWED` | 必须显式填 `true` 或 `false`；首次建立清单才使用 `true` |
| `SAYDIAN_RELEASE_SSH_HOST` | 发布服务器主机名 |
| `SAYDIAN_RELEASE_SSH_USER` | 仅有发布目录写权限的 SSH 用户 |
| `SAYDIAN_RELEASE_SSH_PORT` | SSH 端口 |
| `SAYDIAN_RELEASE_REMOTE_ROOT` | 明确的绝对目录，不可为 `/` 或包含 `..` |
| `JPUSH_CHANNEL` | 正式发布固定为 `production` |
| `JPUSH_VENDOR_CHANNELS` | 显式填 `none` 或 `huawei,xiaomi,meizu,vivo,oppo,honor` 的子集 |

下列 Secrets 始终必填：

| Secret | 用途 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 正式 keystore 的 Base64 |
| `ANDROID_KEY_ALIAS` | 正式 key alias |
| `ANDROID_KEY_PASSWORD` | key 密码 |
| `ANDROID_STORE_PASSWORD` | keystore 密码 |
| `ANDROID_SIGNING_CERT_SHA256` | 预先独立确认的正式证书 SHA-256 |
| `JPUSH_APP_KEY` | 包名 `cc.saidian.app` 对应的 JPush AppKey |
| `SAYDIAN_RELEASE_SSH_PRIVATE_KEY` | 只能写发布目录的 SSH 私钥 |
| `SAYDIAN_RELEASE_SSH_KNOWN_HOSTS` | 经运维独立核对指纹的 known_hosts 内容 |

## 3. 厂商推送凭据

`JPUSH_VENDOR_CHANNELS` 决定哪些通道进入正式包。未列出的通道不会被默认开启。

| 通道 | 条件 Secrets |
| --- | --- |
| Huawei | `HUAWEI_AGCONNECT_SERVICES_JSON_BASE64` |
| Xiaomi | `JPUSH_XIAOMI_APP_KEY`, `JPUSH_XIAOMI_APP_ID` |
| Meizu | `JPUSH_MEIZU_APP_KEY`, `JPUSH_MEIZU_APP_ID` |
| Vivo | `JPUSH_VIVO_APP_KEY`, `JPUSH_VIVO_APP_ID` |
| Oppo | `JPUSH_OPPO_APP_KEY`, `JPUSH_OPPO_APP_ID`, `JPUSH_OPPO_APP_SECRET` |
| Honor | `JPUSH_HONOR_APP_ID` |

启用 Huawei 时，工作流会解码 JSON，并检查其包名包含 `cc.saidian.app`。

所有配置只写入 Actions 的一次性 checkout。工作流结束时会删除 keystore、SSH 私钥、Huawei JSON 并还原 `pubspec.yaml`。

## 4. 公网服务器约定

`SAYDIAN_RELEASE_REMOTE_ROOT` 需要映射为公网下载目录：

```text
<remote-root>/
├── app-update.json
├── android/
│   └── Saydian-X.Y.Z+BUILD-release.apk
├── checksums/
│   └── SHA256SUMS-X.Y.Z+BUILD.txt
└── .staging/
```

服务器必须满足：

- APK 和清单均可无 Cookie、无 Token 公网 HTTPS 访问。
- APK 和清单允许同源路径重定向；最终有效 URL 若改变 HTTPS 主机或端口，发布立即失败。
- APK 文件名版本化且不可覆盖；重试只允许复用 SHA-256 完全一致的旧文件。
- `.staging` 与 `app-update.json` 必须位于同一文件系统，确保 `mv` 原子替换。
- `app-update.json` 建议设置 `Cache-Control: no-cache, max-age=60`。
- 发布 SSH 账号不应拥有其他站点、数据库或系统管理权限。
- 发布锁使用两小时租约；接管过期锁时再次原子创建并核对所有权，竞争失败者不得写入新锁。

## 5. 版本和触发

`pubspec.yaml` 中的 versionName 和 build 都必须比历史 `android-v*` 正式标签大。

自动发布使用带说明的 annotated tag：

```bash
git tag -a 'android-vX.Y.Z+BUILD' -m '本次用户可见的发布说明'
git push origin 'android-vX.Y.Z+BUILD'
```

也可在 Actions 手动选择已存在的 annotated tag，并输入发布说明和最低支持 build。

任何密钥、签名、公网 URL、厂商凭据、版本或清单检查不通过时，工作流在更新公网清单前停止。
