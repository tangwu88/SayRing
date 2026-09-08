# App 微信登录接口联调记录（2026-09-08）

## 结论

服务端已新增 `POST /api/v1/site/app-wechat-login`，但当前请求合约不能安全接入官方 App 微信登录。客户端暂不切换到该接口，避免产生任意 OpenID 冒充登录风险。

当前鸿蒙 App 继续保留官方微信 SDK 的一次性授权 `code + state` 流程，但生产旧接口 `/api/v1/site/wechat-login` 已返回业务 404，因此微信登录在服务端修复前不可用。

## 文档合约

Apifox 页面：`https://s.apifox.cn/860ee0ab-38c8-44b8-baa5-82ce567e7994/511582553e0`

- 方法：`POST`
- 地址：`/api/v1/site/app-wechat-login`
- 类型：`multipart/form-data`
- 文档字段：`unionid`、`openid`、`sex`、`nickname`、`headimgurl`
- 成功响应：`access_token`、`refresh_token`、`expiration_time`、`member`

## 实际探测结果

本轮只使用明确无效的合约探测值，不使用真实用户 code、OpenID 或资料，也没有创建测试账号。

| 项目 | 实际结果 | 结论 |
| --- | --- | --- |
| 旧接口 `/api/v1/site/wechat-login` | HTTP 200，业务 `code=404` | 旧原生 code 兑换入口已不可用 |
| 新接口只提交官方授权回调可提供的 `code/state` | HTTP 200，业务 `code=500` | 服务端直接读取缺失的 `openid` |
| 新接口异常响应 | 返回服务器文件位置和完整调用栈 | 生产错误信息泄露，需要统一收敛 |
| 真机环境 | nova 14 已连接；微信 `8.0.21.38` 已安装 | 客户端具备拉起微信条件，但服务端合约阻断终态登录 |
| 客户端回归 | Asia/Shanghai 与 UTC 各 432/432 通过 | 保持既有登录、账号切换和敏感信息防泄漏基线 |

## 客户端能力边界

当前官方 HarmonyOS 微信 SDK 的 `SendAuthResp` 提供一次性 `code`、`state` 及基础回调字段，不提供 `unionid`、`nickname`、`headimgurl`。虽然基类存在可选 `openId` 字段，也不能将客户端自报 OpenID 当作服务端登录凭证。

客户端不得：

1. 在 App 内保存或使用微信 AppSecret。
2. 直接请求微信服务端用 AppSecret 兑换 code。
3. 信任或伪造客户端传入的 OpenID、UnionID、昵称、头像作为登录身份。
4. 为了兼容新接口而传空资料、固定资料或本地缓存身份。

## 服务端修复合约

建议保留新地址 `/api/v1/site/app-wechat-login`，将请求字段调整为：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `code` | 是 | 微信官方 SDK 返回的一次性授权码；服务端只能消费一次 |
| `state` | 是 | 客户端生成并已在回调时完成精确匹配的授权状态 |
| `platform` | 是 | `harmony`、`android` 或 `ios` |
| `group` | 是 | 固定 `app` |
| `consent_version` | 是 | 当前隐私协议版本 |
| `consent_accepted` | 是 | 固定为已明确同意 |

服务端必须：

1. 使用服务端安全保存的 AppID/AppSecret 向微信兑换一次性 code。
2. 从微信响应中取得并校验 OpenID/UnionID，必要时由服务端读取昵称和头像。
3. 按微信应用身份隔离 OpenID，并对 UnionID 绑定冲突做原子校验。
4. 对 code 重放、过期、AppID 不匹配、微信请求失败返回明确的 4xx/业务错误，不创建或切换账号。
5. 所有异常返回统一安全结构，不返回服务器目录、源码文件、行号或调用栈；HTTP 状态与业务错误一致。
6. 成功响应继续返回 `access_token`、`refresh_token`、`expiration_time` 和稳定标量 `member.id`。

## 服务端完成后的客户端工作

1. 将 Harmony `AccountClient.loginWithWechat` 地址切换到 `/api/v1/site/app-wechat-login`。
2. 继续只发送一次性 `code/state`、平台、应用分组和协议同意信息。
3. 同步 Android/iOS Flutter 客户端的接口路径与平台字段。
4. 增加新接口契约、重放、账号切换、取消、超时和敏感字段防泄漏测试。
5. 在微信已登录真机上验证首次登录、再次登录、取消、拒绝、旧账号切换和退出后重新登录。

## 当前状态

- 客户端代码：未修改，避免引入不安全身份信任。
- 页面与其他登录方式：不受影响。
- 微信登录：P0 服务端阻断。
