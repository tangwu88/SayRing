# 赛电后台 API 缺口

首次盘点：2026-07-29；最近只读核查：2026-08-29。公开 Apifox 文档共 45 个接口，全部标记为“开发中”；
OpenAPI 顶层安全声明为空，多数会员接口没有明确 Authorization 参数。

## 内测前必须完成

- 所有会员、健康、关爱、订单和文件接口强制 Bearer 鉴权，并统一 401/403 行为。
- 从公开示例移除 Token、手机号、IP、余额和内部账户字段；仍有效的凭据立即轮换。
- 补齐 Token 刷新、服务端退出、密码重置、账号注销。
- 新增设备绑定、解绑、能力、固件和同步游标接口。
- 新增 `POST /api/v1/member/health-records/batch`：
  - JSON 请求，最多 200 条。
  - 必须支持 `Idempotency-Key`。
  - 返回 `accepted`、`rejected[{id, reason}]`、`nextCursor`。
- 远程关爱继续补齐接受、拒绝、逐指标授权、撤销、到期时间和审计记录。
- 新增 `POST /api/v1/member/push-devices` 和 `DELETE /api/v1/member/push-devices/{installation_id}`，用于按账号登记/解绑安装实例和推送 registration ID。
- 新增 `GET /api/v1/member/notify/unread-count`、`POST /api/v1/member/notify/{id}/read`，并明确稳定事件 ID、幂等和多设备已读同步。
- 关爱邀请创建必须返回稳定 `invitation_id`，在同一事务写通知 Outbox；推送载荷不得包含手机号、Token 或健康数值。
- 用户协议和隐私政策提供正式版本、版本号、发布时间和用户同意记录。

## 客户端兼容策略

现有小程序路由保持不变。App 通过 `SaydianApi` 适配层访问现有登录、注册和关爱接口；
新能力在服务端未提供时抛出 `FeatureNotConfiguredException`，保留本地数据和待上传队列，
界面显示“未配置”，不假报成功。

2026-07-30 已按提供的 Apifox 页面补齐：

- `GET /api/v1/member/care`：获取关爱列表。
- `POST /api/v1/member/care`：使用 Bearer 鉴权和 `multipart/form-data`，
  字段为 `mobile`；客户端添加成功后刷新关爱列表。

Apifox 页面仍标记“开发中”，因此上线前必须在测试环境验证 401、重复添加、手机号不存在、
对方拒绝和撤销后的服务端行为。

## 2026-08-29 生产只读核查

- `GET /api/v1/member/care` 与 `GET /api/v1/member/care/my`：无 Token 时返回业务 `code:401`，证明现有只读路由受鉴权保护；创建、接受/拒绝和 Outbox 未执行写请求，不能标记通过。
- 推送设备登记/解绑、通知未读数和通知已读路由：只读/OPTIONS 核查返回业务 `code:404`，当前未部署或无法证明存在。
- `GET /api/v1/member/notify` 和消息详情：无 Token 时返回业务 `code:500`，并出现生产框架路径/堆栈；必须改为统一 401/403 并关闭调试堆栈。
- Android JPush SDK 已完成注册和 TCP 连接、控制台包名匹配，说明客户端到极光传输层可用；控制台集成度仍为 `--`，它不能替代上述服务端接口、Outbox 和双账号业务投递。
- iOS 极光控制台没有与 `cc.saidian.app` 匹配的 APNs 证书/Bundle 配置，iOS 系统通知仍为配置阻断。
- HarmonyOS 极光页面的应用包名、Server Key/JSON 尚未配置，不能把 Android SDK 结果计入鸿蒙通知覆盖。

核查过程未登录、未执行 POST/DELETE，未读取或记录 AppKey、RID、Token、AuthKey 等敏感值。

## 错误契约

服务端需统一返回：

```json
{
  "code": 422,
  "message": "字段校验失败",
  "data": {
    "errors": {
      "field": ["原因"]
    }
  },
  "timestamp": 1785338748
}
```

至少覆盖 400、401、403、404、409、422、429 和 500；健康数据部分失败不得用 HTTP 200
和空对象掩盖。
