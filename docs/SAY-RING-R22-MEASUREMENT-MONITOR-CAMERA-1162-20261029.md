# R22 手动测量、监测间隔与双击拍照修复（2026-10-29）

## 范围、基线和设备

用户反馈当前安卓手机连接 R22：手动测量只显示 5%/完成，摘下后反馈慢；自动监测仅心率可设间隔；QRing 原厂 App 可双击拍照，本 App 无反应。本轮保留绑定、账号、健康记录和正式身份，不解绑、重置、清数据或改供应商算法。

修改前 status 干净，origin 为 tangwu88/SayRing，当前分支 codex/login-camera-r7ultra-1136-20261024。fetch --prune 得到两个新提交，干净快进 `2c5deab9351f968bc538e101ce1f6dd02e9e24f7` 至 `24dc5cbc0b3519400ba19632f57ed63d338b06ff`，保留同事的 Android 历史失败状态及趋势日期修复。本机初始手机为 Android API 31、cn.saydian.ring 1.0.7(1154)，不能把另一台 Mac 手机的 1161 安装记录当作本机已安装。

已读 AGENTS、国际交接、回归清单、问题复盘与最新 1161 实施记录。本轮依据用户原 ZIP 中 53 页中文 SDK 文档及 SDKSample、项目实际 qring_sdk_1.0.0.76.aar 的公开接口与字节码；附件内容仅作技术参考，不作为额外操作授权。

## 发现、修改和影响

- P2 测量进度：Android 桥明确写死开始 5%，有效结果 100%，SDK 回调没有百分比。改用既有不定进度 UI，等待真实结果；不按秒虚构百分比或健康值。Dart 其他 SDK 的真实进度保留。
- P1 摘下反馈：SDK 可用 status=RESULT_OK 的 StartHeartRateRsp 另带非零 errCode 报错。原桥只查 status，错误包被当成无有效值并一直等待 Dart 看门狗。现在任一失败字段立即结束等待、停止该轮 SDK 测量并提示；回调加测量操作号、精确连接和所有者上下文保护，取消/重试/换号后的旧回调不能结束新一轮。固件不发送通知时仍需超时保护，不能声称软件能立即感知所有摘下动作。
- P1/P2 监测间隔：原桥虽已具备各开关，readAutoMeasureIntervals 只返回心率。新增 QRingMonitoringSetting，使用真实设置回读，分开发布心率、血氧、压力和皮肤温度间隔。血氧使用独立带 interval 的写入；压力遵循固件返回的是否支持/最小间隔，并限定及清理 SDK 静态区间缓存；皮肤温度只接受正确类型的读取回包。HRV 当前响应没有可验证的间隔字段，保留开关，不造默认间隔。旧固件不返回有效间隔时只保留其已支持开关。
- 各项目开关操作先读取当前设置，保留自己的间隔；改频率不改变其他项目或启用已关闭项目。写入 ACK 后再读回核对启用状态与间隔。全流程绑定原连接/所有者，超时保持未确认状态，不把迟到/重复回调当成功。不改 CoolWear 共用心率/血氧间隔的布局或 iOS 原生上限。
- P1 双击拍照：当前 AAR 的 addOutCameraListener 仅给内部对象设置回调，初始化没有将它注册到通知分发表。厂家文档/示例直接注册 CMD_TAKING_PICTURE。改为在 Photo UI 开启 ACK 后注册该通道；退出、断连及异常时移除。原相机就绪/前台/所有者/连接代次、保持屏幕命令、快门去抖及保存相册流程保留，不用 HID 模式 5 替代 App 拍照。QRing 页面提示改为双击，其他 SDK 的摇动提示保留。

源码范围：Android QRingBridge、新增 QRingMonitoringSetting；共用相机页面与面板的按 SDK 提示；真实 SDK 解码/编码 JUnit 与原有 332dp 相机布局测试；两份既有工具检查适配新的监听与设置读取位置。SDK 二进制、后台、iOS 原生、原生鸿蒙未修改；不发布下载页或提交市场。

## 已执行的检查与工具失败

