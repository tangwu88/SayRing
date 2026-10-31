# 客户端审查修复版 1200：iPhone XR / R8 真机续测

时间：2026-10-31（Asia/Shanghai）。源码提交 `0152b7f51fecd41327cc5ba00bb4e3a0dd55cd9c`，分支 `codex/fix-client-audit-20261031`。本轮只安装与只读观察，不修改账号、戒指绑定、固件、手机蓝牙配对或健康记录。原先五项源码修复与宿主/CI 回归见 [审查修复记录](SAY-RING-CLIENT-AUDIT-FIXES-20261031.md)；本记录只补充实物证据。

## 修改原因、范围和预期

- 原因：前轮 AUDIT-03 只有回调夹具，没有 XR / R8 真实时序。用户要求继续验证并保留现有数据。
- 影响范围：本轮新增测试记录；App 源码、接口、健康来源和设备设置未修改。
- 预期：同一 R8 可持续连接；自然断连后按原绑定自动恢复；覆盖安装不丢现有数据。

## 构建、安装与保数据核验

1. 开始前确认当前 XR 在线，旧包为 `cn.saydian.ring` 1.0.8（1198）；终止同一 XR 上遗留的 Flutter Debug 附加，避免两个运行器争用。先通过 `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier cn.saydian.ring` 私有备份完整容器，成功取得 102 个文件。备份、VM 地址、原生日志均在 Git 外权限受限目录，未纳入本仓库。
2. 从上述固定提交运行 `flutter build ios --config-only --profile --no-codesign --no-pub --build-name=1.0.8 --build-number=1200`，并用 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Profile -sdk iphoneos -destination 'platform=iOS,id=<XR_UDID>' -derivedDataPath build/ios-audit-1200/DerivedData IPHONEOS_DEPLOYMENT_TARGET=15.0 build` 串行构建。使用原有本机私有配置中的 API 与商城定义，未把它们提交到 Git。Xcode 构建退出码 0，`codesign --verify --deep --strict` 通过；包名、版本、开发团队和 arm64 均与目标匹配。命令行最低系统 15.0 是本机 Xcode 27 的构建覆盖，不代表仓库默认 iOS 13 的本机编译通过；默认目标由远端 CI 另行验证。
3. `xcrun devicectl device install app` 对 XR 原位覆盖安装 1200，没有卸载。安装后读取到 1.0.8（1200）。安装前后 100 个共有文件内容未变化；各有 2 个变化的文件名只是系统 `.ktx` 缓存轮换。正常 `lib/main.dart` 的 Profile 包在 XR 前台运行，Flutter VM 服务可读。
4. 测试后再次私有备份完整容器：前后均为 102 个文件，`Documents` 下 49 个文件没有缺失或内容变化；原有 14 张 JPG 和 42 张 PNG 没有缺失或内容变化；应用支持目录中的数据库文件仍在且内容未变化。仅观察到 2 个 `.ktx` 缓存文件轮换和 3 个非文档缓存/状态文件变化。此核验只证明本地文件保留，不证明云端同步或历史记录完整性。

## R8 真实连接结果

- 起始状态：XR 上同一 `SD_RING_R8` 显示已连接，能力状态 `ready`，非同步中，界面状态为“已同步 6 条”。这个文案是现有状态，不把它计为本轮新增 6 条历史记录。
- 第一轮低开销静置观察：每约 10 秒从已附加的 Profile VM 只读采样，37 次采样，VM 请求错误 0。连接持续到约第 231.7 秒；第 241.7 秒首次读到断开，至第 361.9 秒观察结束仍未恢复。13 次连续采样为断开；这段时间 `isWearableRecovering` 均为 false。随后再次查询时同一目标已自动连接，能力再次为 `ready`，但恢复的精确秒数没有采到，不能写成“快速重连”。
- 第二轮从重新连接状态再静置约 294.3 秒，30/30 次采样均为已连接、无 VM 请求错误，结束时仍为 `ready`、非同步中。第二轮短时稳定不能覆盖第一轮失败。
- 本轮没有主动断开、强制重连、切换系统蓝牙、重置戒指或切换账号。`idevicesyslog` 的本轮受限采集没有得到有效 QRing 行，因此没有这次断开的新鲜 CoreBluetooth 错误码。较早 1198 轮曾记录系统 `CBErrorDomain/code 6` 与弱 RSSI，见 [1198 记录](SAY-RING-IOS-RECOVERY-1198-20261031.md)；不能直接替代本轮错误原因。

## 判定和后续门禁

- AUDIT-01/02/04/05 的源码、回归和远端 CI 结果保持原记录；本轮未重新实测账号并发、健康授权倒计时、更新 404 或 Android 加密密钥恢复。
- AUDIT-03 的真实蓝牙关闭/重置路径仍未执行。自然断连及缓慢恢复在 1200 上复现，故 **XR / R8 连接稳定性未通过**。断开期间恢复指示为 false 值值得继续核对事件顺序；仅凭 VM 状态不能把它定性为独立根因或称已修复。
- Android 当前没有连接设备；加密密钥异常只在隔离测试和 CI 中通过，真实用户库不注入故障。
- 1200 是开发签名的普通主入口 Profile 包，已原位留在 XR 用于后续复测；不是 TestFlight 或 App Store 构建。本轮不发布、不合并主线，审查 PR 维持草稿。下一次需在原 XR / R8 上采到系统断开码和恢复事件，并做另一戒指或另一手机的受控对照，再判断是 App 时序、XR 无线还是 R8 射频/固件问题。未经证据不改变连接参数或以重置设备代替修复。
