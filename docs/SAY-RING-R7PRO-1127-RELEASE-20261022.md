# R7 Pro复测与1127发布（2026-10-22）

基线930ecda4262f05010aa409376c1dd7d3fe9a328b，开发分支codex/qring-visual-refresh-20261021，开始工作区干净；fetch/prune、ff-only一致。已读AGENTS、国际交接、回归清单/复盘及1125/1126最新记录。用户最新明确要求连接R7 Pro再次调试、通过后构建新版本并提交苹果审核，取代此前暂停提交；不由此推定可改变法国销售范围或签署新协议。

## 现场与初轮

XR在线，15 Pro Max当前不可用，故继续指定XR原owner/目标测试。先完整私有备份appDataContainer（build/r7pro-release-1127-20261022/before-private，Git忽略）成功。随后尝试从备份读取Library/Preferences/cn.saydian.ring.plist，文件不存在；不猜绑定或从旧报告冒认新连接。生产lib/ios/android及HR05专项脚本相对61b3fe7无变更，冻结1126测试binary重新严格验签、包名/版本/XR描述文件及App.framework哈希核验通过后，经保数据wrapper执行。

首轮旧测试默认HR05，真实记忆目标名称为R7PRO，型号断言失败退出1；失败发生在任何设置写入之前。备份、正常main1126原位恢复与启动均成功，未卸载。此前HR05物理提醒结论不移用到这枚R7 Pro。随后用已有SAYRING_QA_MODEL=R7Pro精确模型参数重新生成独立测试Profile1126，不放宽目标/owner/SDK门禁；config13.9秒、开发签名26.9秒、严格验签/XR包含均通过，正在真实专项验收。

用户已恢复苹果后台认证。实时Say Ring/App6816549943，已上架1.0.4(1120)，TestFlight最新1.0.5(1125)仍缺出口合规，未有1126/1127，拟新构建1.0.5(1127)。账号首页另提示Account Holder需接受更新的Paid Applications Schedule；不擅自接受法律协议。法国标准加密文稿要求需按实时UI和既有SQLCipher/TLS实际范围完成，不用“仅Apple系统加密”绕过；苹果官方说明：https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption。

后续追加真实设置恢复、实际触发、回归/归档/发行验签、苹果上传/处理/合规/审核各自回执；不能把构建上传或SDK ACK当作审核提交、批准或物理提醒。

## R7 Pro专项与用户实际提醒确认

重新指定R7Pro后通过十六项检查：首页、睡眠日期切换、我的/设备、原owner精确目标真实握手、手势图形说明只读、已保存活动/睡眠快照、来电原值读取/改变新鲜回读/恢复、消息实际或未知状态、久坐开关回读/原日程恢复、共享频率新鲜回读/原值与全部开关恢复、来电设置页。该枚戒指有一条既有闹钟，仅读取保留，未为测试替换用户日程，所以不沿用HR05空列表时的十八项计数。来电原true恢复true，心率/血氧共享间隔原30分钟恢复30分钟；消息系统通知授权true，但固件没有enabled实际读值，保留未知、不由脚本擅改。末态syncBusy=false、error=null，正常main1126已原位恢复。

随后用户用另一手机给XR拨电话、发送微信，明确回复“来电和消息都能提醒”。这补齐本次R7 Pro真实执行效果；不移用HR05旧结论，也不扩大为久坐/闹钟的定时触发或完整监测周期精度。现有生产源码未改，1390双时区、Android双ABI Debug/QA Release、iOS Debug/Profile和原生门禁沿用930ecda/61b3fe7已验证同源结果；本轮新增Release1127正常main归档/发行导出验证，未把测试入口用于商店包。

实时App信息页只有加密文稿上传入口、无已批准材料；标准算法问卷选择法国分发为“是”即要求先批准文稿。价格与销售范围实时175个可供应列表确实含法国。尚未保存加密问卷，也未修改销售范围；不将旧“法国不可售”记录作为当前事实。用户最新送审授权不等于暂停法国供应，若需要此方案须单独明确选择。

R7Pro实测保数据drive105.6秒退出0，之后私有备份0.7秒、正常1126安装5.7秒、启动0.2秒均成功。Release1127首轮config15.3秒通过，但归档16.8秒退出65：生产校验要求在既有“iOS JPush停用”发布范围下显式传入一个空Dart JPUSH_APP_KEY，本轮遗漏该定义，未生成可发行归档。按原1125已批准无JPush方案补--dart-define=JPUSH_APP_KEY=，不改脚本门禁/推送权限/ANCS提醒或线上配置。失败日志保留，第二轮独立-v2归档路径继续构建，不复用旧包。

第二轮config13.2秒、归档42.1秒、发行导出92秒全部退出0。实际IPA为cn.saydian.ring、1.0.5（1127）、团队W7SXQ4A226、云管理Apple Distribution签名，get-task-allow=false、APS生产、关联域名正确，App与Runner dSYM UUID一致。38,727,766bytes，SHA-256为42eb3cc013107b3cc07945866c8a54cd57dbbcdb6d8eeccf95e15226a63bcef8。首轮证书核验命令误把codesign提取证书前缀写成分离参数，改--extract-certificates=<prefix>后以openssl证书主体复核；不以缺少Authority文本误判发行签名。

1127上传176.1秒退出0，App Store Connect已处理，构建ID2b0de6f7-8551-48f1-9591-72f69b22ce6d，状态“缺少出口合规证明”。没有宣称已送审或获批。随后用户新增首次绑定清空要求，新功能改用1128，未将1127当成包含该功能的最终版本；见首次绑定实施记录。
