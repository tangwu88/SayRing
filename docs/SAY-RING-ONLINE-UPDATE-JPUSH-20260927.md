# 2026-09-27 Say Ring 在线更新与极光推送

## 原因与范围

- Say Ring 需要使用独立于旧 App 的在线更新清单和极光推送应用。
- 在线更新继续使用现有的同源 HTTPS、包名、SHA-256 和系统安装器校验；不降低重定向或安装安全边界。
- 推送设备登记新增固定产品标识 `say-ring`，由服务端路由到独立极光配置，避免与其他 App 的包名、Registration ID 和凭据混用。
- 不在源码、示例配置、日志或构建产物中保存真实 AppKey、Master Secret、厂商通道密钥或正式签名材料。

## 修改文件

- `lib/services/global_api_client.dart`：Say Ring 推送设备登记附带固定产品标识。
- `config/dev.json.example`：增加空的 `JPUSH_APP_KEY` 示例项，真实值只由受保护构建环境提供。
- `test/global_push_registration_test.dart`：覆盖产品标识、认证头和设备登记契约。
- 服务端与管理后台的独立更新、推送配置见服务端同日实施记录。

## 验证记录

- `dart format`：修改过的 Dart 文件格式化完成。
- `flutter analyze --no-pub`：通过，无问题。
- Flutter 全量测试：UTC 与 `Asia/Shanghai` 各 879 项通过。
- Android 原生 `:app:testDebugUnitTest :app:compileDebugJavaWithJavac --offline`：构建通过；测试任务命中缓存，现有 5 份 XML 共 23 项，失败、错误、跳过均为 0。
- Android Debug 双 ARM APK：构建通过，`cn.saydian.ring`、`0.1.21+1004`，186,153,580 字节，SHA-256 `B9B198117C2AF5C854F4F1ED532DCF20895B4FC5690965306AE15D2CEA3C73AB`。
- Android 内部 QA Release 双 ARM APK：构建通过，69,365,140 字节，SHA-256 `4C1BF851E225AECEBF5F9075C32C568A914B77498185B343563C561A2E704395`。
- 两个 APK 均通过 `apksigner` 验签，证书 SHA-256 均为 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`；这是 QA/debug 证书，不是正式发布证书。
- 服务端全量测试、类型检查、构建、接口文档和部署结构检查见服务端同日实施记录。

## 尚未验收

- 极光 AppKey、Master Secret 尚未由用户在管理后台填写，真实 Registration ID 和通知送达未验收。
- 极光 AppKey 还必须在受保护的正式 App 构建环境中注入；只在管理后台填写 Master Secret/AppKey 不能改变已经安装的 APK。
- 当前手机安装包使用 QA/debug 签名；正式在线更新仍需稳定正式签名、同签名升级包和公开 APK 文件。
- iOS APNs、App Store/TestFlight 目的地及真机推送尚未配置或验收。
