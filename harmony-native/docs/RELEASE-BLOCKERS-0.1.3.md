# 0.1.3 正式发布阻断与配合清单

## 当前结论

0.1.3（7）的推送、支付、苹果版同构页面和 Veepoo 手表客户端链路已实现。华为 nova 14＋W9S 已完成连接、同步、电量、手动测量、设备控制、断开重连和前后台恢复；血氧停止卡住及末帧覆盖有效值已修复。正式 Release 签名及极光普通通知通道已经通过验证。关爱/预警业务推送、真实支付、线上更新、完整心电终态和完整设备矩阵仍未完成，因此仍不能称为正式上线版。

最新范围和证据以 [Vep 手表与苹果版页面对齐 QA](WEARABLE-UI-QA-20260905.md) 为准；下表中旧的模拟器结论已按本轮真机结果更新。

| 优先级 | 阻断项 | 当前证据 | 解除条件 |
| --- | --- | --- | --- |
| P0 | 业务推送服务端未联调 | nova 14 已取得真实推送标识、完成账号绑定，普通通知已前台/后台送达并点击唤醒；尚未收到真实关爱邀请或健康预警事件 | 服务端发送邀请/预警 Outbox 事件，补测前台、后台、进程终止及白名单直达页面 |
| P0 | 支付正式参数未联调 | nova 14 已调用真实 `/api/v1/pay`：微信缺少鸿蒙参数，支付宝仍返回旧平台参数；客户端已拒绝旧参数并安全回查订单 | 服务端返回 Harmony `third_app_id`、合法 JSON `pay_info`，提供指定测试订单及微信/支付宝正式配置 |
| P0 | 支付/升级真机闭环 | nova 14 已完成 App、W9S、页面和普通推送回归；生产支付及市场资源尚未齐全 | 完成业务推送三态、支付三态、市场跳转和正式签名版本覆盖升级 |
| P1 | 隐私/上架材料 | 新 SDK 合并网络状态与广告标识同意权限 | 更新隐私披露、用途说明、备案与应用市场权限清单并完成法务审核 |
| P1 | 在线升级 | 客户端已接严格生产清单与 AppGallery 白名单；线上清单当前未配置 | 发布正式 AppGallery 产品页和 `app-update.json` 后验收普通/强制更新 |
| P1 | 完整手表矩阵 | W9S 主要链路已通过；W8 鸿蒙 SDK 2.1.5 已完成双 SDK 接入、编译、安装和扫描回归，但现场无 W8 广播，真实连接/同步/测量尚未验收；W9/ET488/完整 ECG 仍未完成 | 使用可广播 W8 补测连接、同步、测量、运动和 30 分钟稳定性，并补测 W9、ET488 与佩戴 ECG |
| P0 | 微信原生登录服务端合约 | 客户端已用官方 SDK 拉起微信并校验 state；旧 `/wechat-login` 当前业务 404，新 `/app-wechat-login` 要求客户端自报 OpenID/UnionID/用户资料，只提交官方回调的 code/state 时业务 500 且泄露调用栈 | 新接口改为接收一次性 code，并由服务端使用安全保存的密钥兑换、校验 OpenID/UnionID；收敛错误响应后，客户端再切换地址并完成真机闭环 |

## 服务端接口待确认

- `POST /api/v1/member/push-devices`：nova 14 当前账号登记已成功；服务端仍需确认多设备幂等更新和失效标识淘汰。
- `DELETE /api/v1/member/push-devices/{installation_id}`：退出或账号失效时解绑。
- `GET /api/v1/member/notify/statistics` 或 `/unread-count`：未读数和消息列表状态一致。
- 关爱邀请、健康预警事务写入 Outbox；负载只携带事件 ID、类型、实体 ID 和白名单路由。
- `/api/v1/pay`：按服务端当前订单金额和状态签名，返回 Harmony ThirdPayClient 所需参数。
- 支付回调幂等验签并更新订单；客户端返回或第三方 App 返回不能直接视为成功。
- `POST /api/v1/site/app-wechat-login`：必须只信任服务端用一次性 code 从微信兑换并验证的 OpenID/UnionID；不能把客户端自报的 `openid/unionid/nickname/headimgurl` 作为登录凭证。异常响应不得暴露服务端目录和调用栈。详见 `WECHAT-LOGIN-API-QA-20260908.md`。

## 正式签名门禁

1. AGC 正式应用、工程 bundleName、极光包名、Profile 中 bundleName 四处完全一致。
2. Release APP/HAP 签名校验已成功；仍需从同一正式签名旧包覆盖升级，并确认登录和本地数据保留。
3. 推送前台、后台、进程终止三态送达并可正确路由；通知内容不暴露健康值。
4. 微信、支付宝分别完成成功、取消、失败、重复回调和订单回查；使用指定测试订单，不使用普通用户订单。
5. Release 自动化、双时区测试、权限清单、SHA-256 和归档复核全部通过后，才可标记 release_ready=true。

## 已解除的阻断

- AGC 正式应用已确认：“Saydian赛电”，APP ID `6917615560681044373`，bundleName `cc.saidian.app.hm`。
- `cc.saidian.app` 已被 Android 应用占用；`harmony` 是平台保留词，两者均不能作为新 HarmonyOS 包名。
- AGC 中 Push Kit 已保存开启；本地工程已切换到与 AGC 一致的正式 bundleName。
- 极光 HarmonyOS 包名与 Server key 已配置，nova 14 已取得真实 Registration ID，账号登记接口返回成功。
- 极光普通通知已完成前台送达、后台送达和点击唤醒；普通通知不等同于关爱/预警业务路由验收。
- 正式 Release 证书和发布 Profile 已创建；0.1.3（7）签名 APP/HAP 通过官方完整性及 `type=release` 校验，包名 `cc.saidian.app.hm`、APL `normal`。
- Flutter 分析零问题，UTC 与 Asia/Shanghai 各 403/403 通过；本轮鸿蒙 UTC 与 Asia/Shanghai 各 207/207 通过。
- W8 SDK 2.1.5 已与 W9 SDK 共存接入；0.1.4（9）双时区自动化各 432/432 通过，nova 14 安装、登录、页面、扫描及前后台恢复通过。W8 实表链路仍按阻断项保留。
