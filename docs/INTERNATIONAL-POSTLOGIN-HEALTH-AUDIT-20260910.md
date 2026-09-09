# 登录后健康、AI、关爱与消息只读审查 — 2026-09-10

## 范围与执行边界

- App 基线：`619484c24fea57af9fe28122916de14ffcb5dc88`，`main` 与 `origin/main` 一致；`git status --short --branch` 干净，`git fetch --prune origin` 成功，`git rev-list --left-right --count HEAD...origin/main` 为 `0 0`。
- 已读 App `AGENTS.md`、国际交接、修改测试索引、最新认证真机记录、联合覆盖矩阵、复盘与回归清单。旧记录中 404/无设备等状态不作为本轮在线事实。
- 对照服务端独立工作区 `F:/xcodeplace/saydian-server-global` 源码，HEAD 为 `99bc69692969052dae489028466d329cc5619833`；仅查看状态与源码，不修改、拉取或部署服务端。其分支为 `codex/global-api-foundation`，初始状态比其跟踪分支领先一提交。此本地源码 SHA 不是本分工独立验证过的线上部署 SHA。
- 本轮仅检查与 host 测试、只新增本文。无 runtime 修改、真机操作、后台操作、真实凭据/用户数据读取、业务写接口调用、SDK 启动、APK 构建、提交或索引更新。主任务独占真机 UI。

## 审查结果

路由存在、mock 测试通过、真实接口可用、真机成功分别记录，不互相代替。本轮没有真实接口请求，也没有新增失败复现测试；以下问题由确定的调用分支及两端 DTO 对照得出，给出后续合成回归场景，不冒称已在用户账号复现。

### 已确认兼容的基础路径

| 链路 | App 对照 | 服务端对照 | 本轮判断 |
| --- | --- | --- | --- |
| 手表历史上传 | `global_health_api.dart:44`：逐条 ID、UTC observedAt、offset、values、source、批次 ACK 校验 | `health.controller.ts:20`、`health-validation.ts`、`health.service.ts` | V2 字段结构匹配；未确认/不可表示的波形继续 pending；不是云端读取已完成 |
| 云端预警规则/事件 | `global_health_api.dart:296,375`；规则保存后完整回读 | `health.controller.ts:41,46,54`；`health.service.ts:264,277` | `temperature` 映射、数组结构、eventId/observedAt 匹配；真实事件/设定写入未测 |
| AI 历史/消息 | `global_api_client.dart:160,190`：固定 app 会话名、content、locale | `content.controller.ts:44,53`；`content.service.ts:100,110` | 路由和会话/content/role DTO 匹配；厂商配置、真实发送及多轮能力未验收 |
| 国际关爱 | `global_api_client.dart:249-341`、`global_care_page.dart` | `care.controller.ts:29-83`、`care.service.ts:119,224` | UUID 保持字符串；关系方向、metrics、UTC 日界线匹配；403 与空态区分且不落本人库 |
| 国际消息 | `global_api_client.dart:548-626` | `notifications.controller.ts:22-70`；`notifications.service.ts:136-187` | `items`、eventId、readAt、unread count 及稳定事件已读接口匹配；实际推送渠道未验收 |
| 健康档案/报告 | `api_client.dart:1589-1703` | `health-reports.controller.ts`、`health-reports.service.ts:44,178,278` | profile/eligibility/report DTO 基本匹配；仍有下述账号隔离与语言缺口，不能整组判通过 |

### P1-H01：新手机登录后无法从云端恢复自己的健康历史

- 复现条件：账号在云端已有合法历史，另一台本地健康库为空的国际版手机登录；查看趋势或点击同步。
- 预期：按当前环境、当前账号分页读取云端历史，保留服务器来源/时间/记录标识；不得重复上传下载记录。
- 实际源码：`lib/services/app_controller.dart:1717-1731` 仅 `_healthStore.range`；`lib/services/sync_service.dart:22-107` 只有本地 pending→上传→markSynced 循环；国际 client 没有 `GET health/records` 调用。服务端 `apps/api/src/health/health.controller.ts:29-37` 和 `health.service.ts:127-176` 已提供 `items/nextCursor` 分页读取。
- 影响：跨手机/新安装健康趋势不可恢复；“手表→本机→服务器→重新读取”还不能在 App 完成。服务器有数据不代表 App 首页有数据。
- 建议：新增严格 owner/generation 绑定的国际历史拉取和游标分页；下载记录作为已确认云端来源保存，独立标记，不自动归属旧环境数据。回归同秒分页边界、重复拉取、A→B 迟到回包、记录与波形保全。**本轮不实施。**

