# 2026-09-06 三端兼容与桌面图标整改

## 修改前依据

- 基线 `c5a28e6`；当前分支 `codex/harmony-native-login-home`。已读取 AGENTS、长期修改索引、最近设备记录、复盘和回归清单；仓库专属认证 fetch 后分歧 `0/0`。
- 预期：维持 Android 8/iOS 13 安装下限，将鸿蒙兼容目标改为官方依赖支持的 API 12，并保留高版本能力门禁。完整低版本运行验证由主线程统筹，声明不等于验收通过。
- 图标：iOS master 与所有既有红色源图的原始 RGB 主色均为 `#C30D23`。iOS 为白底圆标，鸿蒙/Android 原来为红底人物，差异来自构图。原母版保持只读，按 iOS 几何机械生成派生资源。

## 已定位问题与影响

| 级别 | 复现与实际结果 | 预期及影响范围 |
| --- | --- | --- |
| P1 | 最终 Android APK 声明必需 `android.bluetooth.le`；P40 只报告标准 `android.hardware.bluetooth_le` | 移除错误特性并在发行最终 manifest 门禁拒绝回归，避免应用市场按错误特性过滤型号 |
| P1 | 鸿蒙配置最低 API 23，Veepoo/JL、极光、微信 HAR 实际均声明最低 API 12 | 下调兼容目标前补齐数据库、通知设置与支付高 API 调用兼容；数据库由并行批次处理 |
| P1 | 通知设置直接调用 API 13 方法，API 12 不具备该方法 | 版本门禁及系统应用设置回退，不能因设置入口异常使页面崩溃 |
| P1 | 支付只使用 API 20 ThirdPay，所有较旧鸿蒙系统都在入口被拒绝 | 微信完整服务端签名可走官方 PayReq；支付宝保持 ThirdPay 能力门禁；缺少签名不得客户端造签 |
| P2 | 三端桌面图标构图不一致 | 保留 iOS 图形、使用同一红色，按平台遮罩和安全区导出 |

## 验证与失败记录

- 只读原始 PNG 颜色检查首次通过 AppKit deviceRGB 得到颜色管理转换值 `#D0242E`；改读原始像素确认 `#C30D23`，没有将转换值写入资源。
- 调研系统设置旧版入口时官方文档抓取出现 404；兼容回退必须捕获系统无法解析设置入口的异常，并提供简短手动设置提示。
- 本批次不安装、卸载、不改变三台手机与手表状态；不执行真实支付。构建、签名、无损覆盖与真机矩阵由主线程统一记录。

## 已实施（2026-09-07）

- Android Manifest 用合并删除标记移除 `android.bluetooth.le`；发行检查直接拒绝最终包含该错误特性，保留标准 BLE 必需特性。
- 鸿蒙最低声明改为 `5.0.0(12)`，target 不变。通知设置 API 13 调用有版本门禁，旧系统进入系统应用详情；失败只显示手动设置提示。
- 微信支付新增显式 Harmony 签名解析、官方 `PayReq`、单请求锁、事务/预支付 ID 匹配、取消及超时。发起 SDK 成功不等于付款成功，页面仍读取服务端订单状态。
- `PaymentKit` 隔离到懒加载服务；完整微信签名在 API 12 可进入官方微信 SDK，支付宝及仅有 ThirdPay 数据的响应继续按实际系统能力开放。
- 微信登录共用的回调接收器按响应类型分流，不把支付回调误当授权登录。没有修改原有服务端平台字段，也没有生成签名或使用 Android/iOS 响应冒充鸿蒙参数。
- 新增 `scripts/generate_launcher_icons.swift`：以只读 iOS 1024 母版机械导出 21 个 Android/Harmony 桌面资源。Android 按密度、安全区及 themed icon 分开导出；Harmony 与 iOS 母版逐字节相同。

## 定向验证结果

