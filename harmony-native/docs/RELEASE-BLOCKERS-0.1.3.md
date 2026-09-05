# 0.1.3 正式发布阻断与配合清单

## 当前结论

0.1.3 的推送和支付客户端链路已实现并通过构建、自动化及模拟器页面检查。AGC 正式应用身份已确认，Push Kit 已开启；发布证书、Profile、极光服务端凭据和真机验收仍未完成，因此仍不能称为正式签名版或上线版。

| 优先级 | 阻断项 | 当前证据 | 解除条件 |
| --- | --- | --- | --- |
| P0 | Release 签名缺失 | `signingConfigs` 为空；构建明确提示 No signingConfig | 取得同一正式应用的发布证书、Profile、别名与本机安全密码，并验证签名链 |
| P0 | 极光鸿蒙配置未完成 | AGC Push Kit 已开启；极光的 HarmonyOS 包名和 Server key 尚未最终保存 | 在极光填写 `cc.saidian.app.hm`，上传该 APP ID 的 Server key JSON，且不向 Git/日志暴露私钥 |
| P0 | 推送服务端未联调 | 客户端有登记/解绑/未读和路由；模拟器无法取得正式 registration ID | 服务端开放 harmony 设备登记，邀请/预警 Outbox 和 APNs/极光事件发送，真机 10 秒内验收 |
| P0 | 支付正式参数未联调 | 订单读取成功；未调用真实 `/api/v1/pay` | 服务端返回 Harmony `third_app_id`、`pay_info`，提供指定测试订单及微信/支付宝正式配置 |
| P0 | 原生真机缺失 | HDC 只有模拟器 | 原生 HarmonyOS 手机安装正式签名包，测试推送三态、支付三态和升级保留数据 |
| P1 | 隐私/上架材料 | 新 SDK 合并网络状态与广告标识同意权限 | 更新隐私披露、用途说明、备案与应用市场权限清单并完成法务审核 |
| P1 | 在线升级 | 原生开发版未接正式市场更新 | 确认 AppGallery 产品页、版本策略和强制升级规则后实现并验收 |
| P1 | 完整手表能力 | 当前仍为设备适配说明 | 取得 Veepoo/Yucheng 鸿蒙 SDK 或正式协议，完成蓝牙、同步、测量、表盘和运动真机验收 |

## 服务端接口待确认

- `POST /api/v1/member/push-devices`：接受 harmony 平台设备并幂等绑定当前账号。
- `DELETE /api/v1/member/push-devices/{installation_id}`：退出或账号失效时解绑。
- `GET /api/v1/member/notify/statistics` 或 `/unread-count`：未读数和消息列表状态一致。
- 关爱邀请、健康预警事务写入 Outbox；负载只携带事件 ID、类型、实体 ID 和白名单路由。
- `/api/v1/pay`：按服务端当前订单金额和状态签名，返回 Harmony ThirdPayClient 所需参数。
- 支付回调幂等验签并更新订单；客户端返回或第三方 App 返回不能直接视为成功。

## 正式签名门禁

1. AGC 正式应用、工程 bundleName、极光包名、Profile 中 bundleName 四处完全一致。
2. Release APP/HAP 可在原生真机安装，签名校验成功，旧正式签名包覆盖升级后登录和本地数据保留。
3. 推送前台、后台、进程终止三态送达并可正确路由；通知内容不暴露健康值。
4. 微信、支付宝分别完成成功、取消、失败、重复回调和订单回查；使用指定测试订单，不使用普通用户订单。
5. Release 自动化、双时区测试、权限清单、SHA-256 和归档复核全部通过后，才可标记 release_ready=true。

## 已解除的阻断

- AGC 正式应用已确认：“Saydian赛电”，APP ID `6917615560681044373`，bundleName `cc.saidian.app.hm`。
- `cc.saidian.app` 已被 Android 应用占用；`harmony` 是平台保留词，两者均不能作为新 HarmonyOS 包名。
- AGC 中 Push Kit 已保存开启；本地工程已切换到与 AGC 一致的正式 bundleName。
