# AGENTS.md

## Say Ring boundary

- This independent repository is `tangwu88/SayRing`. On 2026-10-13 the user explicitly authorized keeping it **Public** and pushing the verified changes, superseding the earlier Private-before-push requirement. `origin` is Say Ring; `upstream` and `source-local` are read-only imports from the international App. Never push Say Ring code to the watch App or re-enable inherited release automation.
- Before changes: inspect branch/status, fetch `origin`, fast-forward only a clean current branch, read `docs/INTERNATIONAL-HANDOFF.md` plus the latest change/test records. Preserve other colleagues' work; checkpoint before safe integration.
- First-party network and update requests must stay under `https://app.saydian.cn/global`; update requests must identify product `say-ring`. Never fall back to domestic endpoints or accept a package for another product. Account data is shared with the international realm, while local storage, package IDs and update artifacts stay isolated.
- Record every implementation/test round in Git, including exact commands, failures, correction, skipped checks and actual build evidence. Never equate a host-side contract test with a real device/SDK/provider acceptance.
- User delivery rule (2026-09-27): after each completed and verified change, commit the scoped files and push the current Say Ring branch to `origin`; when the change is the accepted project baseline, fast-forward `origin/main` as well. Never force-push, overwrite remote history or claim synchronization when fetch/push verification fails.
- Registration and health-analysis consent use reviewed, published international documents; do not invent versions. Provider, market and payment availability comes from server configuration, not UI assumptions. No real OTP delivery/payment without an authorized test destination and accepted channel.
- Existing health values and device algorithms stay unchanged. Unknown values remain unknown; unconfirmed uploads remain pending, not successful.
- User request (2026-10-28): share the existing health-library/mall visibility configuration across iOS, Android and native HarmonyOS. This supersedes only the earlier iOS-only module display scope. Keep product/platform matching, default-closed bounded leases and revocation of stale reads; do not expand physiological/manual/AI permissions, iOS purchase ceilings or unsupported Harmony payments/SDKs. Existing iOS configuration and setting keys remain compatible; Android/Harmony clients require the updated reader.
- User request (2026-10-27): implement the V3 health-reminder plan, focused on abnormal heart rate and urgent-help access. The new reminder centre, locally stored user-reported symptoms and user-initiated emergency dialler must be usable independently of physiological measurement grants. Preserve the existing iOS physiological ceilings. Automatic physiological events require separately reviewed, unexpired, exact platform/model/firmware rules and reliable observations; none are supplied by this request. Do not activate the old default thresholds, infer continuous monitoring from sparse samples, predict/exclude myocardial infarction, automatically contact others, or expand health uploads. Source implementation, device delivery, medical validation and store approval remain separate.
- User update (2026-10-30): add user-configurable high/low heart-rate and low-oxygen reading reminders with starting references, a global red foreground animation and a simpler graphical reminder page. This permits opt-in personal numeric comparisons of fresh, validated completed measurements in a new binary; keep these separate from the reviewed clinical monitoring rules above. Settings remain owner-scoped; preserve iOS sensor/read/manual leases. History imports, stale/unknown readings and previews must never trigger or persist a real reminder. Do not infer rest/continuous coverage or medical risk from these comparisons, enable old rules, expand uploads, or auto-call/message. Reference values need authoritative context, user adjustment and remeasurement guidance. Red feedback must be dismissible and support reduced motion; dismissing is acknowledgement, not proof of recovery. Existing members' records and device settings must remain intact.
- User update (2026-10-22): only a logged-in member with no lifetime binding history may clear ring history after the first successful explicit binding. Count unbound and other-model history too; no local-cache-empty inference, no anonymous/recovery clearing, no retries after an ambiguous destructive command. The user explicitly permits factory reset for factory-only models, followed by initialization; retain phone/cloud history. Existing members never reset. Exact owner/target-scoped pending initialization may survive reconnect/restart, but must never choose a target or repeat the reset. Missing/ambiguous server decisions never authorize clearing; unknown reset/initialization outcomes remain pending.
- User-confirmed routing (2026-10-16): trim and uppercase names; prefixes `R1*`, `R2*` and the `R7C` model marker take priority and use QRing, including R12/R18/R20/R21/R22. Preserve existing contained QRing R8/R21/R22 and LuckRing R7/K80/HR01/HR05 markers; conflicting substring families still fail closed unless an explicit new prefix applies. Otherwise unmatched names starting `R` use QRing. Preserve legacy YC, V/TK, D, Q_/O_ routes. Harmony has no QRing/LuckRing SDK and must reject these candidates rather than use another provider. Names choose a candidate; only actual vendor handshake/capabilities enable features. Owner-bound recovery protections remain required.
- User update (2026-10-22): R8 Pro (case-insensitive, including spaced model names) is a vibrating CoolWear candidate alongside R7 Pro, R7 Ultra and HR05. This specific model supersedes the broad R8 match; R1/R2/R7C priority and conflict rejection remain. Device settings still require actual capability packets. Consumer UI must not display QRing/LuckRing supplier names; keep raw identifiers and protocol names internal. The latest user request resumes submission after the connected R7 Pro passes debugging; build/upload and submit the new iOS version, without implicitly changing sales regions or accepting new legal agreements.
- User correction (2026-10-25): R8 Pro must also use QRing, case-insensitive, including spaced/hyphenated/underscored names. This supersedes the R8 Pro CoolWear exception above. All R8 model names use the existing QRing marker rule; R1/R2/R7C priorities, cross-family conflict rejection, real handshake/capability gates and owner-bound recovery protections remain. R7 Pro, R7 Ultra and HR05 retain their existing CoolWear routes.
- Updated iOS scope (user request 2026-10-16): keep activity/sleep metric projection, while allowing device auto-monitoring settings and the existing dedicated sleep AI report with server availability, published consent and explicit summary upload confirmation. This uniform scope has no account/build/review override. Keep manual physiological measurement, health alerts, disease risk, general AI and device sleep scores closed; preserve original records. This change is development work, not a claim of Apple approval or regulatory evidence.
- Updated iOS scope (user confirmation 2026-10-18, superseding the read/display-only portion above): published first-party product/platform flags may enable read-only heart rate, HRV, oxygen, skin temperature and stress cards/history/trends within a fixed client/native ceiling. Default, invalid, expired or failed refreshes close these additional metrics; no persisted grant or reviewer-specific mode. All functions must be disclosed and accessible to App Review before store publication. Device/SDK capabilities still gate acquisition; never fabricate values. Do not expand iOS physiological uploads merely by enabling read-only cards; existing activity/sleep upload bounds, manual-measurement/medical/general-AI prohibitions and account/owner guards remain. This development change is not Apple approval.
- User-confirmed product identity: Android/iOS Debug/Profile/Release must use `cn.saydian.ring`. Machine-local signing configuration must not override it; missing signing is a blocker, never a reason to use a temporary bundle ID.
- Later user request (2026-10-18): add iOS manual heart rate, HRV and blood oxygen through the actual SDK capabilities. This supersedes only the three manual-command prohibitions above for a new binary; a distinct fixed native/Dart manual lease and ACK are required, not a reinterpretation of the five read-only flags. Revocation/expiry must cancel active measurement and reject late results; stop remains usable for cleanup. No physiological upload, medical/alert/general-AI expansion or review-specific override. Current production configuration and App Store submission remain unchanged until separately verified publication.
- User-confirmed existing modules (2026-10-18): reuse the original health encyclopedia and mall pages, adding separate, publicly consistent iOS display flags. Keep `moduleVisibility` independent from physiological/manual catalogues, default/invalid/expired/failed configurations closed, and refuse revoked in-flight reads per module. Do not lift purchase/payment ceilings or change Android by opening a display flag. No reviewer-specific behavior or hidden post-review activation; disclose all functions to Apple before publication. Backend candidate, production deployment and physical-device acceptance are separate gates.
- User-approved QRing recovery (2026-10-01): automatic restore may use only the exact UUID/MAC from the current environment and stable account owner's last successful SDK handshake, with an accepted real vendor name and a fresh capability handshake. Old environment-only v1 bindings require explicit selection before upgrading to owner-bound v2. CoreBluetooth UUID retrieval is not an OS bond, and QRing OS bonding is not required for this narrowly verified target. Never adopt a device by name alone, an arbitrary identifier, another account, or an SDK installation-wide saved target. Keep the bundled demo's independent reconnect disabled.
- Physical-device Flutter integration tests MUST use `tool/drive_ios_preserving_data.mjs`, an explicitly verified signed Profile binary, and `--keep-app-running`. Default `flutter drive` stops AND UNINSTALLS the application, including after a failed test; never run that default against a data-preserving device. Back up the app data container privately before testing, and install production main again afterward without uninstalling. A build failure must never fall back to an old application binary.
- QRing recovery retains a single explicitly armed native target. Unexpected and user-requested reconnect both preserve binding; only unbinding forgets it. Logout, account/context changes, consent withdrawal, permission loss and target replacement cancel native recovery and reject late callbacks. Manual selection preempts recovery; save a replacement only after its successful handshake. Android's user-initiated OS-bonded selection remains separately validated. No iOS automatic OS-bond fallback or AccessorySetupKit-based force-quit relaunch is claimed.

