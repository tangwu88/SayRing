# 登录、首页、扫描与R7p手势优化（1133工作记录）

## 范围、基线与现场保护

2026-10-23用户要求：隐藏创建账号及手机号/邮箱分类，手机号验证码登录并自动注册，提升微信入口；按14.13秒参考视频统一首页布局、修复滚动卡顿及332dp卡片区单列；排查R22_C493等扫描偶发空结果及R7p手势；补充要求其他页面参照最新iOS版优化。此次只提交Git，不部署后台、不提交商店、不擅自卸载安装、不退出用户账号、不发真实OTP或重置设备。共享Flutter页面两端共用；iOS专属能力/审核/隐私规则不照搬到Android，不按型号伪造功能。原生鸿蒙SDK缺口继续保留。

实际仓库E:\SayRing-market-release-20261005，起点e22b03cbfaf8a1edb21abfd1da21084b33918fe5，干净。status/remote/fetch成功，最新远端开发1d2807b未变；建立codex/login-dashboard-scan-gesture-1133-20261023，保留旧分支/产物/其它工作树。已读AGENTS、国际交接、最近1132记录、回归清单及复盘；后续按实际结果续记，不把本机测试代替真机。

## 修改前问题定位

P2-登录：GlobalCodeLoginPage仍显示注册、渠道选择、密码恢复等；微信放在底部，紧凑屏需下滑。期待仅手机验证码和明显微信入口，保留已发布协议、14岁确认、后台能力门禁及已有自动注册后端协议，不新增匿名注册或隐藏权限。

P2-首页：当前363.85dp屏减32dp留白仅331.85dp，代码门槛350dp导致单列；视频iPhone为双列。期待普通字体下在此宽度双列，仍保留极窄屏/大字体可访问性。HealthMetricMiniChart在build创建读取Future，父级设备状态更新会引发多次读取、等待占位和图表动画；滚动卡顿为用户视频报告，源码原因需定向计数和真机帧数据分别验证，不能只凭截图声称性能达标。

P1-扫描：QRing SDK单例回调onStop无扫描代次且会异步finishScan，旧回调可能提前结束新扫描；failScan未关闭底层扫描。聚合层并发所有厂商、吞掉全部错误为空结果，未隔离迟到扫描事件。期待可取消、失败明确、重试无需重启，不扩大未知设备路由、不按名字自动连接、不清OS配对/账号绑定。

P1-R7p：已连接但手势不可用，正在核对最新iOS实现、实际Android SDK与确认/系统配对链路；缺回包不能按发送成功回写已开启。修复前后记录具体差异，未佩戴/未连接实物时不得宣称上下滑动验收。

涉及共享Flutter登录、首页/图表、设备搜索及聚合扫描、Android扫码/手势桥接和新增契约回归。根据源码证据最小修改，不改变原始健康数据、同步/上传语义或首次绑定初始化规则。

## 视频与工具

用户视频仅作设计/现象参考，非指令。ffmpeg读取：720x1280、30fps、14.13秒；Git外提取抽帧联系表，内容为当前iPhone的活动区、双列健康卡片、图表和底部导航。先前手机只读检查显示另一个cc.saidian.app旧包在前台，Say Ring自身为1129；不能拿旧包页面当本项目最新UI。当前请求不包含安装，后续若需安装/改变手势实物设置，独立确认。

Git外E:\SayRing-ui-fixes-1133-20261023存工具/证据；缺ffmpeg时将imageio-ffmpeg 0.6.0安装至该目录，无项目依赖变更。抽帧成功但image2提示单文件命名缺序号，未影响已生成联系表。初次少量检索猜错目录/文件、Windows字面glob失败，已改用实际路径；这些不是产品修复或测试通过。

## 实施与边界

