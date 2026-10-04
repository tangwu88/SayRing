# Say Ring 1053：安卓手势与固件升级入口

## 范围与来源

- 基线 6caf38c，当前分支 codex/macos-update-20260930。仅 Say Ring，包名 cn.saydian.ring，生产 API https://app.saydian.cn；不改 App Store 审核、不卸载或清数据。
- Android 使用仓库保留的原厂 coolwear_bluesdk-release.aar，只读提取 classes.jar 检查公开 API 和字节码，原 SDK 不变。六种模式为关闭、短视频、音乐、阅读、拍照、电话。
- 实际发送接口 sendGestureConfig(int) 构建 Cmd 1 / DataType 44 / 单字节模式；回包 RCVD_DATA_TYPE_GESTURE_DATA 的 getControlType() 返回确认模式。名称相近的实体 toCEDevData() 使用 128，不能拿它代替官方发送方法。
- 使用说明复用 1052 已核对的原厂手册及当前 App 行为，双平台按手机名称显示。型号的触控次数不统一，不编造 HR01 点击映射；电话手势不等于来电提醒。

## 修改

- Android 手势能力由真实握手、连接和 gestureSupported 功能位共同决定，SDK 标志不支持时不开放；没有扩大来电提醒或 QRing 能力。
- 写入仅接受整数 0–5，等待同模式回包，8 秒超时失败。同步、测量、设置和手势写入互斥；断连、换环、销毁清除确认和待处理请求。
- SDK 回包无请求 ID，超时后禁止同连接重试，须重新连接。捕获到的旧代次和非匹配模式回包不能确认新操作；不声称能识别 SDK 未携带的外设身份。
- 指令开始时清掉旧勾选，失败后重新读取本连接状态；超时显示重新连接提示并禁用模式，不能把缓存模式当本次成功。
- 关于设备新增固件升级页面，显示真实固件版本，支持刷新设备信息，断开不可刷新，未知不补造版本。窄屏和大字号可滚动。
- 固件刷写未开放：CoolWear SDK 有 OTA 状态/数据命令，QRing 有 DFU 相关接口，但本 App 尚无完整 OTA 传输；服务端当前无设备固件发布接口，也没有经过验证的原厂固件、硬件兼容约束和恢复方案。页面明确说明，不显示已是最新，不提供任意文件刷写，不启用 supportsOta。

## 测试与纠错记录

- 首轮定向失败两项：拍照模式在 800×600 测试窗口外；动态 iPhone 文案断言含旧空格。显式滚动、等待布局并核对真实文案后修复，未去掉交互断言。
- 新固件测试首次编译失败：PlatformException 不是 const 构造；修复测试声明。最终定向 109 项通过，覆盖六种模式、无效输入、原生失败、超时清旧勾选、固件入口/未知/刷新失败/窄屏大字。
- 辅助回归首次从 android 工作目录执行，日志目录不存在而退出；修正为仓库根目录并显式进入 android。Node 34 项、发布工具 Python 31 项通过；Android 原生 48 tests / 0 failures / 0 errors / 0 skipped。
- Foundation 首次误传不存在的 .m 文件，编译失败；这些策略实际为头文件内联实现，改为编译 native_coolwear_policy_test.m 后成功执行。只使用合成输入，不等同设备验收。
- flutter analyze --no-pub：4.6 秒，零问题。git diff --check 通过；再次 fetch 后 HEAD 与远端当前分支一致，未拉取覆盖工作树。
- TZ=UTC / TZ=Asia/Shanghai flutter test --no-pub --concurrency=1：各 1186 项通过，分别 93 秒 / 131 秒。原生合成测试和主机测试不等同硬件功能验收。
- flutter build apk --debug / SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release：生产 API、1.0.0 (1053)、双 ARM，分别 21.5 秒 / 102.6 秒成功，Release 显示 69.5 MB。输出保留于忽略目录，不用于市场上传。
- 双 APK 的包名、版本、arm64-v8a / armeabi-v7a 和旧包相同 SHA-256 签名均核对；内部 QA Release zipalign -c -P 16 检查通过。不是正式发布签名，不冒充 Play 正式包。
- iOS 同一源码/生产 API 串行 unsigned Debug / Profile 编译分别 57.3 秒 / 93.8 秒成功，Profile 显示 66.3 MB。Info.plist 验证 cn.saydian.ring / 1.0.0 / 1053 / UIDeviceFamily [1]；codesign 明确未签名，不能直接安装 XR 或作为上传包。
- 本轮未改 API、账号系统或现有审核；没有固件查询/下载/刷写请求，也没有固件更新成功声明。原截图、数据容器和 APK 均在 Git 忽略目录，未提交个人数据或签名材料。

## 真机边界

- 安卓 PPA_LX3 当前 1052，已在保留数据前提下备份本机应用容器（102 MiB）。1053 adb install -r 停在华为风险免责确认，未代接受或绕过；实际包管理器仍显示 1052。覆盖完成前不声称新原生手势已经装上；不会自动换绑扫描列表内的其他戒指。
- iPhone XR 开发者模式已开启且已注册，Apple 设备状态 Processing，平台提示 24–72 小时后可能允许签名；现有开发描述文件不包含 XR，1053 未安装。不把无签名构建当作安装成功。
- 没有真实手势系统控制、固件刷写和升级后版本回读证据。新增固件页面只是可核对的入口与真实状态，不代表 OTA 功能已完整交付。