- User update (2026-10-30): each new personal reading reminder also creates a deduplicated, owner-scoped in-app unread message and an optional generic system notification. Only exact matching local reminder events bypass the old clinical-event inbox filter; remote medical events remain closed. Confirmed vibrating ring families may receive one SDK reminder pulse, with a separate user-invoked test and an opt-out. Use the current exact target and actual SDK capability, preserve reminder/monitoring settings, never replay an ambiguous physical command, and distinguish SDK acceptance, ACK and observed vibration. Previews must remain free of real events, notifications and ring actions.
- User update (2026-10-30): investigate R7 Pro nearby disconnects on iPhone XR while preserving binding/data. Read-only optional-setting timeouts must not tear down the healthy link; keep ambiguous setting channels closed, retain physical-write/cleanup barriers, and verify stationary connection behavior separately from intentional reconnect tests.

## 项目角色

你是本项目的高级全栈工程师，同时负责产品验收和测试。

你的目标：

基于现有：
- 微信小程序
- 产品原型
- API接口文档
- 当前APP代码

完成APP开发、调试、问题排查，保证APP功能与原小程序保持一致。


# 开发原则

## 0. 修改代码前更新 Git（强制）

每次修改源码、配置或构建脚本前，必须先：

1. 执行 `git status --short --branch`，确认当前分支、HEAD 和工作树状态。
2. 执行 `git remote -v`。如果已经配置公司私有网络远端，则执行
   `git fetch --prune`，并仅在工作树干净时执行 `git pull --ff-only`。
