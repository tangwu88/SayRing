# 戒指上下滑屏入口与 LuckRing 指导

- 用户要求手势控制屏幕上下滑动，参考 LuckRing。修改前 status/remote/fetch 成功；干净构建工作树由 54eff17 快进到最新 4dee4e66d1afc362b9a5b8bf08ced603c91dde5a，再创建 codex/ring-screen-scroll-20261017。阅读当前 AGENTS、交接、1053 和当日 QRing 手势记录、复盘与回归约定。
- 现场手机原已打开 LuckRing com.kewo.coolring/GestureControlDesActivity，只读截图与向下浏览参考说明：传感器贴合皮肤、兼容短视频 App、向上手势切下一条。没有看到向下动作说明，因此不编造全型号双向协议或固定点击次数。仅参考页截图/XML保留仓库外，无健康信息写入 Git；没有修改 LuckRing 设置或主动关闭其进程。
- 原源码已有 LuckRing sendGestureConfig(1) 的真实 ACK 路径，最新 QRing 已有 App 模式 1 对原生 2 及 expectedMode CAS/写后读回。手机当前 Say Ring 1065 早于最近 QRing 手势接入；本轮不假装这些协议从零新增。
- 本轮新增明确“屏幕上下滑动”快捷卡、确认状态和开关，开/关仅通过原 handshaken gesture feature 的模式 1/0 写入；QRing 仍按真实 availableModes、readbackVerified 和 raw expectedMode 校验，LuckRing 保留真实 ACK 语义。等待/错误/需重连均不乐观显示已开启，不自动写入或恢复设置、不替换其他未知参数。
- 使用说明加入佩戴、系统蓝牙配对、兼容性、参考向上动作和向下待实测边界；不添加无障碍服务、全局注入、遥控点击或绕过系统权限。支持状态不由广播名称或示例图片猜测。既有其他模式、账号隔离、同步、健康数据、后台和 iOS 产品边界不变。
- 范围：ring_screen_scroll_control.dart、prototype_pages.dart、prototype/device_features.dart、ring_gesture_guide.dart 及相应测试/文档。开关确认只代表模式设置，不代表实体手势或目标 App 上下滑屏验收。本轮不清数据、不解绑、不修改真实健康或供应商设置。
- 首次搜索误传不存在的 sdks/vendor 和 Windows docs/SAY-RING* 参数，只读失败后改用目录/实际路径检索。参考截图在 E:\SayRing-market-artifacts-20261017\gesture-scroll；未把原始截图/XML提交 Git。
- 验证与真机边界按实际结果追加；Windows 不能执行 iOS 构建，不把历史 Mac 和 R21 音乐验证当作本轮上下滑动已通过。

## 测试与构建过程

- 增加仅在模式确认后开放的只读滑屏练习页（20 个明确标记的练习卡片），没有合成手势/自动通过判定；便于实体操作时观察位置，不读取个人资料或健康数据。
- 首次测试补丁引用旧测试名，apply_patch 验证失败且未写文件；按实际名称修正。首轮定向125通过/1失败，为新增卡片改变高度后旧 QRing 拍照模式按钮未等滚动动画完成；增加 pumpAndSettle，保留原点击/原始 expectedMode 校验后126通过。
- 补充滑屏开关失败保持关闭且禁止重试、只读练习页跳转/手工滚动测试。最终定向 `flutter test --no-pub --reporter expanded test/ring_screen_scroll_control_test.dart test/ring_gesture_guide_test.dart test/coolwear_gesture_control_test.dart test/qring_gesture_bridge_test.dart test/ui_shell_test.dart` 132/132 通过。覆盖模式1/0、QRing原始状态CAS、不支持/未读/忙/重连禁用、无乐观状态、取消/失败及小屏2倍字体；手工拖拽测试不是实体戒指通过。
- `dart format` 仅本轮 Dart 文件。首次 analyze 因新增测试单行 if 缺大括号报1条info并停线，已修正，失败日志保留；随后串行重跑完整门禁。
- 构建1.0.2/1102，跟随当前版本范围，使用原受保护 Windows 正式脚本，在内存中仅把旧默认版本字面量1.0.0替换为1.0.2（构建1处、验证2处，先严格检查数量），不改磁盘脚本、生产门禁、证书、密码或供应商配置；日志/产物仅在仓库外。完整analyze、双时区Flutter、Android Debug/原生/Release/签名检查依次执行。
- 用户已同意佩戴靠近并暂时退出 LuckRing 进行真机验证。参考页面后来变化时检测到焦点不同，未盲目发送返回键。本轮最终设置、上下方向效果与恢复情况完成后再记，不把仅设置命令成功当作系统滑屏成功。

