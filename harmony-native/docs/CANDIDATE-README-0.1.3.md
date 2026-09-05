# 赛电原生鸿蒙 0.1.3（4）开发审查包

**未签名，不可上架，不可当作正式手机安装包。**

本包用于同事复核 ArkTS/ArkUI 原生工程。本次新增消息推送客户端、真实商城订单、鸿蒙微信/支付宝支付客户端及 PaymentKit 冷启动防闪退保护。

## 包内内容

- Debug HAP、Release HAP、Release APP。
- 原生源码白名单与锁定依赖。
- UTC、Asia/Shanghai 两套 102 项主机测试结果。
- 推送/支付实施记录、验证记录、发布阻断清单、SHA-256 清单和机器可读审查清单。

Release HAP 必须从同一 Release APP 中提取，脚本会比较二者字节哈希。`review-manifest.json` 必须保持 `release_ready=false`、`signed=false`。

## 已验证

- Debug/Release 构建成功，Release 元数据为 0.1.3（4）、`debug=false`、`buildMode=release`。
- 模拟器冷启动、登录恢复、首页、消息页、真实订单列表和收银台选择页正常。
- 支付前强制检查系统能力并重新读取服务端订单；缺少 PaymentKit 的设备不在冷启动阶段加载支付组件。
- 通知权限、未读接口、极光初始化失败的可解释状态正常。

## 尚未验证

- 正式华为应用身份、Push Kit、极光鸿蒙包名/Server key、真实推送送达。
- 服务端 Harmony 支付参数、微信/支付宝真实拉起及支付回调。
- 正式 Release 签名、原生鸿蒙真机安装、升级和上架。
- 手表蓝牙、健康同步、测量、表盘、运动和完整在线升级。

先阅读 `PUSH-PAYMENT-IMPLEMENTATION-20260905.md`，再阅读 `RELEASE-BLOCKERS-0.1.3.md`。不得通过改文件名把未签名包称为正式版。
