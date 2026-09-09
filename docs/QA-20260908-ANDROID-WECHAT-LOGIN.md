# Android 微信授权登录真机联调记录（2026-09-08）

> 后续状态已更新：服务端已改为只接收一次性 `code`，前端同步完成契约调整。
> 最新真机结论和服务端阻断点请以
> [`QA-20260908-ANDROID-WECHAT-CODE-LOGIN.md`](QA-20260908-ANDROID-WECHAT-CODE-LOGIN.md)
> 为准；本文保留作为首次联调历史。

## 修改前基线

- 仓库：`E:\saydian\harmony_latest`
- 分支：`codex/harmony-nova14-qa-20260907`
- 跟踪远端：`origin/codex/harmony-native-login-home`
- 修改前提交：`33ee50ac16bf0f76377aa7a7a20cad4c011105b9`
- 修改前工作树：干净；执行 `git fetch --prune` 和 `git pull --ff-only` 后为远端最新。

## 修改原因、文件与影响范围

### 原因

Android 登录页原先不显示微信登录入口，也没有微信 SDK 的 Flutter/Android 通道和回调 Activity；Flutter 端仍调用旧的微信登录地址并错误标记为 iOS。需要按在线接口文档补齐 Android 授权链路，并以真机回调确认服务端契约是否可用。

### 主要文件

- `lib/ui/pages.dart`：Android 显示微信登录入口。
- `lib/services/wechat_auth_bridge.dart`：封装原生授权结果及校验。
- `lib/services/app_controller.dart`：登录状态处理和用户提示。
- `lib/services/api_client.dart`：改用 `/api/v1/site/app-wechat-login` 契约。
- `android/app/build.gradle.kts`：注入公开的微信 App ID。
- `android/app/src/main/AndroidManifest.xml`：注册微信回调 Activity。
- `android/app/src/main/kotlin/cc/saidian/saydian_app/MainActivity.kt`：实现 Flutter MethodChannel、微信授权发起和回调交付。
- `android/app/src/main/kotlin/cc/saidian/app/wxapi/WXEntryActivity.kt`：接收微信 SDK 回调。
- `android/app/src/main/kotlin/cc/saidian/saydian_app/AppWechatAuthStore.kt`：短暂保存并一次性消费回调，避免进程/Activity 切换丢失。
- `test/wechat_auth_bridge_test.dart`、`test/api_client_test.dart`、`test/login_page_test.dart`：补授权、接口和 Android 入口测试。

### 影响范围

仅影响 Android 微信授权登录和共享的 App 微信登录请求封装；手机号登录、注册及其他平台原生入口未改业务协议。

## 在线接口契约核对

接口文档当前定义：

- `POST https://app.saidian.cc/api/v1/site/app-wechat-login`
- `multipart/form-data` 必填字段：`unionid`、`openid`、`sex`、`nickname`、`headimgurl`
- 成功响应包含 `access_token`、`refresh_token`、`expiration_time` 和会员信息。

Android 微信开放 SDK 的授权成功回调实际提供一次性授权 `code`，并不保证直接返回 `openid`、`unionid`、昵称或头像。这些身份信息应由服务端使用自身保存的 AppSecret 交换取得，不应把 AppSecret 放进 APK，也不能由客户端伪造或长期信任客户端提交的 OpenID。

## 真机环境与操作结果

- 设备：华为 JAD-AL00，Android 12，序列号 `L2E0222510006851`。
- 测试包：`cc.saidian.app` `0.1.19+24` Debug 构建；为避免签名冲突，已在用户允许后卸载旧正式包再安装，最终包于 2026-09-08 10:46 覆盖安装成功。
- 微信状态：系统存在微信及微信分身。

验证步骤及结果：

1. 启动 App，Android 登录页已显示“微信登录”按钮。
2. 同意协议后点击按钮，能正常调起微信/微信分身选择器。
3. 选择微信分身，出现“Saydian赛电 申请使用你的昵称、头像”授权页。
4. 点击允许，App 收到成功回调；安全日志为 `errorCode=0`、`hasCode=true`、`hasOpenId=false`，未打印授权码或用户身份值。
5. 因缺少服务端可交换的 `code` 契约，客户端拒绝以空或伪造 OpenID 建立登录会话；最终真机确认显示“微信授权成功，但服务端登录接口暂未适配，请使用手机号登录”。
6. 最终包再次验证取消授权：回调 `errorCode=-2`，回到登录页且无错误提示、不创建会话。取消回调可能没有 `state`，仅成功回调执行严格 `state` 校验。

## 自动检查

- `flutter test test/wechat_auth_bridge_test.dart test/api_client_test.dart test/login_page_test.dart --reporter expanded`：72/72 通过。
- `flutter test --reporter compact`：529/529 通过。
- `flutter analyze`：通过，无问题。
- `flutter build apk --debug`：通过，Android/Kotlin 原生代码编译成功。
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`：通过，真机已安装最终 Debug 包。

## 当前结论

- Android 登录入口、微信授权发起、回调 Activity、取消/拒绝/超时处理均已接通。
- 微信 App ID 与 Android 包名配置能被微信识别，真实授权页可正常展示。
- **完整微信登录暂未通过，阻断点是服务端接口契约。** 当前接口要求客户端直接提供 `openid/unionid/昵称/头像`，但 Android 授权成功回调只可靠提供一次性 `code`。

## 服务端必须配合项

建议将 App 微信登录接口调整为：

1. 客户端提交一次性 `code`，可同时提交 `state`、`platform=android` 等非敏感上下文。
2. 服务端使用后台保存的微信 App ID 与 AppSecret 调微信官方接口换取并校验 `openid/unionid`。
3. 服务端完成会员查询或创建，并返回现有 `access_token`、`refresh_token`、`expiration_time` 与会员信息。
4. 校验授权码有效期和一次性使用，拒绝重放；不要信任客户端直接声明的 OpenID。
5. AppSecret 只保存在服务端，禁止写入 Flutter、Gradle、原生源码或安装包。

服务端完成后需再次真机验证：授权成功、首次注册、已有账号登录、取消、拒绝、换号及 Token 持久化。