### P1-H02：健康档案与报告页缺少账号代次保护

- 复现条件：A 打开健康档案，网络响应未完成时会话退出、失效或切至 B，页面仍在导航栈中；A 的成功响应随后返回。
- 预期：A 响应不能成为 B/未登录页面状态；既有 A 档案必须立即隐藏。
- 实际源码：`lib/services/app_controller.dart:4073-4089` 并行启动 profile/eligibility/entitlements/offers/reports 后直接返回 dashboard，无会话代次复核；`lib/ui/health_reports_page.dart:34-72` 不监听账号变化，只在 await 后检查 `mounted`；基础传输 `lib/services/api_client.dart:1982-1989` 对成功响应直接返回，不替页面执行 owner 检查。根页面 `lib/app.dart:643-664` 只更新 home，普通会话变化没有像强制更新那样清空全部 push 路由。
- 影响：迟到的旧账号档案/报告可出现在仍挂载的页；同页授权/重试操作还可能基于旧 dashboard 作出判断。服务端单请求鉴权正确不能消除客户端显示串号。
- 建议：在 dashboard 和独立报告读取前后锁定稳定账号+generation；页面监听账号变化清数据并中止交互；并行 Future 同时收集错误，避免后续 Future 提前拒绝未被接住。合成测试：A→退出/B、五个请求交错完成、成功/403 混合、页面返回后迟到。**本轮不读取实际账号数据复现。**

### P2-N01：关爱轮询与真实通知采用不同事件 ID，可能重复并残留未读

- 复现条件：同一条国际关爱邀请同时被关系轮询和 notifications/推送发现。
- 预期：同一邀请只显示一条消息；点击/处理后按真实稳定 eventId 更新服务器已读。
- 实际源码：App `app_controller.dart:589-592` 取关系 `id`，`:3622-3631` 生成 `care-invitation-{relationshipId}`；服务端 `care.service.ts:52-53` 生成独立 `invitationId=care_<UUID>` 并使用 `care-invitation-{invitationId}`，`:312` 在关系 DTO 另有 `invitationId`。两者不是同一标识。`notification_inbox.dart:47,93` 仅按 eventId 合并；`pages.dart:5632` 的远程/本地过滤也按 eventId。
- 影响：同一邀请有两条记录/红点下限可能重复；点本地轮询项时，服务器 `notifications.service.ts:181-189` 无法用构造出的非真实 eventId 匹配，返回 `read:false`。处理关系后的本地 reconcile 不等于服务器消息已读。
- 建议：国际关系 DTO 明确携带真实 eventId 或按服务端 invitationId 契约映射；relationshipId 只作目标实体，不能兼任事件ID；撤销后再次邀请需保留新邀请轮次。回归 poll→push/反序、已读回读和重新邀请。不要简单按关系ID永久合并所有轮次。

### P2-C01：复合健康指标在国际关爱详情中不能展示已存在的分项

- 复现条件：授权身体/血液成分或 ECG；服务端合法 `values` 包含对应分项，而没有标量 `value`。
- 预期：仅投影本指标真实分项及单位；不存在的摘要保持未知，不混入其他指标。
- 实际源码：`lib/ui/global_care_page.dart:354-373` 展示上述指标入口，但 `:507-517` 除血压外一律只读 `values['value']`；`care.service.ts:282-290` 返回原 values，服务端 `health-evidence.ts:48-59` 明确接受如 bodyFatPercent/BMI、uricAcid/cholesterol、ECG heartRate 等分项。
- 影响：非空合法记录仅显示 `—`，用户无法查到已有分项。没有合成健康数值是正确边界，但不能替代复合指标展示。
- 建议：复用受白名单约束的指标展示适配；不生成缺失波形、诊断或汇总值。回归缺 value/部分子项/未知键/跨指标混入/长文本。

### P2-L01：百科缺译时未按约定回退英文，健康报告动态文案仍固定中文