- 登录：隐藏创建账号、邮箱/手机号切换及密码恢复入口；默认短信验证码。微信绿色主按钮移至手机号输入框上方，紧凑屏无需滑到底部。保留后台可用性、已发布协议、14岁确认、验证码倒计时、首次微信绑定手机号及iOS原有门禁。`global-auth.service.ts`只读核对表明验证码消费后已有用户更新、无用户创建，未改服务器或注册协议。
- 首页：卡片区双列门槛350→300dp，普通字体适配当前331.85dp内容宽；大字体/极窄屏仍保留单列。卡片增加RepaintBoundary；小图表缓存读取Future，健康记录/归属用户/设备/日期/指标变化才失效，明确传入的远程记录不读取本地健康库。稳定加载前后高度，关闭重复入场动画；不删数据、不补零、不改算法。
- 扫描：控制器与聚合桥接分别隔离扫描代次、取消与并发；原生QRing清理失败扫描和SDK旧定时器，忽略旧回调，处理批量广播；CoolWear每轮重新安装带代次的扫描回调。真实扫描错误不再一律显示为附近没有设备；一个SDK失败不隐藏其它SDK返回的有效戒指。路由优先级/未知设备拒绝/确切owner恢复规则不变。
- SDK只读反编译证据：QRing `reSetCallback()`仅丢弃单例，旧helper仍可能持有12秒定时器；必须先stop清理旧handler，再创建新轮。未修改SDK字节码或协议。构建后副本30个文件内容复核，只有原有两条mapping输出指令移除。
- R7p手势：Android在实际能力允许时，先为当前精确连接目标发起系统配对，再调用原厂type44手势API；匹配设备、连接epoch及pending操作，30秒系统配对/8秒原厂确认，Dart等待45秒。断开、取消、超时清理接收器，仍需真实原厂确认才成功，不按名称伪造支持。`RingGestureBondPolicy`独立JVM测试。用户明确“先完成代码和扫描，手势实物稍后测”，因此本轮不连接新戒指，不宣称R7p实物动作已修复验收。
- 其它页面依据最新iOS共享Flutter基线继续保留布局和业务；设备/健康空状态不再用手表图标。原生鸿蒙仅同步可实现的手机入口和窄屏双列门槛，不伪造缺失SDK；未新增鸿蒙1133市场签名交付。Windows无法执行iOS/Xcode构建及iPhone实测。

