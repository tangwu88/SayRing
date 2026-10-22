# 震动款识别、手势引导与界面优化（2026-10-22）

基线0e350063d727678b2dab8d9e61abf8edec51fd11，分支codex/qring-visual-refresh-20261021，初始干净；fetch/prune、ff-only一致。已读AGENTS、最新变更、国际交接、回归清单及复盘。用户要求暂停审核提交并继续修改，本轮不改苹果销售地区、不继续1125送审。

## 修改前问题与范围

P2：iPhone15 Pro Max实际安装cn.saydian.ring/1.0.5(1124)，尚未安装上一轮只恢复到XR的1125提醒修复；不能把旧包缺入口当作1125实物失败。两个iPhone当前在线，后续私下备份、按保数据流程覆盖并核验R7 Ultra真实设置。

P1：既有R8通用名规则将用户本次明确指定的R8 Pro震动款送到错误候选通道。拟在Flutter、iOS及Android同时加入不区分大小写的R8 Pro模型例外，兼容型号内空格/横线；保留R1/R2/R7C优先、其他冲突拒绝和真实SDK握手/功能回包门禁。R7 Pro/Ultra/HR05沿用同一设置实现，不凭震动型号虚构当前开关或实际采样。

P2：手势页为六行文字列表、说明大段堆叠且包含供应商名称。拟用图标模式卡、当前模式状态、三步开始引导和可展开排障；不猜每个固件的具体手势、不把指令确认称为物理执行成功。

P2：前端提示及供应商缺省设备名可能展示内部供应商字样。拟清理界面、通用错误提示和设备显示名称；内部通道ID、原始广播名、数据来源与SDK符号保留，不更改历史记录或误影响路由。

视觉目标：沿用用户已选浅色，采用更克制的蓝/青、暖白留白、图形模式/设备卡，减少常驻说明文字，增大关键正文/数字；系统大字、窄屏、无障碍语义和48pt操作保留。用户“更小的文字、文字大小也要大点”按前述“文字更少、字号更大”落实。

## 首轮回归与校正

定向60项通过、首次analyze零问题（11.7秒），原生型号/提醒契约与46个iOS通道路由用例通过。15 Pro Max备份34文件完整私有保存；1126正常/测试Profile正在串行构建。

首轮全量UTC1378通过/7失败，上海因串行&&尚未执行：旧测试依赖ListTile及旧勾选图标、供应商相机文案；新卡片/折叠说明进入后滚动动画尚未稳定即点击，密码找回按钮因大字移出ListView首屏而未构建。按新交互更新测试：等待滚动稳定、通过实际可点击卡和状态断言验证，找回页真实滚动到提交按钮；不缩小生产字号、不放松指令/迟到门禁。失败日志保留，须最终全量再验。

## 最终主机回归与界面

最终生产代码analyze零问题8.5秒，双时区各1385项通过（UTC23秒、上海31秒）；Node132项中131通过、1项Windows限定跳过，Python发行35通过。iOS路由46个原生用例及256种久坐重复位保留仍通过。新增新手势卡跨320px/2倍字号和390px常规视口实测，验证支持模式筛选、操作指令和忙/重连禁用，不用旧ListTile结构冒充功能断言。

实际Flutter组件截图已生成并目检首页、手势和设备，睡眠阶段条只取真实返回片段时长，不填默认数据；暖白/深青主题、图标场景和戒指矢量插图、主要标签字号增大。预览数据为本机合成，不是个人健康或蓝牙验收证据。清除前端供应商说明/相机提示/不支持设备提示，通用异常不泄漏供应商和SDK信息；DeviceInfo单独displayName/displayModel清理显示文字，原广播名/ID/toJson/路由数据保留。运动页连接名也使用显示字段。

Android双ARM Debug/QA Release40.1/86.8秒及原生JUnit54项零失败、错误、跳过（8.4秒）通过；包名cn.saydian.ring、版本1.0.5(1126)、双ARM与签名核验通过。证书为本机Debug身份，仅回归，不发布正式下载。iOS Debug无签名config25.4秒/构建19秒通过；Profile普通与测试入口均成功，正确团队/包名/1126/目标15ProMax及深度签名通过。最后文案字号与未知模式类型守卫的Dart小修后，发行候选普通Profile及相关构建继续追加，不能把中间包列作最终同源码。