- 复现条件：App 切换到法国/德国等语言，国际库只有英文百科；或读取健康资格/报告。
- 预期：百科明确回退到英文内容；动态报告与资格使用请求/账号语言，缺译有可理解的英文回退。
- 实际源码：`global_api_client.dart:112-151` 始终发送当前 locale；服务端 `content.service.ts:24-79` 对 categories/articles/article 仅 exact locale 筛选，无英文重试，结果为空/404。报告 `health-reports.service.ts:187-192,702-712,741` 动态 missing/freePreview/aiLabel 固定中文；App `health_report_models.dart:174,225-227` 保存原字符串，非 ARB 文案。旧交接已说明全屏语言未收口，本轮确认了具体未完成路径。
- 建议：非法律内容实现显式标注 resolvedLocale 的英文回退；报告动态文案按账号语言或服务端模板键生成。法律同意文档不得借普通文章回退绕过审核版本。

### AI 的额外明确能力边界（P2）

`content.service.ts:100-107` 持久化完整会话，但 `:155-183` 发给供应商的 messages 仅 system+本次 user content，没有历史。App 聊天页面展示历史（`pages.dart:4056`；controller `3816-3835`），不能据此声称“记住刚才的上下文”。后续合成供应商请求断言应验证是否携带限定长度、同账号同会话的历史。当前未发真实 AI 请求，供应商可用性/额度未知。

## 建议主任务的固定 GET 检查清单

共同根地址为 **`https://app.saydian.cn/global/api/saydian-app/v2`**。下表只是建议，不代表已调用。沿用主任务授权会话，不读取/输出 Token；禁止重定向，不接受旧域/本地调试回退；只记录 HTTP 状态、requestId、字段类型/数量与耗时，不打印正文、健康值、联系方式或用户ID。

| 固定 GET 路径/查询 | 最小核对 | 限制 |
| --- | --- | --- |
| `/health/records?limit=1` | data.items 数组、nextCursor 类型 | 源码为本人查询；只计数/字段，不展示值；翻页是另行有界检查 |
| `/health/warning-rules` | data 数组、metric/enabled/shareWithCare/阈值类型 | 不改规则；阈值不记真实数值 |
| `/health/warnings?limit=1` | data.items，eventId/metric/observedAt 类型 | 空态不当作有真实预警样本 |
| `/health/profile` | memberId只在内存匹配、dataCompleteness/analysisConsent结构 | 不点击授权，不生成报告；文档 availableVersion 为空属未配置 |
| `/health/reports/eligibility` | eligible、missing 数量、consentRequired | 无数据不足资格是合法状态，不等于可支付 |
| `/health/reports` | data.items、status 统计 | 不获取实际全文/PDF，不重试生成 |
| `/ai/messages?sessionId=saydian-global-1` | data会话数组/messages数组/role类型 | 不输出用户或AI原文，不POST；空历史不能证明供应商可用 |
| `/care/relationships` | id/invitationId仅内存类型、direction/status/metrics | 不邀请、响应、改共享、撤销；只计数 |
| `/notifications?page=1&pageSize=1` | data.items；eventId/readAt/deepLink类型 | 打开消息会另发已读POST，本分工不执行 |
| `/notifications/unread-count` | data.count 为非负数 | 只记录类型及是否为空，不推断实际投递 |
| `/content/categories?locale=en`、`/content/articles?locale=en&page=1&pageSize=1` | 公共列表/分页、resolved locale可用性 | 不访问返回外链；其他语言另作显式回退检查 |

### 不应默认为无副作用的 GET

- `GET /billing/entitlements` 在服务端 `billing.service.ts:102-104,1309-1339` 先 `expireMemberships`，可能更新会员状态、清剩余额度、写 EXPIRE 账本。健康档案页面会自动发起该请求。属于正常业务实现，但**不是严格只读巡检**；主任务决定是否在授权测试账号范围验收。
- `GET /care/relationships/{id}/health` 在 `care.service.ts:251-263` 写访问审计。仅有明确授权关系与指标时由主任务执行；不枚举他人ID，不把审计写入叫作零写入。
- 授权 GET 的自动 Token refresh 会有 `POST auth/refresh`；严格 GET 诊断工具不得暗中刷新。App 正常登录态刷新是独立已授权行为，也要按实际方法记录。

## 本轮命令、结果和未执行项

从 App 英文工作区执行，Flutter `D:/Dev/Flutter/3.44.9/bin/flutter.bat`：

