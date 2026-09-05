# 赛电原生鸿蒙开发版

ArkTS + ArkUI，独立于已有 Flutter/Android/iOS 工程。当前范围包含账号、苹果版同构的主要页面、远程关爱、消息推送客户端、商城订单、鸿蒙三方支付客户端，以及 Veepoo 手表的扫描、连接、健康同步、测量、设备设置和表盘控制。

最新开发版本为 0.1.3（4），已对齐 AGC 应用身份 `cc.saidian.app.hm`（APP ID `6917615560681044373`）。本轮在华为 nova 14 上完成原生真机安装和 W9S 回归；UTC 与 Asia/Shanghai 各 123 项原生契约测试通过，Flutter 全量 382 项测试通过。实际范围和边界见 [Vep 手表与苹果版页面对齐 QA](docs/WEARABLE-UI-QA-20260905.md)。

当前 HAP 使用本机开发调试 Profile 签名，可留在已授权真机继续测试；它不是生产发布签名，不可据此宣称已达到应用市场上架条件。

Git 保存范围和发布边界见 [2026-09-04 开发检查点](docs/GIT-CHECKPOINT-20260904.md)。此前记录中的“未提交”描述保留为当时状态，本次保存不代表正式上线验收完成。

## 打开及构建

使用 DevEco Studio 26.0 打开本目录（不是仓库根目录），安装项目依赖后选择 `entry` 和目标真机。

本机目录：`/Users/saydian/DevEcoStudioProjects/SaydianHarmony/harmony-native`。必须使用英文路径，中文路径会被构建器拒绝。

本机使用官方 HarmonyOS 7.0 SDK。最低 API 23，因为本版网络安全策略需要禁用重定向。

```sh
ohpm install --all
hvigorw --mode module -p product=default -p module=entry@default assembleHap --no-daemon
node --test tests/*.test.mjs
```

`DEVECO_SDK_HOME` 应指向官方 SDK 根目录，Node 使用 DevEco 随附版本。签名配置仅在本机配置，不提交证书、密码、Token 或私钥。

当前配置省略 `compileSdkVersion`，由 IDE 自带 SDK 编译；目标 `26.0.0`，最低 `6.1.0(23)`。不要把系统镜像版本字符串直接写入 SDK 配置。

ohpm 工程元数据 1.0.0 是构建工具要求，不是 App 正式版本。签名配置只允许保存在本机，不提交证书、Profile、密码、Token 或私钥。

## 当前可用范围

- 现有账号密码登录、失效会话刷新、Asset Store 安全保存凭证、本机退出。
- 参照苹果版功能结构的健康首页、全部健康数据、运动记录、AI、商城、设备和“我的”页面；不复制视觉稿，不生成模拟健康数据。
- 公开健康百科、用户协议和隐私政策；内容由现有服务端读取，本站安全附件配图已实际显示；异常加载与重试仍需补做完整系统层验收。
- “先浏览首页”明确属于未登录浏览，不生成账号、健康记录或模拟测量。
- 远程关爱成员、邀请、共享设置和 10 类成员记录；不混入本机健康记录，写入只在用户点击后执行。
- 消息未读数、通知权限、极光鸿蒙标识登记及关爱/健康预警白名单路由；正式送达仍依赖 AGC、Push Kit、极光和服务端配置。
- 商城真实订单列表、支付前再次读取订单金额与状态、服务端支付参数解析、微信/支付宝选择及结果回查；App 不在本机生成签名。
- 官方 Veepoo 鸿蒙 SDK：Vep 扫描、连接、认证、自动重连、真实电量、健康历史、手动测量、真实心电采样、本地加密记录、设备设置、查找设备及手表内表盘读取/切换/恢复。
- 名称中含 `W8` 的设备固定标记为 `Yuc`；在 Yucheng 没有原生鸿蒙 SDK 前只发现和识别，不进入虚假连接状态。

## 待适配或外部阻断

Yucheng 原生鸿蒙 SDK、关爱双账号后台即时推送、服务端健康预警列表、鸿蒙生产更新清单和 AppGallery 产品页、商城规格/购物车/原生下单，以及微信/支付宝正式商户参数仍未完成联调。W9、ET488 和完整佩戴心电波形还需设备空闲时补做真机矩阵。

生产 Release 证书/Profile、极光服务端配置和真实支付回调仍是上线门禁。服务端缺口必须显示真实不可用状态，禁止用本机假数据或假成功代替。

不得用 Android APK 代替原生 HAP，也不得把本版空态或模拟器结果写成手表真机验收通过。

本轮记录见 [Vep 手表与苹果版页面对齐 QA](docs/WEARABLE-UI-QA-20260905.md) 和 [正式发布阻断清单](docs/RELEASE-BLOCKERS-0.1.3.md)。[推送与支付实施记录](docs/PUSH-PAYMENT-IMPLEMENTATION-20260905.md)、[关爱实施记录](docs/CARE-IMPLEMENTATION-20260904.md) 与旧版 UI 回归保留为历史证据。

## Release 候选包

构建方式：`hvigorw --mode project -p product=default -p buildMode=release assembleApp --no-daemon`。

0.1.3 产物位于 `build/release-review-0.1.3-20260905/`，旧 0.1.0/0.1.1/0.1.2 包保留不覆盖。
该历史归档是开发包名的 **未签名构建候选**，不是可以上架或向真实手机正式分发的版本。当前源码已切换正式 bundleName，但在发布证书、Profile 和签名验证完成前仍不得称为正式版。

先把同一次源码的 Debug HAP、Release APP，以及从该 APP 提取的 `entry-default.hap`（改为候选 Release HAP 文件名）放入该目录，再运行 `node scripts/package-review.mjs 20260905`。
不要直接用模块构建目录的 Release HAP 替代容器版：官方 APP 组装会重新排版 pack.info；虽可语义相同，文件哈希仍不同。
归档脚本复跑双时区测试，验证产物元数据与嵌套 HAP 一致性，只打包原生源码白名单；如汇总 ZIP 已存在则拒绝覆盖。

两台模拟器的 UI 脚本须逐台运行，先确认当前页是健康首页；不要并发发送控件点击，也不要在脚本运行时手动切换页面。
脚本只做只读业务检查，邀请/授权写入需另行安排双账号验收。