1. 文档提取：Windows python 应用别名未提供解释器；py 指向已不存在的 I 盘；pdftotext 不在 PATH；bundled Python 未装 fitz。最后用已有 bundled Python/pypdf 成功提取 53 页，未安装或升级依赖。SDKSample/解包 jar/字节码仅在 Git 外 `E:\SayRing-R22-fixes-20261029`。
2. 第一次格式化在 android 子目录使用根相对路径，报三个文件不存在，未改文件；随后在仓库根完成格式化。首轮 native 测试 2分15秒失败，原因为项目 JUnit 不含 assertThrows；改兼容断言，不升级依赖。
3. `:app:testDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline` 重跑 BUILD SUCCESSFUL（48秒），实际 XML 合计 73 tests，0 failures/errors/skipped；7 个新增用例使用实际 AAR 类验证独立血氧编码、无效/未开启间隔、压力下限和缓存清理、旧固件开关、温度类型和范围、拒绝写 ACK、status=OK 但 errCode=3 的即时失败。
4. `flutter analyze --no-pub` 零问题（74.5秒）。完整 Flutter 测试 UTC 1557/1557（3分15秒）、Asia/Shanghai 1557/1557（3分10秒）。相机卡片在 332dp、两种字号下无异常，包含双击提示，不代替真实相机或戒指验收。
5. Node 工具首轮 141 tests，131 pass、2 fail、8 skipped；两失败为 Windows 创建 symlink 的 EPERM。明确用 test-skip-pattern 排除这两项后，报告 139 tests、131 pass、0 fail、8 skipped。原失败日志保留，不能把两个未执行的符号链接测试算通过；旧拍照/监测结构检查随实现改到实际监听/辅助类，未放宽 ACK、忙状态和回读守卫。
6. 本机 UI 抓取一次 PowerShell foreach 管道语法错误，在执行任何 ADB 前终止；修正后发现 USB 暂时离线。手机随后重新上线，旧版首页显示未连接；不选择或绑定新戒指，不假定仍连接 R22。已通过会话询问佩戴、退出原厂 App 及一张测试照的许可，尚未收到准备完成回执，未按快门、未实拍。

## 构建、Git 和实物验收

Debug 1.0.7(1162) 构建成功（179.8秒），Release 构建成功（338.3秒）。最终原生测试及 releaseRuntimeClasspath 报告成功（2分37秒），XML 仍为 73 tests、0 failure/error/skip。私有 runner 首次添加双 ABI 参数未加引号，PowerShell 在启动前拒绝含逗号参数，未执行检查；补引号后成功，不改源码或 Gradle 配置。

正式 APK：`E:\SayRing-market-artifacts-20261029\r22-1162\SayRing-1.0.7-1162-release.apk`，72,063,783 字节，SHA256 `ca243d63d250b57dd73ce68711959fe61a67094b1bba69f02a229768d58f2d3e`。原正式证书 SHA256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`，cn.saydian.ring/1.0.7/1162、非 debuggable、生产 Manifest/JPush、双 ARM 依赖和 ZIP16KB 核验通过；两项原有 32 位 SDK ELF 对齐限制仍在，不宣称全部市场要求已通过。临时 key.properties 已移除。

逐项比较原始/Gradle 处理后 AAR：文件集合及全部二进制内容一致，唯一差异为预先审查的 proguard.txt 两条 mapping 文件输出规则被移除，未修改 SDK 字节码。

附加 Harmony 主机契约两个时区各 540/540 通过。Python 发布单测 Windows 首轮缺 bash；为本次进程增加既有 Git Bash 路径后仍有 23 errors（35 tests，含子测试），原因为 Windows 临时目录不满足 POSIX 绝对路径守卫、/bin/sh 不存在。原失败记录保留，不修改发布脚本或放宽路径校验以让本机通过；Linux/macOS CI 分开验收。

提交前 fetch 发现远端 `2b1b611`，只追加另一台 R21 手机的断连记录，与本轮源码无重叠。保留本轮明确文件为本地 checkpoint，再合并该远端记录，不覆盖、重置或强推。Git 推送及 CI 回执继续据实补充。

已对当前手机发起 `adb install -r`，仅覆盖原包。新鲜 UI 确认华为 Say Ring 安全检测页等待“继续安装”，当前安装版本仍 1154；已请用户本人确认/身份验证，不把安装请求写成已安装。未点推荐应用、未输入口令、未拍照。安装终态与 R22 连接/实测仍待用户回执。

尚未验收：R22 摘下时固件实际回包及手机结束等待的时延、各频率真实写入/读回和保留其他项目、双击触发及相册落盘、退出相机后无快门、连接稳定性；须使用已准备好的同一只 R22。R21 不在现场，不能把本轮结果当 R21 初始化禁用已修复。iOS/Harmony 编译及实际设备检查与 Android 本机测试分别记录；没有原厂鸿蒙 SDK，不扩大其能力范围。
