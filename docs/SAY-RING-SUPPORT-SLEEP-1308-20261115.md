# Say Ring 1.0.14（1308）在线客服、连接诊断与睡眠报告

2026-11-15（北京时间）。客户端从独立 Say Ring 仓库远端 `codex/u19s-android-connect-20261111` 的 `01a8df1` 开始。服务端配套基线为 `c7bd29f`。开发与测试使用独立分支；本轮未操作商店、审核、正式下载或生产后台。

## 实现

- 「我的 → 联系客服」为中英双语会话。会员以及游客可发送文字和照片、取回历史、重试、转人工；关联游客会话必须由本人选择。断线按消息编号补取，附件需按会话身份授权。英文 WhatsApp 仅在后台配置并启用时显示。「我的服务」末尾的「常见问题」按后台分类读取已发布文章，支持搜索、语言回退和直接联系客服。
- 在已有同步诊断上增加连接过程、手机硬件型号、系统版本与构建号、App 构建与语言。等蓝牙操作结束后异步写诊断队列；先确认后端支持 V2，旧端仍可用 V1。设备及账号状态切换继续按当前上下文隔离，蓝牙关闭也能记录，不读取手机名称、序列号或 IMEI。
- 睡眠首页默认显示最新有记录日期；用户可切日、周、月。重画睡眠分期、趋势和评分，图表支持点选。保留没有分期的总时长、没有数据的空白日期；仅绑定可靠的同设备睡眠区间和真实采样，HRV 按算法区分，睡眠解读默认折叠。保留所有型号的睡眠入口，不改写既有记录或下发设备设置。

## 自动验证及形成测试包的过程

- `dart format --output=none --set-exit-if-changed lib test`、`flutter analyze --no-pub`：通过；`node --test tool/client_package_contract.test.mjs tool/test_native_log_privacy.mjs`：12 项通过。
- `TZ=UTC flutter test --no-pub --reporter expanded` 与 `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded`：各 2,435 项通过。重点覆盖窄屏两倍字号、中英文、切换时间范围、总时长旧记录、真实阶段来源、缺日、跨日、后返回账号隔离、V2/V1 降级及支持入口。
- 早期回归发现本地化测试宿主缺少生成的词条、客服替身缺少接口、旧断言重复匹配总时长，以及两例“只有总时长”的夹具意外携带阶段数据；修正宿主与各自的输入，继续用独立断言验证可用的分期、清醒时长、评分与效率。320 点宽度两倍字号发现长刻度不适合放在图底，调整为图上分布后复测通过。
- 安卓使用 `flutter build apk --debug/--release --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.14 --build-number=1308` 分别构建。一次发行构建在环境文件缺失时被明确的生产签名门禁挡住；加载原签名流程的私有环境后重跑通过。两包均用 `aapt dump badging`、`apksigner verify` 和 `zipalign -c -P 16 4` 检查；Release 证书指纹与已发行正式包一致。Gradle 报既有相机／推送插件后续 Kotlin 迁移提示，未改第三方库。
- iOS Flutter 包装步骤曾停在递归清理 Finder 元数据；直接用同一 `Runner.xcworkspace` 运行 `xcodebuild` 开发签名，Debug、Profile 顺序成功。此台 Xcode 构建使用命令级 `IPHONEOS_DEPLOYMENT_TARGET=15.0` 适配本机 SDK；Profile 使用 development 推送环境。两包通过 `unzip -tq` 与 `codesign --verify --deep --strict`，确认包名 `cn.saydian.ring`、签名团队 `W7SXQ4A226`、版本 1308，开发描述文件涵盖已登记的 XR 和 15 Pro Max。
- 服务端和后台配套说明见服务器仓库 `docs/implementation-log/2026-11-15-say-ring-online-support.md`。本地真实 HTTP/SSE 与隔离 PostgreSQL 的双向人工回执约 0.65 秒，未用真实会话。

## 交付与待验证

制品保存在本机 SayRing 发行资料的 `qa-1308-20261115` 目录。

| 测试包 | 字节 | SHA-256 |
|---|---:|---|
| 安卓 Release（原发行签名） | 75044413 | `941e90f6bb8b28a1534f1bff667766baf94aaf5583f9be373fdd929283847795` |
| 安卓 Debug | 160241614 | `7ed72320b7c0a62cd3b4dac7a93642e877165513a0cb5f95f03a3b1b93396076` |
| iOS Profile（开发签名） | 25389212 | `89796af6cbb4c871fe66152bf150c683868dd548e220805a133f534a032b43d7` |
| iOS Debug（开发签名） | 59387232 | `afbcca7a393c2bb1f632942366df0afafffb0d76b6f07b68247afe3ca06fb9dc` |

用户确认手机暂不能连接，尚未实装或核对覆盖安装前后数据。真实戒指／手表睡眠样本、蓝牙恢复、三款手机操作体验、服务商 AI 请求、系统推送及 WhatsApp 唤起需要联测。iOS 沿用当前产品禁用远程推送供应商的设置，已接通服务端／App 内未读与跳转，系统推送不能记为通过。生产服务未开启新客服入口。iOS/Android 制品未上传。
