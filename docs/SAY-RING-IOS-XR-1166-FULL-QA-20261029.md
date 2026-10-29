# 2026-10-29 XR整体巡检、R7 Pro同步与相机恢复修复

## 授权、基线及证据范围

用户要求在XR连接任一戒指，测试连接、活动/睡眠同步、健康提醒和各页面，发现问题直接修复；随后确认这枚戒指最近没有佩戴入睡。本轮没有商店、下载后台或销售范围变更授权，不上传或送审。源分支`codex/login-camera-r7ultra-1136-20261024`，起点干净、HEAD/远端为`d817eb4999391fefa1620b8eaa0d76a4270e4c52`。fetch及ff-only确认已最新，已读AGENTS、交接、最新记录及复盘/回归清单。

XR通过USB在线、iOS18.7.10，普通1164 Debug的真实控制器只读快照确认原R7Pro已连接、已完成能力握手、电量可读、账号存在；没有选择陌生目标。保留原账号和原戒指，未解绑、卸载、清数据、恢复出厂或修改监测/提醒设置。真机测试前重新导出`cn.saydian.ring`可访问容器，退出0，71文件/9,993,175字节；随后各轮另存前后容器及原始回执。

设备唯一标识、账号与健康内容、图片、SDK原始输出、调试令牌和包只在私有忽略目录`build/ios-xr-any-ring-1165-20261029`。不得将这些目录上传Git。停止上一轮正常Debug后才串行构建，使用带APNs development权限且包含XR的原团队开发描述文件；没有通过移除Profile能力绕过签名。

## 1165三轮实物结果与测试脚本纠正

使用新鲜正常main Profile和单独测试入口Profile，均为1.0.7（1165）/`cn.saydian.ring`，深度签名通过、团队`W7SXQ4A226`、目标设备及APNs权限匹配。所有drive都通过`tool/drive_ios_preserving_data.mjs --profile --no-pub -d <已核验XR> --driver=test_driver/ios_any_ring_full.dart --target=<本轮入口> --use-application-binary=<已核验Profile.app>`，包装器强制`--keep-app-running`；每轮finally均备份并原位恢复普通main，不使用默认卸载清理。

- 第1轮整体入口：健康提醒4项、主页面25项、内页11项通过；资料接口HTTP200，当前会话未过期且账号不变。核心同步用例立即返回设备忙、耗时0秒，不能写成SDK读取通过。健康提醒用例结束时上一自动读取尚未完成，脚本提前销毁控制器并进入下一用例；已增加自动读取结束检查。没有修改产品代码来掩盖这个测试切换问题。
- 第2轮在新进程单独运行R7 Pro：实际手动读取25.372秒，返回当前活动而没有完整历史确认；此前设备忙未复现。后续重连定位发生`Bad state: No element`：脚本仍停在睡眠路由，切换底部tab不会退出上层路由。已先返回主路由再执行重连；失败原记录保留，没有记为真实连接失败。
- 第3轮：本控制器启动0.837秒后确认原目标已就绪（复用同一进程已连SDK，不当作新连接耗时），手动同步25.328秒；当前设备有1条有效且不重复的今日步数记录，没有今天的距离/热量记录，没有当前戒指的睡眠记录。空睡眠与用户近期未佩戴入睡一致，但不是睡眠测量准确性或完整历史读取证明。两轮软件断开后可见入口重连均成功，5.614秒、11.799秒；原账号、绑定和真实电量读取均保留。
- 第3轮主页面29项、内页11项、健康提醒4项均通过，新增覆盖心率、血氧、皮肤温度、HRV详情。初版脚本在异步公开配置尚未返回时就登记不可用；现先等待真实公开只读/模块租约刷新再盘点，不注入授权或绕过能力。压力等不可用项目仍按实际配置/能力关闭；商城公开配置未开放，不伪造可用。

