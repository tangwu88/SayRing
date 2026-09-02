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