1. `git status --short --branch`、`git remote -v`、`git fetch --prune origin`、`git rev-parse HEAD origin/main`、`git rev-list --left-right --count HEAD...origin/main`：通过，基线见上。
2. `flutter test --no-pub --reporter expanded test/global_api_test.dart test/global_health_api_test.dart test/care_authorization_test.dart test/care_read_session_test.dart test/care_share_settings_test.dart test/app_notification_controller_test.dart test/health_reports_page_test.dart test/health_report_payment_controller_test.dart test/health_report_models_test.dart`：**163/163 通过**，exit 0。
3. `flutter test --no-pub --reporter expanded test/sync_service_test.dart test/notification_inbox_test.dart test/notification_payload_test.dart`：**24/24 通过**，exit 0。
4. 合计 **187 个现有 host 用例**，均为 mock/合成数据，不调用真实 SDK/业务服务。旧国内关爱 tests 验证的是兼容链路，不能替代国际关系+通知 DTO 联合场景；既有报告测试也未覆盖 H02 账号切换场景。AI 的国际请求/供应商多轮上下文没有专项执行证据。
5. 探查中有文件名或跨仓库 cwd 不匹配，`rg/Get-Content` 报路径不存在；已根据 `rg --files` 与正确工作区转到实际 `sync_service.dart/content.service.ts` 等文件继续，只读命令失败未触发任何源码修复或依赖操作。
6. 未执行：真实 GET/POST/PUT/DELETE、后台/手机/手表、全量双时区、构建、安装、CI、推送投递、真实AI/支付/报告生成、Git commit/push。不存在本分工新增的“真机通过”声明。
7. 交付前 `git diff --check` 无输出；`git status --short --branch`/`git rev-parse HEAD origin/main` 复核基线未变。本分工仅新增本文；其他任务新增的设备记录和资料检查工具保持不动，未更新索引。

## 下一步

先由主任务汇总真机只读结果；单独授权后优先补 H01/H02 及国际消息 ID 契约，新增覆盖上述确定缺口的合成回归，再按独立测试账号完成端到端。保留本轮缺口与失败探查记录，后续修复追加结论，不把已通过的 187 项等同于已关闭这些缺口。

## 追加：H02 独立纯 mock 诊断复现

### 目的、基线和修改范围

- 主任务追加授权：用真实 `GlobalSaydianApiClient` + `AppController` 成功 GET 200 链路验证旧健康档案是否越过账号切换；如可行保留页面挂载进行 Widget 复现。不改运行代码，不操作手机/服务器，不使用真实账号或健康记录。
- 修改前再次 `git status --short --branch`、`git fetch --prune origin`、`git rev-parse HEAD origin/main`、`git rev-list --left-right --count HEAD...origin/main`：仍为 `619484c24fea57af9fe28122916de14ffcb5dc88`，0/0。其他任务 untracked 审计文件保留。
- 仅新增 `tool/audit_global_postlogin_health_test.dart` 并追加本文；没有改 `lib/`、现有 `test/`、索引或服务端。
- 此工具名称标明 **AUDIT**，放在 `tool/` 显式执行；断言记录当前缺陷，**不是安全回归通过**。运行时代码修复后应改为拒绝旧响应的正式回归，不把“缺陷断言通过”作为准入标准。

### 实际复现链路与结果

1. 内存存储、`MockClient`、不可调用的硬件 fake；API 客户端和 controller 均为原实现，没有继承覆盖请求、返回值或账号方法。`controller.initialize` 不调用，避免原生初始化；直接调用正常 `controller.login`，执行真实 API 登录解析、vault 持久化、账号 generation 变化和健康 owner 切换。
2. A 使用合成邮箱登录后开启档案 5 路 GET；`health/profile` 的 A 响应被暂存，另 4 路正常返回。对请求数量、方法、固定 HTTPS 域名/国际路径、禁止重定向，以及 4 个私有 GET 的 A Bearer 归属作断言；公开 `billing/offers` 无账号头。
3. 在 A profile 未返回期间，执行正常 `controller.login(B)` 完成，断言 controller 与 vault 都为 B；然后才释放 A 的 HTTP 200 profile。
4. **确定复现**：`loadHealthReportDashboard()` 仍正常返回 A profile 与 A 报告标记，B 会话未被覆盖。随后同实例发起新档案读取，正确返回 B，排除了“fixture 永远返回 A”或“偷偷把 session 改回 A”的解释。
5. **保留页面挂载的 Widget 层确定复现**：390×844 下真实 `HealthProfilePage` 先为 A 发起读取；正常 B 登录完成后释放 A 响应；页面 Element 保持同一实例，滚动后旧 A 报告标记仍可命中可见区域。B 报告标记不存在。
6. 所有捕获请求最终均为 HTTP 200，`auth/refresh` 为 0，硬件调用为 0；没有绕过 `writeSessionIfUnchanged` 或假造 401 来触发刷新路径。这里暴露的是普通成功读取缺少陈旧结果校验，**不是 refresh CAS 失效**。

