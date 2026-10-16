# Say Ring 1.0.2（1101）TestFlight 与 App Store 交付

**最终苹果状态（2026-10-17 01:11 CST）：TestFlight 外部审核已提交、正在等待审核；App Store 1.0.2（1101）已提交、等待审核。公开版本说明已在实际使用的域名上线并核验；尚未获批或上架。**

## 授权、基线与功能范围

- 用户要求把本次已验证版本更新至 TestFlight，并提交苹果审核；随后明确允许仅发布 Say Ring 的版本适用说明后继续送审。
- 产品源码基线 `9abbf4a278fdadb7bde5eb2b9a5046acd0a87c5f`，功能代码提交 `ae86c46e4fd6e1e288924fd247772925d6f0ab6b`。归档前已核对 main/origin/main；本次没有修改产品运行代码、Android 版本或下载页。
- 本次商店版本为 **1.0.2（1101）**，Bundle `cn.saydian.ring`，原 Apple 团队 `W7SXQ4A226`，iPhone / iOS 15 起。通过构建参数设置版本，不改继承的 pubspec 默认版本。
- 包含 QRing 能力门控的手势设置、最新优先与按日期选择的睡眠页、专用睡眠 AI 授权与本次摘要上传确认、兼容戒指的固件监测开关/间隔，以及最新名称路由和同步修复。生理指标展示/同步、手动测量、医疗预警、疾病风险、通用 AI 和设备睡眠评分继续关闭。AI 可以提供独立的睡眠参考评分，不将其说成设备或临床评分。
- 上一轮完整回归和真机失败/修复记录保留在 [QRing 手势](SAY-RING-QRING-GESTURE-20261017.md)、[睡眠与监测](SAY-RING-SLEEP-MONITORING-20261016.md)。Flutter 双时区各 1259、Node 37、Android 原生 53、Harmony 20、发布 Python 35 均通过；最终 1099 Profile 的 R21 真机 11 阶段通过，用户另行确认实际音乐手势能控制。其他型号/模式/目标 App 和第三方 AI 生成未全部实物验收。

## 归档、分发与上传

串行执行正式 `lib/main.dart` Release，`--no-pub`，`--build-name=1.0.2 --build-number=1101 --dart-define-from-file=config/ios-app-store-no-push.json`。先 Flutter `build ios --release --config-only`，再 Xcode Runner Release / generic iOS archive，使用自动签名与已批准的 iOS 15 覆盖配置；由同一 archive 导出 App Store Connect 包并上传。没有测试入口、QA 恢复参数或测试账号构建覆盖。

- Flutter Release 配置：7.8 秒，退出码 0。
- Xcode archive：63.8 秒，`ARCHIVE SUCCEEDED`，Bundle / 版本 / 团队与严格签名核对通过。
- App Store Connect export：150.1 秒，`EXPORT SUCCEEDED`。导出 IPA 严格深验签通过，实际为 Apple Distribution，`get-task-allow=false`、`beta-reports-active=true`，无开发设备列表或企业 Profile。
- 已验证的本机导出 IPA：38,059,191 bytes，SHA-256 `db3a05103e5a5ba5b882f2a2045cff8ff446c3872bda49b6082d417aa6c67bf5`。此哈希对应本机导出文件；上传由同一归档再次执行 destination=upload，不宣称上传重导出与该文件逐字节相同。
- 上传：232.8 秒，退出码 0，Xcode 明确 `Uploaded Runner` / `EXPORT SUCCEEDED`；苹果页面显示 2026-10-17 00:53 CST 收到 1.0.2（1101），初始状态“正在处理”。没有重复上传。
- 上传有 15 条厂商框架 dSYM 缺失警告（含 RTKLEFoundation / RTKOTASDK 等）；不阻止包上传，但会限制这些框架的崩溃符号化。未将此写成零警告，也没有修改闭源 SDK。
- 私有构建日志、签名 Profile、安装包及包含设备/会话信息的材料只保存在忽略目录；不进入公开 Git。

