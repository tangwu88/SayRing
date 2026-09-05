# 赛电原生鸿蒙开发版

ArkTS + ArkUI，独立于已有 Flutter/Android/iOS 工程。当前范围包含账号、公开内容、远程关爱、消息推送客户端、商城订单与鸿蒙三方支付客户端，不是完整功能移植或正式发布版本。

最新开发版本 0.1.3（4），本轮实际结果见 [推送与支付实施记录](docs/PUSH-PAYMENT-IMPLEMENTATION-20260905.md)。
0.1.3 在 UTC 与 Asia/Shanghai 下各 102 项主机测试通过，Debug/Release 构建成功；原生模拟器已覆盖安装并验证冷启动保留登录。
0.1.1 的验证记录与归档保留为历史证据，不代替新版本验收。

Git 保存范围和发布边界见 [2026-09-04 开发检查点](docs/GIT-CHECKPOINT-20260904.md)。此前记录中的“未提交”描述保留为当时状态，本次保存不代表正式上线验收完成。

## 打开及构建

使用 DevEco Studio 26.0 打开本目录（不是仓库根目录），安装项目依赖后选择 `entry` 和 `Saydian_HarmonyOS7_Phone`。

本机目录：`/Users/saydian/DevEcoStudioProjects/SaydianHarmony/harmony-native`。必须使用英文路径，中文路径会被构建器拒绝。

本机使用官方 HarmonyOS 7.0 SDK。最低 API 23，因为本版网络安全策略需要禁用重定向。

```sh
ohpm install --all
hvigorw --mode module -p product=default -p module=entry@default assembleHap --no-daemon
node --test tests/*.test.mjs
```

`DEVECO_SDK_HOME` 应指向官方 SDK 根目录，Node 使用 DevEco 随附版本。签名配置仅在本机配置，不提交证书、密码、Token 或私钥。

当前配置省略 `compileSdkVersion`，由 IDE 自带 SDK 编译；目标 `26.0.0`，最低 `6.1.0(23)`。不要把系统镜像版本字符串直接写入 SDK 配置。

2026-09-04，App 0.1.1（2）：UTC / 中国时区各 57 项主机测试通过，Debug / Release 原生构建通过。
已验证用户手动登录、登录恢复、现有页面入口、10 个健康说明页、4 篇百科与 2 张配图、资料只读刷新、协议滚动返回；窄屏系统特大字体完整导航通过。
未完成全部异常 UI、原生手机及跨系统兼容验收；未签名产物不可当作正式手机安装包。ohpm 工程元数据 1.0.0 是构建工具要求，不是 App 正式版本。

## 当前可用范围

- 现有账号密码登录、失效会话刷新、Asset Store 安全保存凭证、本机退出。
- 健康首页、“设备”适配说明、“我的”及真实个人资料只读。
- 公开健康百科、用户协议和隐私政策；内容由现有服务端读取，本站安全附件配图已实际显示；异常加载与重试仍需补做完整系统层验收。
- “先浏览首页”明确属于未登录浏览，不生成账号、健康记录或模拟测量。
- 远程关爱成员、邀请、共享设置和 10 类成员记录；不混入本机健康记录，写入只在用户点击后执行。
- 消息未读数、通知权限、极光鸿蒙标识登记及关爱/健康预警白名单路由；正式送达仍依赖 AGC、Push Kit、极光和服务端配置。
- 商城真实订单列表、支付前再次读取订单金额与状态、服务端支付参数解析、微信/支付宝选择及结果回查；App 不在本机生成签名。

## 待适配

蓝牙连接、Veepoo/Yucheng SDK、健康历史及本地加密库、测量、趋势/真实心电波形图、关爱双账号写入联调、AI、运动、表盘、在线升级、注册及找回密码。推送的生产配置、服务端即时事件和支付的正式商户参数仍未完成联调。

不得用 Android APK 代替原生 HAP，也不得把本版空态或模拟器结果写成手表真机验收通过。

本轮记录见 [推送与支付实施记录](docs/PUSH-PAYMENT-IMPLEMENTATION-20260905.md)、[验证记录](docs/QA-RELEASE-20260905.md) 和 [正式发布阻断清单](docs/RELEASE-BLOCKERS-0.1.3.md)。[关爱实施记录](docs/CARE-IMPLEMENTATION-20260904.md)、[逐页交互与兼容检查](docs/UI-REGRESSION-20260904.md) 和 [最初实施](docs/IMPLEMENTATION-20260904.md) 保留历史证据。

## Release 候选包

构建方式：`hvigorw --mode project -p product=default -p buildMode=release assembleApp --no-daemon`。

0.1.3 产物位于 `build/release-review-0.1.3-20260905/`，旧 0.1.0/0.1.1/0.1.2 包保留不覆盖。
它是开发包名的 **未签名构建候选**，不是可以上架或向真实手机正式分发的版本。发布前必须完成上述阻断清单和正式签名，不得简单改文件名后称为正式版。

先把同一次源码的 Debug HAP、Release APP，以及从该 APP 提取的 `entry-default.hap`（改为候选 Release HAP 文件名）放入该目录，再运行 `node scripts/package-review.mjs 20260905`。
不要直接用模块构建目录的 Release HAP 替代容器版：官方 APP 组装会重新排版 pack.info；虽可语义相同，文件哈希仍不同。
归档脚本复跑双时区测试，验证产物元数据与嵌套 HAP 一致性，只打包原生源码白名单；如汇总 ZIP 已存在则拒绝覆盖。

两台模拟器的 UI 脚本须逐台运行，先确认当前页是健康首页；不要并发发送控件点击，也不要在脚本运行时手动切换页面。
脚本只做只读业务检查，邀请/授权写入需另行安排双账号验收。
