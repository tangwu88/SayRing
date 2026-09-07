# 三端兼容与签名验收边界（2026-09-07）

## 安装门槛与实际证据

不因本轮 UI 优化提高最低系统版本。声明、编译、模拟验证、真机通过四者分别记录；不能用当前三台手机替代所有版本。

| 平台 | 当前代码/产物事实 | 本轮证据 | 仍需补验 |
| --- | --- | --- | --- |
| Android | 最新 r6 `cc.saidian.app`、`0.1.19(23)`；minSdk 26（Android 8）、targetSdk 36；armv7、arm64 | 首轮原生 JPush 配置未注入已拒收；最终重建两包签名、原生及 Dart 配置、ABI/16 KB 静态门禁均通过。P40 已安装的 r5 已核对 APK 哈希与同签证书 | P40 重新授权后又掉线，08:39:46 未检出；r6 未安装，保存重连目标分类未完成。新包点击/冷启动/撤销、Android 8/9、11–14 权限差异、15/16 与真实 16 KB 系统均待验，HRV 撤销 P1 未关闭 |
| iOS | 最低 iOS 13 未变；iPhone 竖屏，iPad 另声明四方向；最新 r6 `cc.saidian.app.dev.v2a92w8qz2`、`0.1.19(23)` | r6 Debug / QA Release 无签名编译、开发签名 Profile 构建/严格验签通过；08:07 同签覆盖，08:09 在 iPhone 15 Pro Max 独立启动 | 新共享 UI 真机回读未完成，不能以覆盖启动替代；较早 RunnerTests 32/32 本轮未重跑。iOS 13–17 低版本冷启动/SDK调用、其他机型/小屏大字、正式团队/APNs/TestFlight 待验 |
| Harmony | 最新 r12 HAP 实核 `cc.saidian.app.hm`、`0.1.3(7)`；min API 12，target API 26，phone/tablet；生产源码仍 `790c2de` | r12 Debug/Release 编译、官方包及 Profile 验签成功，UTC/Shanghai 各 423/423；签名与 r11 一致。真机仍是同源 r11：本次正常结束心率后设备入口恢复，实读表盘 9 个、当前 3 | r12 未覆盖安装，不沿用 r11 为新包安装结果；关爱撤销、非空运动/资料修改及低系统待验。HarmonyOS 5.x / API 12、18 的安装、冷启动、数据库、认证、通知、微信 SDK 不能由高版本手机代替 |

本轮 Flutter r6 最终静态分析零问题，UTC 与 Asia/Shanghai 各 524/524；这是自动化证据，不表示三端所有新页面或硬件均已真机通过。

Android 已移除错误必需特性 `android.bluetooth.le`，保留标准 BLE；相机特性全部 optional。主 Activity 未锁屏方向，部分第三方 Activity 仍为 portrait/behind；r6 两包均以实际 Manifest 和同 APK 编译资源通过门禁，未沿用 r5 证据。

Harmony 低于 API 23 时使用禁止自动重定向的 RCP 请求通道；旧系统不会忽略安全参数继续发送凭据。API 13 通知设置、API 20 ThirdPay 保留明确能力门禁。

## 最小补充矩阵

| 维度 | 最少样本 | 必须观察 |
| --- | --- | --- |
| Android 系统 | API 26/28、29/31、34、35/36；当前 P40 为保留登录的数据基线 | 安装、权限允许/拒绝、返回键、键盘、后台恢复、蓝牙中断、支付/通知返回 |
| iOS 系统 | iOS 13/15、16/17、18、26 | 旧系统 API 门禁、刘海/灵动岛安全区、权限、蓝牙恢复、通知冷启动 |
| Harmony 系统 | API 12、18、20、当前已连接手机版本 | 安全 HTTP/头像上传、数据库迁移与账号隔离、通知设置回退、微信支付回调 |
| 小屏/大字 | 320、360、375、390、430 逻辑宽；默认/1.3/1.6 字体 | 五层内页标题、双列卡片改单列、按钮完整可点、键盘不遮挡、趋势读数与文字摘要 |
| 平板/折叠态 | 600、840 逻辑宽；竖横切换、折叠态切换 | 不硬拉伸内容、不丢页面/筛选状态、弹窗及底栏安全区 |
| 中国厂商 | 华为、荣耀、小米、OPPO、vivo 中可获得的代表机型 | 权限管理、后台限制、厂商推送配置，不能以同 Android API 推断厂商后台策略相同 |

仅在已有机器/模拟器上先执行，不因矩阵扩大下载安装大量运行时。当前本机 iOS 模拟运行时仅 26.5、Android 已有 API 31 AVD；低版本仍记“待补充”，不用高版本结果代填。

## Android r6 门禁与 r5 历史证据

