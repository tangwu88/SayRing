# 赛电 App 开发交接说明

## 2026-09-05 健康档案与付费报告增量

本轮新增“我的 → 健康档案”，对接新服务端健康档案、报告资格、权益、统一支付、报告全文与 PDF 接口；Android 复用现有微信/支付宝桥，iOS 新增 StoreKit 2 购买/恢复和服务端 JWS 验证。完整命令、失败尝试、修复与证据见 [`IMPLEMENTATION-LOG-20260905-HEALTH-REPORTS.md`](IMPLEMENTATION-LOG-20260905-HEALTH-REPORTS.md)。

接手时必须注意：

- 只有服务端支付状态确认成功后才授予权益；Android/iOS 客户端 SDK 返回值都不是最终支付凭据。
- 数据不足不创建支付单；AI 健康分析必须单独同意且可撤回，报告只作健康管理参考。
- 生产服务尚未部署本轮 V2 接口，微信/支付宝、StoreKit 商品、AI 和推送仍需真实配置与沙箱/生产回执。
- 当前 iOS 购买桥要求 iOS 15+；macOS 编译、StoreKit Sandbox、退款通知和购买恢复真机闭环尚未验收。
- Android QA APK 已完成双架构、签名、对齐和自动测试核验，但当前 ADB 无设备，本轮没有覆盖安装或真机支付证据；QA 包仍为 Debug 证书，不能发布生产。
- 服务端还需确认：已有 `AWAITING_PAYMENT` 报告在会员权益到账后重新创建时会消费权益并进入队列。不得只看到权益到账就把报告流程标记完成。

> 本文件是 2026-08-05 的历史基线。包含商城、AI、设备扫描修复和最新 30 项测试结果的
> 当前交接说明请阅读 [`HANDOFF-20260812.md`](HANDOFF-20260812.md)。不要用旧 Git bundle
> 覆盖当前工作树。

## 2026-08-29 最新交接增量

以下内容只追加当前现场结果，不改写下方 2026-08-05 历史基线。接手时先阅读：

- [`IMPLEMENTATION-LOG-20260829-ONLINE-READINESS.md`](IMPLEMENTATION-LOG-20260829-ONLINE-READINESS.md)
- [`REGRESSION-CHECKLIST.md`](REGRESSION-CHECKLIST.md)
- [`BUG-RETROSPECTIVE-20260829.md`](BUG-RETROSPECTIVE-20260829.md)
- [`release/PRODUCTION-RELEASE-BLOCKERS.md`](release/PRODUCTION-RELEASE-BLOCKERS.md)

已取得真机证据：

- MED Android 已扫描并连接 ET488、W9S、W8。
- ET488 在线表盘目录 215 款；W9S 在线目录 161 款且 `dialShape=58`；W8 只读 5 个已安装表盘，无授权在线商城时不显示虚假预览。
- W9S 心电启动/停止有设备 ACK；测试时未佩戴，没有有效波形，因此尚未完成心电全链路验收。
- Android JPush SDK 注册与 TCP 连接成功，控制台包名匹配。该结论仅覆盖客户端传输层，不包含服务端业务推送。
- `jpush_flutter 3.5.1` 已固定到 `third_party/jpush_flutter`，仅移除 Android `setup` 参数日志；最终真机确认连接成功，AppKey 精确值与 Registration ID 形态日志均为 0。设备登记仍为 `server_rejected` 退避重试。
- iPhone 12 Debug 已安装并稳定运行，W9 连接、健康同步和原生电量 `98%` 有真机证据。
- 最终代码在 W8 上读取到电量 `85%`、未充电；该次连接无 GATT 133，捷理敏感对象日志计数为 0。
- 真实远程成员 HRV 页面只显示当前指标且无 `-1` 时间；关于页异常短值回退正常；W8 相机禁用与权限恢复两段真机复测通过。

客户端本轮已修复并复测：

- 远程关爱指标详情不再遍历整行原始字段；按当前指标显示中文标签/单位，血压拆分，HRV 单独显示，无效时间使用记录序号。定向 UI 测试 41/41 通过。
- “关于我们”异常短文本/脏数据使用安全回退。
- W8 相机被系统策略禁用时由黑屏改为明确提示，快门禁用；权限恢复后功能恢复。

当前阻断和未执行：

- 服务端推送设备登记/解绑、未读/已读及关爱 Outbox 未部署；公开更新清单、Android 正式下载地址和 App Store 产品页缺失。
- 极光 Android 集成度仍为 `--`；iOS 没有与 Bundle 匹配的 APNs 证书配置，HarmonyOS 包名和 Server Key/JSON 也未配置；签名 Profile 还缺 APNs entitlement。后续开发证书重新信任阻断了 iOS UI 补充取证。
- iPhone 15 Pro Max 已连接，旧版 `0.1.19 (23)` 启动稳定 30 秒；最终包因 Xcode `No Accounts` 且 Provisioning Profile 不包含该设备而安装失败。第二台 JAD Android 仍被物理 PIN 锁定；两者均不能计入最终代码设备覆盖。
- 生产推送、有效 W9S 心电波形、iOS 最终包 UI、电量/表盘页面与正式更新仍需复测，不得写“正式上线通过”。

