# Android R21_4E5F 锁屏、后台与蓝牙恢复

## 范围与基线

用户明确继续测试华为手机上4E5F锁屏、后台及蓝牙开关后的自动重连，保留绑定，发现问题修复。本轮仍只操作ELS-AN00（Android 12/API 31）、cn.saydian.ring及用户已确认的R21_4E5F；不解绑、移除系统配对、重置戒指、清理健康数据或切换账号。

开始时App为已验签1.0.9（1218）Debug，固件RF22B_2.00.09_261019，原账号及精确绑定一致、ready、同步空闲、没有相机页面。Git基线a778c6a，工作树干净，fetch和ff-only同步后无新提交。前一轮三次前台距离重连与实拍已通过，不能直接当成锁屏/后台通过。

## 执行与判定

先验证锁屏保连，再在锁屏、Home后台、前台分别进行真实系统蓝牙关闭/打开，检查关机断开、同账号同目标绑定保留、在对应生命周期内恢复实际SDK握手及新的电量确认。使用OS电源键/Home和蓝牙服务，不能用手动重连、伪造生命周期或假事件替代。需要手机凭据时仅由用户在手机输入。

只读记录包含实际屏幕/锁屏、前台组件、Flutter生命周期、当前App PID、SDK连接阶段与电量确认时间。完整标识、账号和原始日志放在Git外。只监听配对/连接状态，不读取照片、短信或其他App内容。

本轮首先检验现有Debug，调试器可能影响进程保活，短时成功不能扩大为发行包长期待机保证。当前不测试强制停止或OEM杀进程后的自动启动。系统`cmd bluetooth_manager help`返回无shell实现，后续使用现有`svc bluetooth`并以真实适配器状态读回判定，不仅看命令退出码。

开始时手机解锁、Say Ring在前台、蓝牙开启，stay_on_while_plugged_in=7；保留该设置，使用明确锁屏键测试。后续实际结果、失败与修复分项追加。

## 环境修正与锁屏保连

初次KEYCODE_SLEEP及电源键均真实进入睡眠，但约2.4秒后又唤醒，App恢复前台，因此两次均不计锁屏通过。读取系统状态确认充电常亮为7，保存原值后临时设为0；随后系统保持Asleep、Keyguard showing=true、Flutter paused、App前台=false。测试结束必须恢复原值7；不修改锁屏凭据或绕过验证。

有效锁屏连续观察87405毫秒后，同一账号及绑定保持，SDK mIsConnected=true，目标实际GATT state=2/clientIf>0/services>0，锁屏保连通过。这是短时Debug连接检查，不是整夜待机或发行包保证。

## P1复现：锁屏蓝牙重开后假连接、无自动恢复

- 步骤：保持上述真实锁屏，使用svc关闭蓝牙，确认适配器OFF，等待12秒后打开；实际OFF到ON为14682毫秒。没有启动App、点击重连或解绑。
- 预期：OFF使旧会话和旧能力失效；ON后仅对当前账号保存的精确目标自动发起新连接、SDK握手及新电量读取，锁屏状态不依赖回到前台。
- 实际：原始GATT断开status=0已收到，但QRingBridge没有发布断开，原生代次仍25、connectedId/旧握手标志仍保留。ON超过139秒仍无新GATT连接或SDK握手；实际SDK mIsConnected=false、connecting=false、liveGattCount=0。Flutter却仍ready/connected，电量确认仍停留在关闭蓝牙之前。
- 影响：P1，核心连接恢复失败，旧状态可误导后续操作。现有绑定和账号均保留，没有以解绑重绑掩盖故障。

对断开状态调用只读getCapabilities得到AsyncError，符合当前原生CAPABILITIES_UNAVAILABLE分支；该诊断不计App崩溃。检查isolate pauseEvent=Resume，没有被诊断暂停。完整失败日志及状态快照私有保存。

拟修改QRingBridge系统蓝牙状态监听、旧会话撤销与ON后恢复触发，必要时补充App状态文案；保留精确目标、账号、取消屏障和真实SDK握手。原SDK disconnect字节码确认走disconnectDeviceKeepBond，不使用unBindDevice或移除系统配对。先增加失败回归，再构建新号覆盖安装并重测。
