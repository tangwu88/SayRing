# 原生鸿蒙推送与支付实施记录

本文保留当天各阶段的失败证据；最终状态以文末“推送真机与正式签名闭环”为准。本轮最终构建版本为 0.1.3（5）。

## 本轮范围与开工保护

- 修改前已在 `codex/harmony-native-login-home` 执行远端更新，工作分支与上游均为 `42c2bc8`，无分叉后开始修改。
- 只修改独立原生鸿蒙工程 `harmony-native`；未改 Flutter、Android、iOS、服务器或极光后台数据。
- App 版本升至 0.1.3（4）时先使用开发包名 `cc.saidian.saydian.harmony.dev`，没有在尚未确认 AGC 身份时猜测正式包名。
- 不读取、提交或打印极光 Master Secret、支付密钥、证书密码、用户 Token 或健康数据。

## 推送实现

- 集成 `@jg/push` 1.4.2，使用公开 AppKey；同时读取华为 AAID 和极光 Registration ID。
- 登录后可申请系统通知权限并将 `installation_id`、`registration_id`、`platform=harmony`、版本号登记至现有账号服务。
- 退出时尝试解绑当前安装并清除本机推送状态；失败不阻塞本机退出。
- 首页消息入口显示真实未读数；未读接口按现有 statistics/unread-count 契约读取，未配置时不伪造红点。
- 推送点击只接受 `care-invitations` 与 `health-alerts` 两个白名单路由；未知路由和外部页面参数会被忽略。
- 锁屏健康预警只展示概括通知，具体健康数值必须进入 App 后从服务端重新读取。
- 最初检查极光鸿蒙配置页时，应用包名和 HarmonyOS Server key 均为空；这是后续补齐配置前的历史状态。

## 订单与支付实现

- 订单列表读取服务端真实订单号、金额与状态；不使用本地示例订单或固定金额。
- 仅待支付订单显示“去支付”。进入收银台后可选择微信或支付宝，但 App 不在本机生成签名。
- 点击支付前先确认设备具备 `SystemCapability.Payment.ThirdPaymentService`，再从服务端重新读取订单，防止展示期间金额或状态变化。
- 只有重新读取仍为待支付时，才向 `/api/v1/pay` 请求服务端签名参数；成功拉起后仍以服务端订单状态为最终结果。
- 支付组件改为按需动态加载。此前静态导入会在缺少系统支付 HSP 的模拟器冷启动时触发 `SIGABRT`；修复后不进入支付页也不会加载 PaymentKit。
- 本轮没有点击真实订单的最终支付按钮，没有创建扣款、打开第三方支付 App 或更改订单状态。

## 代码与测试覆盖

- `model/PushPaymentContracts.ts`：推送身份、通知路由、订单和支付参数的严格解析。
- `services/HarmonyPushService.ets`：通知权限、AAID、极光初始化与退出清理。
- `services/HarmonyPaymentService.ets`、`PaymentLaunchState.ets`：按支付方式创建客户端及回调代次保护。
- `services/NotificationNavigation.ets`、`EntryAbility.ets`：通知点击和支付回调分流。
- `services/AccountClient.ts`、`SaydianApi.ets`：认证 GET/POST/DELETE、设备登记、未读、订单和支付请求。
- `pages/Index.ets`：消息、订单、收银台及完整加载/空态/错误状态。
- 主机测试共 102 项，分别在 UTC 与 Asia/Shanghai 下 102/102 通过；包含推送去重边界、前台/冷启动路由、订单解析、支付前刷新和冷启动按需加载防回归。

## 构建与运行结果

- Debug 模块构建成功并覆盖安装至 HarmonyOS 7 / API 26 原生模拟器。
- Release APP 构建成功；包内元数据为 0.1.3（4）、`debug=false`、`buildMode=release`。
- 修复 PaymentKit 冷启动问题后，App 可稳定冷启动，登录态恢复、首页、消息页、订单页和支付选择页均可打开。
- 模拟器真实账号订单接口返回已支付与待支付订单；仅做只读展示，未发起真实支付。
- JPush 依赖合并后新增网络状态和广告标识同意权限，归档校验按最终 HAP 权限而不是仅按源码清单检查。

## 现场失败与最终处理

1. 第一次集成支付后，模拟器启动即退出。日志显示缺少 `paymentServiceHsp`；根因是 EntryAbility/首页静态加载 PaymentKit。改为能力判断后动态导入，并增加源码契约测试，冷启动恢复正常。
2. 极光初始化未造成闪退，但华为返回当前开发包无正式 Push Kit 身份。客户端改为显示可操作的配置缺口，不把失败写成已登记。
3. Release 构建仍提示没有 signingConfig。保留未签名审查包，不通过改名伪装正式签名包。