接手资料、日志和提交中禁止记录 AppKey、Registration ID、Token、AuthKey、密码或完整健康原始数据。

交接日期：2026-08-05

项目目录：`F:\xcodeplace\国内电商\赛电app`

当前分支：`main`

功能基线提交：`db6b5b4 feat: align app UI with Lanhu designs`

## 1. 一页结论

这是一个独立 Flutter 双端 App，不是“赛电商城”的子模块。Flutter 共享 UI、业务、
健康数据和同步层；Android 使用 Kotlin、iOS 使用 Swift 直接封装 Veepoo/HBandSDK。

当前已经完成：

- 账号登录/注册、本地安全会话和基础设置。
- 蓝湖风格的登录、健康首页、健康指标、设备、远程关爱和个人中心。
- 设备状态机、串行指令队列、扫描/连接/断开、能力识别、历史同步和手动测量桥接。
- 步数、距离、热量、睡眠、心率、血氧、血压、体温统一数据模型。
- SQLCipher 本地存储、离线队列、批量幂等同步框架。
- Android Veepoo SDK 真实编译、release APK/AAB 构建和 12 项自动化测试。
- iOS Veepoo Framework、Podfile、Xcode 链接配置和原生桥源码。

当前没有完成：

- 目标量产手表的 Android/iOS 真机闭环验收。
- macOS/Xcode iOS Archive、签名和 TestFlight。
- Android 正式发布签名。
- 后台缺失接口、正式隐私政策/用户协议、推送和商店账号配置。
- Git 远程仓库；目前只有本地 Git 和随交接包提供的 Git bundle。

## 2. 交付物

| 内容 | 位置 | 说明 |
| --- | --- | --- |
| 完整源码 | `F:\xcodeplace\国内电商\赛电app` | 独立 Git 仓库 |
| Git 离线包 | `F:\xcodeplace\国内电商\赛电app-交接-20260805-final\赛电app.bundle` | 可恢复完整 Git 历史和 SDK 二进制 |
| Android APK | `F:\xcodeplace\国内电商\赛电app-交接-20260805-final\app-release.apk` | 内测安装包，当前为调试签名 |
| Android AAB | `F:\xcodeplace\国内电商\赛电app-交接-20260805-final\app-release.aab` | 内测构建，正式上架前必须换签名 |
| 本交接文档 | `docs/HANDOFF.md` | 以 Git 中版本为准 |
| 验证记录 | `docs/verification.md` | 测试、构建、哈希和未闭环项 |
| SDK 接入说明 | `docs/veepoo-integration.md` | 版本、调用顺序和平台边界 |
| 后台缺口 | `docs/api-gap.md` | 需要服务端补齐的接口契约 |

Git bundle 恢复示例：

```powershell
git clone 'F:\xcodeplace\国内电商\赛电app-交接-20260805-final\赛电app.bundle' 'D:\work\赛电app'
Set-Location 'D:\work\赛电app'
git checkout main
git log --oneline
```

## 3. 关键参考来源

- 蓝湖 UI：<https://lanhuapp.com/web/#/item/project/stage?tid=a1412e93-84fd-48c2-a8e6-c352deb5e3e2&pid=deb502cc-27cf-4667-a3c2-24b54882198b>
- HBandSDK：<https://github.com/HBandSDK>
- 小程序源码（本机参考文件，不进入 Git）：
  `F:\xcodeplace\国内电商\赛电app\Saidian小程序源码.zip`
- API/原型资料（本机参考文件，不进入 Git）：`相关信息.txt`、`veepooSDK接入文档.pdf`

蓝湖项目包含 127 个画板。当前已按原型和小程序补齐首页、健康、AI、设备、我的五栏导航，
并落地运动入口/记录、AI 健康与运动管家、健康百科、订单、目标、个人资料、地址和权限管理。
商城完整交易、表盘、OTA 等仍为后续范围。UI 主色为黑白，健康状态使用绿色，页面采用
浅色渐变、圆角卡片和胶囊按钮。

## 4. 工程结构