## R7 Ultra实物回合边界

第一轮Profile测试安装25.4秒，Flutter连接后初始化45秒超时；日志记录SIGCONT进程恢复，未进入设备读写。正常1126已原位恢复、启动回执成功，用户确认已进入首页并连接R7 Ultra。

第二轮重新私有备份后安装16.2秒，及时恢复前台；真实账号/owner-bound R7Ultra目标和首页已通过。实际SDK回包128含监测间隔60分钟、122来电开关及message_switch=1；证明本轮新连接的设置协议/消息能力，不宣称发生通知物理振动。测试在睡眠页导航后pump等待帧15秒超时，40.4秒退出1，尚未进入设置写入；当轮没有改写任何设备设置。再次私有备份并原位恢复正常1126成功。

针对已复现的页面帧等待中断，增加独立配置验收入口ios_vibrating_settings_test.dart：仍仅当前已登录owner/原精确目标和真实SDK，不替换账号、不解绑；先验证来电新鲜读写/恢复、消息实际或未知状态、久坐原日程保留和监测间隔/其他开关恢复，不依赖睡眠页面动画。未知消息原开关保持未写，不擅自开启。测试仍须保数据wrapper/明确已验签Profile，结束恢复普通main。最终实际结果待追加，前两轮失败保留。

### 设置专项首轮与队列读取校正

独立设置首轮已确认原owner/精确R7Ultra和八项真实能力（查找、相机、手势、来电、消息、闹钟、健康监测、普通提醒）；首次来电读取返回空，测试在bool断言前退出，未执行任何设置写入。末态lifecycle=paused，普通main已恢复。原生连接阶段会串行探测提醒；能力一旦首次返回就可打开入口，但readDeviceFeature此前遇到CONNECT_BUSY会直接返回空，监测设置只处理另外三类暂时错误，无法等探测结束。

补充窄范围只读队列等待：仅iOS CoolWear且收到CONNECT_BUSY时每500ms重试，最多40次/20秒等待；非忙错误、其他通道仍原行为。每次等待前重新验证原账号/设备代次和能力，切设备即取消；真实读成功才写UI快照并清旧错误。健康监测读也复用同一等待；不重试任何写操作，不取消SDK队列或修改设备/健康原值。

新增等待后真实快照、换目标取消、持续忙预算终止、其他通道不重试四个回归。初轮四项逻辑均执行后因测试平台覆盖变量在setUp/tearDown阶段恢复过晚触发框架不变量失败，已改为每个测试体try/finally内恢复；失败记录保留，最终全量和重新构建/实物结果继续追加。


设置专项第二轮仍返回空，私有报告实际捕获“设备忙，请稍后重试”；进一步核对原生control使用DEVICE_BUSY，而监测使用CONNECT_BUSY。首次等待补丁只覆盖后一种，不能称已修复来电读取。已将两种明确队列忙码同时纳入同一iOS CoolWear有界只读等待，测试改为DEVICE_BUSY主反例并补CONNECT_BUSY正例；写入仍不重试。无设备设置曾被这两次空读失败改写，每次均已备份并恢复普通main。


## R7 Ultra设置最终读写与用户追加紧凑布局

两种忙码修正后，主机analyze零问题21.4秒、UTC1390通过28秒、上海1390通过45秒；Node132中131通过/1Windows限定跳过，Python发行35通过。Android Debug11.7秒/QA Release44.9秒、iOS Debug config13.4秒/构建7.9秒均通过。

实物busy专项61.4秒退出0，九项检查通过；普通main原位恢复成功。扩大普通提醒覆盖时发现原测试检查sedentary字段而适配器实际返回items列表，原轮不能称已验证久坐写入。已修正为遍历实际items、带最新snapshotRevision修改、回读全日程、finally恢复全原值。重新签名Profile并经保数据wrapper实测66.5秒退出0，十一项检查通过，包括久坐精确日程回读和原设置恢复；私有备份1.3秒、普通1126原位安装2.8秒、启动0.2秒均成功。来电原true恢复true，监测60分钟恢复60分钟，其余开关保留；消息系统通知权限true但固件未返回enabled，保留未知且未写消息开关。本轮没有让用户实际触发R7 Ultra来电/消息振动，R8 Pro尚无实物，睡眠页面帧等待仍不算完成实物验收。