第3轮完整历史确认断言仍失败，未改断言为成功。收到的是type4当前活动包，没有type5历史活动或type6睡眠完成包；type9混合数据不当作完成。当前活动已保留，未知距离/热量及睡眠不补零、不推算；不把空睡眠当作病理结果。Flutter输出的`+5 -1`含一个tearDownAll成功计数，实际是5个业务用例中的4项通过、1项完整历史确认失败。

原厂SDK原包SHA256`e3a7b8ade9383fdd7a1cfb3981bfb4815fa6ccf33cad549b190d2cedc329a339`、iOS Framework SHA256`f56c39605abded5f57b7ab28f245d67218b9df9e8edbb7fe037755b8cd3ca624`均匹配。只读核对原指南、Demo及二进制：`CE_SensorCmd.open`本身会发送真实开关指令，因此拒绝“遗漏数据开关”的猜测，没有再发重复指令或更改配对/首次绑定位、修改SDK。SDK开发控制台输出可能包含设备载荷，完整输出仅私有保留，不纳入Git或公开报告。

## 实际发现并修复的产品问题：P2相机恢复竞态

现象：巡检相机页可停留在“返回App后将重新打开相机”的等待状态。源码复核及可控的真实页面回归复现：相机资源异步关闭未结束时收到resumed，旧实现的初始化因`_cameraSuspending`直接返回；关闭结束后没有补做恢复，预览一直不恢复。

修改`lib/ui/prototype/device_features.dart`：记住关闭期间到达的恢复请求，在关闭完成后仅对仍挂载、仍在前台、账号/设备上下文相同、代次相同且设备能力可用的页面恢复一次。后台、目标变化或页面退出均不重开。finally释放关闭状态；不改快门防重、保存、授权或SDK命令协议。

新增`test/ring_camera_lifecycle_test.dart`以可控相机平台延迟dispose驱动实际`DeviceFeaturePage`，验证快速恢复、持续后台、设备丢失及页面退出。测试夹具最初未推进延迟停止的事件轮、手动平台覆盖未及时清理、以及销毁页面后未排空停止任务；这些夹具失败分别保留，随后用受支持的平台variant和明确排空修正。稳定旧代码回归为恢复用例失败（期望第二个预览、实际只有一个），另3项通过。修复后相机生命周期、面板和快门门禁共8项通过。没有通过删除失败断言得到绿色。

## 健康提醒和页面验收边界

真实提醒中心、通知权限读取、130%文字、急症求助未选地区时禁用拨号、症状空选择及草稿校验通过。未拨打急救电话、保存虚构不适、修改现有事件或发送消息；自动心率提醒仍因没有适用且获审核的规则而未启用，未伪造异常事件或声称心梗预测、后台持续监测、通知实际送达。

页面和截图包括活动日/周/月、睡眠日期/最近一次、消息/远程关爱、百科详情及特大字号、设备及监测/来电/消息/闹钟/普通提醒/手势/相机入口、个人资料、权限、账号、帮助、客服和关于。界面导航检查与实际SDK设置写入、物理振动、相机拍照/相册保存、支付和AI上传分别验收；本轮没有把打开入口写成这些动作通过。源健康值、其他设备的旧睡眠及既有设置保留。

## 本机回归与1166后续验证

已完成相机定向8/8；`host-final`首轮分析发现新测试一处不必要import，移除后保留原失败日志，在`host-final-v2`继续检查。运行命令为：

```text
dart format --output=none --set-exit-if-changed <本轮8个源码/测试文件>
flutter analyze --no-pub lib test integration_test test_driver/ios_any_ring_full.dart
TZ=UTC flutter test --no-pub --concurrency=4 --reporter=expanded
TZ=Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded
node --test tool/test_coolwear_ios_integration.mjs tool/drive_ios_preserving_data.test.mjs
```

Node保护/集成契约19/19通过；格式检查通过、分析零问题，UTC与Asia/Shanghai全量各1561/1561通过（44.8秒、49.6秒），结果由私有JSON与日志分别留证。已增加单独的XR真实相机生命周期验收用例，预览就绪后快速切换Dart生命周期，再由host短暂打开时钟并返回Say Ring，验证真实OS前后台后重新创建预览，确认未请求/保存照片。该用例仍须新1166签名Profile实际执行，不能用宿主8项代替。