## 当时仍需外部配合

- 在极光鸿蒙设置中填写 `cc.saidian.app.hm`，并上传 APP ID `6917615560681044373` 对应的 Server key JSON。包名保存后不可修改，私钥文件不得进入 Git。
- 提供正式发布证书、Profile 和本机安全保存的密码，完成签名安装与升级保留数据测试。
- 服务端实现/确认 harmony 推送设备登记、退出解绑、邀请与健康预警事件 Outbox，以及不含敏感健康数值的推送负载。
- 服务端按微信/支付宝正式商户配置返回 Harmony `third_app_id` 与 `pay_info`；随后使用沙箱或指定测试订单完成回调、取消、失败和订单回查联调。
- 接入一台原生 HarmonyOS 真机进行推送前台/后台/进程终止送达和第三方支付拉起验收。

## 2026-09-05 生产身份补充记录

- AGC 已确认现有 HarmonyOS 应用“Saydian赛电”：APP ID `6917615560681044373`，包名 `cc.saidian.app.hm`，所属项目“Saydian赛电”。
- `cc.saidian.app` 与已有 Android 应用冲突；`cc.saidian.app.harmony` 因包含平台保留词被 AGC 拒绝，未提交。
- AGC Push Kit 已保存开启。本地 bundleName 已更改为 `cc.saidian.app.hm`；正式签名和极光 Server key 仍是独立门禁。

## 2026-09-05 nova 14 支付复测与防崩修复

- 真机订单读取正常：已支付订单不显示支付按钮，待支付订单使用服务端订单号与金额。
- 当前服务端的微信请求未返回鸿蒙 `third_app_id` 与合法 JSON `pay_info`，客户端显示“后台未返回鸿蒙微信支付参数”，并重新核对订单状态。
- 当前服务端的支付宝响应仍是旧平台 `orderInfo/config`。旧实现将其包装后调用鸿蒙 Payment Kit，nova 14 的系统支付服务出现 `libblueshield` 加载失败并终止 App 进程；订单复查仍为待支付，未确认扣款。
- 已删除旧平台参数自动转换。现在只有服务端明确返回鸿蒙原生 `third_app_id` 与 JSON `pay_info` 时才会调用 Payment Kit，避免因猜测参数格式再次触发支付组件崩溃。
- Payment Kit 调用新增 30 秒保护、成功/失败统一释放客户端、返回按钮锁定，以及任意结果后的服务端订单二次核验。客户端返回仍不直接视为支付成功。
- UTC 与 Asia/Shanghai 各 128 项测试通过，Debug HAP 编译与本机开发签名成功，并覆盖安装至 nova 14；正式成功/取消/失败回调仍需服务端鸿蒙参数和指定测试订单后验收。

## 2026-09-05 推送真机与正式签名闭环

- 极光依赖升级至 `@jg/push` 1.4.2。初始化迁至 AbilityStage，且在初始化前设置 AppKey、Channel 和注册回调；注册标识允许回调缓存及 15 秒限时重试，避免首次启动取得空标识。
- 华为 nova 14 已取得真实极光 Registration ID，登录后的设备登记接口返回成功；源码和发行日志不输出该标识、账号 Token、Server key 或证书密码。
- 极光控制台单设备普通通知已验证前台送达、后台送达及点击唤醒 App，设备回执为成功。控制台普通通知不含业务实体，因此不能替代关爱邀请和健康预警的白名单路由验收。
- App 版本升至 0.1.3（5），界面、推送设备登记和更新检查统一读取同一版本常量，避免版本号修改后出现三处不一致。
- 已创建并核验 `cc.saidian.app.hm` 对应的正式 Release 证书和发布 Profile；证书、Profile、私钥与密码只在本机安全位置使用，不提交 Git。
- Release APP 与独立 Release HAP 均构建成功。官方签名工具验证完整性通过，发布 Profile 为 `type=release`、APL 为 `normal`，包名和 APP ID 与 AGC 一致。
- 默认、UTC、Asia/Shanghai 三套原生契约测试均为 128/128 通过；发行 ZIP 通过完整性检查，目录内 SHA-256 全部复核通过。

## 最终剩余阻断

- 服务端仍需为关爱邀请和健康预警发送稳定事件 ID、事件类型、实体 ID 及白名单路由，并补测前台、后台、进程终止三态；普通控制台通知只证明传输通道可用。
- 微信和支付宝仍未返回鸿蒙原生 `third_app_id` 与合法 JSON `pay_info`，真实成功、取消、失败及重复回调不能在客户端自行伪造。
- AppGallery 产品页、生产更新清单、正式版本覆盖升级数据保留，以及 W9/ET488/完整佩戴心电矩阵仍待完成。
