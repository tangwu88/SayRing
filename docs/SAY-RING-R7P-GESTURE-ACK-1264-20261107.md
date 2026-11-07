# R7P选择场景后确认超时诊断

用户明确1262在选择场景后仍提示戒指未确认。此前1262验收只验证进出页面不重连，未验证场景成功，不能据此宣称手势可用。基线969ee67，已fetch、读交接/回归/复盘并新建codex/r7p-gesture-ack-1264-20261107；账号、绑定、历史和系统配对保留。

确认提示来自原生8秒场景确认超时。已读取当前实际SDK字节码，sendGestureConfig通过IK6SendDataManager，接收ProcessDATA_TYPE_GESTURE_CONTROL注册类型44并投递RCVD_DATA_TYPE_GESTURE_DATA，与现代码对应，不能无依据改成实体toCEDevData的128。

先添加仅Profile构建的结构诊断：手势发送、类型44封包的命令/长度/条数、解码是否被现有确认规则接受、确认超时。不输出MAC、账号、健康数值或原始数据载荷，不清taint、不重放命令、不将GATT写成功当作场景确认。正式Release保留profileTrace既有关闭分支。准备原正式证书覆盖安装Profile诊断包，验证后恢复普通正式包；不得用诊断成功替代真实滑动。

前两轮原生手势宿主编译失败：执行环境未设置UTF-8，javac按GBK读取含中文的提取源码；同时为新增profileTrace调用补齐无副作用宿主替身。使用既有-Dfile.encoding=UTF-8后该项通过，确认原有ACK/配对/回退行为不变。该测试不代表真实戒指回包。实际命令、构建、安装及采样结果完成后追加。

## 1264真机证据与1265候选

- 用户确认所有场景、包括关闭均失败，已将R7P平放并本人确认覆盖安装。1264 Profile用原证书签名，UID/首次安装时间未变；不是正式分发包。临时key.properties按保护脚本finally移除。仅Profile明确订阅类型44命令ACK的结构诊断，默认订阅不接收ACK，接收方也显式排除ACK进入历史完成路径；真实SDK宿主新增验证默认、显式诊断及取消诊断时的行为，ACK从不作为业务成功。
- 1264连接同步期间09:33:01、09:33:03已有手势解码回调（无待确认指令，拒绝作为确认），证明混合设置读取能提供手势状态。同步结束后09:34:45.372仅发送一次关闭指令；09:34:53.373确认超时，期间没有场景数据确认。没有反复点场景或回退重发。
- 已核对实际SDK的K6SendDataManager.push直接调用同一CEBluetoothProxyBase.sendData，现有CoolWearReadRequests.MIXED_INFO为仅REQUEST(3)/类型9、不带设置负载。1265候选在set44后顺序排入一次只读混合设置查询，仅真实解码的同模式回包按既有条件确认；不将发送成功、GATT写成功或普通ACK当场景成功。8秒上限、taint、连接代次和配对关闭验证保留。
- 手势宿主验证每次设置只追加一次读取、不提前配对或成功、错误模式不确认；混合读取的真实SDK帧与只读门禁及ACK隔离专项通过后构建1265 Profile。实物匹配状态仍待验证，不宣称已修复。

## 1265实物读回结果及配对边界

- 1265 Profile原证书验签并由本人完成覆盖安装，版本及UID保持，恢复原R7Pro连接；没有重复清空、重置或改变已有账号绑定。
- 同步结束后只点击一次关闭，界面实际显示“关闭/本次连接指令已确认”，与1264相同关闭动作8秒超时的对照不同。
- 随后仅一次短视频设置：09:45:06.888发送、09:45:06.889请求读回、09:45:08.414实际解码并匹配接受；未将普通ACK或GATT写成功当作确认。随后系统配对一直为BOND_BONDING，30秒未完成；09:45:38.427安全回退只发送一次关闭，09:45:38.432请求读回，09:45:38.580实际确认关闭。此后蓝牙短时断开并自动恢复，不能写成滑屏已通过。
- 向本人请求在当前手势页发起一次短视频并完成系统配对，不移除原系统配对、不申请通讯录权限，不连续重发场景。SDK/读回确认与OS配对、实体滑动分项验收。
- 结构诊断与真实SDK只读/ACK隔离/配对宿主专项通过；普通正式包完整门禁正在串行运行。未确认的OS配对仍不放行，不以关闭提示掩盖失败。诊断结果完成后恢复普通正式版。

## 1266：系统配对触发页面重建