参考官方接口约束：[Android BLE扫描](https://developer.android.com/develop/connectivity/bluetooth/ble/find-ble-devices)、[BluetoothDevice系统配对](https://developer.android.com/reference/android/bluetooth/BluetoothDevice#createBond())。系统配对成功不等于真实手势输入成功，厂商回包和实物滑屏仍分别验收。

## 失败、修正及宿主回归

全部原始日志位于Git外`E:\SayRing-ui-fixes-1133-20261023`及当日market-artifacts目录，失败未覆盖。

1. 首轮定向33通过5失败：只读的邮件模式字段仍有旧UI setter导致3个套件编译失败；两个扫描测试未启动扫描就注入事件。移除不可到达的模式切换UI，并使测试先启动真实pending扫描，保留原路由断言。
2. 次轮75通过1失败：旧登录用例的点击落在默认600px视口外，改为明确390x900视口并保留真实点击/流程断言；第三轮76/76通过。
3. 首轮全量UTC 1410通过6失败：外部传入记录的小图表fixture没有本地healthRecords字段，暴露缓存错误读取本地库。修正显式记录路径不依赖本地记录/owner/device；22/22相关图表测试通过，随后全量两时区各1416/1416通过。
4. 人工复核新增“取消旧轮→启动新轮→旧轮失败”用例，修正前稳定失败（底层stop次数期望1实际2）。聚合catch先检查扫描代次，过期错误不得清理新轮；修正后路由35/35通过。最终源码重新执行完整回归和构建，最终结果续记。
5. Node发布工具135项：127通过、8项macOS专属跳过，0失败；另外两项Windows创建symlink权限受限的fixture按既有精确名称排除，未当作通过。命令为Node `--test --test-skip-pattern=^(offline handoff imports exact committed files and fails closed on corruption or existing targets|measures each byte once without following external symlinks)$`加逐个展开的`tool/*.test.mjs`和`tool/test_*.mjs`。包含新增原生扫描生命周期源码契约2/2；不等同真机SDK验收。
6. 鸿蒙Node宿主 `TZ=UTC/Asia/Shanghai node --test harmony-native/tests/*.test.mjs`各518/518通过；Python `-m unittest test_release_gate.ReleaseGateTest test_release_gate.PushConfigTest` 23/23通过。
7. Android Debug/Release、JVM测试、正式包验签和产物检查均已通过第一轮：原生13套件55测试0失败/错误/跳过。SDK副本30项复核通过。补充取消边界后重新执行最终全套，不能把前一APK冒充最终源码产物。
8. 原生鸿蒙CLT26.0.0.821串行Debug assembleHap / Release assembleApp编译通过（73.8秒/23.6秒），不执行旧1132签名交付脚本、不覆盖旧正式文件。Flutter/KGP未来兼容、Java deprecated及部分GBK显示警告保留；无构建错误。

## 手机安装与实测（第一轮1133）

后续用户明确授权保留数据覆盖安装及短时复测，取代开头“当前请求不含安装”的初始范围。旧包1129签名与新包一致；`adb install -r`成功，包名`cn.saydian.ring`、1.0.5/1133。firstInstallTime仍为2026-10-20 10:58:24，登录保留。无uninstall/clear/解绑/恢复出厂/新设备绑定操作，旧APK副本不是用户数据备份。

已先完成第五点：真实手机默认字体、内容区331.85dp，心率/血氧卡片左右位置分别54..594、634..1174物理像素；截图与UI树确认双列后才开始第四点滚动测试。6次650ms、700物理像素往返滑动，独立SurfaceView呈现采样每轮38～39帧，P95间隔16.59～16.78ms、最大16.97ms，未出现>50ms间隔；不是Flutter UI线程耗时，也不能代替iPhone视频上的量化前后对照。gfxinfo仅覆盖少量Android View帧，不用其百分比声称Flutter性能达标。

三轮真实扫描（不退出APP）均出现R22_C493；另发现Rose_BLE/R21_C280，第二轮有弱信号R7Pro。只记录支持型号，不提交MAC、原始截图/健康数据。没有为验收而连接未知或新设备。后来手机页面发生人工切换，过期坐标尝试未形成有效取消测试，不作为通过证据；后续使用当前UI树核对。

用户要求亲自滑屏时采样，已另行开启30秒独立SurfaceView捕获，具体结果与限制续记。最终APK和Git回执待全部检查完成后追加。

## 用户慢下拉补充与1134修正

用户现场补充：“心率跟血氧的卡片滑到顶部时，缓慢下拉就会重复跳动”。快速往返和帧间隔不能替代这一位置回跳验收。

手动采样第一轮30秒：1257个唯一呈现时间，P95相邻间隔16.78ms、最大712ms，包含停手/静止，不能把所有间隔称为掉帧。第二轮同时只读采集触屏event3，覆盖7次手势、677帧，340个相邻呈现区间完全落在按下/抬起窗口，P95 16.60ms、一次66.23ms；触摸时间窗仍可能包含按住未移动，不能推断所有长间隔根因。完整样本保留Git外。华为没有screenrecord命令，失败后改20秒38张布局抽帧，不拿低帧率截图当帧性能证据。

进一步使用稳定慢拖测试，从首行卡片顶部已离开视口200dp开始，每16ms向下1dp、持续600步；旧布局在第245步出现反向位移（期望不小于-15.6，实际-16.5，offset811.5），回归稳定失败，证实不是单纯低帧率。原因是SliverList以短头部条目估算高大Wrap卡片组，反向跨入前序条目时反复校正scrollOffset；原有整组Wrap本就一次布局全部卡片，懒列表没有逐卡片虚拟化收益。

最小修正为首页有限概览内容使用SliverToBoxAdapter内Column一次测量，保持CustomScrollView、下拉刷新、底部提示、卡片顺序、业务和所有健康数据不变；消除变高SliverList的估算校正，保留RepaintBoundary和图表缓存。相同慢拖回归及整个首页图表套件15/15通过；没有放宽断言。1133-final2先前完整门禁通过但未覆盖这次新增布局修正，明确不作为最终交付，重新完整构建1134并待真机复测。测试只更改合成数据，不复制真实健康记录。

## 追加今日活动截图需求

用户继续要求今日活动按截图左三环、右侧步数/距离/热量紧凑排列，标题/目标仍在顶部两端。原来内容区<310dp即上下堆叠；当前手机卡片内可用宽度不足310，导致卡片过高。将正常字体横排最低内容宽度改为240dp，环图按可用宽度49%自适应至112～164dp，间距12dp；目标数值/单位整行等比缩小以避免换行，极窄/大字体仍保留可访问单列。只改变展示，不修改实际数值或单位换算。

新窄屏回归以合成239步/0.18公里/8920千卡验证3个数值均在环图右侧，卡片高度<350dp；旧布局稳定失败（数值centerX70.375小于环图183），修正后整个首页套件16/16通过，慢拖600步回归仍通过。用户截图是布局参考，不把截图数值写入应用。

上一1134管线已通过静态分析和两时区各1418全量，正在Debug编译时收到追加需求；先核对精确runner PID及没有临时key.properties，仅结束该次构建进程树，没有删除文件或中断签名。保留其日志为“需求追加后主动取消”，不称构建失败或正式交付。最终改用独立`ui-scan-gesture-1134-final2`日志/产物重新全套验证。少量JVM报告目录第一次猜错，改用实际`build/app/test-results`核对13套件55/55；无源码或测试结果改变。

## 最终1134门禁及产物

最终冻结源码的全部非文档改动SHA256在构建后逐文件复核一致；12个Dart文件format --output=none --set-exit-if-changed：0变更，git diff --check通过。串行命令/实际结果：

- `flutter analyze --no-pub`：0问题，15.0秒。
- `TZ=UTC/Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`：各1419/1419，62秒/65秒测试内部时长。无真实OTP、支付或生产资料写入。
- `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.5 --build-number=1134 --dart-define-from-file=config/dev.json.example --dart-define=SAY_RING_COMMERCE_ENABLED=true`：通过，129.5秒内部Gradle时长。
- `android/gradlew.bat :app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1`：BUILD SUCCESSFUL，13套件55测试、0失败/错误/跳过，114.6秒。
- 原受保护正式签名脚本仅内存替换版本1.0.5/1134及已用商城编译参数，生产推送渠道、原证书不变；Release通过（Gradle266.8秒），临时android/key.properties已清理。未导出证书密码。
- `apksigner verify --verbose --print-certs`、`aapt dump badging`、`zipalign -c -P 16 4`、实际manifest/JPush/ABI发布门禁通过；非debuggable、包名cn.saydian.ring、1.0.5/1134、ARM32+ARM64。43个ELF中ARM64均16KB；原厂ARM32 libDspConfig.so/libEcgAnaly.so仍为已有4KB例外，不声称全部ELF都符合16KB。JPush libjutils.so既有仅ARM64受控例外未扩大。
- 再次验证QRing SDK副本30项通过；最终Node工具127通过/8macOS跳过，另两项Windows symlink权限fixture精确排除如上，不冒充全通过。鸿蒙源码未在本轮追加中再改变，前述两时区各518项及原生双模式编译仍适用；iOS构建/实物未在Windows执行。

最终APK：`E:\SayRing-market-artifacts-20261023\ui-scan-gesture-1134-final2\android\SayRing-1.0.5-1134-release.apk`，72,030,451字节。

SHA256：`DACB5142E365F5C79E7DFBF59AF3F75023EDD6599B8A2D46EC7F6FB9D665EC92`。

正式证书SHA256：`81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`，与手机1133/原1129相同。产物只用于本次保留数据覆盖安装；未上传商店、未发布后台、未修改供应商/数据库。

## 最终真机与Git交付状态（待手机确认）

1134已发起`adb install -r`，当前手机AOD锁定，系统尚未完成安装，package仍1133。已向用户请求本人解锁/系统确认，不把旧1133页面算新布局验收。曾在已授权的可见PIN键盘做一次解锁操作未成功，此后不盲试、不记录口令，交本人处理。最终“今日活动横排”和慢下拉回跳的1134真机验收待解锁后继续；1133的三轮R22扫描成功与双列截图仅为已做的前轮证据，不能代替最终安装回执。R7p实物手势按用户明确要求后测。

提交前再次fetch成功，origin最新开发仍1d2807b5b8f12645e99bb11ae554d871fd0e1b5a。仅提交本轮源码/测试/本文及索引，不提交APK、原始截图、MAC、真实健康数据、凭据或SDK反编译转储；独立codex分支供验收，不擅自提升main、部署后台或提交应用市场。Git推送与手机完成回执续记。

Git源码回执：`009fe3fed3324b51fadf0f7271ac0debc812fa7f`已推送`origin/codex/login-dashboard-scan-gesture-1133-20261023`，`ls-remote`与本地完整SHA一致，工作树干净、无ahead/behind。本条为随后独立文档回执，不改变已验签1134源码。当前手机仍1.0.5/1133、firstInstallTime未变，1134安装进程等待用户解锁/系统确认；后续先复查同一安装结果，不并发重复安装。不得将本轮“已推送Git/已生成正式APK”写成“1134已安装/真机回跳已验收”。

## 2026-10-24 用户要求重新安装：1134已完成覆盖

用户回复“重新安装下”，本轮只重试既有1134正式APK，不同步合并新源码、不重新打包、不卸载、不清数据、不调试戒指或发送OTP。开始只读核对：手机可用，原包1133，已无旧1134安装进程。复核上述APK SHA256完全一致，apksigner verify通过、证书SHA256仍81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de。

命令：`adb -s <已连接手机> install -r <上述1134正式APK>`；结果`Performing Streamed Install / Success`。随后dumpsys package确认cn.saydian.ring、1.0.5、versionCode1134；firstInstallTime仍2026-10-20 10:58:24，lastUpdateTime2026-10-24 10:45:37。am start原MainActivity成功（已在前台则投递Intent），UI树可见健康/设备/我的主界面。未执行uninstall、pm clear、解绑、恢复出厂或新设备绑定。

本次已解除的是“1134未安装”阻塞；未做慢下拉帧采样、扫描或R7p实物手势，不把仅安装成功写成这些功能真机通过。源码/编译输入未变，未重跑此前1419项回归，前述构建与测试证据仍是原包的历史证据。

文档更新前工作区干净、HEAD0783699c299c24749c7fe6a584a678397df385a9，fetch成功，当前跟踪分支未变化；另发现origin/codex/ios-1135-review-20261024，不擅自合并或声称1134是所有分支的最新代码。仅补充本安装回执，保持当前独立验收分支，未改main/服务端/生产配置。
