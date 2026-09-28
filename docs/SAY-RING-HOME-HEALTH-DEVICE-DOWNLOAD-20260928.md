# 2026-09-28 Say Ring 首页、健康、设备与下载更新

## 修改原因

本轮按产品反馈修复 CoolWear 戒指压力测量回调，恢复 HRV，调整首页与健康卡片布局，补充戒指设备控制；同时统一中国大陆手机号输入，并让 Android、HarmonyOS 在线更新都跳转到 Say Ring 独立下载页。

## 修改范围

- Flutter：`lib/domain/`、`lib/services/`、`lib/ui/`、`lib/l10n/`。
- Android CoolWear 原生桥：`android/app/src/main/java/cc/saidian/saydian_app/CoolWearRingBridge.java`。
- HarmonyOS：`harmony-native/entry/src/main/ets/` 与对应 Node 契约测试。
- 自动测试：`test/` 中登录、更新、SDK、导航与页面回归。

## 完成内容

1. 压力与 HRV
   - 压力继续使用 SDK `sendStressSwitch(OPEN)`，HRV 使用 `sendRriHrvCmd(OPEN)`，不以模拟值代替设备结果。
   - 仅在当前手动测量仍有效、SDK 已返回有效数值但设备时间戳无效或过旧时，使用手机收到回调的时间保存该次测量，避免上一版本因时间戳门禁丢弃真实结果。
   - HRV 重新显示，并保留设备能力检查；不支持 HRV 的型号不会伪装为可测量。
2. 首页与运动
   - 隐藏首页顶部“身心准备度”。
   - 原“健康预警”入口改为“运动”，进入全部运动项目二级页面。
   - 移除首页底部重复运动区；首页关键文字限制单行，防止窄屏换行破坏排版。
   - 健康指标改为统一卡片式布局，保持现有红金色调。
3. 设备控制
   - 增加“摇一摇拍照”“查找设备”“自动健康检测”。
   - 分别接入 SDK `sendPhotoSwitch`、`sendFindDevice`、`sendHeartAutoSwitch` 及能力读取；自动检测配置同时覆盖心率、血氧和检测间隔。
4. 手机号
   - 手机号验证码登录默认中国大陆，不显示区号选择；界面统一输入、显示 11 位手机号。
   - 传给共享国际账号接口时仍在内部规范化为 `+86`，避免破坏现有服务端账号契约；显式 E.164 数据仍可正确解析。
5. 在线更新
   - Android 与 HarmonyOS 使用产品 `say-ring` 查询更新。
   - 检测到新版本后统一打开 `https://app.saydian.cn/global/say-ring` 下载页，由下载页选择直装包或应用市场。
   - 更新清单未发布、返回 404 或暂无版本时不再在前端显示错误。
   - HarmonyOS 支持后台配置直接 HAP 地址或应用市场跳转地址。

## SDK 依据

- CoolWear 示例确认压力实时回调 `RCVD_STRESS_SHOW`，数据结构 `K6_StressStruct`。
- HRV 实时回调 `RCVD_DATA_TYPE_RRI_HRV`，数据结构 `k6_RRI_HRV_DATA`。
- 相机、查找设备和自动检测对应 `sendPhotoSwitch`、`sendFindDevice`、`sendHeartAutoSwitch`。
- 功能展示仍依据设备握手后的能力响应，SDK 源码存在接口不等于当前戒指实机支持。

## 验证记录

- `dart format` 与本地化代码生成：通过。
- `flutter analyze --no-pub`：通过，0 issue。
- 全量 Flutter 测试（UTC）：881/881 通过。
- 全量 Flutter 测试（Asia/Shanghai）：881/881 通过。
- HarmonyOS Node 契约测试（UTC）：481/481 通过。
- HarmonyOS Node 契约测试（Asia/Shanghai）：481/481 通过。
- Android 原生 `testDebugUnitTest` 与 `compileDebugJavaWithJavac --offline`：通过；原生测试 XML 共 23 项，0 失败、0 错误、0 跳过。
- Android Debug APK：`build/app/outputs/flutter-apk/app-debug.apk`，186153147 字节，SHA-256 `E4282C1E8A0EBC750413BDCE9FFDD7F06DF121ACDCB9FC5C17ABB2EFC59B6CDE`。
- Android QA Release APK：`build/app/outputs/flutter-apk/app-release.apk`，68070628 字节，SHA-256 `2CABE2D847AAF79BBA7083CB3A1CCF29D7B264FB068F8FAD6E86AF10A72E421A`。
- 两个 APK 均核对为包名 `cn.saydian.ring`、版本 `0.1.21 (1004)`、ARM64/ARMv7、APK Signature Scheme v2；当前证书 SHA-256 为 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，属于 QA Debug 证书，不是正式上架签名。
- HarmonyOS Debug HAP：`harmony-native/entry/build/default/outputs/default/entry-default-unsigned.hap`，24674922 字节，SHA-256 `6F623D82414C87885015560A64A218D38A391598F405B0E3346D3A5E695BD3D6`；它是未签名开发产物，不能用于正式分发。
- `git diff --check`：通过；仅出现仓库既有的 Windows 换行提示。

## 失败与修复

- 全量 Flutter 首轮暴露 6 个旧断言与本轮中国手机号、运动导航、更新 404 行为不一致；逐项修正测试契约后，双时区全量均通过。
- HarmonyOS 契约首轮仍期待“下载页未配置时报错”；按新需求改为安全返回“暂无更新”，并增加直装包、应用市场、凭据保护测试后双时区通过。
- HarmonyOS 构建期间存在已有资源冲突警告，但最终生成 Debug HAP；未把警告写成构建失败，也未忽略未签名边界。
- 推送 `6ed5bff` 后，GitHub `mobile-ci` 的分支与 `main` 两次运行（`36373810888`、`36373813904`）均在约 2 秒内、任何工作流步骤开始前结束为失败，Harmony/quality 无步骤日志且 Android/iOS 随后跳过；日志接口返回 `BlobNotFound`。本地完整验证仍通过，但远端 CI 不能标为通过；现有证据只支持“GitHub 运行环境未启动任务”，不能进一步臆测为源码失败或具体账户原因。

## 尚未验收

- 本轮没有重新进行真实戒指压力和 HRV 采样，因此只能确认 SDK 命令、回调、有效值和时间戳处理链路；不能声称实测数值已经通过。
- 摇一摇拍照、查找设备和自动检测需在当前 HR01 固件上逐项真机验收，能力不支持时应保持不可用提示。
- Windows 环境未执行 iOS 构建；HarmonyOS 正式签名与真机安装未执行。
- 独立下载页和后台配置必须在服务端提交、CI 部署完成后，再做生产地址及上传/跳转闭环验收。
