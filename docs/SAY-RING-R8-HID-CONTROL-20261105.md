# R8短视频/阅读异常输入排查（2026-11-05）

## 范围与基线

用户反馈当前R8短视频不再正常上滑，出现乱滑并退出App，阅读也异常。基线b75718e，工作树干净并fetch；共享6a41e73为其他平台1246产物文档，未合并无关功能。新分支codex/r8-gesture-control-20261105。保留账号、健康记录、绑定、配对；不重置、不删除系统蓝牙关系、不调整健康监测或佩戴校准。

## 已取得证据

- 原AAR和用户SDK文档的短视频原始模式2、阅读4与现实现一致，不盲目交换场景编号。普通正式1246在手机上。
- 精确R8系统节点为Mouse和Consumer Control；在正常页面确认短视频后，Mouse通道出现左右中键同时按下、大幅相对位移和滚轮输入，实际前台回到桌面。没有记录其他输入设备。动作次数/时间尚待用户回执，不能把全部采集事件都认定为一次严格受控动作。
- 随后通过正常页面关闭并读回关闭状态，停止两个采集器。没有因异常动作卸载/清数据或删除系统配对。
- 只读比对本机已安装QRing公共APK的RingGestureActivity：开启手势后另发触控关闭；现Bridge只修改选定通道。代码存在互斥缺口；是否为本只R8的全部根因仍需验证另一通道状态和修复后的实际输入，HID描述/解析错误也尚未排除。
- 厂商App公共APK、反汇编、原始事件、UI及构件只保存在仓库外E:\SayRing-R8-gesture-20261105，不提交设备标识或真实健康内容。SDK佩戴校准用于测量，不是滑动校准，没有调用。

## 修改

Android QRing手势写入增加真实能力约束下的互斥步骤：只读另一条已支持的普通控制通道；已关闭则不写，活动则保留其强度/触摸休眠参数关闭一次，并独立回读核验后才执行选定场景。关闭按钮也经过同一路径。读操作不改任何设置，不支持的通道不探测，RT11特殊触控协议不冒充已接入。操作槽、连接/目标/代次及阶段约束沿用，失败/超时不继续开启场景、不虚报成功；关闭保留真实零强度，不要求先设置力度才允许关闭。

## 验证记录

- 初始Windows rg路径通配符未展开失败，后改用目录和-g过滤；首次Python无pymupdf，改已安装pypdf；首轮文本输出GBK失败，指定UTF-8后完成。原始失败保留在私有运行记录。公开PDF只读，无修改。
- 主机回归、完整检查、构建、正式签名及实物结果随后追加；手势真实方向、另一通道原状态和HID兼容性目前均待验。Windows不能做iOS编译，本轮仅Android修复，不声明跨端实物通过。

## 主机验证与失败修正

