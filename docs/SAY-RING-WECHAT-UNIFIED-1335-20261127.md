# 安卓1335统一微信分享与关爱邀请

用户要求原分享位置直接使用已经实测可用的微信卡片，不展示两个分享入口；同时修复远程关爱“分享邀请链接”仍走系统文本/复制链接的问题。基线048c4d96266e8e0acbb7fafbf54bd96594761b7a，当前分支codex/android-1320-install-20261124，修改前工作区干净，status/remote/fetch与远端SHA核对一致。已阅读AGENTS、handoff、最近1334记录、跨模块回归清单和复盘；原1334正式包及实测记录保留。

## 改动

- lib/ui/ring_share_page.dart：共享ringShareLink为Android报告与关爱邀请统一发送WXWebpageObject；原紧凑IconButton/完整OutlinedButton各保留一个，原位置点击直接调用微信卡片，移除新增的第二个微信按钮。所有复用RingShareButton的睡眠、健康、运动、周回顾与心血管参考记录自动沿用同一入口。iOS保持原系统分享，Windows不宣称iOS原生接入。
- 原动态公开AppID、正式证书、微信登录/分享回调隔离继续沿用。异步能力读取后重新检查页面、登录账号与owner，退出页面或换账号不继续调SDK。出错时保留明确提示和复制链接补救，不作为第二个常驻分享入口。
- lib/ui/ring_care_page.dart：创建邀请后直接发送微信邀请卡片；本页已生成邀请的菜单从复制链接改为分享邀请，重用同一码、不另建新邀请。48小时/一次性接受/由接收方选择指标的服务器协议保持原样；链接不携带健康值。
- Android RingWechatLinkPolicy只补充第一方/global/say-ring/invite路径和精确20位原协议邀请码，不接受query、编码路径/编码token或仿冒域，不放宽报告43位token规则。
- test/ring_experience_test.dart与RingWechatLinkPolicyTest覆盖单入口、原按钮直接微信、邀请创建及同一码再次分享，原生邀请路由和邀请码边界；原报告隐私及iOS系统分享回归继续执行。

## 验证与边界

- dart format执行三个Dart文件；静态分析、定向测试、双时区全量、Debug/原生测试/正式Release和验签结果后附。所有命令/产物位于Git外E:/SayRing-wechat-unified-1335-20261127。
- 本轮无服务端源码、生产数据库或戒指指令变更；不发送真实邀请给联系人。实机发送和点击验证由用户本人操作，未验证项按实际记录。

## 范围补充与首轮结果

- 初次分析发现共享错误补救回调的if换行缺花括号；补齐后分析无问题，定向26项通过，包括单入口、报告微信失败提示、邀请同码重分享以及异步途中离页/换账号停止分享。
- 用户进一步确认：商城若原来是普通复制/文本链接也一并改。检查global_shop_pages.dart确认原实现为ShareParams(subject:商品名,text:商品名+URL)，故将现有商品分享按钮接入相同微信卡片通道。iOS沿用原商品名及文本URL的系统分享；PDF/CSV文件导出保留。
- 商品分享保留商城显示和交易能力门禁、当前页面/账号/加载代次校验，增加在途防重复点击。native仅接受原第一方商城固定商品路由及现有数字/UUID式180位以内商品ID，不允许变成订单、任意路由、附带跳转参数或其他域名。
- 首轮UTC2547项通过；商城范围补充发生在首轮全量过程中，已用hold在Debug前停止该轮，不将首轮结果当作最终商城修复回归。旧日志归档为scope-before-mall-*，最终将重新串行执行完整门禁。
- 只读HEAD核实/global/saidian-mall/和/global/say-ring/invite均HTTP200，未生成真实邀请或发送消息；页面可访问不等同微信点击后具体商品/邀请实测。
- 最终商城定向首次失败来自测试定位器：新版Flutter的byTooltip找到RawTooltip，不能强转为IconButton；改为定位含share_outlined的真实IconButton，不更改业务实现迎合测试。修正后报告/邀请/商城共39项定向测试通过，分析无问题；覆盖商城单次在途分享及iOS原商品名+文本链接保留。
- 通过源码核对App商品详情和H5商品详情均由同一storefront/products/:id代理读取；只读页面HEAD不等同具体商品实机验收，最终将请用户本人点开卡片核对。

## 最终门禁进度

- 含商城范围的最终静态分析无问题；报告/邀请/商城定向39项通过。UTC全量2549项通过，Asia/Shanghai及Android Debug/原生/Release、签名门禁继续串行执行，实际结果后附。旧范围全量日志保留，不替代本轮结果。
- iOS系统分享回归在Flutter替身测试中通过，Windows未运行iOS Debug/Profile或iPhone实机，不将该结果描述为iOS原生微信卡片接入。
- 最终Asia/Shanghai全量2549项通过；两时区结果一致。Android Debug成功，assembleDebug约226.6秒。
- 原生阶段将:app:testDebugUnitTest与:app:dependencies --configuration releaseRuntimeClasspath合并为一次Gradle调用，保持单worker串行，减少重复配置。实际执行成功，28套/142项、无失败/错误/跳过，新增邀请和商城路由校验均通过。JUnit仅通过Git外init脚本加入testImplementation，不改生产依赖或正式构建配置。release依赖报告已生成，正式包继续构建。

## 正式包与安装发起

- 正式Release成功，assembleRelease约607.8秒。APK：E:/SayRing-wechat-unified-1335-20261127/SayRing-1.0.16-1335-release.apk，76453720字节，SHA256=bcdc9c9553d2fe156480b176b18f38ee03777baec44c932e6b6362f6fa15f79a。
- apksigner核实原正式证书SHA256=81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de，包号cn.saydian.ring、1.0.16（1335）、非debuggable。生产API/JPush manifest、两ARM ABI和ZIP对齐门禁通过；保留既有ARMv7 DSP/ECG 4KB ELF例外，不称所有市场16KB验收。临时android/key.properties已清除，APK及签名材料不提交Git。
- 已向当前唯一USB华为发起adb install -r，手机锁屏，已请本人解锁并完成系统安全验证。当前仅为安装发起，等待系统包管理器核对1335成功后再记录安装完成；不卸载、解绑、重置或清除数据。
- 报告卡片已有1334真实收发基础；本版单入口及新邀请/商品路径仍需用户本人实测，不能用SDK、替身测试或页面HTTP200替代实际发送及点开验证。