r6 首轮实际 APK 的 Dart 推送配置与本机配置匹配，但最终原生 Manifest 是禁用推送的默认值，因此拒收、不安装、不发布。
修正原生环境变量后重建两包，通过实际配置/签名/ZIP/ARM64 ELF 门禁；Debug 15/17 库、Release 15/16 库，依据本次两份真实依赖报告确认锁版本的 `libjutils.so` 例外。完整结果及新哈希见 `QA-20260907-ANDROID-R6-ARTIFACTS.md`；首轮失败不删改，也不能据此声称真机通过。

以下仅为 **r5 历史实核包** 事实；原版至 r5 均保留。产物位于 `artifacts/three-platform-20260907/android/`，文件名以 `-r5.apk` 结尾；历史哈希不作 r6 最新交付值。

- Debug：181259325 字节；SHA-256 `e8284f2fa34a84d354eefea3320b9f0b19955e4d0b43864679ed641e91b1359f`。
- QA Release：64661920 字节；SHA-256 `37b3e235419801bb721622ed96fa1e485092cf8bf99904a6cfa6bf9ef12f127c`。
- 同签证书 SHA-256：`1350168096373439fbb4fb80c0acd145f209e06310ddb658ce318d765525cb97`，仍为开发 Debug 证书，不能称正式发行。

- 两包两个 ARM 架构均有 Flutter 引擎；Release 两个架构均有 App AOT，15 个 armv7、16 个 arm64 动态库。Debug 不要求 AOT；不是只看目录是否存在。
- ZIP 16 KB 检查通过；全部 arm64 ELF LOAD 至少 `0x4000`，偏移与虚拟地址满足 16 KB 同余。ECG/JL/极光/SQLCipher 均无本产物的静态对齐阻断。
- `libjutils.so` 仅 arm64，按固定 JPush 版本与真实 Gradle 依赖报告接受；其余 Release 库对称。Debug 的 Flutter Vulkan 验证层另行注明，不混入正式 ABI 判定。
- 32 位 ECG 库 `0x1000` 与现代 ARM64 16 KB 检查分开，不误判为 ARM64 不兼容；仍需真实 16 KB 环境启动与功能测试。
- r5 当次原生日志核验：不再输出原始注册标识/完整消息/异常，保留的单条 helper 安全日志仅 debuggable 包输出；经 R8 映射核对 Release 的 Debug 标志条件跳转。通知点击仍未完成新包真机复验。
- P40 在 07:25 续测时确认 r5 已覆盖：实际 `base.apk` SHA 与上述 Debug 完全一致，首次安装 `2026-08-30 18:52:53` 不变、最后更新 `2026-09-07 05:58:20`。先前等待机主认证的记录保留为历史，不再当当前安装状态。
- 07:29:40 起 P40 USB 调试变为 unauthorized；本轮未卸载、清数据、绕过密码或发送新推送探针。r6 未安装，不能将 r5 已装写成 r6 已装。
- 用户随后重新连接，P40 一度授权，现装 r5 官方验签与新 r6 同证书；随后 USB 多次掉线，08:39:46 未检出，3 次相关只读失败后停止。未执行安装/启动，未清除已保存手表目标。当前状态以 `QA-20260907-ANDROID-R6-LIVE.md` 为准。
- r5 保留单项权威及新增组合读取账号防御，不修复服务端逐项授权。跨端 HRV 关闭回读后仍显示记录的现场 P1 继续保留；没有该次原始响应，不猜后台分支或把自动化写为撤销通过。

详细历史见 `IMPLEMENTATION-LOG-20260907-ANDROID-CARE-QA.md`；r5 安装续测见 `QA-20260907-ANDROID-R5-RESUME.md`，r6 拒收与重验见 `QA-20260907-ANDROID-R6-ARTIFACTS.md`。

## 签名与推送发布门禁

| 项目 | 事实与边界 |
| --- | --- |
| Android 本轮包 | 最终 r6 Debug/QA Release 官方验签通过，均与已有 QA Debug 证书一致，原生及 Dart 推送配置门禁通过；可作为同签覆盖候选，尚未在 P40 安装，不是正式发行签名。 |
| Android 生产配置 | 当前工作树没有 `android/key.properties`；这仅代表本工程未注入，不能据此认定用户或 CI 不存在正式密钥。正式包需 CI 注入并验证批准证书、版本递增、公开更新资源。 |
| 极光基础配置 | ignored `.env.jpush.local` 中 AppKey 格式有效、channel为 production；可构建启用通用极光通道的 Debug。初轮未注入不等于凭据缺失。 |
| Android 厂商通道 | 上述本地文件未配置厂家列表/各厂商字段，工作树无华为 agconnect-services.json；目前选择 `vendors=none` 仅验通用通道。未核验其他安全存储或 CI，不扩大为“服务商没有凭据”。 |
| Harmony 本轮签名 | r12 两包官方包与 Profile 验签成功；Profile 类型 debug、2 个登记设备，包名 `cc.saidian.app.hm`；开发证书及 Profile 有效期 2026-09-06 10:03:29 至 2027-09-06 10:03:29 中国时间。r12 证书链和 Profile 与 r11 逐字一致，旧 r9–r11 保留；Release 仍不是 AppGallery 发行包。 |
| iOS 发行 | r6 Profile 为开发调试身份，现有签名授权到期 2026-09-13 23:19:57 中国时间；已同签覆盖和独立启动，不等于 TestFlight/App Store。包内没有 `aps-environment`，不能宣称 APNs 已启用；正式团队、推送和商店资源仍需核对。 |