## 1166最终构建、实物与CI回执

运行源码`334f5bf682e8c4bc56a55d8bea5acc74ecef6be6`已推送开发分支。本机串行构建1.0.7（1166）正常Debug、正常Profile及整体探针Profile，6步均退出0；配置/签名耗时分别31.2/12.8秒、25.3/26.7秒、25.7/27.4秒。普通Debug的App.framework SHA256为`08b3851ae3163d786bc1a08d7e0937537540cfacb451ccc7741c944627b69c9c`，kernel_blob SHA256为`8587622329f42fbcbbb03db3ff24af3330a93c1a7aff8c739bf18a6b53bd3ccd`；普通Profile App.framework SHA256为`524b745ec2af6a1d1340e8df2c2589bbc12f1a80f6269d48966cb808a24c8fd2`。包名/1166/团队/目标XR均核对，Profile的APNs development权限完整。

1166整体复测：原R7 Pro两轮重连5.096秒、11.849秒；手动同步25.509秒，当前活动可读，完整历史确认仍失败。29个主页面、11个内页及健康提醒流程再次通过，资料接口HTTP200。相机新增用例在等待初始预览时失败，未进入快速恢复断言；原失败及截图保留。Flutter测试绑定会在用例之间清空生命周期，因此将相机改为独立用例，并在初始预览前通过真实系统切换明确建立前台状态；没有放宽产品的前台条件。

相机独立Profile重新编译/验签后执行，测试1个业务用例实际通过（14秒），整个drive44.8秒；原始输出`+2`还包含tearDownAll，不能计为两个业务用例。已确认：真实初始预览、关闭尚未完成时快速resumed后新建预览、真实OS切到时钟后返回仍新建预览。生命周期实际观察到`inactive → hidden → paused → hidden → inactive → resumed`，没有请求/保存照片，App容器的5个既有照片文件数量和哈希均不变。只核验预览恢复，不扩写为戒指物理手势或相册保存通过。

host在`XR CAMERA: establish-native-foreground`及`XR CAMERA: ready-for-native-background`标记后，依次执行`xcrun devicectl device process launch --device <XR> com.apple.mobiletimer --timeout 15`和`xcrun devicectl device process launch --device <XR> cn.saydian.ring --timeout 15`；未修改时钟、账号或系统设置。每轮恢复普通main时使用`--terminate-existing`只重启Say Ring，避免把测试进程或仅launch成功当作普通页面恢复。曾遇到恢复后截屏为黑屏，实际显示为开启、未要求密码；明确重启本应用后正常首页截图已确认。进程查询误用NSURL的CONTAINS筛选曾被工具拒绝，改为读取后本机筛选；未当作App崩溃。

普通1166 Debug使用已验签预编译App启动，安装31.5秒，输出VM/DevTools后调试连接丢失；不将其写成稳定Debug或热重载通过。两台iPhone仍在线；当前普通main Profile经明确新进程启动、实图首页及原账号/当前活动确认可用。后续新版本调试需重新核验连接。

新增源码完整格式/分析通过，双时区全量各1561/1561；最终Node工具140通过、0失败、1跳过（Windows ACL不适用于Mac）。[mobile-ci 40899781003](https://github.com/tangwu88/SayRing/actions/runs/40899781003)精确head为上述334f5bf，completed/success，quality、Android、iOS、Harmony UTC、Harmony Asia/Shanghai五项全部success。本记录后续只含相机实物测试建立真实前台的脚本修正和回执，`lib/test/android/ios/harmony-native/tool/scripts/.github/pubspec`及host driver相对334f5bf运行/单元输入均无差异；新相机探针另有本机分析、签名、源码哈希及真实执行证据。

完整历史同步仍待戒指提供完成/空数据回执及真实新睡眠样本；不提升main、不发布商店。用户随后追加连接/同步等待优化及Android R21戒指手势不触发拍照，继续作为下一阶段处理，不用本轮相机预览恢复冒充R21物理拍照验收。
