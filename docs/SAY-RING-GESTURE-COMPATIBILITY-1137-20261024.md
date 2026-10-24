# 2026-10-24 手势手机兼容性提示与独立监测间隔核验

## 范围与基线

- 用户要求心率、血氧监测间隔分别设置，手势页增加部分手机不支持的说明，并生成正式包覆盖安装。
- 修改前工作区干净，origin=tangwu88/SayRing；fetch origin --prune 成功，当前分支及其远端均为 36f3b47edc0a6f70307548506c8bb740f84b498b。保留原1136登录、相机及精确配对恢复候选，不推广未完成实物验收的 main。
- 已复核 AGENTS、国际交接、最新1136记录及回归/复盘约束。不改后台配置、验证码发送、绑定、健康数据或戒指设置。

## SDK 证据及未完成项

- 只读核对用户原 Android&iOS_SDK20260910.zip 中 Android_SDK_DEMO_1.4.0.zip 的 SDK Guide.md 和 SdkDemoActivity.java。自动检测命令为 sendHeartAutoSwitch(heartSwitch, oxygenSwitch, interval)，只有一个间隔参数；K6_DATA_TYPE_HEART_AUTO_SWITCH 也仅返回一个 timeInterval。
- 当前 CoolWear Android桥使用该命令，iOS YD_SyncAutoHeartCmd 同样只有 time。QRing当前适配只取得可写心率间隔；血氧接口是开关，不能猜测新增频率字段。
- 因此独立监测频率本轮未实现；需要厂商明确支持的接口/固件。没有以本地缓存双数值、手机后台定时测量或两个互相覆盖的命令伪装独立频率，也未擅改现有监测值。
- 调查中首次读取不存在的 CoolWearMonitoringMapper.h 失败，实际桥和SDK文档核对后明确限制；无源文件丢失或改动。

## 实现

- lib/ui/widgets/ring_gesture_guide.dart：在常显“三步开始”区域加入手机型号/系统兼容性提示，明确部分机型不支持，开启模式不等于所有手机和目标App均可使用。非折叠隐藏，纯展示，不改变配对或指令。
- test/ring_gesture_panel_test.dart：窄屏大字和正常尺寸均断言提示存在，继续检查原能力/忙碌/重连写保护。
- 复用共享Flutter页面，Android/iOS源码同步；原生鸿蒙无对应戒指SDK，不冒称其手势接入。

## 用户补充后的范围调整

- 用户确认共用间隔时不要在两项下重复显示，统一放到下方。因此第一项按新的共用布局实施，不再要求SDK不支持的独立频率。
- lib/ui/pages/settings.dart：已知CoolWear共享参数保留各自开关，下方单独“共同监测间隔”卡片，仅展示一次。只使用真实已读取间隔，不按相等值推断其他厂商共用，不新增能力或改变SDK命令。心率关闭但血氧开启时通过血氧类型写入同一官方参数；两项皆关闭时不允许写间隔。
- 其他SDK保留原独立间隔布局；当前QRing通常仅提供心率可写频率，不额外捏造血氧频率。未知/未返回间隔不显示可写控件。
- test/ui_shell_test.dart：332dp/200%与390dp/100%，心率/血氧四种开关组合的单入口、写入路由及读回，另验证非共享SDK不会因数值相同被合并。

## 验证与安装

本轮命令、结果和正式产物及安装回执将在完成后追加；未执行不得视为通过。Windows无法完成iOS原生编译及iPhone实测。用户仅授权保数据覆盖安装，不卸载、不解绑、不重置。

### 已完成宿主验证

- dart format：仅本轮Dart文件，首次2个文件重新格式化，其余0变化；git diff --check通过。
- flutter test --no-pub test/ring_gesture_panel_test.dart test/ring_gesture_guide_test.dart --reporter expanded：6/6通过。
- flutter test --no-pub test/ui_shell_test.dart --plain-name 'monitoring interval' --reporter expanded：9/9通过，覆盖血氧单独开启时写入血氧类型、两项都关闭不写。
- 外部Git外Run-Checks1137.ps1复用已核对本机门禁，显式版本1.0.6(1137)及原正式签名，不改变仓库构建脚本。analyze零问题；UTC和Asia/Shanghai全量各1441/1441通过。
- node --test tool/test_qring_monitoring_integration.mjs tool/test_coolwear_ios_integration.mjs：19/19通过。此为宿主源码/协议检查，非iOS编译、实际写戒指频率或手势实物验收。
- 正在串行Android Debug、原生JUnit/依赖检查、正式Release及验签；本段不是构建/安装完成声明。

### 构建续记

- Android Debug双ARM成功，assembleDebug约204秒；沿用已有Kotlin插件迁移及厂商deprecated警告，没有扩大本轮范围升级工具链。
- python -m unittest scripts.release.test_release_gate.ReleaseGateTest scripts.release.test_release_gate.PushConfigTest：23/23通过；未将需要POSIX/Xcode的其他用例计为通过。

## 用户追加：R7 Ultra 同步耗时及笼统部分失败提示