## 实际构建与 HR05 未通过项

- 最终 analyze 无问题；UTC 与 Asia/Shanghai 各 1280/1280 Flutter 测试通过。Android Debug 双 ARM 构建成功（121.5 秒）；原生测试 53 项全部通过，Release 1.0.2/1102 构建成功（383.2 秒）。这些是主机检查，不是实体滑屏验收。
- 正式 APK 的包名 cn.saydian.ring、版本 1.0.2/1102、min26/target36、双 ARM、正式证书、v2 签名、16KB zipalign 和生产推送清单检查通过。releaseRuntimeClasspath/ABI 门禁通过，仅保留已锁定的 JPush libjutils arm64 例外。43 个 ELF 中 arm64 全部 16KB 对齐；原厂 armv7 libDspConfig.so/libEcgAnaly.so 仍是既有 4KB，不修改厂商二进制。临时签名配置已移除，不提交产物或密钥。
- APK 存于仓库外 gesture-scroll/SayRing-1.0.2-1102-release.apk，SHA256 4F77D3BC64D6A1436A25D1AC5FCBB099F453569D4A2B674F58926D266E5D6292。`adb install -r` 返回 Success，实际安装 1102，首次安装时间未变化；没有卸载、清数据或解绑。用户授权后仅暂时退出 LuckRing，避免蓝牙占用。
- P1：HR05 握手并显示已连接，手势能力入口存在，但开启模式1后8秒内无匹配 ACK，页面显示需重连并保持关闭。用户实际做向上、向下动作后明确回复两个方向均无反应。之后仅重启本 App 以重建连接（保留绑定和数据），确认 HR05 再次连接后再试一次，仍未确认。不能交付为实体滑屏已打通。
- 只读核对参考 App 公开调用接口和当前原厂 AAR：双方手势写入均为 sendGestureConfig(int)，协议类型44；没有改成同名实体的类型128。参考 App 新版另有 sendTouchConfig(int)/触控能力接口，现有 AAR 缺少；这只是兼容性线索，尚不能证明 HR05 必须使用该接口。没有复制参考 App 的闭源代码或 SDK，没有猜测触控命令直接写环，没有放宽 ACK 或乐观标记成功。
- 只读检查系统蓝牙页面，当前可见项未匹配 HR05；HID 服务存在不等于目标已配对，未据此宣称根因已确认。没有配对陌生设备、改系统蓝牙开关或解除既有配对。原始蓝牙信息、参考包、截图和 XML 均在仓库外私有诊断目录，不进 Git。手机锁屏时停止操作，请用户解锁后再继续；没有使用历史密码。
- 诊断中 Windows 通配路径与不存在的 vendor/sdks 路径检索失败，以及 APK 分析器方法参数不完整的只读检查失败，均未导致源码或设备配置改变；改为实际文件/类级接口核对。
- iOS 构建和实体滑屏未执行（当前 Windows）；鸿蒙没有本型号厂商 SDK，不扩大能力。尚待 HR05 系统目标配对/固件与官方 SDK 兼容性确认，以及真实上下方向验收；不将主机通过、其他型号音乐控制或安装成功代替该项。

## 第二轮：用户确认 LuckRing 同环可滑动，补齐 HID 配对

