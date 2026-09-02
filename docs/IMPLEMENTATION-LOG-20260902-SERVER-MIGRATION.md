# 2026-09-02 新服务端平滑迁移联调记录

## 目标与基线

- 目标：在不影响已发布旧服务的前提下，让 Flutter App 优先使用新服务端的健康批量同步、健康预警和反馈接口，并让多商品结算在新兼容层生成一张真实商城订单。
- 修改前 Git：`main` 与 `origin/main` 均为 `f821c56e60fb1673db2560c7945493eebdfb846d`，工作树干净；已执行 `git fetch --prune origin` 和安全快进检查。
- 固定边界：仅在新接口明确返回 HTTP/业务 `404` 或 `405` 时回退旧接口；鉴权、校验、限流和服务异常不得被静默吞掉。

## 修改记录

### 09:30 App 新服务端必要联调

- 原因：当前健康同步只走旧小程序接口，多商品结算会拆单，健康预警只保存在本机，反馈页固定显示不可用。
- 文件/范围：`lib/services/api_client.dart`、`lib/services/app_controller.dart`、`lib/ui/prototype_pages.dart`、`lib/ui/pages.dart` 及对应测试。
- 影响范围：云端健康同步、预警设置与记录、帮助反馈、商城下单；不修改 BLE、设备能力、健康测量算法和本地账号隔离。
- 预期：新服务可用时采用 V2/新兼容契约；旧服务尚未切换时保持原有可用流程；非 404/405 错误如实提示。
- 结果：进行中。
- 失败原因：无。
- 修复结论：待验证后补充。
- 后续待验：定向测试、双时区全量测试、Android Debug/Release、当前 Windows 可执行的 iOS 边界检查。

## 验证记录

> 每次命令、失败原因和修复结论在执行后追加，不覆盖失败记录。

### 15:37 定向 Flutter 测试（首次）

- 命令：`flutter test --no-pub test/api_client_test.dart test/prototype_coverage_test.dart`
- 结果：失败，56 项通过、2 项失败。
- 失败原因：两条旧测试仍强制要求健康同步直接调用旧 `/api/v1/member/daily-date`，并把多商品拆成每 SKU 一单；这是本轮要修复的旧行为，不是运行时崩溃。
- 修复结论：新增 V2 成功与 404 回退用例；多商品改为一单用例，并单独保留旧服务缺少批量路由时的回退用例。

### 15:40 定向 Flutter 测试（修复后）

- 命令：同上。
- 结果：通过，62 项成功、0 失败。
- 失败原因：无。
- 修复结论：新服务优先、旧服务回退和原型页面回归均通过。

### 15:45 Flutter 静态检查（首次）

- 命令：`flutter analyze --no-pub`
- 结果：失败，2 条 info 级规范问题。
- 失败原因：新增可空 ECG 附件 Map 使用显式 `if`，且时区回退的单行 `if` 未加花括号。
- 修复结论：改用空安全 Map 元素 `?` 并补花括号；重新执行后无问题。

### 15:49 Flutter 静态检查（修复后）

- 命令：`flutter analyze --no-pub`
- 结果：通过，`No issues found`，耗时约 55.6 秒。
- 失败原因：无。
- 修复结论：本轮新增代码符合现有静态规则。

### 15:52 双时区全量 Flutter 测试

- 命令：分别以 `TZ=UTC`、`TZ=Asia/Shanghai` 执行 `flutter test --no-pub`。
- 结果：两个时区均为 372/372 通过、0 失败。
- 失败原因：无。
- 修复结论：健康采集时间、时区偏移、新服务优先/旧服务回退及既有 UI/设备回归均未出现时区依赖。

### 15:58 Android Debug 与 QA Release 构建

- 命令：Android Debug 双架构构建；设置 `SAIDIAN_ALLOW_QA_RELEASE=true` 后执行 QA Release APK 构建。
- 结果：Debug 成功；Release 成功，APK 约 61.6 MB；ZIP 内容确认同时包含 `arm64-v8a` 与 `armeabi-v7a`。
- 环境变化：首次构建由 Android 工具链自动安装 SDK Platform 34，这是依赖满足动作，不是应用源码修改。
- 失败原因：无。
- 修复结论：本轮 App 联调改动可形成 Android 调试包和内部 QA 包。

### 16:02 发布脚本 Python 测试