```text
lib/
  app.dart                         App 启动与登录/主页路由
  domain/
    device_state_machine.dart      BLE 状态机与串行指令队列
    models.dart                    设备、能力、健康记录和同步类型
  services/
    api_client.dart                现有赛电 API 适配
    app_controller.dart            UI/设备/同步主状态控制器
    local_health_store.dart        SQLCipher 健康数据与游标
    secure_vault.dart              系统安全存储
    sync_service.dart              离线、去重和批量补传
    wearable_bridge.dart           Flutter Method/Event Channel 契约
  ui/
    app_theme.dart                 蓝湖风格主题、色板和渐变
    pages.dart                     五栏页面、业务子页面与通用组件

android/app/src/main/kotlin/.../MainActivity.kt
                                    Veepoo Android 直接适配
android/app/libs/                   已锁定授权 AAR
ios/Runner/AppDelegate.swift        Veepoo iOS 直接适配
ios/Runner/Vendor/                  已锁定授权 Framework
ios/Podfile                         FMDB/MJExtension 等 iOS 依赖
test/                               状态机、API、同步、登录和 UI 布局测试
```

## 5. Veepoo 接入基线

锁定版本：

- Android 官方提交：`773759d71d0c9d8003d7267c0e319d3167862410`
- Android 核心：`vpprotocol-2.3.77.15.aar`、`vpbluetooth-1.20.aar`
- iOS 官方提交：`2e25bde67031d7d89e3c6d8d9f9dc76204d9fabe`
- iOS SDK：`2.2.96.15`
- 小程序 SDK 提交：`f24c35d020e989d6fa147dbbd6f2d81bbf6ded20`
- 小程序 SDK：`1.1.19`

设备主流程必须保持：

```text
disconnected → scanning → connecting → authenticating → syncing → ready
                                                               ↓
                                                          measuring/error
```

Android 调用顺序必须保持：

```text
init(applicationContext)
→ startScanDevice
→ connectDevice
→ Notify 成功
→ confirmDevicePwd
→ syncPersonInfo
→ 历史同步或手动测量
```

不要并发调用多个耗时 SDK 指令。Flutter 和原生层已经有串行约束，接手人扩展功能时必须
继续进入同一队列。不要在没有目标型号真机证据时启用 ECG、HRV、身体/血液成分。

## 6. API 与运行配置

复制配置示例：

```powershell
Copy-Item config\dev.json.example config\dev.json
```

默认 API 地址：

```json
{
  "SAYDIAN_API_BASE_URL": "https://app.saidian.cc"
}
```

运行时使用：

```powershell
flutter run --dart-define-from-file=config/dev.json
```

已经接入并有客户端实现的关爱接口：

- `GET /api/v1/member/care`
- `POST /api/v1/member/care`
- POST 使用 Bearer 鉴权和 `multipart/form-data`，字段名为 `mobile`。

后台批量健康同步、刷新 Token、绑定/解绑、注销、推送注册等仍需服务端提供完整契约。
客户端对未接通能力显示“未配置”，不要伪造成功数据。

## 7. Windows/Android 开发与验证

本机 Flutter：`F:\Codex\home\tools\flutter\bin\flutter.bat`

中文路径下 Analyzer 曾出现路径解析问题。本机已使用英文 Junction：
`D:\Temp\User\saidian-app-verify`。如果不存在，可重新创建：

```powershell
New-Item -ItemType Junction `
  -Path 'D:\Temp\User\saidian-app-verify' `
  -Target 'F:\xcodeplace\国内电商\赛电app'
```

验证命令：

```powershell
Set-Location 'D:\Temp\User\saidian-app-verify'
$flutter = 'F:\Codex\home\tools\flutter\bin\flutter.bat'
& $flutter pub get
& $flutter analyze --no-pub
& $flutter test
& $flutter build apk --release
& $flutter build appbundle --release
```

2026-08-05 验证结果：

- `flutter analyze --no-pub`：通过。
- `flutter test`：12/12 通过。
- 390 × 844 手机视口的五个核心 Tab：无布局溢出。
- release APK：67.15 MB，构建通过。
- release AAB：57.54 MB，构建通过。
- APK SHA-256：`C382975530E7897B457AE9B8AF6731E534CA7FEC2B46BD10AB4906EADFDFADD3`
- AAB SHA-256：`D18151A2373B02CFF520D60C119431D8421DE54CEA6F0D34312F5DF2D837915E`

当前 release 暂时使用 debug key，只适合内部安装。正式签名必须通过安全环境配置，禁止将
keystore、密码或服务凭据提交 Git。

## 8. iOS 接手步骤

当前 Windows 机器不能做 iOS 验收。将仓库放到安装了当前 Xcode 的 Mac 后执行：

```bash
flutter pub get
cd ios
pod install
open Runner.xcworkspace
```

接着完成：

1. 配置 Apple Team、Bundle Identifier 和内测签名。
2. 先确认所有 Vendor Framework 的链接与 Embed & Sign 状态。
3. 用目标量产手表验证扫描、连接、密码认证、个人信息同步、历史同步和四种手动测量。
4. 验证 iOS 13、16 和当前最新系统的权限拒绝、蓝牙关闭、后台恢复和断线重连。
5. Archive 成功后再进入 TestFlight；没有签名账号时只记录“未配置”。

