# App 微信登录接口联调记录（2026-09-08）

## 结论

按产品方 2026-09-08 的明确要求，Harmony 客户端已切换到服务端现行的 `POST /api/v1/site/app-wechat-login` 合约。客户端从微信官方 SDK 回调读取 `openId`，继续在本机核对一次性 `code + state` 和超时状态，再按接口文档提交五个表单字段。

该修改解决的是“客户端与已部署接口不一致”，并不消除服务端信任客户端自报 OpenID 的身份冒充风险。正式发布阻断仍保留，直到服务端改为用一次性 code 向微信兑换并验证身份。

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
| 真机环境 | nova 14 已连接；微信 `8.0.21.38` 已安装 | 客户端具备拉起微信并接收回调的基础条件 |
| 当前客户端合约 | 新地址＋`unionid/openid/sex/nickname/headimgurl` 五字段 | 与 Apifox 现行示例一致；只有 `openid` 来自微信 SDK 回调，其余当前回调未提供的资料留空 |
| 兼容版真机拉起 | SDK `sendReq` 与 App Linking 均成功，微信端显示“微信登录失败 / empty scopes” | 请求尚未回调 App、也未到新登录接口；需核对微信开放平台 Harmony 应用的登录权限、应用身份配置及当前微信版本兼容性 |
| 客户端回归 | Asia/Shanghai 与 UTC 各 433/433 通过，ArkTS 构建成功 | 保持既有登录、账号切换和敏感信息防泄漏基线 |

## 客户端能力边界

当前官方 HarmonyOS 微信 SDK 的 `SendAuthResp` 提供一次性 `code`、`state` 及基础回调字段，其基类提供可选 `openId`。回调不提供 `unionid`、`sex`、`nickname`、`headimgurl`，因此客户端只能把 SDK 返回的 `openId` 作为当前接口身份字段，其余资料按文档示例留空。

客户端不得：

1. 在 App 内保存或使用微信 AppSecret。
2. 直接请求微信服务端用 AppSecret 兑换 code。
3. 伪造 OpenID、UnionID、昵称或头像，或用本地缓存身份替代本次官方回调。
4. 将空资料字段解释成已经从微信取得的真实用户资料。

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

## 本轮客户端兼容实现

1. Harmony `AccountClient.loginWithWechat` 已切换到 `/api/v1/site/app-wechat-login`。
2. 微信回调仍必须通过本地 state 精确匹配、十分钟超时和非空一次性 code 校验。
3. 登录请求只采用本次 SDK 回调的 `openId`；`unionid/sex/nickname/headimgurl` 留空，不伪造资料。
4. 已增加新地址、五字段顺序、OpenID 边界、账号切换失败和客户端密钥缺失测试。
5. Android/iOS Flutter 客户端不在本轮修改范围内。

## 仍需真机和服务端验收

1. 先解决微信端 `empty scopes`，再验证 SDK 是否实际返回 `openId`，以及服务端能否返回有效 Session。
2. 验证首次登录、再次登录、取消、拒绝、旧账号切换和退出后重新登录。
3. 确认同一微信用户不会因空 UnionID 或资料字段生成重复账号。
4. 服务端最终仍应按“服务端修复合约”兑换并校验一次性 code，不能长期信任客户端自报身份。

## 当前状态

- 客户端代码：已按产品方要求切换为服务端现行五字段合约。
- 页面与其他登录方式：不受影响。
- 微信登录：自动化与编译已通过；真机已能拉起微信，但被微信授权侧 `empty scopes` 阻断，尚未产生回调或调用服务端；服务端身份校验风险仍为 P0 发布阻断。