| 检查 | 实际结果 | 边界 |
| --- | --- | --- |
| `python3 -m unittest discover -s scripts/release -p test_release_gate.py` | 20 项通过，包括最终 manifest 错误特性拒绝回归 | 尚待主线程最终 APK 实物检查 |
| `node --test harmony-native/tests/wechat-payment.test.mjs` | 7 项通过；UTC、Asia/Shanghai 分别重跑各 7 项通过 | 模拟 SDK/系统回调验证，不代表真实支付成功 |
| layout-contract 中支付状态、桌面标识定向检查 | 2 项通过 | 完整页面检查由页面批次及主线程统筹 |
| `swift scripts/generate_launcher_icons.swift` | 生成 21 项成功 | 仅机械派生，未改变母版 |
| 同脚本 `--check` | 21 项逐字节一致 | 重复执行未产生差异 |
| 派生图目视与原始像素核对 | 圆标/人物几何与 iOS 一致；Android/Harmony 非白主色均为 `C30D23` | 真机桌面遮罩尚待覆盖安装验收 |
| `git diff --check` | 通过 | 不代替编译及全量测试 |

母版 SHA256：`547674e3020fb3833f9fd9250ae5d6fb3b28ded7f776de6fc47cab73b23ce273`，生成前后不变。

## 保留的失败与修复轨迹