- 新Node/Java夹具执行从实际QRingBridge提取的gestureControl、另一通道关闭/读回及原选定场景读回方法，使用真实模式/参数策略，只有无线、时钟和Flutter边界是替身。10个场景检查双通道关闭顺序、已关闭不重复写、原始阅读模式4、关闭零力度、失败/错误回执/参数变化、最多三次回读、不支持不探测、旧连接隔离和普通读取无写操作。把互斥分支改回立即继续的旧转移，真实断言在“另一通道须先关闭”失败。新增用例加入CI显式列表，不能替代真实方向验收。
- 首次新Java夹具在Windows默认GBK编译失败，新增明确`javac -encoding UTF-8`后定向4项通过。首批关联协议检查因PATH没有unzip为16通过/1失败/2跳过；补本机Git usr/bin后19项中17通过、2个Darwin/Foundation项在Windows跳过、0失败，未改SDK或忽略失败。
- `flutter analyze --no-pub`无问题；`TZ=UTC`及`TZ=Asia/Shanghai`分别`flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`，各2006项通过。
- 首轮检查包装器将Java的stderr提示转为PowerShell NativeCommandError而停止；Debug APK虽已出现，不凭此认定整轮完成。改为操作系统重定向，重新执行Debug及后续原生/Release/验签阶段。Debug双ARM1248再次成功，原生`:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1 --offline -Ptarget-platform=android-arm,android-arm64`通过。
- 原证书签名的1248诊断包已验签并发起`adb install -r`，当前等待用户本人在华为风险页完成继续安装/身份验证，尚不写已安装或实物已修好。安装前回读原UID与首次安装时间作为保数据对照，完整标识留在私有目录。
- 系统HID报告按描述解析为按键/相对位移，这是[Linux内核HID说明](https://docs.kernel.org/hid/hidintro.html)的一般契约，不能证明本只R8一定缓存错误。尝试只读sysfs报告描述被系统拒绝，无提权/绕过；系统公开dump没有给出完整描述。没有删除配对、调整全局鼠标设置或通过无障碍拦截来掩盖异常输入。

本机执行记录与脚本位于仓库外`E:\SayRing-R8-gesture-20261105`。分析/双时区/构建使用`Invoke-1248-Checks.ps1 -Phase ...`；外层重试脚本`Resume-Checks.ps1`仅重跑Debug之后被包装器中断的门禁。实际SDK协议回归命令包含`node --test tool/qring_android_gesture_exclusion.test.mjs tool/qring_android_photo_session.test.mjs tool/qring_android_disconnect.test.mjs tool/qring_android_radio_lifecycle.test.mjs tool/qring_android_connection_state.test.mjs tool/test_qring_camera_integration.mjs tool/test_qring_monitoring_integration.mjs tool/test_qring_reconnect_integration.mjs`。

## 正式构件与当前交付边界

- 原生JUnit汇总103项、0失败/错误。Debug及普通Release均为双ARM、1.0.10（1248），正式APK为72,814,401字节，SHA-256 `AEFF897E71445739B74B3CAD191B9D673C17E4C708A6103E4FBF0362ADDB6D91`。原正式证书SHA-256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`，cn.saydian.ring；正式Manifest无debuggable、极光生产参数及双ABI/zipalign门禁通过。既有两个ARM32闭源库仍为4KB ELF对齐，不声明适配全部应用市场。
- 首轮verify查找native.log，而实际重试记录为native-retry.log，修正引用后ABI核验通过；接着嵌套Windows PowerShell缺少Get-FileHash，改用.NET SHA256计算并完整重跑verify，最终退出0。未改SDK、签名材料或生产源码规避门禁；保留原失败日志。临时key.properties已清理。
- 最后回读手机仍为1246，1248诊断安装待华为本人确认。没有把安装发起、源码测试或正式包生成写成实物修复成功。旧包下最后一次正常页面回读为关闭；停止输入采集，未再自动开启场景、修改绑定/系统配对或进行阅读动作测试。
- 待用户安装确认后，先在新包正常页面执行关闭/读回并检查另一通道原状态，再安排受控输入与原厂App对照。短视频及阅读真实方向、HID报告/系统描述兼容性仍OPEN。不将互斥代码缺口认定为本次所有异常的唯一根因。
- 提交前执行git diff --check、显式暂存以及git diff --cached --check，fetch核对远端；仅推本轮修复分支，不推进main、发布后台、更新下载页或提交市场。
- 最后fetch另见共享5921962为周期日记功能，不含本轮Android QRing桥修复，未将其混入本轮已测源码或声称正式1248包含该新功能。自己的新修复分支远端尚不存在，无覆盖他人提交。

## 1248实物续检与本次异常定位

- 用户回复已安装后，实际回读为1248原证书诊断包；原UID/首次安装时间不变。正常启动后无需手动选择即恢复SD_RING_R8连接。正常页面执行关闭并读回关闭；调试阶段记录显示本次走gesture通道，没有执行另一普通控制通道的关闭步骤，不能把这只R8的异常直接归因于双通道同时活动。互斥修复是一处真实接入缺口，不是本次已证明的唯一原因。
- 用户明确授权“允许，仅重建这只R8的系统配对”后，通过系统蓝牙设置核对唯一的已连接SD_RING_R8详情，取消这一个系统配对，没有使用SDK解绑/恢复出厂，没有处理其他设备。原R8输入节点随后消失。SDK恢复期间系统已重新建立R8连接；再次点击该R8时出现的是断开确认，立即取消，没有再断开或接受额外通讯录/通话记录授权。
- 重建前同一R8的event7为Mouse，包含BTN_MOUSE/BTN_RIGHT/BTN_MIDDLE及REL_X/REL_Y/滚轮；重建后同一目标event7名称为SD_RING_R8，变为直接触屏的ABS_MT_POSITION_X/Y、跟踪ID与BTN_TOUCH，范围0..4095。前后使用同一1248二进制、同一SDK，本轮没有调整固件/健康设置。由此把本次异常定位为旧系统配对/HID识别状态不匹配；具体系统缓存字节受权限限制未读出，不能声称已取得错误描述原文，也不能推断所有R8/手机永久存在问题。
- 在新配对下正常页面选择短视频并真实回读，随后只采集精确R8触屏节点。用户对“上滑、下滑及是否误退”的反馈为“正常了”；记录恢复为竖向触屏轨迹，X保持，Y变化，没有先前鼠标三键组合。设置页前台保持可用。原始采集中的完整轨迹主要为一个竖向方向，不把它扩大为两个方向均有独立原始轨迹证明。
- 正常切换阅读并回读后，另开新采集，排除切换前视频动作。用户对“左翻、右翻”的反馈为“正常了”；记录为横向触屏轨迹，X变化、Y未变化，未出现先前鼠标组合键。完整采集轨迹主要为一个横向方向，反向方向以用户反馈为据，未单独取得完整原始轨迹。没有据设置页样本宣称所有第三方阅读App均已验收。
- 测试后正常关闭得到独立写/读回确认（13:47:33~13:47:35），当前模式为关闭，保留新系统配对；全部本轮控制日志和HID采集已停止，无遗留开启场景。
- 普通正式1248已`adb install -r`成功覆盖诊断版，回读无DEBUGGABLE，原UID/首次安装时间未变；拉回已安装base.apk的SHA-256与正式构件`AEFF897E71445739B74B3CAD191B9D673C17E4C708A6103E4FBF0362ADDB6D91`完全相同。正常主入口已启动。未重新构建、卸载或清空数据，不把普通包恢复等同所有其他健康功能重新验收。
- 源码c25ff44已推独立修复分支并ls-remote核验；公共Actions API仍403限流，未称远端CI绿色。该续检仅追加文档，没有改变已通过主机门禁的生产源码，未重复全量构建。
