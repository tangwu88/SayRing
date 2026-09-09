# Harmony 国际版实施与测试记录 — 2026-09-09

## 本轮边界与基线

- 工作区：`F:\xcodeplace\saydian-app-global`，独立国际版 clone；阶段基线 `06bf2a6`。主任务已获取 upstream 并合并新版 Harmony 分支，保留 main 报告代码及双端蓝牙修复。本子任务只修改 `harmony-native/**`，未提交、未推送。
- 开始前已读根 AGENTS、CHANGE-TEST-LOG 最近记录、BUG-RETROSPECTIVE、REGRESSION-CHECKLIST。后续同事先查看 Git 状态和本记录，再按根 AGENTS 安全更新；工作树不干净时不得覆盖。
- 这是可继续开发的阶段交付，不是三端发布完成：尚无本轮 Harmony HAP、模拟器/真机、母语排版验收。

## 修改与原因

1. **国际身份隔离**：bundle `cn.saydian.app.global.hm`，名称 `Saydian`；会话别名 `saydian.global.harmony.session.v1`，健康库 `saydian_global_wearable_health.db`，语言首选项 `saydian_global_preferences`。不导入国内会话/健康库；不读取或迁移真实用户数据。
2. **国际服务地址**：所有正常、上传及旧系统兼容 HTTP 统一经过 `internationalUrl`，使用 `https://app.saydian.cn/global`；新账号、资料、报告、更新调用 V2。保留已存在业务 V1 兼容路径，但只发送到全球独立实例，不等于已完成全量 V2 迁移。
3. **账号**：邮箱优先，国家/区号选择，JSON 登录、验证码 challenge、注册、找回密码。ID 保留 UUID 字符串、过期时间按 ISO UTC 解析；不将 UUID 强转整数。密码按服务端至少 8 字符、至多 72 UTF-8 字节校验，包含中文/emoji 测试。
4. **法律与渠道门禁**：注册使用 capabilities 的真实已审核 `legal` 与 `consentVersion`，匿名读取 V2 法律正文；缺文档或版本改变时不注册。重新读取后须重新勾选同意。找回密码独立使用 `recovery`，不被新注册法律文档门禁误拦；登录不依赖 capabilities。
5. **国际第三方能力**：国内 AGC client ID、微信 App ID、JPush key 不再用于新包；支付、微信登录、推送默认禁用，未取得国际配置前不初始化推送、不索取相关权限、不伪造支付成功。原支付回调代码保留，测试只注入明确的 synthetic ID/开关。
6. **语言**：英文首次默认，8 个语言选择持久化，不调用手表语言命令。复用 Flutter ARB；新增通用短文案、关键账号/隐私文案、英文长说明回退。用户姓名、聊天、文章、报告原文保持原文，不交给公共翻译服务。
7. **客服与更新**：国际客服不再默认展示/拨打国内 400 电话、复制国内公众号，提供现有真实反馈入口。更新改为 V2 `/support/app-update`，校验 `realm=global`、独立包 ID、`/global/down/files/*.hap` 路径和哈希元数据；无发布配置报不可用，不回退国内包。
8. **报告阶段**：新增账号设置中的真实 V2 报告列表/全文读取，UUID 校验、页面/账号/请求代际保护、退出清空。服务端报告正文原样展示；生成、付费、导出尚未接入 Harmony，本页明确说明，不伪造可用或成功。

## 文案覆盖证据（16:17 CST 重新核对）

运行 `node tools/audit-global-locale.mjs`：

- 8 locale：en / zh-Hans / zh-Hant / de / fr / es / ja / ko。
- 559 条有 8 个语言值的语义行；其中 311 条通用短文案为机器辅助初稿，英文与“安装到手表、保存、订单待付/待发/待收、关爱”等歧义词已校正，仍需母语人员与真机排版验收。
- Index 的单引号中文静态字面量 651 项，英文查表/回退覆盖 651，未覆盖 0。
- 其中 260 项长说明对尚未补齐的非简中语言明确回退英文，不称完整 8 语翻译。
- 此扫描不是 UI 渲染覆盖率：动态模板、原生回调字符串、服务端文章/报告/通知仍须独立审查。服务端报告 PDF/生成模板和通知正文仍主要中文，已与服务端同事确认未验收。
- `tools/translate-ui-draft.mjs` 只含预先审核的通用 UI 短文案白名单，只有手动调用才联网；没有读取源码、日志、真实帐号或健康记录再上传的逻辑。它不是构建步骤，不应自动运行。

## 测试命令与结果（失败保留）

工作目录均为 `harmony-native`，Node 使用 `D:\Program Files\nodejs\node.exe`。

