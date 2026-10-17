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
