# 2026-09-29 HR05 同步、运动实时值与客服提示跟进

## 修改前检查与原因

- 仓库 `E:\SayRing`；开发分支 `codex/home-health-device-update-download`，修改前 HEAD、`origin/main` 与远端开发分支均为 `d7180698396a8906aefadc926bd43a2168927c14`；执行了 `git fetch origin --prune`。既有 `docs/SAY-RING-YOUTHFUL-LUCKRING-UI-20260928.md` 空行改动属于其他工作，保留且不纳入本次提交。
- 按 `AGENTS.md` 阅读国际版交接、变更日志、复盘、回归清单与最近 HR05 记录。真机 HR05 已连接；用户确认戒指暂未佩戴，故本次不作真实运动心率验收。
- 真机设备页手动同步两次都未收到最终同步完成事件。Android 桥以前会把同步期间已收到的有效记录在超时后全部清空；运动页还会先等健康同步，再发起第二次历史同步，造成“正在同步”持续。前台客服公开接口实际返回 `configured=false`，用户指定本轮只修页面提示，不写入联系方式。
- SDK 的运动实时回调有心率、时间与距离；没有可确认的实时热量字段。历史运动记录有热量。禁止凭心率/时间估算并冒充戒指实报。

## 本轮改动

- `CoolWearRingBridge.java`：活动包只记录数量，不打印健康值；最终同步事件缺失时，将已解析的健康/运动包随超时错误交给 Flutter，仍保持失败状态，避免把不完整历史标为同步成功；实时运动心率接受有效 BPM，不再因固件的零或本地时间戳丢弃。
- `app_controller.dart`：按当前连接设备和会话校验后保存超时前读到的记录，保持待上传与“未完整同步”的状态；无数据时显示明确重试提示。运动历史不再跨设备保存迟到响应。运动开始命令返回前抵达的实时心率不再被清空。
- `pages.dart`：运动今日活动先展示本地已保存记录，不等两次 SDK 历史请求；实时心率、热量先显示 `--`，HR05 热量说明协议没有实时值、结束后检查历史，不生成估算值。
- `prototype_pages.dart`：国际客服区分未配置、网络失败和联系方式不完整；不混入国内固定联系方式。
- 增加对应 Flutter 回归：部分数据保留、异设备拒绝、无数据提示、提前到达的心率、运动历史部分包和跨设备迟到结果、客服空配置。

## 验证与失败修复

- `dart format`、`flutter analyze --no-pub`：通过；最终源码 Flutter 全量测试 UTC 与 Asia/Shanghai 各 903 项通过，定向 `qa_user_flows_test.dart` 45 项通过。
- 原测试“结束运动时保存提示”一度失败：新增指标卡片使提示位于可滚动区域以外；测试滚动到提示后通过，运动状态逻辑未变。
- Android `:app:testDebugUnitTest --offline --quiet` 首次被 Gradle 的 QRing 单个不可变缓存污染拦截；停止项目 Gradle daemon 后，将精确缓存目录移至 `E:\saydian\.toolchains\gradle-quarantine`（可恢复），重跑通过：31 项、0 失败。未删除用户数据。
- Harmony Node 契约测试 481/481 通过；Harmony Release 模式 `assembleHap` 编译成功，但因 `signingConfigs=[]` 仅输出未签名 HAP。当前鸿蒙设备服务未接 HR05/CoolWear SDK，编译通过不等于 HR05 功能可用。
- Android QA Release 最终源码重构建通过：`build/app/outputs/flutter-apk/app-release.apk`，70,128,238 字节，SHA-256 `E63BB2D45269E0783B5E99B77245B6D65FE7E9C74781974EA3E4FC42EB4D0ED5`；`aapt` 核对 `cn.saydian.ring`、`0.1.21 (1004)`、minSdk 26、targetSdk 36；`apksigner verify` 的 v2 签名通过，证书为 **Android Debug**，SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`。这不是应用市场正式签名。
- 鸿蒙未签名编译产物：`harmony-native/entry/build/default/outputs/default/entry-default-unsigned.hap`，18,358,753 字节，SHA-256 `5657A9BEA1BDC29FEE8EA980D82AF281F4DE5080BE5E5BBDB4B643C8E86ACF13`。没有 Android 正式 keystore、鸿蒙正式签名配置，用户选择先做非正式测试包，因此不提供应用市场正式包或正式签名。
- 国际后台上轮高德配置已推送至 Git 分支，但本次复查 `https://app.saydian.cn/global/health/ready` 仍报旧 revision `ef2f64323df46ddfe6ffeb415795429d3ed3e37e`，不能称后台已部署。此轮不扩大服务器改动。

## 待验收

- 戒指佩戴后，需在真机验证 HR05 运动心率回调、今日活动包与运动历史回读。没有数据包时页面只会明确告知，不伪造数值；实时热量仍取决于 SDK 是否提供真实字段。
- 客服后台须发布公开联系方式后才能显示可拨打/可复制的内容，本轮没有修改生产配置。
- Android 正式签名、鸿蒙正式签名及鸿蒙 HR05 SDK 适配缺失，不能提交应用市场。iOS 需 macOS/Xcode 真机另验。