- 用户确认同一只 HR05 在 LuckRing 可控制滑动，故不能再以型号不支持解释。重新 fetch 后 origin/main 仍为 4dee4e6，本轮接续独立分支 55fb983，保留其他工作树修改。第一次只读打开 LuckRing 显示暂无设备，用户随后亲自连接并停在控制开关页；实际为经典手势页/短视频，不据新版触控 API 的存在认定必须更换 SDK。
- 从用户提供的 Android&iOS_SDK20260910.zip 内 Android_SDK_DEMO_1.4.0.zip 完整核对 SDK Guide 第29节、README 与 SdkDemoActivity.createHid：启用 HID 必须同时调用系统配对和 sendGestureConfig(1)。现有桥只有模式写入，遗漏配对。这是已证实的接入差异，实际效果仍需新包验证。
- 修改范围：Android CoolWearRingBridge/CoolWearGestureState、对应 Kotlin 测试、Dart 手势写入等待上限和 UI 提示/测试。原厂二进制、协议类型、QRing、健康算法、后台不变；iOS 不加入 Android 配对代码。
- 仅用户主动写入非零模式、已握手且真实能力存在时，对 connectedId 精确对应的 BluetoothDevice 发起公开 createBond API；不取厂商全局缓存地址、不扫描/猜设备、不自动接受确认、不使用隐藏 PIN/解除配对接口。关闭模式0不删除系统配对。依据 Android 官方 BluetoothDevice 文档的异步 createBond/ACTION_BOND_STATE_CHANGED 流程。
- 新配对最长45秒同时等待系统真实 BOND_BONDED 与同代次匹配模式 ACK，两者无论先后均不可单独成功；已配对和关闭仍8秒。Dart等待上限50秒避免30秒先超时；失败需重连，不把超时当确认。监听核对精确目标、当前连接、代次及实际系统状态，完成/失败/断连/销毁清理。系统配对提示由用户确认。
- 安全与验收：本轮仅补齐原厂要求的系统 HID 前提，不能将创建配对或主机测试通过写成真实滑屏成功。测试、构建、手机安装和用户上下方向结果随后据实追加。
- 首轮第二轮定向测试126通过/1失败：小屏测试仍按旧提示“先完成系统蓝牙配对”查找元素，提示已改为“如出现系统配对请求”，因此 No element；同步对应查找文案后重跑全量，不删除失败日志。新增长等待测试已在此轮通过，验证31秒不会被Dart先超时，44秒原生配对失败保持原错误。
- 修正后 `flutter analyze --no-pub` 无问题（29.7秒）；`TZ=UTC flutter test --no-pub --reporter expanded` 1281/1281（1分50秒）、`TZ=Asia/Shanghai` 同命令1281/1281（1分37秒）。`:app:testDebugUnitTest --no-daemon --max-workers=1` 成功（5分35秒），实际XML总计57项/0失败/0错误/0跳过，新增覆盖配对与ACK先后顺序、配对超时、换连接拒绝迟到回调、模式0不要求配对。新增状态测试不能替代真实系统配对与滑屏。
- 系统 API 依据：[Android BluetoothDevice](https://developer.android.com/reference/android/bluetooth/BluetoothDevice#createBond())；createBond 返回发起结果而非配对成功，故仅依据真实系统状态与厂商 ACK 共同确认，不以返回 true 标记开启。
- 1103 Debug 243.3秒、Release 443.0秒编译成功，原正式签名/生产清单检查通过，临时 key.properties 已移除；SHA256 EB0F0E9DF036CD6F1492FBB240C3CA607CC6546E7D3BAE7F05D8D973529AEE90。仅作为配对修复中间产物，未安装或发布。
- 进一步现场只读核对：LuckRing 正常连接时系统存在 HR05 Consumer Control 和 HR05 外接触屏输入，均 enabled；与本 App 已保存的精确设备标识一致。暂时退出 LuckRing 后系统输入仍存在，但本 App 1102 回到等待靠近状态，重新连接仍未恢复。当前 CoolWear 只接受扫描列表中的候选，没有系统已配对候选，因此补齐这条发现路径，不解除已建立的配对来规避问题。
- 第三轮仅增 Android CoolWearBondedDiscovery 及测试，并在现有扫描槽中纳入系统真实 BOND_BONDED、真实名称符合既有路由的候选；不伪造 RSSI/厂商字段/能力。手动选择仍需明确选择，自动恢复沿用既有账号隔离的精确绑定筛选；连接后仍必须原厂设备信息与能力握手。QRing/冲突型号不进入该列表。未改 Dart 源码，保留已冻结 Dart 的两时区1281项与analyze结果；重新运行完整 Android 原生测试及Debug/Release，最终包使用1104区别于中间1103。
- 第三轮 `:app:assembleDebug :app:testDebugUnitTest --no-daemon --max-workers=1` 通过（3分15秒），新生成XML总计61项/0失败/0错误/0跳过；覆盖真实配对候选、无配对/非法标识拒绝、QRing/冲突型号隔离及既有LuckRing型号路由。正式1104构建沿用原受保护脚本及证书；本进程额外设置Java HTTP/HTTPS代理到本机127.0.0.1:7897，与既有Git/Flutter代理一致，不关闭TLS验证，不改全局代理或磁盘构建脚本。
- 实体范围继续区分：本轮HR05已由LuckRing建立系统配对，不为测试解绑。因此全新首次配对的系统提示/用户确认仍待独立验收；本轮先验现有配对的恢复、模式回执及实体上下方向，不把系统输入设备存在当作模式写入或滑动成功。
- 最终1104正式双ARM Release编译成功（250.1秒），正式证书/版本1.0.2/1104/包名/生产JPush清单/v2签名/16KB zipalign检查通过；临时签名配置已移除。APK SHA256 0260DC580A8B9F2E659772CE8DFEA0D206C88F091936F97FDFD610B348547752，仅在仓库外 gesture-scroll/SayRing-1.0.2-1104-release.apk。`adb install -r` 已发起，手机息屏时停止交互并请求用户解锁/确认；在收到实际成功与实体动作结果前不标记安装、恢复或滑屏通过。
- 用户确认解锁/安装后，`adb install -r` 实际返回 Success；包版本1.0.2/1104，firstInstallTime仍为2026-10-06 14:32:30，lastUpdateTime为2026-10-17 11:53:14，未卸载、清数据或解绑。正常main启动后设备页HR05实际显示已连接、电量可读、手势入口存在；对比1102的等待靠近，已配对目标恢复在本机此次通过。随后仅对该已连接HR05发起短视频模式1，模式与实体效果继续据回执记录。
- 1104 模式1仍未在8秒内收到匹配状态回执，保持未确认/需重连，没有改成超时成功。但 HR05 系统触屏仍存在，用户实测明确反馈“上滑正常，下滑无反应”；UI位置也实际变化。因此已配对恢复/上滑通过，模式状态判断与下滑仍未验收，不能合并为功能全部完成。
- 对精确HR05触屏设备节点进行有界只读输入捕获（不读手机触屏/其他键盘）：15秒窗口得到120条输入事件，6组触摸均为同一纵向方向；这不证明下滑能力不存在。用户进一步确认同一只HR05在LuckRing上下均有效，故继续对照原厂动作/输入，不以型号限制关闭该问题。
- 再次只读核对原厂模式常量与当前LuckRing公开调用接口：短视频仍为1，没有据猜测改成其他模式、类型128或新版触控命令。参考App清单未声明无障碍服务或INJECT_EVENTS；当前对照继续沿用真实系统HID路径，不新增全局注入。暂时退出本App再打开LuckRing，实际“我的设备(HR05) 已连接”，只进入既有“控制开关/手势控制/短视频”页，没有修改原厂开关。接下来对原厂下滑动作单独采样，结果另记。
- 用户确认LuckRing此前上下均有效，并按提示做下滑及上/下对照；又明确实际操作为不碰戒指的抬手/晃手，而非手指触摸戒指。不能因为新版SDK有sendTouchConfig或原厂警告占用触摸功能，就把本需求改成触控功能。
- 采样发现两项工具局限：重连后系统输入ID变化（路径可能重用），以及非PTY输出缓冲会使中途读取和短窗口为0，不能把这些0当作原厂不支持下滑。改为每段重新核对EventHub的HR05名称和精确UniqueId，仅捕获该目标的触屏/Consumer Control两通道。直接读取sysfs name/uniq被系统拒绝后没有提权或绕过，改用已允许的dumpsys信息。私有PowerShell诊断脚本使用隐藏后台窗口、有界子进程；后续已按adb帮助启用shell -tt并验证PTY_READY，以免短动作缓冲丢失。脚本、原始输入、截图与SDK接口诊断全部在仓库外，不进入Git。
- 已完成的参考捕获中有6组、以及动态捕获3组完整同方向纵向触摸，但没有取得可信反向滑动的阳性样本；不据此断言原厂无此能力，也不声称已证实下滑失败的根因。新版原厂手势接收器同为类型44，并非查到类型128可作为替代。
- 为重建原厂阳性对照，先明确告知后将LuckRing当前同一短视频手势开关关再开，最终恢复原先开启状态；原厂仅显示降低续航/占用其他触摸的功能提示，点击“好的”，未选“不再提示”，未解绑、清数据或换模式。随后进入原厂手势说明长页，未触发健康测量。资料中的占用提示是线索，不代替动作和协议证据。
- 当前交付边界：1104已正式签名保数据安装、配对目标恢复与上滑实测通过；下滑和模式回执仍待修复。代码e012a0a已推独立开发分支，尚未作为验收基线快进main。所有有界输入捕获已结束；手机暂留LuckRing手势说明，等待用户提供原厂下滑正常、同时可见动作和屏幕的短视频/现场演示，再精确对照，不继续猜测参数或改固件。
