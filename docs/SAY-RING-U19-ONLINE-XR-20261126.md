# Say Ring 1331 联网后复测 U19M

2026-11-26，基线 `d7bb52f`。用户确认中国站已连通后，在 iPhone XR 和同一枚 U19M 上重新读取设备已有记录。

## 真机结果

| 检查 | 结果 |
| --- | --- |
| 中国站读取授权 | 签名 Profile 的 Say Ring 进程请求实际配置接口返回 HTTP 200。血压、心率和血氧读取授权均生效。普通 1331 的设备页权限提示消失，同步进度可正常结束。 |
| 连接与日期 | 原登录账号保存的精确目标完成蓝牙握手和能力确认。日汇总日期与 XR 相差 0 天，表内日汇总有睡眠数据。 |
| 血压 | 两次完整历史读取各返回 2 条记录并正常结束。去重后共 2 条。其中 1 条与同一手表先前保存在 XR 的记录匹配，核对记录标识、收缩压、舒张压、脉搏和测量时间。另一条的两种时间解释均落在过去，现有证据无法判断实际时间，因此本次没有新增可确认的血压记录。 |
| 心率与血氧 | 两项各完成 3 次查询，每次收到手表明确的空历史结束包。当天没有这两项可导入的历史记录。 |
| 云端读回 | 使用 XR 当前会话独立读回已核对的血压记录，会员接口返回 HTTP 401。重新认证后才能核对云端数值及时间。 |

## 验证过程

- XCTest 运行器访问中国站仍返回 `-1009`。改用相同包名、同版本的签名 Profile 临时采集，使用 `tool/drive_ios_preserving_data.mjs`，网络和设备结论以 Say Ring 进程为准。
- 第一次采集到血压探测回包时，能力握手仍在进行，直接同步还未启动。增加就绪检查后重跑正常历史读取，再用同一只读消息处理器核对逐项回包、记录来源和时间。
- 补充云端状态采集时，临时探针将错误编号当作字符串导致首次编译失败。修正类型后签名 Profile 实机运行通过，取得真实 HTTP 状态。正常 1331 已覆盖恢复并启动。
- 报告只保存命令次数、样本数和一致性判定。验证使用手表已有记录。
- `flutter test --no-pub` 定向运行 U19 协议会话、云端读取恢复及 U19 历史读取共 81 项，全部通过。文档差异检查通过。

本轮证据保存在 `build/say-ring-u19-online-retest-20261126.lspmLleA/`。第三次设备采集详见 `xr-u19-online-retest-v3.json`，云端错误状态见 `xr-u19-online-retest-v4.json`。

## 英文邮箱注册排查

- 重新认证时，用户确认在英文界面无法用邮箱注册。中国站当轮版本为 `2d332feba0153593ba143bba233851296cfef77a`。只读请求 `/global/api/saydian-app/v2/auth/capabilities`，显式传 `product=say-ring`，对比 `locale=en` 与 `locale=zh-Hans`。
- 英文返回 `consentVersion=null`、`legal=null`，邮箱与短信注册和相应自动注册均为 `false`。两个英文专属文档的公开读取均未查到。简体中文返回两个已审核且已启用的 `say-ring-cn-2026-10-05-v3` 文档，邮箱与短信注册及自动注册均开放。公开能力中邮箱渠道可用表示投递渠道已配置，本轮没有验证真实邮件收件。
- `GlobalAuthService.requestCode` 在创建验证码挑战前查验同语言、同版本的已发布协议。缺少对应协议时返回 `legal_unavailable`。验证码登录、密码登录和创建账号也校验这一配套文档。补齐已审核的英文文档后，现有版本可重新获取注册能力。
- 对应生产提交的独立工作树运行 `global-legal.test.ts` 与 `global-auth.test.ts`，共 81 项通过。新增一次隔离夹具复现英文缺失、只有一份、尚未启用及版本不匹配四种状态，均未调用投递。两份合成文档同版本启用后，模拟验证码可以创建并登录新会员。App 登录、注册、协议及接口定向用例共 172 项通过。
- 独立工作树使用 `pnpm install --offline --frozen-lockfile --ignore-scripts`、`pnpm --filter @saydian/app-contracts build` 及 `pnpm --filter @saydian/app-api prisma:generate` 准备测试。首次 Vitest 启动遇到桌面进程内置 Node 与 Rollup 本机模块签名不匹配，改用已安装的 Codex 运行时 Node 后通过。Flutter 使用 `flutter test --no-pub --reporter expanded` 运行 `global_verified_registration`、`global_auth_consent`、`global_code_login_page`、`global_auth_page`、`global_legal_page`、`global_api` 六组。
- 两份英文稿依据现网中文正文翻译，保存在本机 `build/say-ring-english-registration-20261126.dToYLVOA/`。用户协议现网运营方文本为空，稿内标记待确认。发布前还需核对现行邮箱验证码、U19 手表等实际范围。草稿待审阅，线上英文注册尚未恢复，本轮未发送生产验证码。
- 最后一次 USB 检查至 XR 为 `unavailable`。云端血压需要 XR 原账号重新认证后核对。普通 1331 的安装与复测结果见上文。
