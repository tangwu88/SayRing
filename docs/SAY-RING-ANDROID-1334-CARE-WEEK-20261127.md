# 1.0.16 安卓问题清单修复

用户附件《1.0.16问题 安卓》列出周回顾、微信分享、举报无反馈及连续发送后其他账号失败四项。按修复APP功能处理，原文档与截图保留，不提交客户截图。工作区基线1b7ad790ff54282ac079213f7423a20b931d81e8；已读取AGENTS、交接、最近记录、回归清单与复盘，status/remote/fetch通过。原分支领先远端27个已提交记录，保留其历史，不覆盖其他工作区。

## 最终改动

- 周回顾取消数据不够对比时仅返回最近一条记录的回退，改为本周全部有效运动累计时长、有效距离及步数；睡眠按真实日期去重、选择同设备记录计算平均，睡眠和运动同时展示。上周同期对比仍有原最低天数条件，缺失指标不补零。日期范围固定为本周开始至当天。
- 周回顾分成睡眠与运动卡片，显示日期范围、已有指标与分项标题，保留附言和私人笔记隔离。
- 用户明确选择“可点击的微信链接卡片”。Android紧凑和完整分享入口增加“分享到微信”，先按原规则创建快照，再通过现有微信6.8.40 SDK发送WXWebpageObject。仅接受https://app.saydian.cn/global/say-ring/share的完整链接及43位fragment；保留原系统分享入口，iOS布局不新增未接入的原生按钮。动态读取现有global auth capabilities的公开AppID，不硬编码、不提交密钥。微信卡片仅展示品牌、报告类型和打开说明，不直接展示健康数值；点击后仍按原分享授权规则查看。
- native callback将SendMessageToWX响应与SendAuth分开，不把分享响应写成登录结果。SDK接受请求只表示尝试打开微信，不显示“发送成功”；未安装或配置不可用时提示明确并保留复制链接。
- 举报接口成功后显示提交成功并标注已举报；同页在途及已成功的同一消息不重复提交。失败保留重试，退出页面或换账号不显示旧回调。
- 429反馈改为明确的一分钟限流说明。后端配套修复在独立工作区，发送限流按真实认证账号计算，不能以APP提示改动代替线上服务修复。

## 验证过程及纠正

- 第一轮静态分析发现新增举报方法在异步后只检查封装current，分析器不能确认mounted，以及一个单行if缺少花括号。改为明确mounted检查并补齐括号。
- 等待分享形式答复期间曾实现本机PNG方案，其首次import位置有误，调整后19项测试通过。收到用户选择后，完整移除PNG实现和PNG测试，替换为原生微信网页卡片。旧图片方案的通过不作为最终卡片验收依据；已用hold中止旧流程的Debug阶段，未交付旧范围APK。
- 原生卡片新增三项Flutter用例：发给SDK的token/AppID/标题正确、未装微信提示、缺配置不调SDK；预览不泄露健康数值。补充同日两次运动45分钟/3980步、多晚平均睡眠450分钟、附言与私人笔记隔离。一次定向命令误带不存在的ring_care_test.dart，实际ring_experience_test.dart的21项通过，但该命令整体失败；后续以真实全量命令为准。新增测试初次分析发现三处缺少if花括号，已修正；最终静态分析无问题。
- 新增RingWechatLinkPolicyTest，验证原生桥拒绝仿冒域、用户信息、异常端口、错误路径、编码路径和损坏token。原生测试依赖通过Git外init脚本使用已有JUnit4.12，仅供测试，不改变生产依赖锁；正式Debug/Release仍使用原构建配置。
- 通过公开只读capabilities核实wechatApp.enabled=true且存在合法AppID；这不等同开放平台包号/正式签名及实际微信收发验收。
- 正在串行执行静态分析、UTC/Asia-Shanghai全量、Android Debug/原生单测/Release、发行包签名及运行库门禁，最终结果后附。Windows未执行iOS构建；微信实机收发、举报实机与服务器上线状态按实际记录。
- 本轮不重置或解绑戒指，不更换手机账号，不操作真实好友消息或触发真实举报。只读核对当前华为USB已可用，不将其视为新包装机成功。构建产物和失败日志保留在Git外E:/SayRing-1.0.16-issues-20261127。

## 最终回归与发布证据

- flutter analyze --no-pub通过，无问题。全量flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn在TZ=UTC、Asia/Shanghai分别2542项通过。
- Android Debug构建成功，assembleDebug约253.2秒。Git外test-init.gradle仅为本次原生单测加入缓存中的JUnit4.12，执行:app:testDebugUnitTest成功；XML汇总28套/140项，无失败，包含新增原生分享链接策略用例。随后releaseRuntimeClasspath依赖报告成功；非单测正式构建未引用该init脚本。
- 配套服务器源码0b01cd23c551d5e2d888aa23eef51624babb33fd已推送main。CI verify、国内auto-deploy均成功，国内/global/health/ready实际读回ready、database=ok及该revision，账号限流修复已在国内生效。美国节点发布前磁盘空间门禁失败，未确认更新；未为通过门禁删除服务器数据或镜像。独立实施日志补充证据为ed81675，见服务器分支codex/say-ring-care-fixes-20261127。
- 用户已确认会本人在微信“文件传输助手”发送卡片并点击验证。正式版完成验签后再保留数据覆盖安装，不代用户向联系人发送；实际收发结果后附。
- Release构建成功，assembleRelease约502.9秒。正式APK位于E:/SayRing-1.0.16-issues-20261127/SayRing-1.0.16-1334-release.apk，76453720字节，SHA256=bf4d262ec7281349d0697b44fe0654a56769d723ee2a64c31f2734e7f82fdfc3。
- apksigner实际验证原正式证书SHA256=81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de，包号cn.saydian.ring、versionName=1.0.16、versionCode=1334且非debuggable。production API/JPush manifest、ARMv7/ARM64 ABI及zipalign -c -P 16 4门禁通过；已知ARMv7 DSP/ECG 4KB ELF例外保留，不能称所有市场16KB验收。android/key.properties已按原脚本清除；签名材料与APK不提交Git。
- 已向唯一USB华为L2E0222510006851发起adb install -r。手机锁屏，已请本人完成解锁及安装安全验证，尚不把发起安装写成安装成功。未卸载、清数据、解绑或更改系统安全设置。