## CI 与发布状态

工作流提交 `d18542d` 已成功推送，此前 GitHub workflow 授权问题已解除。
当前 Actions 仍因账号付款/额度在 0 个步骤执行时失败，不能记为远端测试通过，也不能把该平台阻断归为源码测试失败。

本机 Flutter 双时区 524/524、鸿蒙双时区 423/423 与本机构建结果独立记录；GitHub 预发布附件不等于商店发布或所有上线门禁已解除。

## 鸿蒙 r12 交付定位（r9/r10/r11 原包保留）

安装包保存在 Git 忽略目录 `artifacts/three-platform-20260907/harmony/`，包含 r9/r10/r11/r12 共 8 包、`SHA256SUMS` 与 `README-QA.md`；不纳入源码提交，上传预发布附件由主线程统一执行。

- 最新 r12 Debug SHA-256：`470f12c4b3caac8c9b87c466968c5a127dce924b1ccb5e543dd1096e1e9548ce`。
- 最新 r12 Release SHA-256：`2102b7d3f15b936ef4b0bcb00df333a6c81575dcd81ec69a454f6e5510e20ae8`。
- 历史 r11 Debug / Release SHA-256：`65b723fb667d3bf9a4ca6a137fbcdfcf9dc8e4ac33e5051ee5e606c3e14b7968` / `8efc84021f9671c8159744b270b2e31a6dc8b2b03cb4a152a72c17f9743e7fb1`。
- 历史 r10 Debug / Release SHA-256：`24b2ac94defa8fdc6c909a15f0cb5498ae7b05873431922c4d7b6d1bcbcc7029` / `cab657b4c976460566a794cbc5fcac7bc32adbce5bae0828c7677bbeb7935b4a`。
- 历史 r9 Debug / Release SHA-256：`7721ba2ee9663d16256f494fa2894fee35deefd1397998a622a81fd0af8ce0c2` / `e56b95c0264ce978c12e5423665e98dd57cca4d620f3d1096b77bb9bb76a8989`。
- 包名、版本、API、优化方式从两个 HAP 的 `module.json` 读取；设备数量、有效期与类型从官方已验证 Profile/证书读取，未公开设备 ID 或私钥。
- r12 Debug 33.294 秒、Release 21.913 秒构建成功，UTC/Shanghai 各 423/423；生产源码未变、根签名配置未变。r12 未覆盖安装，手机实际仍是 r11 同源版本，见 `BUILD-20260907-HARMONY-R12.md`。
- 本次 r11 真机只读排查后正常结束既有心率占用，设备入口恢复，表盘实读总数 9、当前 3；未切换表盘或断连，见 `QA-20260907-HARMONY-MEASUREMENT-OCCUPANCY.md`。这不替代新包或全部测量验收。
- 根因与失败历史见 `IMPLEMENTATION-LOG-20260907-HARMONY-COMMAND-DRAIN.md`、`IMPLEMENTATION-LOG-20260907-HARMONY-OFFLINE-SPORT-PROFILE.md` 与 `IMPLEMENTATION-LOG-20260907-HARMONY-CARE-AUTHORITY.md`；本节不代替主线程真机记录。
- r11 的单项权威结果带来明确可用性边界：旧后台 typed 错误即显示不可用，不再由总表补旧值。若单项本身在撤销后继续返回数据，仍需服务端正确执行逐项授权，不能声称客户端已修复服务器。
- r10 真机运动验证仅覆盖断连提示、本机刷新、同步按钮禁用和空态；非空本账号离线运动/详情尚无真机样本。资料仅未更改任何值后提交及回读确认，不是全部字段改写或新头像上传验收。

不真实扣款、不恢复出厂、不 OTA、不清健康记录；不同证书禁止用卸载重装绕过覆盖失败。厂商 SDK、推送通道与商店资源缺口必须保留真实证据。

## iOS 最新 r6 产物

- `artifacts/three-platform-20260907/ios/Saydian-iOS-QA-Profile-0.1.19-build23-r6-development.ipa`。
- SHA-256：`4156a4347b662089f13122d5769a0069c8be9ef5899d31338bb5219463c162c5`，22,905,034 字节；严格签名与 ZIP 完整性通过，r3/r4/r5 原包均保留。
- 版本 `0.1.19(23)`、包名 `cc.saidian.app.dev.v2a92w8qz2`；08:07 同签覆盖、08:09 独立启动，账号与数据未卸载清空。
- 本轮 Profile、Debug、QA Release 均构建通过；新共享 UI 回读真机未完成，原生 RunnerTests 32/32 为先前执行，本轮未重跑。不把未签名 Release 或开发 Profile 称正式版本。
