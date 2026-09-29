# 修改与测试记录索引

本文件是项目长期执行约定。每位同事开始修改前必须先同步 `origin/main`，再阅读最近记录；每组修改和每次验证都写入对应日期的实施记录，并随源码一同提交。

## 执行顺序

1. 检查分支、工作树、本地与远端提交号；工作树不干净时只做安全合并，不覆盖既有修改。
2. 阅读最近实施记录中的已完成项、失败方法、待验证项和真机边界。
3. 记录本次修改原因、文件、影响范围和预期结果后再实施。
4. 逐次记录格式化、静态检查、自动测试、构建、安装、真机流程和日志检查结果。
5. 失败记录保留，并补充根因与最终修复；交付时提交记录并核对远端提交号。

## 最近记录

- [2026-09-29 HR05 戒指扫描、连接与重启恢复](SAY-RING-HR05-DISCOVERY-20260929.md) — 同机 LuckRing 与系统扫描确认精确 `HR05` 名称；Say Ring Android/Flutter 两层放行该名称、保持真实握手与能力门禁，修正型号标记。华为真机已显示 HR05、完成连接并回报电量，冷启动恢复连接；完整测试和 Git 状态见正文。
- [2026-09-29 双戒指 SDK 前端运动与睡眠补全](SAY-RING-DUAL-SDK-FRONTEND-20260929.md) — 恢复今日活动、4 个运动模式与查看更多；补独立睡眠入口、R22 REM/评分/效率展示，并按 QRing SDK 修正睡眠秒单位及 15 分钟活动槽，旧错误记录保留且过滤。双时区 Flutter 各 892 项、Android 30 项及双 APK 构建通过；华为最终 QA 包已覆盖安装，R22 当前未广播，真实重同步/iOS 仍待验。
- [2026-09-29 R22 戒指扫描修复与真机连接](SAY-RING-R22-SCAN-20260929.md) — 修复 `R22_C493` 被 Android、Flutter、iOS 三层名称规则过滤，并补 Android 已配对但不广播时的精确已保存设备恢复；华为真机已扫描、配对、握手、读取电量及升级后自动恢复，双时区 Flutter 各 887 项、Android 28 项与双 APK 构建通过；iOS 真机和健康/运动全链路仍待验。
- [2026-09-29 Android 真机覆盖安装](SAY-RING-ANDROID-INSTALL-20260929.md) — 将 QRing 接入后的 QA APK 覆盖安装到华为手机，确认版本与短时启动存活；GitHub 连接重置导致远端最新状态未能重新核实，戒指和接口功能未在本轮验收。
- [2026-09-29 QRing 双端 SDK 与多戒指自动路由](SAY-RING-QRING-MULTI-SDK-20260929.md) — Android/iOS 接入 QRing，按厂商 `Q_`/`O_` 广播名前缀自动选择 QRing SDK并锁定后续操作；未知名称继续关闭。双时区各 885 项、Android 原生 26 项、Debug/QA APK、权限/签名和 iOS arm64 Framework 结构检查完成；真实 QRing 与 Mac/Xcode 验收、既有 JCore 发布门禁漂移仍按正文待处理。
- [2026-09-28 Android 模拟器 Debug](SAY-RING-ANDROID-EMULATOR-DEBUG-20260928.md) — `Saydian_API_36` / `emulator-5554` 已以显式 x86_64 Debug 开关构建、安装并附加 Flutter；最新蓝色登录页和数字键盘正常，当前进程无崩溃/ANR/缺失动态库，业务请求仅见 `app.saydian.cn`。记录了 Android 16 前台 Activity 检查差异、更新清单 404、启动/键盘跳帧及模拟器不能替代真实戒指验收的边界。
- [2026-09-28 Say Ring 全局科技色调、设备页与个人中心统一](SAY-RING-UNIFIED-TECH-UI-20260928.md) — 去除普通界面残留的大红色，将设备页、个人中心、商城及各类二级页面统一为蓝青靛紫科技色和冷色卡片层级；双时区各 884 项、Android 原生 23 项、双 APK 构建与验签通过。手机锁屏导致最新包尚未覆盖安装，Git/CI 与平台边界见正文。
- [2026-09-28 Say Ring 冷色科技年轻化调整](SAY-RING-COOL-TECH-PALETTE-20260928.md) — 将偏粉嫩的表面重新收拢为冷白、蓝、青、靛紫科技配色，品牌红仅保留于关键操作和选中态；新增精确配色断言，双时区各 883 项、Android 原生 23 项、双 APK 构建、验签及华为覆盖安装通过；GitHub Actions 在分配 runner 前被外部门禁阻断，不能标 CI 通过或已发布，完整边界见正文。
- [2026-09-28 Say Ring 年轻化界面与首页健康大卡片](SAY-RING-YOUTHFUL-LUCKRING-UI-20260928.md) — 现场参考 LuckRing 的大卡片层级与留白，在保留 Say Ring 红色浅色品牌调性的前提下，将首页健康指标改为单列全宽渐变大卡片，并统一功能面板、通用卡片和输入框圆角；双时区各 882 项、Android 原生 23 项、双 APK 构建、验签与华为覆盖安装通过，iOS/HarmonyOS 和正式签名仍按正文待验。
- [2026-09-28 HR01 实机连接、健康与运动调试](SAY-RING-HR01-LIVE-DEBUG-20260928.md) — 修复 CoolWear 设备能力入口遗漏，压力与 HRV 均取得真实戒指有效回调，HRV 增加新命令优先、旧固件命令延迟兼容；同时修正首页单行展示和无按键戒指提示。双时区各 882 项、Android 原生 23 项、双 APK 构建与华为覆盖安装通过；物理振动、摇动成片、iOS/HarmonyOS 与正式签名仍按正文待验。
- [2026-09-28 Android 真机 Debug 重新启动](SAY-RING-ANDROID-DEBUG-20260928.md) — 最新 `main` 已在华为 PPA-LX3 重新构建、两阶段覆盖安装并附加 Flutter Debug；登录页正常、当前进程无崩溃/ANR、业务接口只见 `app.saydian.cn`。记录了安装坐标字符串拼接错误及修正、安全存储算法迁移 0 项、更新清单 404、冷启动跳帧和真实登录/戒指链路未验收边界。
- [2026-09-28 首页、健康、设备与独立下载页更新](SAY-RING-HOME-HEALTH-DEVICE-DOWNLOAD-20260928.md) — 修复 CoolWear 压力/HRV 有效回调因设备时间戳异常被丢弃的问题，恢复 HRV，重排首页与运动入口，补相机/查找设备/自动检测，统一中国手机号并接入 Android/HarmonyOS 独立下载页；双时区 Flutter 各 881 项、Harmony 各 481 项、Android 原生 23 项及 Debug/QA APK 构建通过，真实戒指测量与正式签名仍待真机验收。
- [2026-09-27 Android 真机 Debug 启动](SAY-RING-ANDROID-DEBUG-20260927.md) — 最新 `main` 已在华为 PPA-LX3 覆盖安装并保持 Flutter Debug；首页与登录会话正常、当前进程无崩溃/ANR、首轮业务请求仅见 `app.saydian.cn`。更新清单 404、冷启动跳帧、空推送/天气配置和真实戒指链路继续明确未验收；同时记录并纠正 PowerShell `$PID` 保留变量误用。
- [2026-09-27 Say Ring 在线更新与极光推送](SAY-RING-ONLINE-UPDATE-JPUSH-20260927.md) — Say Ring 推送设备登记携带独立产品标识，配合后台独立更新清单和极光配置，避免与旧 App 混用；真实凭据、正式签名升级和通知送达仍需配置后验收。
- [2026-09-27 Say Ring 微信授权登录对接](SAY-RING-WECHAT-LOGIN-20260927.md) — Android 使用服务端公开 AppID 发起微信 SDK 授权，服务端以一次性 code 换身份；首次授权绑定已验证手机号，后续直登，并与国际 H5 会员复用。Flutter 双时区各 878 项、Android 原生单测、Debug/QA Release 双包和华为覆盖安装通过；真实微信回调、真实短信、iOS 构建及开放平台包名/签名登记仍按正文待验。
- [2026-09-27 GitHub 同步规则与打包提交上线](QA-20260924-ANDROID-PACKAGE.md#2026-09-27-git-同步) — 已将开发分支和 `main` 普通快进到最新本地代码，并把后续每轮完成、验证、提交后同步 `origin` 写入项目约定；禁止强推，网络或权限失败时必须明确标为未同步。
- [2026-09-24 Android QA APK 打包](QA-20260924-ANDROID-PACKAGE.md) — 基于 `452ab89` 生成 `SayRing-Android-QA-v0.1.21+1004-20260924.apk`；包身份、ARM 双架构、ZIP 对齐与 v2 签名校验通过。该包使用 QA Debug 证书，不是生产上架包；Windows 未生成 iOS IPA。
- [2026-09-24 HR01 压力测量回调与连接窗口修复](SAY-RING-HR01-STRESS-MEASUREMENT-20260924.md) — 兼容 CoolWear 同一压力协议的两种实时回调命名，严格只接受设备实报有效值；HR01 首连/重连不再被长历史同步占用，历史改为设备页手动触发。双时区各 875 项、Android 原生 23 项、接口/隐私 87 项和双 APK 构建通过；华为真机已确认连接后可立即测量，但链路再次中断，最终真实压力结果仍待稳定连接复验。
- [2026-09-24 默认中文、隐藏 HRV 与全部运动子页](SAY-RING-CHINESE-HRV-SPORTS-20260924.md) — Say Ring 默认简体中文并移除语言选择入口；HRV 仅从健康 UI 隐藏而保留 SDK、历史与同步数据；运动首页固定一排 4 项，“查看更多”进入独立页面展示戒指实报的全部模式。完整验证与平台边界见正文。
- [2026-09-24 无屏戒指文案、LuckRing 样式与运动折叠](SAY-RING-SCREENLESS-UI-SPORTS-20260924.md) — 清理戒指端确认/亮屏/手腕等误导提示，过滤屏幕专属入口；保留红金浅色调优化内外页，并按窄屏 2、手机 4、平板 6 项预览运动后支持展开。双时区各 873 项、Android App 原生 23 项、Debug/QA Release 与华为覆盖安装结果及第三方 CameraX 边界见正文。
- [2026-09-23 LuckRing 健康功能重新对齐](SAY-RING-LUCKRING-HEALTH-PARITY-20260923.md) — 逐项复核压力、睡眠结构、皮肤温度、身心准备度、心理状态和生理周期；真实 SDK、页面、同步与保留边界以记录正文为准。
- [2026-09-23 LuckRing 视频功能对齐](SAY-RING-LUCKRING-PARITY-20260923.md) — 对照用户提供的 LuckRing 操作视频，修复活动数据不可见与 HR01 运动能力门禁，并补齐 SDK 已确认的运动入口；自动化、构建与真机结果以记录正文为准。
- [2026-09-22 HR01 健康历史与运动补充](SAY-RING-HR01-HEALTH-SPORT-20260922.md) — 对照 CoolWear SDK 与手机 LuckRing，补充健康历史、HRV 与运动控制/记录，并保留能力和真机验收门禁。
- [2026-09-19 HR01/CoolWear 戒指连接调试](SAY-RING-HR01-DEBUG-20260919.md) — 核对用户 SDK 包、当前路由和华为真机，记录连接/功能门禁、构建与现场结果。
- [2026-09-19 Say Ring 页面回退与覆盖安装](SAY-RING-ROLLBACK-20260919.md) — 用户取消深色四栏新界面；源码恢复到改版前的健康/设备/我的三栏和原验证码登录页，安装与真机验证结果见记录正文。
- [2026-09-19 Say Ring 视觉、微信入口与功能清单](SAY-RING-VISUAL-WECHAT-20260919.md) — 参照手机 LuckRing 四页的信息层级重做 Say Ring 专用深色四栏；微信入口按服务端能力关闭，功能矩阵与真实联调门槛单列。双时区各 861 项通过；Android 构建结果见记录正文。
- [2026-09-19 以同事交接包重建 Say Ring 与共享验证码登录](SAY-RING-REBUILD-20260919.md) — 校验离线包、恢复独立私有仓库；改为 H5 共用的全球会员验证码登录，默认手机号，移除主登录页注册/密码入口；最终双时区各 858 项、Android 原生 16 项及 Debug/QA Release 构建通过。微信首次手机绑定、CoolWear 真戒指及服务端多源策略仍未验收。
- [2026-09-19 Say Ring 阶段性交接与离线恢复](SAY-RING-HANDOFF-20260919.md) — 回读私有空仓库、生成可恢复交接材料，并重新执行 App 双时区 853 项、Android 原生 16 项、QA Release 及服务端类型/测试/构建；明确服务端分支落后 15 个主线提交、更新接口 404、真戒指/iOS/HarmonyOS 仍未验收。
- [2026-09-13 Say Ring 独立产品、戒指路由与阶段一验证](SAY-RING-IMPLEMENTATION-20260913.md) — 从国际版 `9530387` 历史和商城增强迁入独立产品；三端包身份、八语应用名、`say-ring` 更新隔离、YC/V/TK/D 路由、鸿蒙国际路径和玉成多设备记录 ID 已落地。定向 Flutter/Harmony 测试通过；全量构建、真戒指、服务端多源策略、仓库 Private 与推送仍按记录明确待验。
- [2026-09-13 国际 App 商城与 H5 能力对齐](INTERNATIONAL-COMMERCE-PARITY-20260913.md) — 源码、双时区 837 项、服务端 755 项、域名 37 项及 Debug/QA Release 构建已完成；华为手机拒绝 USB 安装，待开启手机端安装权限后做冷启动验收；仍未推送或发布。
- [2026-09-12 Android 真机 Debug 启动](QA-20260912-ANDROID-DEBUG-START.md) — 从最新干净 `main` 以 `app.saydian.cn` 配置覆盖安装并保持 Flutter Debug；登录和手表自动连接恢复、当前进程无崩溃，国际更新清单 404、闭源 SDK Debug 原始日志和单次启动跳帧继续明确记录。
- [2026-09-11 Android 扫描、能力展示与同步反馈修复](INTERNATIONAL-ANDROID-DEVICE-FIXES-20260911.md) — 扫描信号原位刷新、通知按真实支持项展示、健康提醒间隔与屏幕能力往返修复、同步结果八语提示及发行日志移除；双时区各 827 项、真机连接/两次同步/冷启动恢复和新域名日志检查通过，设备写入与其他型号继续明确未验收。
- [2026-09-11 Android 双型号设备与新域名联合复验](INTERNATIONAL-ANDROID-MULTIWATCH-QA-20260911.md) — 原目标受经典蓝牙连接影响未广播后，按用户授权实连 W8Pro 与 W9；两类能力按型号展示、同步与主要登录后页面完成只读复验，第一方结构化请求仅到 `app.saydian.cn`，国际更新清单未发布、闭源 SDK 原始扫描日志风险及三轮重连继续明确保留。
- [2026-09-10 登录后真机功能检查](INTERNATIONAL-POSTLOGIN-DEVICE-CHECK-20260910.md) — 保留真实会话的逐页只读检查、12 项专用账号 GET、4 项 P1 缺口；双时区各 822 项通过不等于功能全通过。17:24 追加：USB 调试已授权，连接状态下通知/屏幕/设备信息可读，并真机确认不支持通知项仍显示；冷启动后精确绑定目标未被扫描发现，未猜选同名设备，自动重连及其余控制继续未验收。
- [2026-09-10 健康/AI/关爱审计](INTERNATIONAL-POSTLOGIN-HEALTH-AUDIT-20260910.md) — 缺云端历史拉取；真实客户端/换号成功响应复现旧档案显示，3 项纯 mock 诊断及 187 项现有定向测试，保留探针失败与修正。
- [2026-09-10 资料/商城/设置审计](INTERNATIONAL-POSTLOGIN-COMMERCE-AUDIT-20260910.md) — 头像迟到串写、资料回读失败仍报成功、单位不持久、国际地址未接入；4 项纯 mock 缺陷探针、公开接口现状与 86 项回归。
- [2026-09-10 设备能力与契约审计](INTERNATIONAL-POSTLOGIN-DEVICE-AUDIT-20260910.md) — 通知可见性、运动模式推断、屏幕时长与提醒间隔四项源码缺口；134 项定向测试、8 项原生日志源码检查不替代真机能力验收。
- [2026-09-10 国际注册登录真机复验](INTERNATIONAL-AUTH-DEVICE-20260910.md) — 隔离国际服务已部署、真实只读门禁通过；专用账号与 Android 登录同意流程逐项复验，旧 404 失败记录保留。
- [2026-09-10 登录隐私同意 P1 修复](INTERNATIONAL-AUTH-CONSENT-20260910.md) — 登录/注册/重置显式同意，失败不覆盖状态，通知权限不冒充隐私同意；93 项定向回归。
- [2026-09-10 专用测试账号验证工具](INTERNATIONAL-AUTH-ACCOUNT-QA-20260910.md) — 显式授权创建单个隔离账号，注册/会话轮换/退出/密码登录；私有凭据不进 Git，真实结果单独记录。
- [2026-09-10 国际注册登录只读检查](INTERNATIONAL-AUTH-SMOKE-20260910.md) — 固定新域 /global、拒绝跳转、真实能力与已审协议检查；47 项测试通过，线上 404 与腾讯云重新登录阻塞明确保留。
- [2026-09-10 国际媒体相对地址兼容](INTERNATIONAL-MEDIA-COMPATIBILITY-20260910.md) — 仅补已允许媒体路径的相对解析，保持新域名、路径与重定向保护。
- [2026-09-10 联合验收覆盖矩阵](INTERNATIONAL-JOINT-COVERAGE-20260910.md) — 页面、域名、接口与回读证据逐项区分通过、失败、未验收。
- [2026-09-10 独立真机 QA 驱动](INTERNATIONAL-JOINT-QA-DRIVER-20260910.md) — 私有配置指定精确设备，三轮只读同步测试；不执行 OTA、覆盖联系人或表盘，不把设备侧成功计为云端通过。
- [2026-09-10 正式协议入口修复](INTERNATIONAL-LEGAL-ROUTES-20260910.md) — 登录、账号、关于统一走真实协议及版本；禁止旧文章路径与未审核替代文本，98 项相关测试通过。
- [2026-09-10 重连独立复查](INTERNATIONAL-RECOVERY-INDEPENDENT-REVIEW-20260910.md) — 每 SDK 实际排空与迟到清理，独立 48 项验证；不凭有并发操作的旧真机日志臆测原因。
- [2026-09-10 Dart 日志隐私](INTERNATIONAL-DART-LOG-PRIVACY-20260910.md) — 健康保存异常仅记类型；供应商直打日志与本地依赖替换边界单独保留。
- [2026-09-09 Android 与隔离国际服务联合验收](INTERNATIONAL-JOINT-QA-20260909.md) — 新域名固定 /global 路由、下载/媒体请求保护、环境数据隔离及真机联调；逐项记录已通过、失败与未验收边界。
- [2026-09-09 更新重定向防护](INTERNATIONAL-UPDATE-REDIRECT-GUARD-20260909.md) — 下载每跳发送前检查、国际安装器独立门禁与 72 项定向测试。
- [2026-09-09 原生日志隐私审计](INTERNATIONAL-NATIVE-LOG-PRIVACY-20260909.md) — 厂商日志开关及 App/插件日志脱敏；玉成闭源日志残留单列待验。
- [2026-09-09 环境持久化隔离](INTERNATIONAL-ENVIRONMENT-STORAGE-20260909.md) — 旧记录/密钥保留、环境绑定与精确目标恢复，113 项相关回归。
- [2026-09-09 国际商城只读闭环](INTERNATIONAL-COMMERCE-READONLY-20260909.md) — UUID 商品详情、搜索/分页及缺币种安全展示；交易能力保持关闭。

- [2026-09-09 国际版生产域名直接切换](INTERNATIONAL-PRODUCTION-DOMAIN-SWITCH-20260909.md) — 清除通用 API/更新/真机 QA 中的旧 `.cc` 默认值，强制国际版使用 `https://app.saydian.cn`。
- [2026-09-09 国际版真机扫描定位开关](INTERNATIONAL-DEVICE-SCAN-20260909.md) — Android 10 权限允许但系统定位关闭导致搜索为空；用户开启定位后确认已发现设备，补共享扫描前置检查、八语设置引导和返回重试。
- [2026-09-09 国际版临时免验证码注册](INTERNATIONAL-UNVERIFIED-REGISTRATION-20260909.md) — 服务端能力明确驱动邮箱/E.164 手机免码注册，联系方式仍保持未验证；Flutter 636、Harmony 481、Android 原生 15 项通过，模拟器与隔离 API/数据库闭环完成，生产开关默认关闭。
- [2026-09-09 国际版实施与测试](INTERNATIONAL-IMPLEMENTATION-20260909.md) — 独立私有仓库、三端身份、隔离账号/V2健康同步、八语基础、真实协议与渠道门禁；所有失败、修复、尚未验收项保留。先读[国际版交接](INTERNATIONAL-HANDOFF.md)，不得按以下国内历史记录直接发布国际版。

- [2026-09-08 Android 微信授权登录真机联调](QA-20260908-ANDROID-WECHAT-LOGIN.md) — 已补 Android 微信入口、原生授权回调和 App 登录接口契约；真机可到达微信授权成功回调，但当前服务端接口要求客户端直接提交 `openid`，与 Android SDK 实际仅返回一次性 `code` 不兼容，完整登录待服务端按 `code` 换取身份后复验。
- [2026-09-07 三端设备型号展示回退](IMPLEMENTATION-LOG-20260907-DEVICE-MODEL-FALLBACK.md) — SDK 型号为空时仅在展示层取蓝牙名最后一个 `-` 后的非空内容；Flutter 双时区各 525、鸿蒙双时区各 429，Android/iOS/鸿蒙 Debug 编译通过。
- [2026-09-07 鸿蒙运动与记录完整闭环](IMPLEMENTATION-LOG-20260907-HARMONY-SPORT-PARITY.md) — W9S 真实能力限制为跑步/步行/骑行，跑步启停、51 秒加密记录和详情真机通过；双时区各 428 项、Debug/Release 构建与验签通过。
- [2026-09-07 三端包 GitHub 上传确认](release/QA-UPLOAD-20260907-R6.md) — `qa-20260907-r6` 私有预发布，5 个安装包加说明/校验共 7 附件，远端 SHA 和大小一致；标签 `1110a5f`，不等于商店或 CI 验收通过。
- [2026-09-07 最新三端 QA 安装与发布说明](release/QA-RELEASE-20260907-R6.md) — Android r6 两包、iOS r6 Profile、Harmony r12 两包及安装/签名边界；仅 GitHub 私有预发布，不能作为正式上线结论。
- [2026-09-07 Android r6 真机安装预检](QA-20260907-ANDROID-R6-LIVE.md) — 重连后确认现装 r5 与新包同签；随后 USB 三次断续，未执行安装或清绑定，不启动未知保存目标抢占手表。
- [2026-09-07 三端续测、授权恢复与 r6 构建](IMPLEMENTATION-LOG-20260907-CARE-PUSH-RESUME.md) — workflow 已推送但 CI 计费仍阻断；P40 r5 已装而 USB 未授权，r6 / 鸿蒙 r12 独立记录最终构建与验证边界。
- [2026-09-07 共享保存回读与账号隔离](IMPLEMENTATION-LOG-20260907-CARE-SHARE-READBACK.md) — POST 后原账号回读一致才成功、换号拒绝迟到响应、保留未知键；新增 44 项、完整双时区各 524 项通过，不替代服务端撤销授权修复。
- [2026-09-07 Android r6 安装包门禁](QA-20260907-ANDROID-R6-ARTIFACTS.md) — 首轮原生推送配置漏注入拒收，重建后按实际 APK 复核签名、原生参数、ABI 与 16 KB。
- [2026-09-07 鸿蒙 r12 构建与签名](BUILD-20260907-HARMONY-R12.md) — 同源重新生成 Debug/Release，双时区各 423、官方验签；开发 Profile 不等于商店发行。
- [2026-09-07 三端整改阶段总结](QA-SUMMARY-20260907.md) — 已完成、真机失败、开发验证包、服务器与系统限制分开；优先从此进入本轮最终结果。
- [2026-09-07 关爱组合读取账号归属](IMPLEMENTATION-LOG-20260907-CARE-READ-SESSION.md) — r5 拒绝换号后的迟到成功/错误与旧 401 刷新，同账号刷新保留；定向 90、完整双时区各 480 项，现网 HRV 撤销仍须后台修复与复验。
- [2026-09-07 关爱单项结果权威性](IMPLEMENTATION-LOG-20260907-CARE-METRIC-AUTHORITY.md) — r3 真机撤销 HRV 仍显示摘要失败后，Flutter r4 删除无类型总表预读/回填，完整双时区各 463 项通过；旧后台单项失败不再伪装成功。
- [2026-09-07 鸿蒙关爱单项权限边界](IMPLEMENTATION-LOG-20260907-HARMONY-CARE-AUTHORITY.md) — r11 同步删除总表补偿，403/空/不可用分开，完整双时区各 423 项；服务器单项授权与后台推送仍须现场闭环。
- [2026-09-07 鸿蒙离线运动与资料保存回读](IMPLEMENTATION-LOG-20260907-HARMONY-OFFLINE-SPORT-PROFILE.md) — 按账号查询本机运动而非依赖连接及全局快照；实际提交字段逐项回读，保存不完整不报成功。
- [2026-09-07 CI 鸿蒙双时区契约检查](IMPLEMENTATION-LOG-20260907-HARMONY-CI.md) — 新增独立 Node 测试矩阵，非 HAP 编译；工作流授权及远端计费门禁仍阻断。
- [2026-09-07 鸿蒙命令排空与迟到回调隔离](IMPLEMENTATION-LOG-20260907-HARMONY-COMMAND-DRAIN.md) — 8 类旧操作补真实 Promise 排空及断开确认；生产服务 53 项、完整双时区各 380 项通过，最终 r9 构建和验签通过。
- [2026-09-07 鸿蒙单位设置非目标字段保护](IMPLEMENTATION-LOG-20260907-HARMONY-UNIT-SAFETY.md) — 避免官方单字段接口随手机覆写手表时制；保存前后逐一核对 32 字段，真机恢复原 24 小时并完成距离/温度切换回归。
- [2026-09-07 三端关爱授权撤销核查](IMPLEMENTATION-LOG-20260907-CARE-AUTHORIZATION.md) — 修复 Flutter 单项 403 被总表回退吞掉及未授权旧值显示；若现网只返回 200 空表，仍需服务端明确授权状态，不能据此声称撤销联调通过。
- [2026-09-07 鸿蒙心电无效值与佩戴状态](IMPLEMENTATION-LOG-20260907-HARMONY-ECG-VALIDITY.md) — 厂商明确 ECG HRV 255 为无效值；补真实佩戴回调、单次安全取消和迟到结果隔离，双时区各 344 项通过，独立日历史 255 未做推断性删除。
- [2026-09-07 关爱红点、前台横幅与通知点击复核](IMPLEMENTATION-LOG-20260907-CARE-NOTIFICATION-UNREAD.md) — 远端0不抹本地邀请未读；完整双时区439项通过；旧安卓包系统通知点击异常仍待新包现场复验，不能标完整通过。
- [2026-09-07 现网旧后台关爱推送](QA-20260907-CARE-PUSH-LIVE-BACKEND.md) — 已用Chrome核实旧Yii与有效极光配置；P40单设备通道约1秒到达，实际业务自动触发仍缺旧控制器/主机证据。
- [2026-09-07 鸿蒙前台关爱邀请提醒](IMPLEMENTATION-LOG-20260907-HARMONY-CARE-POLLING.md) — 补前台定时兜底、按账号本地收件箱、通用系统通知、稳定邀请去重和迟到请求隔离；后台即时投递及跨通道系统去重仍待服务端与真机验收。
- [2026-09-07 三端统一、账号隔离与真机回归](IMPLEMENTATION-LOG-20260906-THREE-PLATFORM-QA.md) — 本轮持续实施记录；Flutter账号/连接代次、通知契约、iOS原生表盘路由与响应式布局已补定向及全量回归，三端真机与后台通知仍在联调，不能作为整体上线通过。
- [2026-09-07 账号与手表会话防串写](IMPLEMENTATION-LOG-20260907-ACCOUNT-WEARABLE-SESSION.md) — 登录切换排空旧测量/连接，拒绝迟到回调和未绑定记录；保留手动取消与自动完成边界。
- [2026-09-06 Android 连接、权限与发行安全细节检查](IMPLEMENTATION-LOG-20260906-ANDROID-DETAIL-QA.md) — 修复蓝牙权限竞态闪退风险并收紧发行权限；华为 P40 已完成覆盖安装、ET488 自动重连、同步、趋势、表盘读取、查找手表和前后台恢复回归，404 项测试通过；当前账号 401 阻断远程关爱、消息与推送验收。
- [2026-09-06 鸿蒙 Vep 设备全功能真机验收](IMPLEMENTATION-LOG-20260906-HARMONY-ET488-FULL-QA.md) — ET488 历史问题与 W9S 现场回归已归档；已修复距离单位、血氧结束卡住和末帧覆盖有效读数，W9S 连接/同步/设备控制/测量/重连通过，完整心电终态及非零运动数据仍待后续真实样本。
- [2026-09-06 鸿蒙资料、关爱与设备发现整改](IMPLEMENTATION-LOG-20260906-HARMONY-PROFILE-CARE-DISCOVERY.md) — 资料编辑/头像选择、关爱指标状态与成员人数一致性已修复并真机验证；扫描链路正常但目标表未广播，非空成员健康数据与正式发行签名仍有外部阻断。
- [2026-09-06 鸿蒙内页逐页对照、功能补齐与手表发现复查](IMPLEMENTATION-LOG-20260906-HARMONY-INNER-PAGES.md) — 商城详情/规格/购物车/确认订单/订单详情/物流/售后续补；鸿蒙双时区各 198 项、Flutter 各 403 项、Debug/Release 编译及真机覆盖安装。交易写入、部分内页和目标表待验；GitHub CI 计费/额度阻断，非整体验收通过。
- [2026-09-06 鸿蒙设备发现与蓝牙广播排查](IMPLEMENTATION-LOG-20260906-HARMONY-DISCOVERY.md)
- [2026-09-06 鸿蒙版全面对齐 iOS 界面](IMPLEMENTATION-LOG-20260906-HARMONY-IOS-UI.md)
- [2026-09-05 iOS 微信登录与界面文案精简](IMPLEMENTATION-LOG-20260905-IOS-LOGIN-COPY.md)
- [2026-09-05 鸿蒙推送、支付与发布检查](../harmony-native/docs/PUSH-PAYMENT-IMPLEMENTATION-20260905.md)
- [2026-09-05 健康档案、付费报告与 StoreKit 接入](IMPLEMENTATION-LOG-20260905-HEALTH-REPORTS.md)
- [2026-09-04 iPhone 与 W9S 真机测试](IMPLEMENTATION-LOG-20260904-IOS-W9S-DEVICE.md)
- [2026-09-04 合入 main 并保留 iOS 支付修复](IMPLEMENTATION-LOG-20260904-MAIN-MERGE.md)
- [2026-09-02 新服务端平滑迁移联调](IMPLEMENTATION-LOG-20260902-SERVER-MIGRATION.md)
- [2026-08-30 华为 P40 鸿蒙真机回归与窄屏溢出修复](IMPLEMENTATION-LOG-20260830-HARMONY-P40.md)
- [2026-08-30 iOS 心电手动测量崩溃修复与真机回归](IMPLEMENTATION-LOG-20260830-IOS-ECG.md)
- [2026-08-29 通知、表盘、电量、在线升级与多设备真机整改](IMPLEMENTATION-LOG-20260829-ONLINE-READINESS.md)
- [2026-08-29 关爱、跨端历史、运动、预警与 iOS 表盘修复](IMPLEMENTATION-LOG-20260829.md)
- [2026-08-28 远程关爱、小程序参数、双支付与健康链路回归](IMPLEMENTATION-LOG-20260828.md)
- [2026-08-27 心电、AI、关爱、监测间隔与连接恢复](IMPLEMENTATION-LOG-20260827.md)
- [2026-08-25 全界面体验与型号能力收口](IMPLEMENTATION-LOG-20260825.md)
- [2026-08-24 远程关爱、商城、头像与心电真机回归](IMPLEMENTATION-LOG-20260824.md)

## 固定防复发资料

- [2026-08-29 跨端问题修复复盘](BUG-RETROSPECTIVE-20260829.md)
- [赛电 App 修改与回归检查清单](REGRESSION-CHECKLIST.md)

## 记录模板

```text
### HH:mm 修改/验证名称

- 原因：
- 文件/范围：
- 预期：
- 结果：通过 / 失败 / 未执行
- 失败原因：
- 修复结论：
- 后续待验：
```