- 用户本人完成系统配对后反馈自动回首页并重新同步。09:56:21.613设置、09:56:21.614请求只读回执、09:56:23.174匹配状态确认；09:56:31.353 Android ActivityTaskManager明确记录本应用 `Config is relaunching invisible activity`、`changes=0x60`，09:56:31.457移除Activity，09:56:31.611重建，进程PID不变。不是将正常首页刷新推测成崩溃；新增HID输入引发navigation/keyboardHidden配置变更，而Manifest只声明keyboardHidden、keyboard，缺少navigation。Flutter宿主重建丢失路由并重新建立本机连接/同步所有者，与用户所见一致。
- 仅为MainActivity补齐navigation配置处理，由FlutterActivity现有配置变更路径接收，不关闭自动同步、不忽略断联、不跳过初始化或场景读回，不改系统配对或健康记录。新增宿主Manifest回归断言覆盖HID三个相关配置位，防止回退到只处理键盘可见性。
- 官方说明参考：https://developer.android.com/guide/topics/resources/runtime-changes 。配置处理不代表能够跨进程死亡保留所有状态，也不代表实体手势已通过。
- 1265修改前全量Flutter UTC/Shanghai各2100通过、analyze、Android Debug/native通过；Release开始后因新增实际问题主动中止，不作为完成包。确认无残留编译进程后清除本轮保护脚本创建的临时android/key.properties（未读取或输出凭证）；原签名材料保留。旧日志保留于私有验证目录，1266重新执行最终门禁。
- 1266原证书正式构建及实机配对/页面保持/滑动测试待完成；不声称已验收。仍保留账号、绑定、历史，不取消或重建系统配对。

## 1266最终源码检查（进行中）

- 私有目录 `E:\SayRing-gesture-ack-1266-20261107` 的 `Run-Checks.ps1` 串行执行 prepare/analyze/utc/shanghai/debug/native/release/verify；环境为Flutter 3.44.9、JDK17、UTF-8、单Gradle worker、1408MiB堆。日志按阶段保留，不覆盖1264/1265失败或中止记录。
- `flutter pub get --offline`、`flutter analyze --no-pub`通过；`flutter test --no-pub --concurrency=2 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`在UTC、Asia/Shanghai各2101项通过；包括新增HID配置回归。
- `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.11 --build-number=1266 --dart-define-from-file=config/dev.json.example --dart-define=SAY_RING_COMMERCE_ENABLED=true`通过。
- `android/gradlew.bat :app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1 --offline -Ptarget-platform=android-arm,android-arm64`通过；Release和协议专项、签名门禁继续串行执行。既有Kotlin迁移/弃用提示未当作测试失败，也未借本轮升级依赖或改变SDK。
- Windows无Xcode，iOS Debug/Profile及iPhone实机未执行；没有将Android实测扩展为iOS或Harmony验收。

## 1266正式构建、交付及待验收

- 上述全流水线通过：原生108项、无失败/跳过，普通Release1.0.11/1266生成；随后 `Run-ProtocolChecks.ps1` 串行完成Node协议/隐私42项、QRing构建副本非允许项一致检查（30个原始条目）及Python发行门禁23项，全部通过。未执行真实支付、短信或外部生产配置变更。
- 原正式证书SHA256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`验签通过；包名`cn.saydian.ring`，非debuggable；JPush、双ABI及ZIP对齐门禁通过。既有两项ARM32封闭SDK的4KiB ELF限制未变，不能据此声称所有市场/设备审核通过。
- 补充安装包配置检查首次按文本查navigation时失败，原因是apkanalyzer将属性输出为十六进制掩码；按ActivityInfo位标志复查，实际为`0x40003ff4`，`& 0x70 == 0x70`通过，keyboard/keyboardHidden/navigation均在包内。不是源码或构建失败。临时android/key.properties已由保护脚本finally删除。
- 交付 `E:\SayRing-market-artifacts-20261107\SayRing-Android-1.0.11-1266-release.apk`，73536169字节，SHA256 `FC779087854293DDAA9379A55F694B1DFFFFA95776B76135175F75095B6538B7`。只复制完整原始签名APK，没有解包重打包，不提交构建产物或私有验证资料。
- 第一次`adb install -r`返回`INSTALL_FAILED_ABORTED: User rejected permissions`；复查手机仍1265且无待确认页面，没有卸载。重新发起一次覆盖安装并请求本人完成华为安装/身份确认；实际安装、配置变化后的页面保持、物理滑动均仍待验收，不能写成已通过。
- 已停止本轮拥有的Profile结构日志采集器；后续以正式包复查。临时USB保持亮屏原值0，实测结束需恢复。
