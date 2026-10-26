# 2026-10-26 R7 Ultra 运动、自动监测、地图和订单修复

## 需求、授权与同步

用户要求修复运动缺少步数/实时心率/热量、轨迹无地图、今日热量单位待确认、来电无反应、自动监测记录缺失。商城先告知方案，经用户明确“同意，按此方案修复”才修改：复用国际版订单/详情及状态筛选，支付继续受后台配置、验签和服务端确认约束；不代启支付、不改维护状态、不付款。

仓库 E:\SayRing-market-release-20261005，origin 为 tangwu88/SayRing，当前 codex/login-camera-r7ultra-1136-20261024；开始干净，fetch 成功，HEAD 与跟踪分支均 e3baf0b074e531bd30885bf5e21a6dc57089c40e，0/0，ff-only 报已最新。已读 AGENTS、交接、最新巡检、复盘和回归清单。本轮不改 main、服务端、旧后台或其他 App；E:\saydian h5 存在同事文档改动，仅作有关接口的只读查阅，不拉取覆盖或提交其文件。

## 原因与修改范围

1. **订单入口确定错误**：个人中心/继承入口使用 OrdersPage，其 loadOrders 调用了国际版故意拒绝的 V1 整数 ID 契约。改为在该入口按 global 分流 GlobalShopOrdersPage，保留 UUID、原详情和商品回跳；将旧快捷状态显式映射到待支付/待发货分组/已发货/已完成/售后，不改国内 V1。新增 completed 筛选，不修改服务端订单/资金数据。
2. **实时地图确定漏接**：运动页 SportRoutePreview 未传 controller，而详情页已传，故运动中无法发起地图加载。补传；对同一可变 GPS 列表按点数/末点变化有界每十秒刷新，以不可变快照请求，避免每秒请求或同一 list 身份漏更新。区分加载中、服务未就绪、失败和地图已取得，支持重试；错误 Future 立即登记处理，避免 retry 到下一帧之间未处理异常。保持轨迹、不补定位点。
3. **自动数据确定漏接**：CoolWear collectHealth 原先在 pendingHealthSync==null 直接返回，丢弃非显式同步期间收到的被动数据。现在仍校验真实连接/设备信息，把有效历史包通过 healthRecord 交给现有账号/设备校验及幂等持久化；传感原始时间和值不变。新增回调目标/连接代次保护，rawVersion=2 明确被动历史，防止同指标手动测量期间错误提升为手动结果；首次初始化待确认时历史仍不能导入。不把收到有效包等同于完整历史同步结束。
4. **运动心率链路补充、待实物验收**：SDK 的 App 运动控制包只有 type/status/time/distance。依据同包手动心率开关和锻炼心率接收接口，在设备明确报告手动心率能力时，开始/继续运动开启真实心率通道，暂停/停止关闭自己的通道；断连/换设备清状态，历史同步未结束不抢占开始。不创建假步数/热量字段，亦不把控制回显的初始 0 当有效距离。
5. **未知运动值不再落成实测 0**：SportRecord 增加向后兼容 missingMetrics，新本地记录缺失距离/热量/步数/心率时序列化省略对应字段，恢复时保持缺失；保留原版本已有记录。列表显示 --，详情不冒充实测距离，缺距离不生成配速；iOS 固定投影保留缺失元数据，不扩大其测量/上传权限。无清库或不可逆迁移。
6. **来电原因已由用户对照闭环**：系统初检和用户第一次“开启通知权限”后 enabled_notification_listeners 均不含 Say Ring，不能按已授权后的协议缺陷归因。打开通知使用权专用页由用户本人授权；用户明确反馈“已允许通知使用权，来电有反应”，再次只读系统检查为 true。把界面改为“通知使用权/通知读取权限”，解释并非“允许发送通知”；保留本人授权、独立开关及真实能力门禁。不自行打开敏感权限，不采集通知正文或拨打电话。

主要文件：Android CoolWearRingBridge.java；models.dart、wellness_release_policy.dart、app_controller.dart；pages.dart、pages/commerce.dart、global_shop_account_pages.dart、pages/sports.dart、prototype/device_features.dart；新增 r7ultra_followup_test.dart；通知文案关联测试及 tool/test_coolwear_android_sync.mjs。

## 尚未闭环的 SDK 取数与配置

