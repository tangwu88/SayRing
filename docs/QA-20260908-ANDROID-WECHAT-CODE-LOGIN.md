# Android 微信授权登录 code 契约回归

## 结论

- Android 微信开放 SDK 已成功拉起微信并返回一次性 `code`。
- Flutter 与 Android 原生桥接已移除对 SDK 回调 `openId` 的错误依赖。
- App 现在只向 `POST /api/v1/site/app-wechat-login` 提交 `code`，不提交
  `openid`、`unionid`、昵称、头像、`state`、平台或任何密钥。
- 无效测试 `code` 返回业务码 422 和 `invalid code`，证明服务端已进入微信兑换流程。
- 服务端已修复 `CLIENT_WECHAT_APP` 未定义异常。真机有效 `code` 登录成功，
  App 可进入首页并读取会员资料，强制结束进程后登录状态仍然保留。
- 微信新用户可能返回 `gender=0`（未设置）。个人资料页现已兼容该状态，
  不再触发 `DropdownButton` 断言红屏；用户选择性别并补全资料后可正常保存。

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
- 真机个人资料回归：进入页面、选择性别、填写生日/身高/体重、保存和重新读取均成功。
- 微信未设置性别组件回归测试：通过；`flutter analyze`：0 问题。
- AppSecret、微信授权码和用户身份值均未写入源码、测试记录或正式日志。

## 已关闭的服务端阻断

此前 `/api/v1/site/app-wechat-login` 的 `SiteController.php` 第 100 行引用未定义的
`CLIENT_WECHAT_APP`，导致有效授权码返回业务码 500。2026-09-08 真机复测已确认该问题关闭。

服务端仍应确保生产响应不返回 PHP 文件路径和异常堆栈。