| 探针 | 执行结果 | 证明层级 |
| --- | --- | --- |
| 同账号控制组 | 通过 | 原客户端/controller 在未切账号时正常接收自己的档案 |
| A 请求 pending → 真实 B 登录 → A 200 返回 | 缺陷复现 | 当前 B 会话能收到旧 A dashboard；新发请求仍正确归 B |
| 同一健康档案页继续挂载 | 缺陷复现 | 旧 A 报告标题实际呈现并可见，不仅是 API Future 返回 |

固定摘要输出仅包含 `case`、`reproduced`、`currentOwnerPreserved`、`lateOldOwnerDashboardReturned`、`freshReadUsesNewOwner`、`allResponses200`、`oldOwnerReportVisible`、`samePageMounted` 等布尔标记，不输出真实凭据、标识或健康值。

### 命令、失败原因和复跑

从 `F:/xcodeplace/saydian-app-global` 执行：

1. `dart format tool/audit_global_postlogin_health_test.dart`：格式化完成。
2. 首次 `flutter test --no-pub --reporter expanded tool/audit_global_postlogin_health_test.dart`：**2 通过、1 失败**。controller 缺陷已复现；Widget 夹具的异步 HTTP callback 调用 Flutter `expect` 与 `pumpAndSettle` guard 冲突，且 controller 的 30 秒关爱轮询 timer 仅在 teardown 释放，晚于 Widget invariant 检查。这是探针编排错误，不是 App 功能报错。
3. 仅修探针：HTTP callback 改用 `expectSync`；Widget 在结束前显式 dispose controller，保留幂等 teardown 兜底。复跑同命令 **3/3 通过**，其中 2 条为缺陷复现断言。
4. 补“切 B 后全新档案读取正确归 B”控制断言；一次 patch 因 formatter 已折行而匹配失败，未修改任何文件，重新读取准确上下文后应用。
5. 最终 `dart format tool/audit_global_postlogin_health_test.dart`：0 个文件变化；`flutter analyze --no-pub tool/audit_global_postlogin_health_test.dart`：**No issues found**，exit 0。
6. 最终重跑同测试命令：**3/3 通过**，exit 0；controller 摘要 `reproduced=true/currentOwnerPreserved=true/lateOldOwnerDashboardReturned=true/freshReadUsesNewOwner=true/allResponses200=true`，Widget 摘要 `reproduced=true/currentOwnerPreserved=true/oldOwnerReportVisible=true/samePageMounted=true`。

### 验收边界与修复建议

- H02 从“源码确定缺口、未专项复现”升级为“真实运行时方法 + 模拟成功 HTTP + retained Widget 的确定复现”。仍维持 **P1 未修复**，不能用先前 187 项或本次 3 个探针关闭。
- Widget 是专门保持健康档案页挂载并通过公开 controller 登录切账号；**没有声称复现完整 App 导航点击到换号的自然 UI 路径**，也没有真实手机上的跨账号数据显示证据。页面若先被销毁，原 mounted 防线会阻止显示；本探针明确只验证仍挂载的条件。
- 未验证 401、Token 刷新、真实服务端响应/权限、真实健康值、网络超时或支付，未发送真实 API 请求。模拟的 `billing/entitlements` 没有真实服务端 GET 的账本副作用。
- 后续最小修复应在 controller 档案读取前捕获 session/generation，并在所有返回前校验不变；页面应响应账号切换清空旧视图/取消旧结果，防止已有缓存或迟到回调呈现。新增正式回归要求 A→B/退出/销毁时旧结果被拒绝且旧数据不出现，而非只在返回后比对标题。同步检查 full/export 等同类读取，但本轮不扩权修改。