- 用户要求继续查原始资料，本轮重新解压用户的 Android&iOS_SDK20260910.zip 到 Git 外，检查 Android SDK Guide、Demo 源码、当前 AAR 的 K6_Sport/K6_SEND_APP_SPORT_STRUCT、发送及解析类的 javap 字节码；并补查随包 iOS 新/旧指南、框架头文件、英文 PDF 全部相关页及二进制导出符号。AAR 与原包均 SHA256 ad482d5d69b99941d906038794165c1d479e5e038713954d9ca22059083d0f5f，没有换 SDK。
- K6_Sport 整数 calories 直接取数据包计数，未发现可证实当前字段倍率的代码/注释。iOS 的目标设置接口标注 cal，但不是 Android 日活动数据字段，不能跨接口套用；运动数据说明有绝对步数/距离及热量，没有给出该字段倍率或本次运动基线规则。英文 PDF 的相关项同为目标接口，未提供该日活动字段的额外单位依据。故**今日活动热量仍未修复为可信千卡**，保留既有 unknown/原始计数保护，未猜除以 100/1000、按步数估算或强行改单位。
- App 运动控制/回调结构确无步数和热量，另类活动包不等于当前运动增量；**R7 Ultra 实时运动步数和热量仍未验收**，不把日累计值塞进本次运动。需要厂商字段契约或同型号、固件、已知数据的可靠对照再补，不能用单测夹具证明硬件支持。
- 线上公开 GET /global/api/saydian-app/v2/support/sport-map-config 实测 provider=amap、configured=false。只读服务端表明同时要求公开 say_ring_map 设置已启用、say_ring_amap 的 Web 服务 Key 可解密读取。已请用户在后台配置，不在聊天索取 Key，不改用其他 App Key。地图代码修复不意味着线上底图已加载。
- commerce/capabilities 线上返回 checkout.enabled=true、maintenance.readOnly=false，但 wechat_app/alipay_app 均 enabled=false，原因各为 App 支付未配置。保留该状态，不绕过支付门禁；**支付不能标为恢复可用**。未发真实付款、下单或修改渠道。

## 本轮验证与失败修正

- 定向 flutter test --no-pub test/r7ultra_followup_test.dart test/sport_record_route_test.dart test/global_shop_pages_test.dart --reporter expanded：首次地图立即离线失败触发未处理 Future 错误，保留失败；修复后 20/20。覆盖六个旧入口状态均走 V2、禁止 V1 调用、未知值序列化不补零、已知真实零保留、可变 GPS 列表快照和限频、重试失败明确状态。
- node --test tool/test_coolwear_android_sync.mjs：4/4。为源码契约检查，不冒充原生 SDK/实物验收。
- flutter analyze --no-pub：初次一个花括号 lint，补齐后零问题（15 秒）。
- UTC 全量初次 1486 通过/2 失败，均为文案已准确更名但旧测试仍断言“手机通知权限”。修正两处断言并新增特殊权限区别检查，未放宽权限逻辑。最终 UTC 1488/1488（69 秒）、Asia/Shanghai 1488/1488（84 秒）。命令为 TZ=对应时区 flutter test --no-pub --concurrency=4 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn。
- dart format 仅本轮 Dart 文件；git diff --check。期间 apply_patch 定位旧上下文失败时未强行覆盖，按实际格式重读后修改；只读 rg 旧路径/Windows 通配路径失败改用实际文件/--glob。失败保留，不算产品通过。
- Android Debug 双 ARM，版本 1.0.6(1145)：flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.6 --build-number=1145 --dart-define-from-file=config/dev.json.example --dart-define=SAY_RING_COMMERCE_ENABLED=true，通过（229.1 秒）。原生单测和 QA Release 编译结果后续追加；现阶段不把存在旧 APK 当新构建成功。

## 发布与实物边界

本轮不更换已安装 1144，不卸载、不重置戒指、不改个人资料或原监测间隔，不改变后端配置/维护/写入/支付，也不发布应用市场。现有 R7 Ultra 账号/原记录保留。源码通过不等于自动监测按设定周期真正采集、运动连续心率/步数/热量、户外地图或订单实物流程已验收；除用户确认的来电之外，新二进制真机复测仍待安排。iOS Debug/Profile 不能在本 Windows 构建，本轮无 macOS 构建结果。

提交仅显式指定以上修复、测试与本日志/索引，提交前重新 fetch；远端变化则保留现场停止，不强推、不推广 main。后台工作树与其同事修改保持不动。

## 构建续记

- 直接 `android/gradlew.bat -p android :app:testDebugUnitTest --no-daemon --max-workers=1` 实际 BUILD SUCCESSFUL（3分10秒）；汇总本次 build/app/test-results/testDebugUnitTest/TEST-*.xml 为 62 项、零失败/错误/跳过。沿用模板对旧 Kotlin Gradle 插件的兼容警告，不为消除警告升级依赖或擅改 Gradle 配置。
- 用户本人授权后再次只读 enabled_notification_listeners，Say Ring 特殊通知权限 true，与用户明确来电有效反馈一致；没有读取通知内容或联系人。
- QA Release 双 ARM 实际通过（301.9秒），同版本 1.0.6(1145)；生产模式 false、QA 模式 true，仅验证编译，不是市场正式包。aapt 核对 cn.saydian.ring/1145，apksigner 验证通过、证书 SHA256 c7267f20525c6cd52ee97a1625aafffb10806d54811af5cc1ac4a2bb6ee0b546（不是原正式证书）；zipalign -c -P16 4 通过，文件 SHA256 6e19f1d4cf21a9e3442ec4362d69c0789e1d114a9f7eeac5af8ceaa101738fb4。私有副本 SayRing-1.0.6-1145-QA-NOT-FOR-MARKET.apk 存 Git 外，不安装、不当正式包分发。
- 收尾再次只读线上地图接口仍 configured=false；支付、地图及实物待验结论不变。iOS 未编译，不以 Flutter/Android 结果冒充 iOS 通过。
