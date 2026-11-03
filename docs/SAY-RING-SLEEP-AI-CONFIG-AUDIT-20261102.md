# R7 Ultra睡眠AI“尚未完成配置”排查

日期：2026-11-02。用户报告原可生成的睡眠AI报告，在连接R7 Ultra时提示未配置。范围是确认客户端请求和线上配置判定，未授权代用户勾选睡眠汇总上传、切换供应商、变更说明或删除记录。

## 真实回执

- App工作树初始d3c8972干净；fetch后只有文档更新435a421/3c49f41，已安全快进3c49f41。实际USB华为App是正式1.0.10(1225)，没有换包或解绑。
- 手机停在AI睡眠分析报告页，点击“生成AI睡眠评分与报告”复现“睡眠AI服务尚未完成配置”。该点击只到availability检查，没有进入上传同意弹窗，没有代用户接受或创建/重试报告。UI证据仅保存在Git外E:\SayRing-sleep-ai-audit-20261102，不上传健康数据或精确硬件标识。
- 公开GET /global/api/saydian-app/v2/support/app-display?product=say-ring&platform=android 返回sleepAiEnabled=true；hideAi=true与独立睡眠AI开关不同，不能用普通AI隐藏解释本错误。
- 公开GET /global/health/ready返回ready、revision=7f3e816d83568622668537bd3467c24247b797f5，与服务端origin/main一致。公开睡眠分析说明返回版本say-ring-sleep-qwen-2026-10-18-v1、zh-Hans，接收方为千问。

## 源码判定与边界

- APP sleep_ai_report_page.dart先调用getSleepReportAvailability，available非true时显示服务端reason；只有可用才显示主动上传确认。错误来自服务端，不是戒指型号能力或某个睡眠数值校验。
- 线上同源SleepReportsService将以下状态合并为providerReady：AI integration状态CONFIGURED、provider非disabled、服务地址与当前睡眠说明匹配。任一不满足均映射同一条“尚未完成配置”，所以仅凭提示不能断言Key丢失、余额不足、具体地址错误或接收方不匹配。
- 当前千问说明匹配代码仅接受https://maas.qianwenaiapi.com/compatible-mode/v1；智谱地址或其他未匹配地址会被拒绝。不能删除该校验、换回旧用户同意、任意开放地址或将真实健康数据发给其他服务方。
- 服务端E:\saydian h5原工作区已有他人未提交文档及法律材料，已保留，没有拉取覆盖或修改。只读fetch及git show读取origin/main；本机睡眠服务、同意读取和contracts源码与该revision逐文件diff一致。
- 本机无可直接使用的服务器SSH身份；已使用可信主机和BatchMode尝试只读id查询，返回Permission denied，无服务器写入。未抓取APP会话、读取密钥或绕过后台认证。
- 部分首次文件检索使用不存在的目录/文件名和PowerShell不支持的rg路径通配，返回找不到文件；改为真实目录/精确Git文件读取，未写源码或覆盖工作树。
- `pnpm --filter @saydian/app-contracts exec vitest run src/sleep-report.test.ts`20/20通过，含供应商/说明交叉拒绝及地址限制；只是合成契约回归，不是当前生产供应商调用成功。

## 尚需确认

- 初次诊断已询问当前服务地址、模型ID及是否换过服务商；用户随后提供后台截图并确认“没改过”。截图显示启用、已通过真实调用、https://maas.qianwenaiapi.com/compatible-mode/v1、qwen3.8-flash，与支持的千问地址一致，无须重填Key。
- 后续公开读取八种语言的睡眠说明：zh-Hans为当前千问版；en仍是say-ring-sleep-ai-2026-10-03-v1旧智谱版，其他语言无当前说明。服务端按账号locale优先选择造成明确缺陷，已有API/Worker合成回归分别复现“配置就绪=false”和当前授权被拒绝；该手机账号数据库locale未直接读回，最终需实际可用性确认。
- 已在独立服务端工作树修复为先选当前已发表说明版本、再选同版本语言；API及Worker共用策略，保留接收方、新版授权、撤回及生成期复核。相关单测与完整门禁通过，源码已推送服务端main：1b0fca6c724132b0fccd409c9f0fa990cc512670；CI41420381603正在运行，尚未宣称生产已生效。
- APP运行时代码、后台开关/模型/凭据、已发布正文和健康记录未修改，也没有发起真实供应商调用。服务端发布后先用当前APP验证可用性，再由用户主动确认本次睡眠汇总上传。上传/真实报告未完成时不记为生成成功。

## 18:17 发布进度与只读检查

- 服务端1b0fca6的CI verify成功，含Linux门禁及迁移/恢复检查；自动发布仍在受限SSH receiver步骤。根/global readiness仍为7f3e816，不能写已部署或已恢复。
- 用户本人在两次独立SSH窗口输入密码，命令执行后会话退出；第一次读取进程确认API镜像docker pull约17分钟，第二次读取Docker近30分钟日志只有info，没有错误或拉取完成记录。不读取或保存服务器密码，不改变生产服务/配置/数据。
- 后续汇总SSH检查被自动审批拒绝，简化为透明直接只读命令仍被拒绝；没有执行或绕过。改请用户在现有终端执行只读诊断。用户截图显示根盘69G、已用57G、可用9.7G(86%)；Docker tmp无匹配普通文件，该事实不能证明拉取失败或没有进展。未清理Docker、删除锁或重启服务。
- 本机App仓库git fetch两次返回Empty reply from server；保留工作区，未声称已再次同步，也未提交未核对的远端文档。API状态查询仍可用。
- 真实手机可用性和实际报告生成仍待部署后检查；没有勾选上传授权、创建报告或更换安装包。
## 2026-11-03 生产核验与后续文档同步

- 原发布41420381603的verify成功，生产部署任务因镜像拉取未完成而cancelled。备用原artifact HTTPS导入41474145938成功后，受保护流程才发起offline_images=true发布41483417714，resolve/deploy均success。
- 北京时间11月3日00:39辅助记录以及10:08实时复查，根与/global readiness均ready、revision=1b0fca6c724132b0fccd409c9f0fa990cc512670。睡眠AI服务端修复已上线，不要求为该修复单独重打App。实际手机availability及用户主动授权后的真实报告生成仍未验收，没有代勾授权或上传。
- 13:49本轮文档已私有备份和精确stash，工作树随后从3fd8ff0安全快进69f61ec；正文从原私有副本原样恢复，索引逐项保留远端新增记录。两次普通fetch的Empty reply已保留，后续HTTP/1.1 fetch实际成功，不能把初次失败记为已同步。未在原版本上覆盖远端运行源码。
- 本次按用户新指令从最新源码编译Android1230并覆盖华为，另见SAY-RING-ANDROID-SYNC-INSTALL-1230-20261103.md；睡眠报告真实生成仍须本人上传授权，不因安装1230自动完成验收。