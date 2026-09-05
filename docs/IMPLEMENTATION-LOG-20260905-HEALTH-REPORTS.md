# 2026-09-05 健康档案、付费报告与 StoreKit 接入记录

## 修改前基线

- 分支：`main`。
- 修改前本地与 `origin/main`：`b671e7f170d2f1aa97642342db3f3b7eaf6224b2`，工作树干净，`git rev-list --left-right --count HEAD...origin/main` 为 `0 0`。
- 已阅读 `AGENTS.md`、`docs/CHANGE-TEST-LOG.md`、最近服务端联调记录、`docs/BUG-RETROSPECTIVE-20260829.md` 和 `docs/REGRESSION-CHECKLIST.md`。
- 对接服务端整合提交：`saydianapp-server` 的 `59aeffba06d8d5b230b3a63265232411a6a94936`；该提交本地 77 项测试和全部构建通过，但 GitHub CI `33955725515` 因账户 Actions 账单/额度限制在 Runner 启动前停止，没有数据库/镜像证据，生产尚未部署。

## 本轮目标、文件与影响范围

- 原因：服务端已增加健康档案、报告资格、报告历史、权益、统一支付及 Apple 交易验签接口，Flutter 尚无入口和调用实现。
- 预计范围：健康报告领域模型、`SaydianApiClient` V2 调用、App 控制器、健康档案/报告页面、iOS StoreKit 2 MethodChannel、报告 PDF 分享、对应 Dart/Widget/Swift 边界测试及交接文档。
- 预期：用户从“我的”进入健康档案；数据不足不展示付款动作；AI 分析先单独同意；只有服务端确认支付后才解锁；iOS 交易携带 PaymentIntent UUID 并把 Apple JWS 交给服务端验证；Android 使用现有微信/支付宝桥；报告可查看、失败可重试、准备完成可导出分享。
- 不影响：不修改 BLE、设备能力、健康采集/去重、本地账号隔离、预警规则或商城实体订单支付流程。
- 边界：生产服务尚未部署这些 V2 接口，微信/支付宝/StoreKit 商品和证书也未完成真实配置；客户端必须显示普通用户提示，不能模拟付款或报告成功。

## 修改前检查与资料核对

- `git status --short --branch`、`git fetch origin --prune`、HEAD 对照：通过。
- `rg --files -g AGENTS.md`：确认仅仓库根指令适用。
- 对照服务端 `HealthReportsController`、`BillingController`、共享 contracts 和支付授予逻辑：确认报告创建、单独同意、资格、权益、方案、支付状态、Apple JWS 验证与 PDF 导出契约。
- 核对 Apple 官方 StoreKit 文档：交易由 `VerificationResult` 返回 JWS；`appAccountToken` 可绑定服务端 UUID；内容交付/服务端确认后再 `finish()`；恢复购买只能由用户主动触发 `AppStore.sync()`。
- 核对 `share_plus 13.3.0` 官方包要求：当前 Flutter、Dart、AGP 9.0.1、Gradle 9.1、iOS 13 基线满足其最低要求。

## 失败与修正记录