用户追加“界页排版，适当紧凑点”。修改前再次fetch/prune确认基线未变并保存before-compact.patch。仅调整app_theme、dashboard、devices、ring_gesture_panel/guide的留白：主题按钮52pt、列表垂直间距缩小，首页区块12px、睡眠卡16px内边距，设备插图64px/功能卡最低110px，手势场景卡14px内边距、区块12px。保留主要字号、系统文字缩放与至少48pt操作范围；不改控制器、协议、数据计算或设置写入。最终截图、回归、正常main重装及Git证据继续追加。


### 紧凑版最终回执

五文件dart format为0改动，git diff --check通过。合成组件截图八张生成并目检首页、设备、手势，无裁切；手势页390px常规视口可见六个场景。截图仅为合成布局证据，不等于实物通知触发或睡眠正确性。

- compact-preview：退出0，7.1秒。
- compact-analyze：退出0，9.9秒。
- compact-utc：退出0，28.2秒。
- compact-shanghai：退出0，38.6秒。
- compact-android-debug：退出0，7.4秒。
- compact-android-release：退出0，22.6秒。
- compact-ios-debug-config：退出0，14.2秒。
- compact-ios-debug：退出0，9.0秒。
- compact-profile-config：退出0，12.4秒。
- compact-profile：退出0，24.5秒。
- compact-signature：退出0，0.1秒。
- compact-install：退出0，3.3秒。
- compact-launch：退出0，0.2秒。

UTC/上海分别1390项全量通过，包含320px/2倍文字等回归。正常main 1.0.5(1126)已完成cn.saydian.ring、W7SXQ4A226、目标15 Pro Max包含及深度签名核验；测试结束后的私有容器备份保留，最终紧凑版原位覆盖安装与启动成功，未卸载。Android仍为QA身份，只作构建回归，未发布下载。

最终轮可复现命令如下；FLUTTER为本机Flutter3.44.9，OUT为上述私有构建目录，IOS_TARGET_UDID为已验证15 Pro Max目标（精确值保存在忽略的私有日志）。Android使用既有JDK17/SDK与SAIDIAN_ALLOW_QA_RELEASE=true。两轮全量分别设置TZ=UTC和TZ=Asia/Shanghai。

```sh
$FLUTTER test --no-pub --dart-define=CAPTURE_DATA=populated --dart-define=CAPTURE_PHASE=compact "$OUT/experience_preview_test.dart"
$FLUTTER analyze --no-pub
$FLUTTER test --no-pub
$FLUTTER test --no-pub
$FLUTTER build apk --debug --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --build-name=1.0.5 --build-number=1126 --target-platform=android-arm,android-arm64
$FLUTTER build apk --release --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --build-name=1.0.5 --build-number=1126 --target-platform=android-arm,android-arm64
$FLUTTER build ios --debug --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --build-name=1.0.5 --build-number=1126 --config-only --no-codesign --target=lib/main.dart
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination generic/platform=iOS -derivedDataPath build/ios-xr-release-1125-20261022/host-ios IPHONEOS_DEPLOYMENT_TARGET=15.0 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
$FLUTTER build ios --profile --no-pub --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --build-name=1.0.5 --build-number=1126 --config-only --no-codesign --target=lib/main.dart
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Profile -sdk iphoneos -destination id=$IOS_TARGET_UDID -derivedDataPath "$OUT/derived" IPHONEOS_DEPLOYMENT_TARGET=15.0 SAIDIAN_DEVELOPMENT_TEAM=W7SXQ4A226 DEVELOPMENT_TEAM=W7SXQ4A226 CODE_SIGN_STYLE=Automatic 'CODE_SIGN_IDENTITY=Apple Development' build
python3 "$OUT/verify-profile.py" compact-normal
xcrun devicectl device install app --device $IOS_TARGET_UDID "$OUT/compact-normal-profile-1126.app"
xcrun devicectl device process launch --device $IOS_TARGET_UDID cn.saydian.ring
```

发行审核继续暂停；没有修改苹果地区、服务端功能开关、生产下载或上传新的商店构建。R8 Pro实物、R7 Ultra实际通知振动与完整睡眠页面实物验收仍未完成，不将主机测试替代这些验收。代码和此记录同批同步当前开发分支；保留当前main，待上述整体验收/用户确认后再提升基线。
