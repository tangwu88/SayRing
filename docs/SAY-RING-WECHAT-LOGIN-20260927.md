# Say Ring 微信授权登录对接与验证（2026-09-27）

## 修改原因

后台已配置微信开放平台移动应用参数，Say Ring 需要完成真实微信 SDK 授权，并与国际 H5 的会员数据互通：首次授权绑定手机号，后续微信授权直接登录原账号。

## 修改范围

- `lib/domain/global_account.dart`
  - 增加服务端微信能力、首次绑定结果和公开 AppID 模型。
- `lib/services/wechat_auth_bridge.dart`
  - 发起授权时接收服务端公开 AppID；不保存或发送 AppSecret。
- `android/app/src/main/kotlin/cc/saidian/saydian_app/MainActivity.kt`
  - Android 在调用微信 SDK 前使用服务端公开 AppID 注册；保留构建配置作为兼容回退。
- `ios/Runner/AppDelegate.swift`
  - 校验服务端 AppID 必须与 iOS 构建期 URL Scheme 配置一致，避免错误应用接收回调。
- `lib/services/global_api_client.dart`
  - 接入 `wechat-login`、`wechat-phone-code`、`wechat-bind-phone`；首次绑定完成前不提前保存登录会话。
- `lib/services/app_controller.dart`
  - 管理微信授权、首次绑定状态、验证码发送、绑定成功登录和失败恢复。
- `lib/ui/global_code_login_page.dart`
  - 服务端能力允许时展示微信登录按钮；首次授权进入手机号绑定页，支持国家区号、验证码和协议确认。
- `test/*wechat*`、登录和接口测试
  - 覆盖入口门禁、原生授权参数、首次绑定、会话保存时点和错误路径。

## 安全与数据边界

- App 只持有微信公开 AppID；AppSecret 始终留在后台。
- App 只向赛电国际接口提交微信 SDK 返回的一次性 `code/state/platform`，不自行伪造 `openid/unionid`。
- 首次授权未绑定手机号时不创建本地已登录状态；绑定成功后才保存服务端签发的会话。
- 手机号、微信身份和 H5 会员的合并判断由服务端完成；发生身份冲突时停止并提示，不覆盖已有账号。

## 验证记录

### Flutter

- 静态分析：通过，无问题。
- 全量测试（UTC）：878 项通过。
- 全量测试（Asia/Shanghai）：878 项通过。
- Android 原生单测：通过，300 个任务中 3 个执行、297 个缓存命中。

### Android 构建与包检查

- Debug APK：构建通过，包名 `cn.saydian.ring`，版本 `0.1.21+1004`，包含 `armeabi-v7a`、`arm64-v8a`。
- QA Release APK：构建通过，约 66.2 MB，包含 `armeabi-v7a`、`arm64-v8a`。
- 两个 APK 均通过 `apksigner` v2 验签；当前 Release 仍使用 QA Debug 证书，只能作为联调包，不能作为商店正式发布包。
- 当前签名 SHA-1：`6A:17:FB:12:2A:C5:06:71:A0:54:E1:8D:C0:A2:1B:A1:D5:00:F6:BB`。微信开放平台 Android 移动应用必须登记包名 `cn.saydian.ring` 和这一本轮联调签名，正式上架前再换为正式签名并同步更新平台登记。
- 华为真机 `L2E0222510006851`：Debug 包覆盖安装成功，主进程启动成功，当前日志未发现本应用崩溃；未清除用户数据。

### 构建失败与修复

- 首次构建缺少 Kotlin、Flutter 引擎和 Android 构建依赖，在线 Gradle 下载多次长时间无响应。
- 将缺失依赖下载到本轮 `build/local-maven` 临时目录，校验仓库哈希后以离线、低并发方式完成原生测试和双 APK 构建。
- 临时写入的全局 Gradle 仓库脚本已删除；`build/` 下临时依赖与日志均为 Git 忽略文件，未加入提交。

## 尚未验收

- Windows 不能编译或真机验证 iOS。当前 iOS `SAIDIAN_WECHAT_APP_ID` 与 Universal Link 仍为未配置占位值；发布 iOS 前必须由 Xcode 构建配置写入与后台一致的 AppID 和已备案 Universal Link。
- 本轮未退出手机现有账号、未清理 App 数据，因此没有在真机上破坏性地走完“未登录 -> 微信授权 -> 首次绑定手机号”全流程。
- 微信真机授权还依赖微信开放平台移动应用审核、包名/签名登记和微信客户端回调；后台填好参数只是其中一部分。
- 阿里云真实短信、微信真实授权回调、服务端线上部署与能力开关仍需发布后现场复验。
