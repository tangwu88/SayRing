# Harmony 与 Android 最新调整对齐：1.0.7（1187）

## 范围与基线

用户要求“鸿蒙这边根据安卓最新的调整同步调整下，然后打包正式包”。工作目录为 `E:\SayRing-market-release-20261005`，仓库 tangwu88/SayRing；初始工作区干净，当前开发分支 `codex/login-camera-r7ultra-1136-20261024`，fetch 后本地和远端均为 ec1cb582dba8b09848e3ab690059c3e3caee0aee。Android 最近正式包为 1.0.7（1186），本轮仅改原生 Harmony，不重新生成 Android、不提交苹果审核、不发布下载配置、不修改后台/数据库/main。

延续用户已确认的边界：目前没有 QRing/LuckRing 原生鸿蒙 SDK，只对齐可实现的页面、账户及后台业务。不能通过名称识别或旧健康记录伪造当前设备能力；不把表协议用于这些戒指，不宣称测量、连接或手势已经原生接通。

## 实现

- 登录默认手机号/邮箱加密码，保留验证码切换。密码参数严格使用 Android V2 的 channel/identifier/password/product/locale/consentVersion/consentAccepted 契约；验证码继续使用已部署的两个国际版商城共享认证接口，不扩大其他路由。验证码必须有公开 explicitRegistrationCodeLogin 授权，新用户自动注册提示只随 smsAutoRegistration 显示。
- 注册必须完成手机号或邮箱验证码验证，并输入密码及确认密码；不使用旧未验证注册入口。保留用户协议、隐私政策与明确的14周岁确认、过期/账号切换/退出防晚回包保护。成功登录返回健康首页并清除已使用密码/验证码/challenge。密码长度错误提示具体原因。
- 首页加入步数/距离/热量三环今日活动、活动目标、睡眠概览；大卡片双列继续覆盖332dp，大字提供可读回退。当前设备当天的显式单位记录才用于活动；未知热量不补零、不猜换算，其他设备/过期日期不串用。活动/睡眠不在普通卡片重复展示。
- 首页、全部健康数据、卡片编辑只显示当前连接且能力已确认支持的指标。保留已有历史、隐藏偏好及排序；历史本身不能开放血压/心电等能力。HRV手动入口仅供实际有对应手动命令的Yuc接入，Vep的被动HRV不冒充手动支持。
- 健康提醒采用紧凑分组、显式开启、单独的个人HRV/皮温参考与当前设备/固件匹配、提示音和减少动态效果、预览与紧急拨号入口。复用实际设备日常提醒读写入口。只有新的、有效且完成并收到开始接受回执的本次手动测量可生成个人比较记录；未开启、历史导入、未知单位、未完成、超时、跨目标结果均不能生成。
- 个人设置用设备解锁保护的AssetStore保存，真实个人提醒用独立加密S3数据库按owner/id去重；不改原健康数据库，不扩展健康数据上传。预览不写真实提醒、健康记录、系统通知或戒指指令；声音仅在当前token界面真实可见后播放一次，尊重手机铃声模式，静音/后台/离开/账号或目标变化时撤回，旧界面回调不能静音新提醒或重播旧声音。采用现有自有4秒WAV，不提交外部素材或个人数据。
- 原生鸿蒙尚无这两家戒指SDK，因此不补虚假的戒指提醒振动、触摸/晃动或连续监测承诺；原生支持缺口与页面对齐分开列明。个人比较不是诊断、连续监护或恢复证明，默认关闭，参考值需用户调整。

## 文件

Harmony 的 Index、GlobalAuth/RingParity、AccountClient、EntryAbility、版本常量；新增 RingHomePresentation、ReadingReminders、PersonalReadingReminders、ReadingReminderStore/Sound、ReadingReminderPanel、提示音资源；对应Host测试与本日志、CHANGE-TEST-LOG索引。所有签名材料、产物和完整运行日志均在Git外。

## 检查与失败修正

环境：现有官方CLT 26.0.0.821、JDK17；没有下载或伪造SDK。运行脚本放在 `E:\SayRing-market-artifacts-20261031\harmony-parity-1187`。

1. 初轮Host 540项：538通过、2失败。旧UI断言禁止手机号/邮箱切换，与本轮对齐需求冲突；改为允许切换并校验密码默认。signOut生产方法的执行型夹具缺新增提醒服务依赖；补明确clear mock，保留通知先停再等待退出的原有时序断言。
2. 首轮ArkTS编译失败：实际编译SDK的AudioManager没有getRingerModeSync；改为官方异步getRingerMode，并在await后再次检查generation；未绕过静音检测。更正后Debug与Release均真实编译成功。资源冲突、厂商既有API弃用/异常处理及音频系统能力警告保留，不记成零警告。
3. 新增7项真实逻辑测试（总547）：能力不能由历史授予、活动单位/目标/日期隔离、测量完成/有效性/来源/新鲜度、HRV与显式体表温度及固件参考隔离、V2密码请求和输入前置拒绝、预览可见/静音/后台/owner时序、开始ACK与事件去重。初轮新增用例因JS默认参数把undefined误变130而失败，改为显式构造无值记录，保留生产拒绝undefined的断言。
4. 最终全量分别执行 `TZ=UTC node --test <全部tests/*.test.mjs绝对路径>` 和 Asia/Shanghai；Debug执行 `hvigorw.bat --mode module -p product=default -p buildMode=debug assembleHap --no-daemon`，Release执行 `hvigorw.bat --mode project -p product=default -p buildMode=release assembleApp --no-daemon`。最终结果与正式签名回执在下节追加，不用局部测试或旧二进制代替。
5. 只读核对线上公开认证能力：product=say-ring、realm=global，协议存在，短信/邮箱验证码及explicitRegistrationCodeLogin、smsAutoRegistration均为true，verificationRequired=true。没有发送实际短信/邮件、登录用户、支付或改服务参数。账户接口的请求、会话隔离通过合成数据的传输层测试，不冒称真实验证码送达。
6. `git diff --check`；`hdc list targets`实际返回Empty。本轮没有可用原生鸿蒙设备，不能完成页面像素、大字真机、音频听感或戒指联调验收。Android/iOS运行源码未改，本机不重复其全量编译；当前分支CI及正式签名分别核验，不把Host测试当真机功能通过。

## 正式签名与交付

版本固定1.0.7（1187），bundle cn.saydian.ring.hm，保留原Harmony发行证书。使用受保护原证书签内层HAP，官方project pack.info/pac.json整包打包，再签完整外层APP；沿用已修复991的完整校验门禁，不能只签HAP或把ZIP改后缀当正式APP。校验需要APP、嵌入HAP、独立HAP的签名/内容、原证书、有效期、profile发布类型、bundle/version/debug及未签外层APP负向拒绝。

签名后的文件名、SHA256、源提交、最终测试/编译结果和Git回执待实际完成后追加。尚未上传AGC；官方签名与最终应用市场审核是不同状态。
