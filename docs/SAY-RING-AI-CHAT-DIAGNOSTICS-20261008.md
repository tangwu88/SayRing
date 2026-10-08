# AI 对话失败提示与脱敏诊断

- 用户明确允许修正 AI 错误提示、服务端增加脱敏分类/耗时、更新后手机复测。此前真机捕获约 3 秒内的统一英文失败提示，不是 60 秒超时证据；历史已保存提问但没有回复。供应商准确原因仍未确定。
- App 基线 fetch 成功为 5946b581f473aff9f1b169e6e2850d76177907ac，干净构建工作树新建 codex/ai-chat-diagnostics-20261008。E:\SayRing 既有文档改动和旧基线保留。
- 修改 `ai_chat_failure.dart`、`app_controller.dart`、`pages.dart` 和测试：仅允许固定错误类别转明确提示；保留发送失败状态，将安全提示放入失败气泡。未知错误不显示原始响应，真实网络错误才提示检查网络；登录/权限、服务未启用、供应商鉴权、额度/限流、拒绝、繁忙、超时、连接失败、无效回复区分。
- 不读取/打印 Token，不更换模型或 Key，不修改会话、健康算法、设备连接、法律授权、睡眠分析或 H5。不自动重发提问，不伪造成功回复。
- 服务端实现和验证见独立 saydianserver 的 2026-10-08-ai-chat-safe-diagnostics 记录。历史客户端仍兼容；供应商原始内容不回传。
- 待补充 Android 正式包/签名、部署与真机回执。Windows 无 iOS 构建；原生鸿蒙有独立 AI 对话实现，本轮没有修改或验收该实现，也未构建新鸿蒙包。

- API 仅 AI 固定错误类别允许读取受限 HTTP 状态和 3–6 位数字服务错误码，严格校验后用于失败气泡。其它字段/原始 message 丢弃；不用读取 Token 即可真机确认类别。
- dart format 仅本轮八个文件；首次定向 41 通过/1 失败，因新增页面测试先发送失败再打开页面，被正常历史刷新清空。调整测试为先打开页面再发合成提问，不改生产历史刷新。定向完整 43/43 通过。
- Flutter analyze 无问题；全量测试 UTC 与 Asia/Shanghai 均 952/952 通过。首次 analyze 的四处大括号规则已修正，失败日志保留。首次 Android Debug 因 QRing Gradle 缓存完整性检查失败；停止构建守护进程后，仅将该准确缓存目录内可重建内容移到 gradle-quarantine，保留锁文件与失败日志，不更改 SDK 或关闭校验。
- Rebuild-SayRing-20261006.ps1 -BuildNumber 1015 -OutputDirectory E:\SayRing-market-artifacts-20261008\ai-1015 -ResumeBuild 成功，Debug/原生 32 项/正式 Release 均通过。Verify-SayRingAndroid 与 Verify-SayRing-20261006 验证 cn.saydian.ring、1.0.0/1015、production JPush、正式 RSA4096 原证书及双 ARM ABI；保留既有受控 JPush libjutils arm64-only 例外，不新增例外。临时 key.properties 已清除。
- APK 69,044,934 字节，SHA256 CA082FE8260BDBEB65A6E1FF9DE3A895CCEBADA269099E1000C9ED0931267931，仅保存在 Git 外。git diff --check 通过。服务端 4095410 的 CI verify 已通过，自动部署进行中；安装和最终手机回执待补，不宣称供应商联调成功。
- Android 1015 以 adb install -r 覆盖安装成功，华为安装风险确认已完成，没有卸载或清除数据。dumpsys 核对 1.0.0/1015，回读手机 base.apk 的 SHA256 与正式包完全一致，启动成功；没有操作戒指、健康检测、支付或发送验证码。
- 源码提交 c5e3096 已推送 SayRing 当前分支与 origin/main；服务端 4095410 已推送 saydianserver 当前分支与 main。Actions 37717399767 verify 与 auto-deploy/resolve 成功，auto-deploy/deploy 仍在运行；两处 readiness 曾核对仍为旧基线 f037228，未宣称部署或 AI 联调完成。
- 自动部署在服务器步骤运行超过 25 分钟，运行中日志 API 尚不可用；本机没有服务器 SSH 身份，浏览器控制组件不可用。已请用户在腾讯云终端执行仅查看 docker pull 进程的只读命令，等待确认具体卡点。没有盲目取消发布、重新开放写入、更换供应商配置或重复发送提问。
- 未验收：服务端新版部署成功与版本回读、新版服务端的 AI 真机安全错误码、真实供应商成功回复；iOS 和原生鸿蒙未构建/联调。错误提示修复通过自动测试，不等于 AI 已恢复。
- 后续并行任务在 main 增加 57d7abc（未覆盖，merge-base 确认包含 4095410 的 AI 修复），其 verify 也通过。仅取消本轮已被取代的 37717399767；已结束旧流水线的日志确认停在 Pulling runtime image api。最新 37719753485 发布失败，明确 Another release is running，线上仍 f037228；不能把 verify 通过写成整条 CI/发布成功。
- 已通过已有 Export runtime images 工作流 37720696923 导出最新已通过 verify 的原始镜像作为备用（upload_to_server=false），不导入、不重启服务、不修改数据库。旧服务器进程/发布锁尚需服务器端只读检查；没有强删锁、强杀未知进程或盲目重复发布。待用户提供准确 docker pull 进程信息或配置现有服务器诊断权限后继续。
- 最终回执（本轮只更新记录，不改源码/供应商配置）：用户终端截图的 docker pull 查询无匹配进程；重新核对 Deploy production 37725106453 已 success，双 readiness 均 ready/revision=57d7abc3218be208145975bd65a37abdb144c082，该提交包含 AI 修复。发布阻塞已解除，本轮未再次发布、未杀进程/删锁；未将其他任务的部署操作写成本轮执行。
- Git 首次直连 fetch 连接重置，使用本机既有代理重试成功；保留独立服务端分支与其他任务的后续 main，不覆盖。SayRing fetch 成功且基线 57fcbae 干净。
- Android 1015 真机仅发送一次简单“你好”，约 3 秒捕获明确 AI_PROVIDER_LIMIT、HTTP 429、providerCode=1113 的失败气泡和提示。智谱官方错误码 https://docs.bigmodel.cn/cn/api/api-code 定义 1113 为账户欠费；当次页面重新抓取超时，后续检索未命中，依据本次对话先前已成功读取的官方错误码表。真实根因已定位，不断言 AI 成功回复。
- 新版提示实机验收通过；没有调整 Key、模型、余额、会话/健康数据或重复发送测试。需用户处理后台 Key 所属智谱账户欠费后再获成功回复验收。iOS/鸿蒙仍未构建或复测。仅文档变更执行 git diff --check，无重新运行源码构建；1015 源码/签名保持原验证结果。