## 商店资料与公开说明

- 先确认线上已发布版本为 1.0.1（1064），创建独立 1.0.2 草稿；不撤回、替换或删除已发布版本。
- [商店描述](APP-STORE-DESCRIPTION-1101.txt)、[更新说明](APP-STORE-WHATS-NEW-1101.txt)、[审核备注](APP-REVIEW-NOTES-1101.txt) 已通过 App Store Connect 原生表单保存，并逐项回读全文一致；沿用既有审核登录和联系信息，不在 Git 或日志保存凭据。继承现有截图、销售地区及审核后自动发布选项。
- 公开隐私/协议页原有“1062 起均无监测或 AI”提示与本次范围不符；先准备 [中英文适用说明](IOS-1101-POLICY-SCOPE-UPDATE.md)，用户明确批准后才触发服务端生产发布。
- 服务端基线 `e22b7f9355ff2cf0b7f5abb6b96361eadd2faaf9` 已在国内与 global 两个 readiness 实际运行。变更仅 Say Ring HTML 版本提示、对应测试和实施记录；不修改已发布文档正文/同意版本、不写健康或账号数据、不新增迁移。
- 服务端定向内容测试首轮 15/16（旧英文单复数期望），修正断言后 16/16；全部五个根门禁通过：api:docs:check / tools:test / typecheck / test / build。API 1167 通过、34 数据库用例本地跳过；实际 PostgreSQL 与容器检查另由 CI 执行，不把本机跳过视为通过。
- 原生 Git HTTPS 推送因本机无凭据失败，保留本地 checkpoint；通过已授权 GitHub 连接推送完全相同 Git tree，无强推。服务端主线提交 `9a8e98fe86b8e6c85370351e9ae3f234889537cd`，tree `d2904d8408f6f3891fdc61cb943f4466c479e397`；fetch 回读一致、工作树干净。
- 服务端流水线：[CI #177](https://github.com/tangwu88/saydianserver/actions/runs/38935667023)。推送、CI、实际部署和公开页面回读分别核验，最终回执追加如下。

- CI #177 的真实 PostgreSQL 与 API 检查通过，但 HTTP 脚本仍要求旧“仅 Android 或历史版本提供睡眠 AI”文案而失败，因此生产部署正常跳过。只修正这条旧期望并增加 1101 / 1062–1064 范围断言，再次完整通过五个根级门禁。修复提交 `5d1f102343260fa8311934feda86047a55dbd689`（tree `dccb3adb61d9cc774126b85fb2626377cfc27867`）；原生无凭据推送再次失败后，通过 GitHub 连接发布相同树并保留本地 checkpoint。服务端干净 main 与远端一致。
- [CI #178](https://github.com/tangwu88/saydianserver/actions/runs/38936731106) 后续已通过实际 PostgreSQL、API 启动和 HTTP **202 项**断言，并继续容器/部署门禁；未绕过原失败检查。
- 苹果完成 1101 处理，构建 ID `3ca2cdd5-9994-4be6-b464-aadd5250e80d`。沿用既有用户确认的标准算法（含 SQLCipher）、非专有算法及不在法国分发范围，保存出口合规；没有选“不属于上述算法”，不改算法或销售地区。
- TestFlight 测试内容已保存为本次更新说明，独立 Beta 审核备注已保存并全文回读一致，补齐既有公开隐私 URL；原审核账号/密码/联系字段未更改。选择原真机内部组与原公开外部组，明确关闭“自动通知测试员”；待生产说明验证后才提交外部审核。
- App Store 已选择并保存 1.0.2（1101），原生“添加以供审核”校验通过，进入 **01:04 CST 的草稿提交**；尚未点击最终提交按钮。App 隐私现有 13 类声明包含身份关联的健康/健身及 App 功能/个性化用途，本次未减少声明。App Store 只配置简体中文商店语言；未擅自新增地区或其他语言资料。

## 最终回执

等待服务端生产发布后追加；本检查点已确认苹果处理与商店审核草稿，但尚不证明 TestFlight 外部审核或 App Store 已提交。01:08 CST 提前只读线上探针仍返回 e22b7f9，因此没有点击最终送审；此时 CI verify 已成功，部署分支刚启动。

- **生产说明：01:10 CST 核验通过**。CI #178 的 verify 全部成功（5 分 24 秒），真实容器和备份/恢复门禁通过，`auto-deploy / deploy` 成功（1 分 22 秒），统一生产 revision `5d1f102343260fa8311934feda86047a55dbd689`；既有业务开关保持，部署日志确认没有待执行迁移。
- HTTPS 只读验证 `/health/ready` 与 `/global/health/ready` 均 HTTP 200、ready、database ok，revision 均为 5d1f102。`/say-ring/privacy` 与 `/say-ring/terms` 均 HTTP 200，包含 current-build=1101、旧 1062–1064 边界及 2026-10-17 说明。
- 与发布前私有副本比较全部 `<article>`：隐私政策、用户协议版本仍为 `say-ring-cn-2026-10-02-v2`，睡眠独立授权版本仍为 `say-ring-sleep-ai-2026-10-03-v1`；三段正文及版本标记逐字一致。本轮只替换外部版本提示，没有修改已发布协议或用户同意数据。
- **TestFlight：01:11 CST 已提交外部审核**。1101 列表实际回读“正在等待审核”，关联既有 `Say Ring 真机验证` 内部组和 `SayRing public` 外部组，自动通知测试员关闭。原公开链接 `https://testflight.apple.com/join/k9Uye5C6` 保留；尚未宣称 1101 已可公开安装或通过 Beta 审核。没有添加新邮箱邀请。
- **App Store：01:11 CST 已提交审核**。最终操作后苹果返回“已提交 1 个项目”，进入提交详情再次回读 iOS App **1.0.2 / 1.0.2（1101）/ 等待审核**。提交 ID `1fc2e3a7-d501-4d87-913a-003c23fc5a2e`；沿用审核通过后自动发布，不承诺审批结果或时间，不撤回当前已上架 1064。
- 两个等待审核页面已保存可用截图，仅保存在忽略构建目录；正式审核详情没有审核账号密码字段，截图已人工查看，清晰显示 Say Ring、1.0.2（1101）和等待审核。
- 物理手机继续保留此前正常 main 1100 调试会话；此次没有为上传而卸载、重装或改动用户绑定/健康记录。1101 的 TestFlight 真机安装仍未执行，不把先前 Profile/Debug 真机验收等同于 App Store 分发安装。

- 独立美国站任务：CI #178 首次的 `auto-deploy-us / deploy` 在 SSH banner exchange / port 22 超时，退出 255，因此首次整个 workflow 显示失败；不能将国内生产部署成功说成所有地区 CI 全绿。只重试该美国 job（attempt 2，job 117097705498），不重跑已成功的国内部署或验证。01:16 CST 该重试仍在受限 SSH receiver 阶段，本机另行只读访问 `app.saydian.com` 的两条 readiness 均 TLS 握手超时，尚无美国站完成证据；未修改 SSH、网络、密钥、业务开关或数据。Say Ring 本构建实际请求的 `app.saydian.cn/global` 与公开 `app.saydian.cn/say-ring/*` 已独立验证新 revision，苹果审核提交已被接受。美国任务的后续最终状态以 Actions 回执为准。

- Git 交付检查：本轮 SayRing 只增加上述商店资料、获批说明和发布回执并更新索引；没有修改产品运行代码，所以沿用已通过的完整回归，不为文档重复构建或安装。`git diff --check` 与六个显式文件的 `git diff --cached --check` 均通过；通过已授权 GitHub 连接发布与本地完全相同的 Git tree，使用当前 main 的 SHA 作租约、不强推，最后 fetch 验证；回执存本机忽略目录，不把密码、真实健康记录或安装包加入 Git。
