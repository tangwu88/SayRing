# Android 微信授权登录 code 契约回归

## 结论

- Android 微信开放 SDK 已成功拉起微信并返回一次性 `code`。
- Flutter 与 Android 原生桥接已移除对 SDK 回调 `openId` 的错误依赖。
- App 现在只向 `POST /api/v1/site/app-wechat-login` 提交 `code`，不提交
  `openid`、`unionid`、昵称、头像、`state`、平台或任何密钥。
- 无效测试 `code` 返回业务码 422 和 `invalid code`，证明服务端已进入微信兑换流程。
- 真机有效 `code` 已到达服务端，但服务端随后返回业务码 500；阻断点为
  `SiteController.php:100` 使用了未定义的类常量 `CLIENT_WECHAT_APP`。

## 前端修改

- `lib/services/api_client.dart`：微信登录请求体只保留 `code`。
- `lib/services/wechat_auth_bridge.dart`：只校验 SDK 返回的 `code` 和本地 `state`。
- `lib/services/app_controller.dart`：只把授权 `code` 交给接口层。
- Android 微信回调：成功条件改为有效 `state + code`，不再要求 `openId`。
- 对应单元测试已改为断言请求中只有 `code`。

## 验证结果

- 微信登录相关 Flutter 回归测试：72 项通过。
- `flutter analyze`：通过，0 问题。
- Android Debug APK：编译、覆盖安装成功。
- 真机：HUAWEI JAD-AL00，微信回调 `errorCode=0` 且 `hasCode=true`。
- AppSecret、微信授权码和用户身份值均未写入源码、测试记录或正式日志。

## 服务端待处理

请检查 `/api/v1/site/app-wechat-login` 的 `SiteController.php` 第 100 行：

1. 改用项目中已定义的登录客户端类型常量，或补充合法的 APP 微信客户端类型；
2. 不要引用不存在的 `CLIENT_WECHAT_APP`；
3. 修复后，有效 `code` 应返回 App 的 `access_token`、`refresh_token` 和 `member`；
4. 生产响应不得返回 PHP 文件路径和异常堆栈。
