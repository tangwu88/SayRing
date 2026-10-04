# Say Ring Android 1043 自动重连修复

## 问题与实测根因

- 1042 华为安卓真机设备页保留 R21，靠近仍停在等待；蓝牙 ON、定位模式 3、Android API 29、定位权限已授予。没有解绑、清数据或更换账号。
- 附加只读 JDWP 检查，桥接 cancellingConnection=true、recoveryConnecting=false；原厂 BleBaseControl connecting=false、mIsConnected=false、GATT map size=0。检查结束已恢复线程并退出调试器，未修改运行时字段。
- 核对只读原 SDK 字节码：disconnectDeviceKeepBond 已取消请求并关闭 GATT，但只在之前发布过 ready 会话时发断开通知。未完成握手的失败请求没有通知，桥接却一直等待，后续自动重试被永久阻塞。

## 修改范围与预期

- 仅 Android QRingBridge：取消后按当前代次、精确目标和真实 SDK 状态确认结束；SDK 不连接、不正在连接且目标 GATT 不存在时，共用既有断开清理并恢复精确绑定重试。仅超时、状态读取失败、仍有 GATT 或迟到探测都不得放行。
- 不改 SDK 原包、用户绑定、账号隔离、能力握手或健康算法；不启用厂商任意历史设备自动连接。探测最多 20 秒，仍未确认则保留取消屏障。
- 新增纯原生取消门禁与 64 组合单测；最终构建号 1043。全量检查、构建、覆盖安装与真实自动握手按后续实际结果追加，未执行项仍待验。

## 检查结果

- `flutter analyze --no-pub` 零问题；`TMPDIR=/private/tmp TZ=UTC flutter test --no-pub` 与 Asia/Shanghai 全量各 1159 项通过；`dart format --output=none --set-exit-if-changed lib test` 无变更。
- `./android/gradlew :app:testDebugUnitTest -p android --max-workers=1` 成功（2m58s），XML 实际共 40 项，失败/错误/跳过为 0。新增用例逐一覆盖取消状态的 64 种组合，不等于 64 个真机用例。
- `node --test tool/measure_ios_bundle.test.mjs tool/client_package_contract.test.mjs tool/test_coolwear_ios_integration.mjs tool/test_native_log_privacy.mjs` 27 项通过；Python release discover 31 项通过。
- 原厂 AAR SHA256 仍为 0021886ae500740945cf76e61d750812b96ff54d51fd0c32ebe77083862326d4。取消确认使用 SDK 的 isConnecting/ismIsConnected/getGatt，不使用永远返回 0 的 getConnectState。
- 诊断首次 Flutter attach 未发现 VM，退出等待；JDWP 首次对象方法/线程选择表达式失败，改为选择实际主线程后只读取字段，才取得以上状态证据。未改调试对象字段，结束后已恢复线程并移除本次创建的 ADB 转发端口。原始配对/账号/健康数据与调试日志均在忽略目录。

## 构建与真机结果

- Android 1043 Debug 双 ABI 构建成功，38.7 秒；独立保存 .build/SayRing-1.0.0-1043-debug.apk。新旧 1042 Debug 签名证书 SHA256 相同，包名 cn.saydian.ring，版本 1.0.0 (1043)。QA Release 构建成功，87.5 秒、69.4 MB，独立保存 QA 包；两包 apksigner 与 16 KB zipalign 检查通过。QA 签名不作为应用市场生产签名。
- iOS 无签名 Debug/Profile 严格串行构建成功，Xcode 分别 40.8/75.4 秒，最终 Profile 66.2 MB；核对 cn.saydian.ring、1043、UIDeviceFamily=[1]。没有覆盖当前 iPhone 的签名 Profile 1042，没有修改现有审核。
- 原厂 SDK 构建副本 30 项保持不变，仅移除既有 mapping 输出配置；QRing Foundation 合成映射断言通过。未修改 CoolWear/iOS SDK，本轮不把合成断言当作硬件结果。
- adb install -r -t 成功，华为安装确认界面仅点击“继续安装”；实际版本 1043，首次安装时间仍为 2026-10-03 12:55:15。正常启动后原登录、头像和旧记录可见，没有卸载、清数据或解绑。
- 只点击底部“设备”导航，不点击重新连接：R21 自动完成新的能力握手，原生新进程返回电量，设备页已连接且重连按钮隐藏。新进程没有继承旧桥接内存中的电量，不能把页面变化解释为旧缓存冒充连接。
- Flutter attach 到同一安卓真机和 cn.saydian.ring 的 VM 成功；热重载 8/2227 个库成功（2828 ms）。当前日志没有 FATAL EXCEPTION、Unhandled Exception 或 RenderFlex overflow，调试器保持附加；这不是全时段无崩溃承诺。
- 仍待真实远离/靠近三轮与后台、开关蓝牙压力复测。本轮没有人为修改 SDK 状态或把冷启动恢复当作距离验收，也没有真实复现新包在远离状态下的超时取消；该路径由旧包实测根因、原厂取消实现与新原生门禁测试共同核对，待补硬件复测。
