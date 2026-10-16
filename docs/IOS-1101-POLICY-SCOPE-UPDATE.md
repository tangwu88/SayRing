# Say Ring 1.0.2（1101）公开适用说明更新稿

目的：公开 `/say-ring/privacy`、`/say-ring/terms` 的旧 iOS 补充说明仍称“1062 起不提供自动健康监测或 AI 报告”，与本次用户已要求并验证的版本不一致。本稿只更新 Say Ring 的版本适用说明及睡眠独立说明的版本提示，不改已发布协议正文、同意版本、处理者、联系方式、保存期限、用户权利或其他产品。不创建或更改任何账号、业务或健康记录。

发布位置：saydianserver 的 `apps/api/src/content/say-ring-legal-page.ts`，并更新对应内容测试。用户已明确批准“允许发布 Say Ring 说明并继续送审”；本稿用于服务端 `5d1f102343260fa8311934feda86047a55dbd689`，2026-10-17 01:10 CST 的生产回读已确认两页展示 1101 适用说明，全部已发布协议/睡眠授权 article 及版本与发布前逐字一致。具体 CI、部署和审核回执见 [1101 交付记录](SAY-RING-APPSTORE-1101-20261017.md)。

## 中文适用说明

本说明区分 Say Ring iOS 的实际构建范围，不表示某构建已经通过审核或上架。Android 和此前版本仍按各自实际功能适用下文政策。

iOS 构建 1062 至 1064 的已发布活动与睡眠版本，可展示和同步的戒指记录限于步数、距离、热量、睡眠阶段与时长，不提供生理指标测量、展示或同步，不提供自动监测设置、疾病风险评估、设备睡眠评分或 AI 报告，也不触发睡眠 AI 数据上传。

本次 1.0.2（构建 1101）继续仅展示、同步活动与睡眠数据；不提供手动生理测量、生理数据展示/同步、医疗预警、疾病风险评估、设备睡眠评分或通用 AI 咨询。兼容戒指可按真实能力设置手势模式、固件自动监测开关及监测间隔；设置自动采样不代表 App 提供临床测量或医学准确性承诺。

构建 1101 的账号用户在服务实际可用时，可单独选择睡眠 AI 参考评分及作息建议。生成前须阅读并单独同意当前睡眠分析说明，再明确确认本次睡眠摘要上传。服务端按下文已发布的独立说明向智谱 BigModel（北京智谱华章科技股份有限公司）的 GLM 服务发送选定睡眠摘要，不发送姓名、联系方式、头像、App 账号标识、设备 UUID/MAC 或原始逐段睡眠时间轴。AI 输出可能不准确，属于作息参考，不是设备评分或临床评估。拒绝不影响本机记录查看，游客不上传睡眠数据用于 AI 分析。

游客记录留在本机；账号同步及活动/睡眠远程关爱仍按实际功能及相应授权处理。升级不删除原有本机或云端记录，未展示的历史生理记录不表示已经删除。本说明不改变处理者 Xuewu Tang、联系邮箱 kf@saydian.com、保存期限及访问、删除、撤回和注销权利。作出任何医疗决定前请咨询医生。

睡眠独立说明提示替换为：以下独立说明适用于实际提供可选睡眠 AI 的版本，包括本次 iOS 构建 1101；iOS 构建 1062 至 1064 的已发布活动与睡眠版本不提供此功能。是否可用仍取决于实际功能、服务配置与单独授权。

## English scope notice

This notice distinguishes actual Say Ring iOS build scopes; it does not claim review approval or App Store availability. Android and earlier releases remain subject to the policy below according to their actual features.

The published activity-and-sleep editions, iOS builds 1062 through 1064, display and sync only steps, distance, calories, sleep stages and duration. They do not offer physiological measurements, display or sync, automatic-monitoring settings, disease-risk estimates, device sleep scores or AI reports, and do not initiate sleep-AI uploads.

Version 1.0.2 (build 1101) continues to display and sync only activity and sleep records. It does not offer manual physiological measurements, physiological data display/sync, medical alerts, disease-risk estimates, device sleep scores or general AI consultation. Compatible rings can expose actual gesture modes and firmware auto-sampling switches/intervals; configuring sampling is not a clinical measurement or accuracy claim.

When the service is available, signed-in build-1101 users may separately choose an AI sleep reference score and routine suggestions. They must read and separately accept the current sleep-analysis notice, then explicitly confirm uploading the selected summary for that request. As explained in the published independent notice below, the service sends the selected sleep summary to Zhipu BigModel (Beijing Zhipu Huazhang Technology Co., Ltd.) GLM, without names, contact details, profile photos, App account identifiers, device UUID/MAC or raw sleep segments. AI output may be inaccurate and is routine reference, not a device or clinical score. Refusing does not affect local records; guest mode does not upload sleep data for this analysis.

Guest records stay local. Account synchronization and authorized activity/sleep remote care follow the actual supported scope and corresponding consent. Upgrading does not delete existing local or cloud records; hidden historical physiological readings have not thereby been deleted. The controller, contact, retention periods and access/deletion/withdrawal/account-closure rights below remain unchanged. Consult a doctor before making medical decisions.

Independent sleep notice introduction: The notice below applies to versions that actually offer optional sleep AI, including iOS build 1101. Published activity-and-sleep iOS builds 1062 through 1064 do not offer this feature. Availability still depends on actual features, service configuration and separate consent.