1. 初次用 `rg` 同时传入 Windows 下的 `android/settings.gradle*` 通配路径，Windows 文件名解析报错；该命令只读且未改文件。改为显式读取 `android/settings.gradle.kts` 与 `android/build.gradle.kts`，确认 AGP/Kotlin/Gradle 版本。
2. 初次在 PowerShell 组合搜索支付实现时，引号被 shell 误解析，`type:` 被当成命令；该命令只读且未改文件。后续改为逐个显式读取支付桥、控制器和测试文件。
3. 在中文路径直接执行 `flutter analyze --no-pub` 时，Analysis Server 返回截断 JSON，Flutter 报 `FormatException: Unexpected end of input`；没有发现 Dart 分析错误。复用英文 Junction `D:\Temp\User\saidian-app-verify` 后重新执行，静态检查零问题。
4. 第一轮定向测试有三类测试夹具问题：HTTP 中文 JSON 未声明 UTF-8、Widget 对持续进度动画使用 `pumpAndSettle` 超时、报告按钮位于可滚动区域外。分别补充 UTF-8 响应头、改用有界 `pump`、先 `ensureVisible` 后点击；定向套件随后 61/61 通过。
5. 页面流程复查发现真实业务问题：创建报告的 `_run` 忙碌锁尚未释放时直接进入购买 `_run`，购买流程会被静默跳过。将“创建报告”和“选择/发起购买”拆成两个串行阶段，并增加从生成按钮点击到支付桥的回归测试；该测试已通过。
6. 完整 Flutter 测试两次出现 `File modified during build. Build must be rerun.`，Flutter 自动重跑后全部通过；该现象与项目既有记录一致，没有删除缓存或改业务代码掩盖问题。
7. 在英文 Junction 中执行 Android 原生单元测试时，Gradle Worker 将路径还原到含中文的真实目录，测试类编译成功但运行阶段 `ClassNotFoundException`。创建纯英文物理副本 `D:\Temp\User\saidian-native-health-20260905-01`，覆盖本轮相同源码后原命令通过 12/12；确认是 Windows/Junction 测试路径问题，不是原生代码失败。
8. Windows 直接执行发布 Python 测试时，19 项中 13 项通过，6 项 POSIX 专用用例无法启动：5 项固定调用 `/bin/sh`，1 项原子发布脚本依赖 POSIX 路径语义。补充 Git Bash 到 PATH 后仍受 `/bin/sh`/Windows 路径边界限制；本机没有 WSL 发行版。本轮不修改发布脚本，也不将这 6 项记为业务通过，留给 Linux/macOS CI 复验。
9. 最终 `dart format --output=none --set-exit-if-changed` 发现 `test/api_client_test.dart` 尚有一处纯排版差异。执行标准 `dart format` 修正后再次检查 11 个本轮 Dart 文件，结果 `0 changed`；随后 Analyzer 与 61 项定向测试继续通过。
10. 提交前用户文案扫描发现支付等待卡片写有“服务端”、既有头像上传降级文案写有“接口未配置”。两处均改为用户可理解的结果说明，不展示实现名词；再次执行格式、静态检查和定向回归。
11. 扩展用户可见文案扫描后，心电空态、预警、关爱邀请、退出/注销降级、iOS 表盘防御路径和跨厂商连接异常中仍残留“服务端、接口、SDK、Yuc/云创”等实现词。全部改为结果导向提示；不支持手机操作的表盘防御路径统一提示“请在手表上操作”，并同步更新对应回归断言。
12. 扫描页、已连接设备卡片和设备详情仍通过 `DeviceSdkBadge` 显示 `Vep/Yuc 设备服务`。移除三个正式界面厂商路由标签，设备详情改为“连接状态”；底层 `WearableSdkSource` 仅保留给路由与诊断日志，并新增 UI 断言保证 `Vep/Yuc` 不再显示。
13. 清理技术文案后的第一次 UTC 全量回归为 393 通过、1 失败：`ui_shell_test` 仍断言旧的“未返回带校准信息”文案。更新为新提示“暂未获取可用的心电波形”，并增加“服务端”不出现的反向断言；随后重跑该用例与全量测试。

## 修改与验证结果

### 领域模型、接口与控制器

- 新增 `lib/domain/health_report_models.dart`：健康档案、数据完整度、报告资格、报告状态、价格方案、权益、支付意图及购买流程类型；未知值保持空值/“未获取”，不转成健康数值 `0`。
- `SaydianApiClient` 实现健康档案、分析授权、资格、报告列表/创建/重试/全文/PDF、价格方案、权益、统一支付状态和 Apple JWS 验签接口；报告/支付 ID 先做白名单校验，PDF 同时校验成功状态、MIME 和非空内容。
- `AppController` 统一 Android 微信/支付宝及 iOS StoreKit 购买编排。客户端支付 SDK 返回值只用于引导，权益仅以服务端支付状态 `succeeded` 为准；Apple 交易仅在服务端确认后 `finish()`。
- 单次报告和 30 天会员均由服务端方案决定金额、次数和有效期，客户端没有硬编码价格或伪造权益。

### 页面与用户流程

