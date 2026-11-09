# 鸿蒙R7 Ultra手动测量会话（2026-11-09）

基线b27585b，fetch成功且工作树干净。用户已佩戴并授权测量，精确指定尾号9F:32，完整目标只在Git外保存。复用1193真实回读的能力，但每轮仍须重新握手和读取能力，不从上轮缓存授予支持。已阅读交接/复盘/回归与上一轮实施记录。

本轮接入心率/血氧单次读数：只允许当前目标/账号/前台、每轮唯一操作；开始ACK不等于数据，收到合法本轮新读数后发送STOP并等待停止ACK再返回。取消/离页/换号有界发送停止且断开，未知停止结果不得写成功。只展示读数，暂不写健康库或云端，避免在会话尚未验收时扩大数据范围。管理/历史同步另验，不重置/清空/校时。

## 实现与失败修复

- 会话先重读信息/电量/能力，再发送相应单次测量START；START ACK、有效新读数、STOP ACK分别判断。取消/离页/换账号撤销旧回调，停止清理最长2秒，停止物理写入不重试；新增回归覆盖读数到达与已排队STOP之间的取消竞态。只展示临时读数，不入库、不上传、不发提醒。
- 搜索页仅R7 Ultra提供临时连接验证及真实能力对应的心率/血氧按钮；开始下一轮清除旧能力，避免旧目标/失败握手继续显示能力。其余戒指未借用此协议；设备管理设置、持续绑定、历史同步尚未完成。
- 首次在仓库根运行hvigor失败00304004（根目录无hvigor配置），改在harmony-native执行后编译成功。
- 首次全量570项中版本契约失败：app.json5已1194而AppUpdateService仍1193；补齐1194后双时区各570通过。
- 清理链添加超时后，ArkTS发现闭包中writer可能undefined；在已校验作用域捕获写入类型后构建通过。没有关闭编译检查。
- 1194第一候选官方verify-app通过、保留数据覆盖安装、普通入口启动。只操作用户明确指定尾号目标。首次心率START ACK返回，约32秒后出现状态21并随后断连，期间锁屏；没有有效健康结果。再次血氧在前台START ACK返回，约20秒后反复收到状态21（每10秒重发），最终70秒超时。均不记测量成功。
- P1协议缺口：此前只允许测量命令同type数据，遗漏原厂状态21确认与安卓监听的实时心率type7。对照原AAR ProcessDATA_TYPE_HEART_REAL（type7，3字节前缀后5字节K6_HeartStruct）、K6_DATA_TYPE_HR_CONTROL（高4位类型/低4位状态）修复。状态21只确认或识别当前项目结束，不冒充数值；默认只读解码白名单保持不变。实时数值匹配安卓当前时间10分钟边界，过旧/未来/畸形/零/越界拒绝；不写戒指时钟。
- 原厂Oracle增加合成K6_HeartStruct数值/时间与256种状态解析对照；现场原始包、真实健康数据、完整地址不进Git。新增结束状态回归最初发现ACK队列未执行即cancel，改为等待ACK写入后拒绝本轮，再清理STOP；该失败保留。
- 一次PowerShell内嵌Node编辑脚本引号解析失败，未执行编辑；改为字面here-string传Node后通过。

## 验证命令与待验

`JAVA_HOME=<private JDK17>; TZ=UTC / Asia/Shanghai; node --test harmony-native/tests/*.test.mjs`；原厂AAR Oracle在测试中实时javac/java执行。`hvigorw --mode module -p product=default -p buildMode=debug assembleHap --no-daemon`与`--mode project -p product=default -p buildMode=release assembleApp --no-daemon`串行，设备签名配置仅临时复制且finally恢复。官方verify-app、hdc install -r、aa start和DevEco CLI布局检查使用Git外日志。临时延长手机亮屏以完成前台验证，结束后恢复原超时。

中间候选Debug多轮成功，第一次Release成功29s501ms；最终源码测试/构建/重装和真机结果在下方追加。Android/iOS/Flutter/服务端无源码改动，跨端完整构建及服务端pnpm门禁未执行，不声称这些平台验收。未重置、清空、解绑、校时、写提醒或执行OTA。

## 最终候选验收

- 测试与临时签名构建曾同时读取build-profile.json5，导致一项旧测试用JSON.parse读取临时JSON5签名配置失败；串行恢复干净配置后，最终UTC与Asia/Shanghai各573/573通过（manual-final4-utc/shanghai.log），不修改旧测试以掩盖竞态。
- 最终Debug成功16s656ms，Release成功18s885ms；官方verify-app通过，1194 HAP保留数据覆盖安装成功，bm dump实际versionCode=1194 / versionName=1.0.7，普通入口可启动。签名配置已恢复，未跟踪签名或构建产物。
- 搜索页实机截图检查：标题、说明、型号卡片、尾号、信号及验证按钮可读，没有重叠。9F:32一度三轮扫描未出现，只显示另一同名目标，未代换；用户随后明确已靠近，重新扫描准确找到该尾号并完成新能力回读，继续当前目标手测。

## 当前目标真实测量结果与剩余问题

- 用户确认靠近后，最终1194对9F:32重读能力并手测心率：START ACK收到，约32秒返回状态21（controlType=1/state=1），确认该通知后不再反复重发；连接保持至70秒有界超时，期间未收到type7/24有效数值包。本轮未成功测量。
- 重新读能力后测血氧：START ACK收到，约20秒返回状态21（controlType=3/state=1），同样没有type20有效数值，最终超时。设备状态不是测量值。
- 用户明确要求重测，上一轮已超时结束，自动化点击旧stop_ring_operation报节点不存在；检查当前状态后重新读能力并明确启动同一目标血氧，不复用旧轮或换目标。用户确认内侧有亮灯，说明实际传感器已启动；约33秒状态21确认后仍无数值包，70秒超时，清理停止并断开。不能据亮灯、START ACK或状态OPEN声称测量成功。
- 继续核对原厂SendBlueToothData.sendHeartRateSwitch / sendBloodOxygenDetection及K6SendDataManager，实际调用链与已对照toCEDevData完全对应；OPEN=1/CLOSE=0，没有发现可据此合理新增的命令。未尝试猜测绑定、校时或初始化设置来绕过缺数据。
- 完成后执行power-shell timeout -r恢复原手机灭屏时间。停止物理效果另向现场用户确认，不将断开或SDK写入完成当作已收到STOP ACK。
- 当前交付是开发分支上的单次测量候选：实物连接/能力读取/开始确认/状态确认及用户观察亮灯已验；真实心率血氧数值及正常STOP ACK成功路径尚未实物验收。持续连接绑定、自动重连、健康历史库/云同步、查找、提醒与其它戒指管理仍待后续适配，不宣称完成。