## 9. 下一位同事优先级

### P0：目标手表闭环

1. 确认主销手表准确型号、芯片和固件版本。
2. Android/iOS 各至少一台手机、两块样机。
3. 对每个启用指标完成“手表产生 → App 展示 → 本地保存 → 后台上传 → 历史查询”。
4. 连续断开重连 10 次；离线累积 1,000 条后恢复网络，检查重复与漏传。

### P0：iOS 构建

1. Mac 执行 `pod install` 和 Xcode 编译。
2. 修复仅在 Xcode/真机暴露的 Swift selector、Framework 架构或签名问题。
3. 完成 Archive，并保存构建日志和安装证据。

### P1：后台契约

1. 获取后台源码仓库和测试环境。
2. 补齐 Token 刷新、退出、注销、设备绑定/解绑、批量健康同步和关爱授权。
3. 验证 400/401/403/409/422/429/500、分页和幂等键。

### P1：正式内测材料

1. 替换用户协议、隐私政策。
2. 配置 Android/iOS 正式内测签名。
3. 配置推送、Apple Developer 和商店账号。

### P2：后续功能

核心链路稳定后再排商城完整交易、表盘、OTA、联系人、相机遥控和消息通知；AI 管家已接入
小程序现有接口，仍需用正式账号完成内容安全、限流和长对话验收。

## 10. Git 历史与接手规则

当前关键提交：

```text
db6b5b4 feat: align app UI with Lanhu designs
f9c2378 feat: integrate Veepoo wearable SDKs
839ada0 feat: initialize Saydian Flutter app
```

仓库目前没有 remote。配置远程前先确认公司仓库归属、可见性和 SDK 二进制授权范围；这是
合作方 SDK，不能直接推到公开仓库。

`.gitignore` 会忽略本地参考资料、构建产物、配置和签名文件。AAR/Framework 虽然符合
忽略规则，但已经作为授权依赖在现有提交中跟踪；不要执行会意外删除已跟踪 Vendor 文件的
清理命令。

## 11. 交接验收清单

下一位同事接手当天确认以下项目：

- [ ] 可从 Git bundle 克隆并看到上述提交。
- [ ] `git status` 干净。
- [ ] `flutter pub get` 成功。
- [ ] Analyzer 和 12 项测试通过。
- [ ] Android release APK 能构建并安装。
- [ ] 能访问蓝湖、小程序源码和测试 API 环境。
- [ ] 已拿到目标型号、固件、样机和 Mac。
- [ ] 已确认远程仓库及 SDK 私有权限。

如任一账号、样机、签名或服务端能力没有实际拿到，继续标记“未配置”，不要用 Demo、假数据
或仅有 UI 的状态代替完成验收。

## 12. 2026-09-29 QRing 多 SDK 路由补充

- Android 已加入 `qring_sdk_1.0.0.76.aar`，iOS 已加入静态 `QCBandSDK.framework`。
- 广播名称规范化后 `Q_`、`O_` 及 `R22_` 后恰好四位十六进制字符进入 QRing；`R22_C493` 已由 QRing App 现场发现，并在 Say Ring 通过 QRing SDK 真机扫描与握手。`YC` 仍走 Yucheng，`V`/`TK` 仍走 Veepoo，`HR01` 仍走 CoolWear，`D` 仅在 Moyoung 桥存在时启用。其他未知名称不得猜测。
- Flutter 扫描结果使用 `qring:<native-id>` 隔离；用户选中后所有健康、运动与设备操作锁定到 QRing Bridge。
- 连接成功不等于能力成功。QRing 必须完成 SDK 初始化、校时和能力读取，失败时保持不可用；健康未知值不得补零。
- Android 的 Realtek bbpro 以 QRing 内置 1.9.4 为准；根 Gradle 只从宇辰插件的通配 JAR 中排除了未被其源码/AAR引用的旧 1.6.1，并保留 `Msc.jar`。改动此策略前必须同时回归 QRing 与宇辰设备。
- Windows 已通过双 APK、双时区 Flutter 885 项、Android 原生 26 项和 iOS arm64 静态库结构检查；Mac/Xcode 编译和真实 QRing 全链路仍未验收。详细证据见 `docs/SAY-RING-QRING-MULTI-SDK-20260929.md`。
- 后续 R22 扫描修复已在 Android 真机确认扫描、配对、能力握手、电量读取，以及配对后停止广播时的同一已保存设备恢复；回查必须同时核对当前环境保存的精确 ID、系统蓝牙配对和 QRing 名称，再走 SDK 握手。iOS 与健康/运动全链路仍待验证，详见 `docs/SAY-RING-R22-SCAN-20260929.md`。上一条 26 项与仅 Q_/O_ 为首次接入时的历史状态。
