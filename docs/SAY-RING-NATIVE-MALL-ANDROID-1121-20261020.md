# 原生赛电商城与 Android 1121 构建准备

## 请求与源码

2026-10-20，用户要求开放赛电商城及购买，更新 `/down2` 安卓下载；随后明确沿用原有原生商城模块，并要求在这台 Mac 重新构建安卓包。因此本轮新包可显式开启原生商城购买上限，但仍须遵守账号、商品、市场、报价及真实支付渠道能力检查。

主工作树先从干净 `4dee4e6` 安全快进到 `origin/main` 的 `8e7541d074afc8fc8c6f23528c4069d5dbd94196`。再次 fetch 后，独立工作树/分支 `codex/native-mall-android-1121-20261020` 从已发布 iOS 1120 的源码分支 `3c9dee1` 创建，运行源码为 `c82b027d176018cbd5ea6daabfdfdae9ac053dbe`，包含最新原生模块显示、手测、关爱及商城名称；`origin/main` 是该分支祖先。没有将尚有硬件验收待办的整条分支合入 main。

本轮没有修改 Dart/原生业务、依赖或 SDK；正常 `lib/main.dart` 构建参数增加 `SAY_RING_COMMERCE_ENABLED=true`，版本为 **1.0.5（1121）**。复用 `GlobalShopHomePage`、商品、购物车、结算、订单和原生微信/支付宝桥接，未将入口改为网页商城。

## 已确认的线上状态

- Say Ring iOS 公开 `moduleVisibility.modules.mall=true`，后台对应商城显示开关已开启；本轮没有改动健康百科、AI、只读指标及其租约。显示租约仅允许浏览，不能突破已发布 1120 的编译时购买上限。
- App 原生公开能力：CN/CNY，checkout.enabled=true，maintenance.readOnly=false；`wechat_app`、`alipay_app` 均 enabled=false，分别提示 App 微信/支付宝未配置。后台“第三方服务 → 支付收款”亦显示两项 App 渠道未配置。H5 微信/支付宝已配置与此分开，不能将其凭据或状态作为原生 App 已接通。
- 现有结算页在没有本平台可用原生渠道时禁用提交订单，保留此检查。没有发送真实验证码、创建生产订单、发起扣款或宣称回调到账。
- 已请求用户在原生 App 支付配置入口补齐已开通的移动应用资料。密钥不得进入聊天或 Git；微信应用、Android 包名及签名须对应 Say Ring。

## 下载页版本误标修正

初始 `/down2` 与公开更新清单写 Android **1.0.0（1111）**，实际文件仍是旧地址 `say-ring-android-1791526039480-75639bff.apk`。从公网完整下载并独立核验：

- 69,323,534 bytes，SHA-256 `f67194877b1d3b186f5bdedd9f96a7db4f88f8a46e2d1686c5b8375f43425b2e`。
- 官方 aapt 回读 `cn.saydian.ring` / **1.0.0（1016）** / minSdk26 / targetSdk36 / 双 ARM；不是 1111。
- 官方 apksigner 验签通过，证书 SHA-256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。

在用户已登录的后台，仅修改 Say Ring App 更新表单的 Android buildNumber：**1111 → 1016**，保存后公开清单和真实页面均回读正确。逐项比较前后 JSON，除该字段外内容一致，包括 Android 文件/大小/哈希、iOS 1.0.4（1120）App Store、HarmonyOS 1.0.2（1111）、audience 和 publishedAt。

这是误标纠正，**不是已经发布新安卓包**。未把 Debug 包或不可读取的 Windows 正式 1111 包当成新的公开下载。

## 本机检查与构建

- 已有 Flutter 3.44.9、JDK17、Android build-tools36；没有安装新软件。依赖离线解析成功，锁文件未修改。构建前没有竞争的 Flutter/Xcode/Gradle 进程。
- `flutter analyze --no-pub`：退出0，零问题，3.6秒。
- 双 ARM Debug：`flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.5 --build-number=1121 --dart-define-from-file=config/dev.json.example --dart-define=SAY_RING_COMMERCE_ENABLED=true`；退出0，44.2秒。
- 独立冻结的 **DEBUG ONLY** APK：158,900,069 bytes，SHA-256 `923a10e22b0db8d499976e72b4e04a71bcb797ecffa315edf1fcd47b487b2728`。aapt 实读 `cn.saydian.ring` / 1.0.5 /1121 / min26 / target36 / 双 ARM / debuggable=true。此包未上传、未进入下载页。
- 正常生产 Release 构建使用相同版本/商城参数，并设 `SAIDIAN_PRODUCTION_RELEASE=true` 和原 first-party API/update origin；2.3秒退出1，`:app:verifySaidianReleaseMode` 明确拒绝：`Production release requires JPUSH_APP_KEY and JPUSH_CHANNEL=production`。没有改门禁或使用 QA 签名替代正式发布。
- 正式签名 `android/key.properties`、keystore 和生产推送配置在本项目、本机相关配置及已迁移的同产品目录均未找到；环境也未设置。已请求将 Windows `E:\saydian-release-signing` 挂载/复制至 Mac 并提供可读取路径，密码留在配置文件中。
- 本机 ADB 无连接设备，未安装、卸载或清理用户手机数据；未完成 Android 原生支付或戒指实物验收。

- 完整 Flutter 回归：`--no-pub --concurrency=1 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`，UTC **1336/1336**（108.2秒）、Asia/Shanghai **1336/1336**（89.9秒），均退出0。此为原运行源码的完整组件/合同回归，不是支付供应商、手机或新正式签名包验收。

当前没有新正式签名 APK，原生收款与新正式包下载仍待发布材料/商户资料齐备；不把编译通过写成正式上线。用户随后要求优先优化健康百科详情及大字阅读，此项在后续独立实现记录中继续；此处 Debug 和测试仅对应优化前的源码。

私有快照、完整下载和修正截图在主工作树忽略目录 `build/mall-download-20261020/`；新包、生产构建失败日志及测试日志在本工作树 `build/native-mall-1121/`，不入 Git。