- 首次命令：使用隔离 Python 执行 `tests/test_release_scripts.py`。
- 首次结果：19 项中 13 项通过、6 项环境错误；Windows 环境缺少测试假定的 Bash。
- 修复动作：把 Git for Windows Bash 加入当前测试 PATH 后重试。
- 重试结果：19 项中仍为 13 项通过；5 项 Xcode 门禁硬编码 `/bin/sh`，1 项原子发布按 POSIX 绝对路径规则拒绝 Windows 路径。
- 修复结论：这些测试验证的是 macOS/Linux 发布环境，不修改与本轮服务端联调无关的发布脚本；结果按环境边界如实保留，iOS Release/APNs 仍需 macOS 和签名材料验收。

### 16:07 Android 原生单测路径诊断

- 首次命令：在当前英文 Junction 工作区执行 `android/gradlew :app:testDebugUnitTest --rerun-tasks`。
- 首次结果：Gradle 报两个测试类 `ClassNotFoundException`；Kotlin 编译产物实际存在。
- 诊断：`javap` 可读取类；直接 JUnit 执行 `VeepooBatteryReadGateTest` 为 5/5 通过。Gradle 工作进程使用 Junction 指向的中文真实路径，加载测试类失败。
- 复验动作：以同一 `origin/main` 提交创建纯英文物理 Git worktree，重新 `flutter pub get` 后运行相同 Gradle 测试。
- 复验结果：2 个测试套件、10/10 通过、0 失败，`BUILD SUCCESSFUL`。
- 修复结论：确认是当前 Windows Junction/中文真实路径组合的 Gradle 工作进程限制，不是原生源码回归；避免为环境问题修改原生构建逻辑。后续原生门禁应使用纯英文物理工作树。

## 本轮最终功能结果

- 健康同步优先调用 `/api/saydian-app/v2/health/records/batch`，支持 200 条、幂等键、部分失败、断点游标、明确指标映射、时区和质量字段。
- ECG 波形先 gzip 并以 SHA-256 标识上传到 V2 私有文件入口，健康批次仅引用附件索引；旧服务缺少 V2 时才回退原有逐项同步。
- 健康预警设置与事件从新服务加载；登录会话切换有 generation 防护，避免旧账号晚到响应污染新账号。
- 反馈页改为真实提交并提供处理中、成功和错误反馈，不再固定显示占位提示。
- 多商品结算优先调用批量兼容入口，只生成一个商城订单；仅当旧服务明确缺少该路由时回退原有逐 SKU 流程。
- BLE、设备能力、健康测量算法、本地数据归属和既有旧客户端契约均未修改。

## 提交前最终门禁

- `flutter analyze --no-pub`：再次通过，`No issues found`。
- `TZ=UTC flutter test --no-pub`：再次 372/372 通过；启动时缓存提示 `File modified during build. Build must be rerun.` 后工具自动重建并正常完成，不构成失败。
- `git fetch --prune origin` 后本地与 `origin/main` 仍同为 `f821c56e60fb1673db2560c7945493eebdfb846d`。
- 敏感信息正则首次因 PowerShell 引号转义失败；修正后的长字面量检查仅命中测试 Token/密码，不含生产私钥或真实集成凭据。
- 暂存差异审查发现云端 `enabled=false` 会被默认值 OR 重新开启；改为服务器明确布尔值优先、缺字段才回退默认值，并新增禁用状态断言后重跑门禁。
- 修复后 API 定向测试 46/46、静态检查和 UTC 全量 372/372 均通过。

## 19:05 服务端部署复验、消息兼容与 QA APK

### 修改前基线

- 执行 `git status --short --branch`、`git remote -v`、`git fetch --prune origin`；本地从 `f821c56e60fb1673db2560c7945493eebdfb846d` 安全快进到 `caeffa8d99479b1106001fcfda36f368475a9d1a`，与当时 `origin/main` 一致。
- 用户原有未跟踪目录 `docs/legal/` 未被覆盖，并额外备份到仓库外 `E:\saydian\本地改动备份\docs-legal-before-pull-20260902-1000.zip`。
- 修改原因：线上已切换消息统计和已读契约，但 App 仍调用旧路由，导致未读数和已读同步无法使用。
- 修改文件：`lib/services/api_client.dart`、`test/api_client_test.dart` 和本记录。
- 影响范围：只调整消息未读/已读接口适配；不修改 BLE、健康测量、订单金额和支付算法。