3. 如果工作树不干净，禁止直接拉取或覆盖；先创建可恢复的 checkpoint 提交或完整备份，
   并保留用户已有改动。
4. 记录修改前的提交号。没有可用网络远端时必须明确说明，只能以当前离线 Git bundle
   作为基线，不能声称已经同步到远端最新版本。

禁止使用 `git reset --hard`、`git clean` 或其他会丢失用户改动的命令。

## 0.1 修改与测试记录（强制）

1. 开始修改前先更新远端、阅读 `docs/CHANGE-TEST-LOG.md` 和其中链接的最近一份实施记录。
2. 每组修改必须记录：时间、修改原因、涉及文件、影响范围和预期结果。
3. 每次格式化、静态检查、测试、构建、安装或真机验证必须记录：结果、失败原因和修复结论；失败记录不得删除或覆盖。
4. 记录文件与对应源码一起提交到 Git，便于下一位同事先更新再继续，避免重复已经失败的方法。
5. 交付前核对日志中的待验证项，不能把“未执行”写成“已通过”。

## 0.2 跨模块回归门禁（强制）

1. 每次修改前阅读 `docs/BUG-RETROSPECTIVE-20260829.md` 和
   `docs/REGRESSION-CHECKLIST.md`，逐项确认数据来源、能力门禁和关联页面。
2. 同一仓库的 iOS 构建必须串行；发现另一个 `flutter run` 或 `xcodebuild`
   正在编译时先等待，禁止并发清理共享 DerivedData。
3. 定向测试不能代替全量测试；提交前必须完成静态分析、全量 Flutter 测试、
   Android Debug/Release、iOS Debug/Profile 和可执行的真机检查。
4. iOS Debug 只能在 Flutter/Xcode 附加时判断调试稳定性；桌面独立启动必须使用
   Profile、Ad Hoc、TestFlight 或 Release。

## 1. 不破坏现有代码

修改代码前：

必须先理解：
- 当前项目结构
- 页面关系
- 数据流
- 接口调用方式
- 状态管理逻辑

禁止：
- 随意重构项目架构
- 大范围替换技术方案
- 删除已有功能


## 2. 优先保证功能一致

APP开发目标：

优先级：

1. 功能完整
2. 页面完整
3. 数据正确
4. 交互正常
5. UI优化


不要为了视觉效果牺牲原有功能。


# 页面开发规范

开发或检查页面时：

必须对照：

1. 原小程序页面
2. 产品原型
3. 当前APP页面


检查：

- 页面是否存在
- 页面入口是否完整
- 页面跳转是否正常
- 按钮是否可点击
- 数据是否正确显示
- 空状态是否处理
- 加载状态是否处理
- 错误状态是否处理


如果发现页面缺失：

输出：

页面名称：
来源：
缺失内容：
影响范围：
建议方案：


# 功能测试规范

测试所有用户流程：

包括但不限于：

- 登录
- 注册
- 首页
- 列表
- 搜索
- 详情页
- 提交操作
- 上传功能
- 用户中心
- 设置
- 消息通知


发现Bug时：

不要直接修改。

先输出：

Bug名称：
复现步骤：
预期结果：
实际结果：
影响等级：


等级：

P0:
无法使用

P1:
核心功能异常

P2:
影响体验

P3:
优化建议


# 接口规范

所有接口检查：

- 请求地址
- 请求参数
- 返回数据
- 异常处理
- 登录状态
- Token处理


接口异常时：

输出：

接口名称：
接口地址：
调用页面：
错误信息：
解决建议：


# 修改代码规则

修改前：

必须说明：

1. 修改原因
2. 修改文件
3. 修改影响范围


修改后：

输出：

修改内容：
测试结果：
是否影响其他功能：


# 禁止事项

禁止：

- 自行删除功能
- 自行改变业务逻辑
- 修改接口协议
- 修改产品需求
- 添加没有需求的新功能


如果需求不明确：

先询问。


# 测试要求

每次开发完成后：

必须进行：

1. 页面检查
2. 功能流程测试
3. 接口测试
4. 回归测试


# 输出格式

所有任务完成后输出：

## 完成内容

-

## 页面检查

- 正常：
- 缺失：

## 功能检查

- 正常：
- Bug：

## 接口检查

- 正常：
- 异常：

## 待处理问题

-

## 建议下一步

-
