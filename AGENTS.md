# AGENTS.md

## Say Ring boundary

- This independent repository is `tangwu88/SayRing`. It must be **Private before the first push**. `origin` is Say Ring; `upstream` and `source-local` are read-only imports from the international App. Never push Say Ring code to the watch App or re-enable inherited release automation.
- Before changes: inspect branch/status, fetch `origin`, fast-forward only a clean current branch, read `docs/INTERNATIONAL-HANDOFF.md` plus the latest change/test records. Preserve other colleagues' work; checkpoint before safe integration.
- First-party network and update requests must stay under `https://app.saydian.cn/global`; update requests must identify product `say-ring`. Never fall back to domestic endpoints or accept a package for another product. Account data is shared with the international realm, while local storage, package IDs and update artifacts stay isolated.
- Record every implementation/test round in Git, including exact commands, failures, correction, skipped checks and actual build evidence. Never equate a host-side contract test with a real device/SDK/provider acceptance.
- User delivery rule (2026-09-27): after each completed and verified change, commit the scoped files and push the current Say Ring branch to `origin`; when the change is the accepted project baseline, fast-forward `origin/main` as well. Never force-push, overwrite remote history or claim synchronization when fetch/push verification fails.
- Registration and health-analysis consent use reviewed, published international documents; do not invent versions. Provider, market and payment availability comes from server configuration, not UI assumptions. No real OTP delivery/payment without an authorized test destination and accepted channel.
- Existing health values and device algorithms stay unchanged. Unknown values remain unknown; unconfirmed uploads remain pending, not successful.
- Device names are routed only by the normalized prefixes `YC` (Yucheng), `V`/`TK` (VEP), `D` (Moyoung), `Q_`/`O_` and user-confirmed `R2` (QRing, including R21), and user-confirmed CoolWear/LuckRing models `HR01`, `HR05`, `K80`, `R7`, `R7Y`, `R7Pro`. CoolWear accepts exact model names and bounded numeric/hex suffixes, retaining legacy `HR01-` aliases; adjacent unconfirmed models fail closed. Name routing never proves capabilities; only a successful vendor handshake and real capability response may enable a feature. The user-supplied 20260910 CoolWear iOS SDK adds real scanning, metadata/capability handshake, battery and manual heart/oxygen transport. New RRI-HRV types 60/61 (SDNN in ms, manual command 62) and passive skin temperature type 47 have their own strict mapping gated by real hrvSupport/temp_supported flags; legacy HRV types 42/45 remain uninterpreted. Full-history completion, sleep, sport and other iOS controls remain unverified and fail closed. iOS type 9 is mixed child data, not Android history completion. Never enable vendor installation-wide auto-connect. The supplied Moyoung glasses sample is not a ring SDK and must not be shipped as one.
- User-confirmed product identity: Android/iOS Debug/Profile/Release must use `cn.saydian.ring`. Machine-local signing configuration must not override it; missing signing is a blocker, never a reason to use a temporary bundle ID.
- User-approved QRing recovery (2026-10-01): automatic restore may use only the exact UUID/MAC from the current environment and stable account owner's last successful SDK handshake, with an accepted real vendor name and a fresh capability handshake. Old environment-only v1 bindings require explicit selection before upgrading to owner-bound v2. CoreBluetooth UUID retrieval is not an OS bond, and QRing OS bonding is not required for this narrowly verified target. Never adopt a device by name alone, an arbitrary identifier, another account, or an SDK installation-wide saved target. Keep the bundled demo's independent reconnect disabled.
- QRing recovery retains a single explicitly armed native target. Unexpected and user-requested reconnect both preserve binding; only unbinding forgets it. Logout, account/context changes, consent withdrawal, permission loss and target replacement cancel native recovery and reject late callbacks. Manual selection preempts recovery; save a replacement only after its successful handshake. Android's user-initiated OS-bonded selection remains separately validated. No iOS automatic OS-bond fallback or AccessorySetupKit-based force-quit relaunch is claimed.

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