### 登录态在线接口结果

- `POST /api/v1/member/push-devices`：业务 `200`，登记成功。
- `DELETE /api/v1/member/push-devices/{installation_id}`：对本轮刚登记的探测实例仍返回业务 `404`，登记/解绑闭环未通过；该不可投递探测记录因服务端缺少解绑路由而无法由客户端清理，服务端应清理测试账号下 `codex-contract-` 前缀的安装实例。
- `GET /api/v1/member/notify`：业务 `200`，消息列表可读取。
- `GET /api/v1/member/notify/statistics`：业务 `200`，实际返回 `announce_count`、`remind_count`；App 已改为合并两类计数。
- `GET /api/v1/member/notify/{id}`：业务 `200`，与原小程序“查看详情即已读”的行为一致；旧 `/notify/{id}/read` 不再作为主路由。
- 无登录态访问消息列表和详情仍返回业务 `500`，且响应包含框架诊断字段；“统一 401/403、关闭生产调试堆栈”的服务端鉴权整改尚未生效。
- `GET /api/v1/member/daily-date/preview`：以远程成员和当天中国时区起点分别验证 `pulseReat`、`BloodPressure`、`BodyTemperature`、`HRV`，均为业务 `200`，且返回对应图表结构，先前部分类型业务 `500` 未复现。
- `POST /api/v1/pay`：微信 `pay_type=100`、支付宝 `pay_type=101` 均返回业务 `200` 和“待支付”，但两者 `data.config` 都为 `null`；没有微信 `appid/partnerid/prepayid/noncestr/timestamp/sign` 或支付宝签名订单串，客户端仍无法调起真实 APP 支付。
- 联调仅生成支付参数请求，没有确认支付、没有真实扣款；日志未保存账号密码、Token、订单号、成员 ID 或健康数值。

### 客户端兼容修正

- 未读数主路由改为 `/api/v1/member/notify/statistics`，支持分类计数求和，也继续兼容 `unread_count`、`count` 和标量旧格式。
- 数字消息和服务端事件的已读主路由改为 `GET /api/v1/member/notify/{id}`。
- 仅当新路由明确返回 HTTP/业务 `404` 或 `405` 时回退旧 `/notify/unread-count`、`/notify/{id}/read`；鉴权、校验和 `500` 不会被吞掉。

### 回归与构建

- 定向接口测试：`test/api_client_test.dart` 46/46 通过。
- 静态分析首次在中文真实工作目录触发 Dart Analysis Server LSP 输入截断；改用指向同一仓库的英文 Junction `E:\saydian\app_ascii` 后通过，`No issues found`。这是工具路径问题，不是源码分析错误。
- 全量 Flutter 测试：`TZ=UTC` 372/372、`TZ=Asia/Shanghai` 372/372，均为 0 失败。
- Windows 测试首次因 GitHub 无法下载 `sqlite3` 开发测试二进制而中断；测试期间临时使用系统 `winsqlite3.dll`，完成后已删除临时 `pubspec.yaml` hooks，文件内容与 Git 基线一致。Android APK 使用恢复后的正常项目配置构建。
- QA Release：`SAIDIAN_ALLOW_QA_RELEASE=true` 构建成功，包名 `cc.saidian.app`，版本 `0.1.19`，构建号 `23`，`minSdk=26`，`targetSdk=36`，包含 `arm64-v8a`、`armeabi-v7a`。
- APK 签名与结构：`apksigner verify` 通过（APK Signature Scheme v2），`zipalign` 通过；签名证书为 `Android Debug`，仅限内部 QA，不是生产发布签名。
- 交付文件：`E:\saydian\测试包\赛电APP-QA-v0.1.19-build23-20260902-1903.apk`，大小 `64,561,036` 字节，SHA-256 `E61F1945E12817F28B32173309AECEC5AD4D2D4B0249318D4B7376FF44C68AE4`。

### 仍需服务端处理

1. 实装并验证 `DELETE /api/v1/member/push-devices/{installation_id}`，同时清理本轮不可投递探测实例。
2. 无 Token 的消息列表/详情统一返回 `401/403`，关闭生产环境框架路径和堆栈暴露。
3. 微信和支付宝 APP 支付必须返回非空签名参数，并在真机完成取消、成功、回调验签、订单状态更新和重复点击幂等联调后，才能解除支付发布阻塞。