| 顺序 | 命令/检查 | 结果和处理 |
| --- | --- | --- |
| 1 | `node --test tests/*.test.mjs` | 初次 GlobalAuth 的类型被作为值导入，主机运行失败；改为 type-only imports，未删测试。 |
| 2 | `node --test --test-reporter=spec tests/*.test.mjs` | 441 项，412 通过、29 失败。主要为旧域名、旧包名/第三方身份、增加翻译包裹后的源码结构预期；并发现通用素材域白名单仍为旧域名，已修复。 |
| 3 | 同上 | 441 项，427 通过、14 失败。保留布局断言，通过测试专用只读 wrapper 解包器比较原表达式；国际客服改反馈入口、名称改 Saydian 后更新对应预期。 |
| 4 | 同上 | 441/441 通过，保留 BLE/运动/账号并发/商城等既有测试。 |
| 5 | `node --test tests/global-auth.test.mjs` | 新增首批 14 项全部通过。 |
| 6 | 首批加国际恢复独立门禁、报告 UUID/原文测试 | 16/16 通过。 |
| 7 | 全量 `node --test --test-reporter=spec tests/*.test.mjs` | **457/457 通过**，0 失败、0 跳过。最后一轮含语言英文回退、真实邮箱资料与报告清空。 |
| 8 | 见下方 TypeScript 命令 | **通过**，覆盖新增纯 TS 模型与 AccountClient；不替代 ArkTS/HAP 编译。 |
| 9 | `git diff --check -- harmony-native` | **通过**；仅 Windows Git LF/CRLF 提示，无补丁空白错误。 |
| 10 | `node tools/audit-global-locale.mjs` | 559 语义行、651/651 英文静态字面量覆盖、260 英文回退；动态与服务端正文未假报覆盖。 |

纯 TS 检查（使用已存在的服务端仓库 TypeScript，不安装大工具）：

```powershell
& 'D:\Program Files\nodejs\node.exe' 'F:\xcodeplace\saydian-server-global\node_modules\typescript\bin\tsc' --noEmit --skipLibCheck --target ES2022 --module esnext --moduleResolution bundler entry/src/main/ets/model/GlobalAuth.ts entry/src/main/ets/model/GlobalLocale.ts entry/src/main/ets/model/GlobalConfiguration.ts entry/src/main/ets/model/GlobalUpdate.ts entry/src/main/ets/model/GlobalHealthReports.ts entry/src/main/ets/services/AccountClient.ts
```

执行过程中还保留以下开发工具问题结论，避免后续重复：
- PowerShell 中 `rg services/*Payment*`、其他未展开的路径通配符会被作为非法路径；改为显式文件或 `rg --files`。
- 大型 JSON 将 UI 全文件与全部 ARB 合并输出会被工具截断，解析失败；拆为 ARB、局部源码读取，未把截断结果写回。
- 巨型 apply_patch 对同一早期锚点反复插入会找不到上下文；拆为独立资源文件、按源码顺序补丁。失败检查后才继续。
- 第一批按中文短词机译把 watch 误作“观看”、saving 误作“省钱”，未采用为最终英文；先人工校英文，再生成通用多語初稿，并逐项修正关键歧义。不可盲信机器译文。

## Native 构建与设备边界

本机按父任务要求检查了已存在环境而非只看 PATH：

- 枚举 `D:\Dev`、`D:\program`、`C:\Program Files\Huawei`、`D:\Program Files\Huawei`、`F:\Program Files` 及用户 AppData Huawei/DevEco 目录。
- `Get-Command hvigorw,hvigor,hdc,ohpm` 未找到命令。
- 用 `rg --files` 定向查 `hdc.exe / hvigorw* / hvigor.js / ohpm*`，覆盖 `D:\Dev`、`F:\Codex\home`、Huawei 安装目录和既有本地调试环境，未找到可执行工具链。
- 仓库旧 Harmony 构建记录提到 macOS DevEco 工程，不代表当前 Windows 存在可用 SDK。
- **本轮未执行 HAP 编译、签名、安装、真机蓝牙或 8 语截图验收。** 未新装 SDK，未读取任何证书/密钥，未复用国内签名或 AGC 身份。

## 下轮必须先看

1. 用真实国际 API 的 reviewed legal + 已配置邮件/SMS供应商做端到端注册/找回；当前均为 synthetic transport 测试，不代表生产服务已发布。
2. 同日后续已补报告生成、真实版本健康分析说明/明确同意/撤回、失败重试和真实PDF下载选择保存，详见 [报告专项记录](GLOBAL-REPORTS-20260909.md)。仅真实已有权益可生成，购买未开放；477项主机测试通过，但原生编译/实机保存及真实服务端流程仍未验收。
3. 补齐 260 条英文回退为 reviewed 8 语，以及动态模板/回调/通知、原生系统提示与服务端正文；检查所有输入/国家选择长文本和 1.5/2.0 字体。
4. 真正 DevEco/SDK 环境进行 ArkTS 校验及独立 bundle 的无签名/签名构建；正确国际 AGC/推送/支付材料到位后才能开启对应功能。
5. V1 兼容模块（商城、地址、关爱、文章等）仍保留原 ID/字段语义，并指向 global 实例；需逐模块按 V2 正式迁移。旧健康同步已在国际模式阻断，真实本地数据保留pending，未冒充V2成功上传。现有国家选择只覆盖本轮支持的 20 国/地区目录，未涵盖全世界。
6. 移交时本文件、测试和源码一起提交；不要提交下载包、构建目录、截图、临时 SDK 检查输出或真实用户数据。
