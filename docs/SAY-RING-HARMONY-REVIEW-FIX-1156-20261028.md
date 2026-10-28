# 2026-10-28 鸿蒙审核反馈三项接口修复与1156正式包

## 范围、同步与复现

- 用户提供华为反馈截图：HarmonyOS6.1.0/nova14Pro/API24/Wi-Fi/中文下，远程关爱邀请和成员请求失败、健康百科加载失败、商城显示无效API地址；要求按最新安卓版修复并重打包。本轮不上传商店、不改生产配置/显示开关，不发送真实邀请、验证码或付款，不调试/重置戒指。
- 独立SayRing仓库当前开发分支，本地与远端均ae1b210465a98557e30b63eb994b5c83b0c59aef、ahead/behind=0/0、起始干净；status/remote及定向fetch完成。已读AGENTS、交接、最近1155/1154和鸿蒙1150记录、复盘/回归清单；保留原工作树与main。
- P1共同根因：AccountClient的关爱、百科、商城首页/详情仍使用V1旧路由与数字ID，而NativeHttpTransport只接受固定国际V2目标；旧路由在发送前被拒绝，原宿主mock transport没有暴露此矛盾。关爱和分类/商品的数字解析还会拒绝生产UUID。未通过放宽目标白名单、回退旧域名或把错误伪装为空列表来处理。

## 实现

- GlobalPortal保留实际UUID，按现有安卓/服务器V2合同解析关爱关系、公开内容和商品。公开百科/商城请求都带Say Ring产品、harmonyos平台、locale和分页；固定HTTPS、无重定向、无缓存、模块缺省关闭及撤销门禁保留。
- 关爱读/邀请/接受与拒绝/共享设置/逐项健康均走V2。关系ID与成员ID分离，校验本账号方向/有效状态；共享更新先复读快照，保留已存在但本版不编辑的项目，拒绝陈旧页面覆盖。每个健康请求由服务端逐指标授权，返回后再复查关系，撤销后不显示迟到健康内容；未知值不补零，不新开健康上传。
- 邀请手机号默认中国大陆规范化为E.164，账号自邀由服务器验证，不把脱敏profile手机号当作完整号码。没有发送真实邀请；测试全部使用合成身份。
- 本地关爱通知/消息保留UUID，旧数字缓存仍可读；实际实体ID与本地OS通知数字分离，不用哈希/数字替换API身份；账号和代次隔离、持久未读、去重保持。
- 百科分类/列表/详情使用UUID、contentHtml及分页，新增查看更多与重试。线上公开Say Ring百科分类/文章ID和DTO字段已只读核对，未读用户健康或改变配置。
- 商城按与安卓版一致的bootstrap、独立分页商品列表、目录币种/最小金额单位/小数位、coverImage/gallery/detailHtml读取，分类和搜索走服务器；金额/库存未知保持待确认，不默认人民币或免费。新增只读详情、分页与失败重试；隐藏/退出页面后丢弃迟到结果。
- 原生鸿蒙支付平台仍未接通，保持GLOBAL_PAYMENTS_ENABLED=false及原供应商开关；可浏览商品并查看既有订单，旧购物车/购买入口不再引向不可用V1。模块可见性仍只控制入口/读取，没有启用支付、旧SDK或医疗权限。Android/iOS运行源码和后台均未修改。
- 版本1.0.7(1156)、bundle cn.saydian.ring.hm，沿用原证书/图标。HAP和完整APP分别签名验证，不以仅签内部HAP的APP冒充市场包。

## 测试与失败修正

- 初轮宿主测试512/515，两个通知测试因新增运行时类型依赖缺Node解析hook未能加载，另一个动态Notice契约因新增两处对象格式失败。补hook与真实ID函数注入，修正Notice传递；第二轮529/529通过，未删弱断言。
- 新增10项经真正NativeHttpTransport与API24 NetworkKit边界的测试，SDK仅以合成HTTP响应替代外网：V2固定目标/UUID/公开作用域、分页详情、币种不臆测、关爱方向/当前邀请、共享快照/保留项目、逐项授权/撤销迟到记录、退出账号、隐藏模块不发请求及旧/外部API仍拒绝。
- 首轮新增测试发现ETS混合导入接口被Node保留为运行时导出，改为明确import type；次轮9/10发现测试误用全量mobile字段，核对生产profile仅有phoneMasked后，取消不可靠的脱敏号码自邀判断，由真实服务器合同400验证，10/10通过。
- 补UUID通知持久/重启/已读/不同账号测试，UTC和Asia/Shanghai各540/540、0跳过。第一轮ArkTS Debug在三个旧Set<number>引用发现6处联合类型不匹配，改为保留数字兼容的ID联合类型集合；原失败日志保留，随后完整重跑和Debug/Release结果续记。
- Git外检查目录E:\SayRing-harmony-review-fix-20261028。hdc list targets为Empty，没有原生鸿蒙实物，不将宿主或编译通过写成nova14Pro真机/市场验收。既有QRing/LuckRing原厂鸿蒙SDK缺口仍保留。

## 正式包与待验

- 最终冻结源码两个时区各540/540、0跳过；实际ArkTS Debug22.0秒、Release24.6秒成功。原Kotlin/Android/iOS/Dart运行代码未改，沿用本日完整回归和正式Android1155的证据，本轮不伪称重新编译iPhone或安装手机。
- 原证书/Profile直接签HAP，官方project pack.info与pac.json打完整APP，再签外层。官方双验、bundle/版本/非debug/app_gallery身份、内部HAP字节保持均通过；未签外层APP负样本被拒绝，保留991回归门禁。没有调用需要把明文签名配置写回工程的旧构建方式；源signingConfigs仍为空、android/key.properties不存在。
- Git外正式包目录：E:\SayRing-market-artifacts-20261028\harmony-review-1156\delivery。市场文件SayRing-HarmonyOS-1.0.7-1156-release-signed.app，9496747字节，SHA256 `0cfdee5f8a8e66e54e0b3eacc8df5b042e070867a93060ad83e4b9deedc6f73d`。HAP文件SayRing-HarmonyOS-1.0.7-1156-release.hap，18816742字节，SHA256 `4cc37bfb9ad45d4540479e7c2f8f33063ba70c0abcbf190a1ab98f7b4244d0a4`。
- 16:14只读线上核对：公开百科列表/详情200、真实UUID和contentHtml匹配；不带凭证的关爱返回401而非不存在的路由；共用配置百科true、商城false，带harmonyos作用域的商城404符合隐藏规则。未为测试开启商城、未绕过产品/平台开关，不以401冒充真实用户关爱读取通过。允许商城时的bootstrap/分页/详情由真正请求层的合成HTTP回归验证。
- hdc仍无目标，未在nova14Pro/HarmonyOS6.1实机安装验证，也没有上传AGC或获得重新审核通过回执。HAP使用正式app_gallery Profile，实际侧载遵循系统策略。缺原厂鸿蒙戒指SDK和原生支付接入的能力没有伪装为可用。
- 最终git diff --check通过；推送前重新fetch，原远端仍ae1b210未发生变化。只提交本轮源码/测试/本记录与索引，不提升尚含未验收硬件功能的main，不提交产物、密钥、凭据或真实健康记录。