- 用户明确型号为R7 Ultra。已完成第一轮UI门禁后，正式签名器停在在线pub依赖下载；因追加同步修改，核对PID/命令后只停止这次dart pub子进程，让签名器finally退出并移除临时key.properties，未安装半成品。首次核对目标命令不匹配时没有停止。旧日志保留在Git外before-sync-update目录，不把这一轮的通过当追加源码的验证。
- 原SDK字节码与Guide核对：synDevData会同时构造用户、时间、通知等设置写入；ProcessDATA_TYPE_DEV_SYNC解析混合设置，不能当历史结束。原注册RCVD_DATA_TYPE_DEV_SYNC监听不能证明全量历史完整。
- Android同步改用Guide第8/9节已有sendAsynInfo及setEnableGsDataTrans(true)，不覆盖戒指设置。去除错误的设置包即历史成功分支；完整历史终态仍需厂商明确契约/真机证据，没有因静默、记录数或时间自动认定成功/无数据。
- 新CoolWearSyncWindow保留30秒无有效包超时；实际记录到达后延续空闲窗口，硬上限90秒。Android Dart等待95秒覆盖原生边界，iOS原有独立60秒边界不变；不通过无限延长、伪造百分比或清空旧数据隐藏问题。
- 同时读取运动记录时加入同一健康数据流，collectSport保留该流的实际记录，避免并行二次发起和丢弃运动包。没有把未确认运动列表缓存成成功或从别的账号/设备复用。
- 本地syncRecords事件只含设备标识及去重后接收条数。经router加提供方前缀，controller验证当前设备、正在同步和合法计数；UI显示真实接收条数，不凭条数构造百分比/完整性。换号/断开同步失效时清零计数。
- 超时已有记录提示改为“已更新N条，戒指尚未确认完整同步；已有记录已保留”，保持结果false、原记录及待上传状态，不将未确认状态伪装成功。用户要求的实际等待时间和完整历史验收尚须真实R7 Ultra复测，本轮宿主检查不能替代。
- 追加定向Flutter222/222、Android同步源码契约2/2通过。新增原生时钟单测覆盖静默、有效包续期、90秒硬上限、过期不能复活；下轮完整门禁重新执行。
- 下轮签名器仅在Git外调用层将pub get设为--offline：本轮没有更改依赖，使用前述Debug已验证的同一缓存和锁文件；不改受保护签名脚本/凭证，不放宽发布校验。

### 含同步改动的重新完整验证

- analyze --no-pub：零问题。UTC和Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded：各1442/1442通过。
- Android Debug双ARM重新构建通过，约202秒。:app:testDebugUnitTest及releaseRuntimeClasspath依赖报告通过；实际XML14个suite、59项、0失败/错误（包含新增同步窗口3项），Gradle约188秒。
- Node Android同步+QRing监测+CoolWear iOS源码专项合计21/21通过。iOS实际原生编译仍不可在Windows执行，没有将源码契约检查计作实机。
- 正式Release已使用原证书进入构建，离线依赖准备成功，pubspec.lock无差异。最终APK验签、文件哈希和保数据安装另续记。

### 正式产物

- 最终Release构建成功，约322.5秒；apksigner、zipalign -P16、正式包名版本/JPush权限、双ARM ABI及ELF门禁通过。沿用原已审JPush arm64-only jutils及两项ARM32 4KB例外，未放宽规则。
- Android 1.0.6(1137)，cn.saydian.ring，APK为 E:\SayRing-market-artifacts-20261024\gesture-compatibility-1137\android\SayRing-1.0.6-1137-release.apk，72,046,779字节，SHA256=041F6EA8F4A354B4269BF24E689DE15A23B64CA5AE9A704503FD3945EEBCE424。
- 原正式证书SHA256=81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de；android/key.properties已finally清理，未将凭据或产物放入Git。
- 已执行adb install --no-incremental -r，等待手机安装终态；在实际版本及base.apk哈希核对前不算安装完成。先前1136的firstInstallTime为2026-10-20 10:58:24，本次不卸载、不清数据。
- iOS原生/真机和R7 Ultra实际耗时/完整历史终态尚未验收；新增接收接口及无误终态必须在实物复测，不以主机测试掩盖此边界。未发布应用市场/在线下载版本，也未修改线上后台参数。

### Git与手机安装最终回执

- 功能提交88451797667e28bd89f7df90238b08fc2e1adfb1已推送origin/codex/login-camera-r7ultra-1136-20261024，ls-remote一致；未强推或将尚未实物验收的R7行为推广main。源码及实施日志显式提交，生产密钥/健康证据/构建产物均未加入。
- 用户回复“已安装”后，adb安装会话返回Success。实际手机cn.saydian.ring为1.0.6(1137)，lastUpdateTime=2026-10-24 16:13:05；firstInstallTime仍为2026-10-20 10:58:24，无卸载/清数据。
- 拉取该包自己的已安装base.apk至Git外私有目录，SHA256精确匹配本段041F6EA8...BCE424正式产物，排除同版本Profile/旧包。显式启动MainActivity后本应用进程存在，所查当前PID日志未见FATAL EXCEPTION/ANR；这不是长时稳定或实物SDK验收。
- 本轮未代用户勾选年龄/协议，未注册新账号或发送真实OTP，未解绑/重置/代绑戒指；R7实际等待时间、完整历史及手势物理效果仍需在用户本人登录连接后复测。