- 第一次用同一 patch 删除并新增支付路由文件被拒绝，没有落入半成品；改用原文件 Update patch 成功。
- 新服务首次 Node 定向检查因 `WechatSignedPayment` 作为运行时导入失败；改为 `import type` 后通过。页面契约中的 `import.metaurl` 拼写在运行前纠正。
- 旧版设置入口检索先遇到文档 404/GitHub API 403，且初稿 `ohos.settings.app.info` 无官方依据。随后查到 [OpenHarmony 官方权限申请指南](https://gitee.com/openharmony/docs/blob/3b5665a92234a177016080174066e457dc9d30c6/en/application-dev/security/accesstoken-guidelines.md)，按其 `action.settings.app.info` 修正，并新增真实服务调用的低 API/fallback 失败测试。
- 定向 Node 测试仅出现 Node 内置 TypeScript stripping 实验性提示，无运行失败；没有为消除提示改动生产配置。

## 待主线程验收与外部依赖

- Index 支付入口已由页面协作任务接入 `canStartHarmonyPayment(provider)`，保留原有订单刷新与错误处理；3 项支付/图标页面契约复验通过。
- API 12 的安装、冷启动、通知设置、微信 SDK 唤起必须在对应系统验证；当前已有 nova 14 高版本真机不能替代低版本覆盖。不能仅凭最低声明写为鸿蒙 5 全功能通过。
- Android/iOS 构建、三机覆盖安装和 Launcher 遮罩由主线程统筹；鸿蒙构建在本批后续接管并完成，见下方整合验证。
- 微信真实验收仍依赖服务端 `platform=harmony` 返回显式 `third_app_id` 与 `pay_info` 的 appId/partnerId/prepayId/nonceStr/timeStamp/packageValue/sign；客户端不造签、不扣款。支付宝低于 ThirdPay 支持版本明确不可用，不伪造 H5 降级。
- 图标母版及用户原始 Logo 不改动；未提交、未推送，由主线程合并验证后统一处理。

## 低 API 认证安全补查

- 签名构建准备时从旧 README 发现原最低 API 23 还有安全原因：`SaydianApi.ets` 普通请求和图片上传使用 `NetworkKit.maxRedirects: 0`，该字段实际自 API 23 提供。不能在旧系统忽略该字段继续发送凭据。
- 查阅本机官方 SDK `@hms.collaboration.rcp.d.ts`：`TransferConfiguration.autoRedirect` 自 API 11 支持，`Request.destination` 流式回调自 API 12 支持。新增 `LegacySafeHttp.ets`，只在低于 API 23 时调用。
- 旧系统通道在请求发送前设置 `autoRedirect: false`，固定服务端 HTTPS origin，流式累积上限 2 MB，超限取消，3xx 明确拒绝，结束始终关闭 Session；高系统原有请求路径不变。
- 新增 4 项低 API HTTP 测试；连同微信/通知 7 项，UTC、Asia/Shanghai 各 11 项通过。重定向不携带凭据访问下一地址；没有加入放宽证书校验、HTTP 降级或客户端签名。

## 鸿蒙整合编译与签名验证

主线程在本批中途将鸿蒙 Debug/Release 编译交由本任务执行，仍禁止安装、操作手机或更换签名密钥。

| 顺序 | 操作与结果 | 修复/结论 |
| --- | --- | --- |
| 1 | 构建命令误在中文仓库根目录启动，Hvigor 找不到配置，未进入编译 | 切至英文暂存工程，不修改仓库结构 |
| 2 | 首次 Debug CompileArkTS 失败 | 两处数据库 `throw error` 由关爱任务加 Error 类型；低 API helper 同样修正；微信回调 reject 改明确 ApiError 类型，pending 清理独立方法避免闭包收窄为 never |
| 3 | 重编 ArkTS 与 PackageHap 通过，但旧 DevEco 暂存 SignHap 报 keystore password incorrect | 未试探密码/重建密钥；保留失败，改用主线程指定的前次成功暂存 `/tmp/saydian_harmony_build_20260906_0952`，该目录原有赛电签名不变 |
| 4 | 成功暂存 Debug 完整构建：33 项任务完成，31.4 秒 | 同步完整 entry/src 与 AppScope，不复制原始私钥或签名配置到 Git |
| 5 | 同工程串行 Release 完整构建：33 项任务完成，29.2 秒 | Release 编译不等于正式发布签名，当前仍为已有 development Profile |
| 6 | Debug、Release 官方 `verify-app` 通过；Debug `verify-profile` 通过 | 代码签名、完整性、权限签名全部通过；无真机安装声明 |
| 7 | 鸿蒙全量 Node 契约/服务测试 | UTC 259 项、Asia/Shanghai 259 项通过；无失败、无跳过 |

保留工具调用失败：`hvigor tasks --all` 不支持 `--all`，去掉后成功；签名工具 `verify-app -help` 不支持该参数，使用全局 `-h` 后按正式参数执行校验。没有用失败参数尝试签名写入。

编译保留警告：厂商 HAR 资源同名/缺少 source map、若干既有 may-throw、UI `show` deprecated；ThirdPay API 20 使用提示仍存在，但所在模块仅在 capability 门禁后动态加载。没有为压掉警告引入 API 26 的 `apiAvailable` 到旧系统。

### 可交主线程安装验证的产物

临时目录 `/tmp/saydian-harmony-compat.rD3qsb` 权限由 mktemp 限定，保存 Debug/Release unsigned 及 development-signed HAP。不是商店发行包。

| 文件 | SHA256 |
| --- | --- |
| `Debug-signed.hap` | `181213f5cf3f66abb5a96f7b7714e531a5cf4b5b4c663e1c9e5b1488821c0681` |
| `Release-development-signed.hap` | `7713e69cbea58d6917c2bc9238fc09e2eb4960f07fe9cde6621d15acea94074f` |

包内 `cc.saidian.app.hm`、versionCode 7、minAPIVersion 50000012。Debug Profile 与原成功暂存配置文件逐字节一致，类型 debug，APL normal，2 个已登记 UDID，有效至 2027-09-06 10:03:29（中国时区）。本任务未读取当前手机 UDID，安装许可仍由主线程现场核对。

开发 app-identifier 为 `6918741466092469448`，和旧 README 中正式 AGC ID 不同，不能据当前开发签名宣称正式推送身份通过。证书公开 SHA256：`B8:3E:67:55:0F:43:77:81:AF:8D:BD:E2:99:47:5C:CB:D3:59:17:49:10:B1:C6:2D:D3:11:F3:DE:A9:20:C7:B9`。

## Android 16 KB 只读基线检查

- 检查的旧包：`build/app/outputs/flutter-apk/app-release.apk`，SHA256 `2595737768173845d15dec0a33a1fe8fae153bf28bb20085261630540357f638`，不代表本轮新构建。
- Android build-tools 36.0.0 `zipalign -c -P 16 -v 4` 通过。全部 16 个 ARM64 `.so` 的 ELF LOAD 对齐至少 `0x4000`，文件偏移与虚拟地址按 16 KB 同余；包括 ECG、JL、极光、SQLCipher、Flutter 等，未发现这份基线包的闭源 ARM64 对齐阻断。
- 32 位 `libEcgAnaly.so` 仍是 `0x1000`，与现代 ARM64 16 KB 检查分开记录，不能混称 ARM64 不兼容。其他 32 位库对齐均至少 `0x4000`。
- 该旧包 `armeabi-v7a` 目录缺少 Flutter `libapp.so`、`libflutter.so`，仅有厂商依赖，不能据目录存在宣称 32 位运行支持。主线程最终双架构包应重查实际引擎及 App 库、完整 ABI 门禁、zip/ELF，并补低版本启动；本批不改闭源二进制。
