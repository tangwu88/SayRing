# 2026-09-04 服务端在线更新接口接入记录

## 修改前基线

- 分支：`main`。
- Git 基线：`0a6e4d6318703b486053a016907565a49d5af111`。
- 修改前已执行远端刷新，本地与 `origin/main` 均为该提交。
- 既有未跟踪目录 `docs/legal/`、`output/` 保留未动。

## 服务端契约

- 接口：`GET https://app.saidian.cc/api/v1/site/version`。
- 请求参数：`v` 为 App 当前构建号，`platform` 为 `android` 或 `ios`。
- `code=200,data=null` 表示无可用新版本。
- 新版本字段：`title`、`version`、`version_code`、`description`、
  `android_type`、`android`、`ios`、`force`、`lowwer`、`status`、
  `created_at`、`updated_at`。
- Android `android_type=0` 使用外部平台跳转，`android_type=1` 使用 App 内 APK 下载。

## 客户端调整

- 默认版本来源改为 `SAYDIAN_API_BASE_URL + /api/v1/site/version`，不再依赖旧的
  `SAYDIAN_UPDATE_MANIFEST_URL`。
- 检查前读取真实包版本，并自动提交当前构建号与平台。
- 支持服务端业务错误、禁用版本、无更新、新版本、最低兼容版本和强制更新。
- 服务端 HTML 更新说明转换为纯文本；更新弹窗优先展示服务端标题。
- 服务端未提供 SHA-256 时，内部 APK 仍可通过同源 HTTPS 下载；若后端后续返回
  `sha256` 或 `android_sha256`，客户端会继续执行完整摘要校验。
- 原有正式清单解析暂时保留，仅用于旧 QA/发布产物兼容；生产默认路径为服务端接口。

## 验证结果

- 在线接口现场验证：`v=23&platform=android` 返回版本对象；
  `v=1002&platform=android` 返回 `data=null`，符合版本筛选规则。
- `dart analyze lib/app.dart lib/services/app_update_service.dart test/app_update_service_test.dart`：
  无问题。
- `flutter test test/app_update_service_test.dart`：27/27 通过。
- `flutter test test/app_update_gate_test.dart test/prototype_coverage_test.dart`：22/22 通过。
- `flutter test`：380/380 通过。
- Debug APK：通过纯英文临时路径完成编译，输出
  `build/app/outputs/flutter-apk/app-debug.apk`。项目中文目录会触发 `jni` 插件路径兼容问题，
  该问题与本次 Dart 修改无关。

## 服务端待处理

- 2026-09-04 现场返回的 Android 地址为 `测试.apk`，解析后的
  `https://app.saidian.cc/测试.apk` 当前 HTTP 状态为 404。
- 后端发布正式版本前必须改为真实可下载的 HTTPS APK/应用市场地址；否则客户端能发现
  更新，但用户无法完成下载或跳转。