- “我的 → 我的服务”新增“健康档案”入口。
- 新页面展示有效记录、自然日、指标、设备、预警、权益、资格和历史报告；数据不足时说明缺项且不显示付款动作。
- AI 分析采用默认未选择的单独同意，可查看说明、授权和撤回；报告明确标识“AI生成的健康管理参考”，保留非诊疗和不适及时就医提示。
- 报告支持状态刷新、生成失败重试、服务端确认后的全文查看和 PDF 系统分享；已退款权益显示撤销状态。
- Android 可选择微信/支付宝；支付完成返回后显示“等待服务端确认”并提供刷新，不根据客户端回调直接显示购买成功。iOS 提供明确的“恢复购买”。

### iOS StoreKit

- `ios/Runner/AppDelegate.swift` 新增 `cc.saidian/storekit` 通道，使用 StoreKit 2 查询商品、购买、显式恢复、JWS 传递及按交易 ID 完成交易。
- `appAccountToken` 必须是服务端 `PaymentIntent.id` 对应 UUID；客户端校验返回交易仍属于当前意图，避免串单。
- 当前实现要求 iOS 15+；iOS 13/14 可继续使用 App 其他功能，但数字报告购买显示暂不可用。Windows 本机不能编译 Swift，也没有 Apple 签名/沙箱商品回执，本轮只完成源码和 Dart 通道测试，必须在 macOS CI 与 iPhone StoreKit Sandbox 继续验收。

### 自动测试与构建

- `flutter pub get`：通过，锁定 `share_plus 13.3.0`。
- Dart 格式化：通过。
- 健康报告模型、API、支付控制器、StoreKit 通道和 Widget 定向测试：61/61 通过。
- `flutter analyze --no-pub`：通过，`No issues found`。
- 完整 Flutter 测试：`TZ=UTC` 394/394；`TZ=Asia/Shanghai` 394/394。
- Android 原生 `:app:testDebugUnitTest --rerun-tasks`：纯英文物理副本 12/12，通过，0 failure、0 error、0 skipped。
- Android Debug 双架构构建：通过。
- Android 显式 QA Release 双架构构建：全部文案和厂商标签清理后最终重建通过；产物 `build/app/outputs/flutter-apk/app-release.apk`，64,691,392 bytes，SHA-256 `CA3F75B6BE8FB26CA713011CCD3016E3D6DB2D95BF9DB2179B9ED63A0B3F72A1`。
- APK 核验：包名 `cc.saidian.app`、版本 `0.1.19 (23)`、名称 `Saydian赛电`、minSdk 26、targetSdk 36；`armeabi-v7a`/`arm64-v8a` 均包含 `libapp.so` 和 `libflutter.so`；`apksigner` v2 验证与 `zipalign` 验证通过。
- 该 QA APK 使用 `CN=Android Debug` 证书，仅供内部验证，不能作为生产发布包。
- 发布 Python 测试：Windows 可执行断言 13/13 通过；6 项 POSIX 专用测试受当前主机限制未执行成功，需 Linux/macOS CI 复验。
- 技术文案清理相关设备、表盘、核心 UI 与 QA 流程定向测试：105/105 通过；修正旧文案断言后，UTC 与 Asia/Shanghai 全量 Flutter 测试再次各 394/394 通过。

### 现场与外部依赖边界

- `adb devices -l` 当前为空，本轮没有真机安装、冷启动、支付 App 跳转或覆盖安装证据。
- 生产 `app.saidian.cc` 尚未部署本轮服务端 V2 接口；页面在服务不可用时只显示普通用户提示。
- 微信支付、支付宝支付、Apple IAP 商品、AI 供应商和推送凭据没有本轮真实回执，继续标记“未配置/未验收”。
- 服务端创建报告的待支付复用路径仍需本轮配套修复：会员权益到账后应重新消费权益并入队，不能长期停留在 `AWAITING_PAYMENT`。完成后在服务端独立日志和提交中记录。

## 提交前后检查

- 修改中再次执行 `git fetch origin --prune`，`HEAD...origin/main` 为 `0 0`，远端仍是基线 `b671e7f170d2f1aa97642342db3f3b7eaf6224b2`。
- 提交前仅暂存本日志列出的源码、测试、依赖锁和交接文档；排除 `build/`、英文验证副本及临时测试产物。
- 最终提交号、推送结果和 CI 状态在提交后追加；Actions 若仍在 Runner 启动前被账户账单/额度限制阻断，只记录平台阻断，不写成代码失败或测试通过。
