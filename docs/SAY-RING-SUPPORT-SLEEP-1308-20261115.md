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

## 追加：2026-11-15 安卓模拟器复测

- 新建独立的 `SayRing_QA_1308`（Android 16 / API 36、ARM64）。先在隔离的模拟器用调试入口和测试记录运行，完成后换回同一份原发行证书签名的 1308 正式 APK。保存原 APK SHA-256（见本文件）；安装后核对 `cn.saydian.ring`、1.0.14（1308）、非 Debug。通过原包冷启动、登录页、游客客服和常见问题入口检查，返回 App 前台，未发现本轮进程致命异常。未接触实体手机、现有模拟器数据或正式账号。
- `TZ=Asia/Shanghai flutter test integration_test/android_1308_emulator_qa_test.dart -d emulator-5560 --no-pub --reporter expanded --dart-define=SAYDIAN_ALLOW_LOCAL_DEBUG_API=true --name <本轮重点用例>`：**16 项通过**。用实际 Android Flutter 运行环境验证原生手机系统信息、蓝牙关闭时的诊断原因及隐私字段过滤；验证睡眠日／周／月、跨午夜和小睡、缺日留空、只有总时长、图表点击和窄屏两倍字号。
- 用安卓 App 的真实 HTTP 和 SSE 通信与仅在本机开放的 API、隔离 PostgreSQL 联调：发布 FAQ 搜索及详情、过滤草稿和其他产品的文章；游客发消息、转人工、收到坐席模拟回复并重新进入同一会话。客户端测试还覆盖离线重试、同编号去重、账号切换、WhatsApp 按配置显示和通知跳转。测试坐席与会话历史均使用本地测试数据；线上客服配置未更新。
- U19 血压使用模拟回包：新结果结束等待、显示并按原时间写入加密数据库；只收到旧结果时，界面结束等待，不入库第二条也不重发测量。该结果与实体 BLE、真实健康采样、云端数据回读及系统推送分别验收。
- 首轮复用了一条刻意抛错的宿主 Widget 用例，在 Android Live 测试宿主里中断后续用例；聚焦本轮模拟目标后重跑。联调夹具另修正了无效产品枚举、过于频繁的后台轮询和格式非法的模拟固件字符串；保留早期失败日志，未改动运行源码。临时调试入口已移除，本地联调监听已停止，模拟器保留原签名 1308 在前台。
- 本机资料 `qa-1308-20261115/android-emulator` 保留编译/回归日志、UI 截图和临时测试脚本；无模拟器镜像、设备缓存或测试附件提交 Git。

## 追加：安卓客服图片及断线恢复

- 独立 Android 16 模拟器的系统相册选取一张合成照片。先模拟服务端保存照片但 App 没收到回执，再从界面重试；本机测试库只保存一张，坐席和有权限的会话可打开同一附件，原 EXIF 等元数据未保留。
- 切断实时消息连接后由本地坐席连续发送两条回复。App 无需刷新页面即可按上一次收到的消息进度补取，两条各显示一次。
- 用户取消访客会话关联时，归属不变；明确关联后的首次回执若丢失，修复后的服务端向同一会员补发确认。旧访客及另一账号均不能查看原照片；切换账号会立即隐藏已打开的照片。
- 与本地真实 API 和隔离 PostgreSQL 完成以上串联场景，证据保存在本机 `qa-1308-20261115/android-emulator-followup`。仅调整配套服务端；客户端运行代码与原签名 1308 安装包未变，仍可在原模拟器继续操作。生产后台及实体设备未参与。

## 追加：2026-11-16 iPhone 15 Pro Max 真机调试

- iPhone 15 Pro Max（iOS 26.6）经 USB 在线，XR 不在线。安装前核对 `cn.saydian.ring` 原为 1.0.14（1303）；旧版不允许导出数据容器。`codesign --verify --deep --strict` 和 `shasum -a 256` 通过后，以 `xcrun devicectl device install app` 原位覆盖 1308 Profile。升级后用 `devicectl device copy from --domain-type appDataContainer --domain-identifier cn.saydian.ring --source .` 在 Git 外私下备份当前容器（23 文件）；这个副本不等于 1303 安装前的完整备份。测试中未卸载 App、清数据、换账号或重置设备，原登录会话和已有睡眠记录在新版均可读取。
- 普通 Profile 能前台启动；`flutter attach` 首次含此命令不支持的 `--no-pub`，移除后未发现 Profile VM。改用同一构建的正常开发签名包执行 `flutter run --debug --no-pub --no-uninstall-first --device-connection attached --use-application-binary=<1308 iOS Development IPA>`，实际读回安装构建为 1308，精确安装路径匹配正在运行的 App。Dart VM HTTP 200，iOS 主 isolate 为 `Resume`，Flutter view 与 Inspector 在线，DevTools 本机 HTTP 200。
- 首轮探针在构建之外调用 `ModalRoute.of`，意外记录了路由依赖，随后触发 Flutter 框架断言；热重启及多次独立查询也曾超时。移除这些路由依赖，重新启动正常 Debug，把应用恢复前台并在一个调试会话中执行现有页面按钮回调。复测完成全部页面标记，最终会话无框架异常、布局溢出或调试断开日志；未修改 App 运行代码。
- 实机核对睡眠日视图有既有汇总与阶段图，周、月切换均生成真实记录时长趋势。通过「我的服务」打开 FAQ，搜索框和空态正常；通过「联系客服」打开备用页，线上 `online-config` 返回 HTTP 404。在线客服发消息、转人工、系统推送、WhatsApp，以及外设新采样与重连均未在本轮验收。
- 最终回到首页并保留正常 Debug 运行、Flutter 调试会话及私有日志。未操作生产后台、下载页、TestFlight 或 App Store 审核。
