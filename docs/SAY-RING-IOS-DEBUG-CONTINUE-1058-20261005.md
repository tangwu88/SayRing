# iPhone Debug 续检与权限状态修复：1058

## 范围和基线

- 2026-10-05，继续 Say Ring iPhone 真机调试；基线 820f32f，分支 codex/macos-update-20260930。开始和修改前 fetch / ff-only pull 均为已更新，工作树原先干净。
- 使用当前可用的 iPhone 15 Pro Max / iOS 26.6。包名 cn.saydian.ring，生产第一方 API 仍为 /global；不操作其他 App、账号或当前 App Store 审核。
- 原调试主机进程已结束；没有把旧 VM URL、已安装包或普通 App 进程写成仍在线的调试证据。

## 保护与调试恢复

- 获取新的安装、进程、解锁清单。按 cn.saydian.ring 的实际容器路径核对，没有匹配通用 Runner 名称去停止其他应用。
- App 当时未运行；Library / Documents 分别私有备份成功，合计约 11 MiB，备份根目录权限 0700。这不是完整系统或 Keychain 备份。未卸载、未清库、未解绑。
- 第一轮 flutter run --debug --no-pub --use-application-binary 失败：characters、vector_math 等锁定依赖缓存文件缺失。flutter pub get --enforce-lockfile 恢复依赖成功，锁文件及运行时版本没有变化。
- 恢复依赖后的两轮安装成功，但 VM websocket 分别出现 Connection closed / Connection reset。verbose 日志确认苹果原生启动和 JIT 已运行，Flutter 的 iproxy 转发失败；未把它宣称为已确定的 App 崩溃。
- 采用 devicectl --start-stopped 启动同一签名 Debug 1057，使用本机 Flutter SDK lldb.dart 的 JIT 断点处理方式附加到精确 App PID，保留 VM 认证。通过本机发现的手机地址直接连接 VM，不更改 Flutter SDK 或系统权限。
- 手动 LLDB 输入脚本遇到 TTY 缩进，改用私有 Python helper；attach 异步完成前的 continue 曾报 Process must be launched，待实际 stopped 后继续成功。Foundation 表达式先导入模块并明确对象类型；不把表达式编译错误误判成设备故障。
- flutter attach --debug-url 在当前 wired 识别下仍会尝试转发；只提供 host-vmservice-port 时，该参数默认被 DDS 占用。明确同时指定 host-vmservice-port=64817、dds-port=64818 后连接成功。首次只读 evaluate 缺 compilation service 是 Flutter 尚未附加，不是业务表达式错误。
- 最终实际 VM getVM HTTP 200、一个 main isolate；Flutter 连接真实 view、提供 DevTools、第一次热重载成功，8 / 2228 libraries，961 ms。原生调试器和 Flutter 均保持附加，不关闭认证、不用另一平台代替 iPhone。

## 实际设备与页面结果

- 只读 VM 确认旧登录仍有效、正常账号模式、保存的绑定仍在。首轮 R21 自动恢复后能力 ready，真实功能含 findWatch / healthMonitoring / camera；未点击重新连接、未修改能力或绑定字段。
- 随后真实断开。只读原生状态为蓝牙 poweredOn、精确绑定目标及账号上下文存在、CoreBluetooth peripheral connecting，取消和系统恢复取消屏障均为空；目标匹配验证为 true，没有输出 UUID / MAC。
- 后续再次自行完成新的握手并开始历史同步。本轮未安排物理远离三轮；自然断开 / 自动恢复不冒充三轮距离、后台或真实拍照验收。
- 通过现有页面的正常回调查看设备、关于 Say Ring、权限、关于设备及固件页。未构造隐藏路由、修改设备能力、改变同意或权限。
- 截图使用当前真机 VM 的 Flutter inspector 渲染保存到私有目录，部分带根渲染边界空白；不是完整系统截图。原生截图因 usbmux 无匹配设备、RSD 连接 reset 未取得，失败单独保留。
- 关于页品牌和说明无重复；固件升级仍只从关于设备进入，未取得可信固件资源，未执行刷写。完整摇动拍照、保存相册和 OTA 仍待验。

## 发现与修复

- 权限页在断开时建立系统权限快照，当时没有相机行；同一页面收到迟到握手后显示相机行，却没有查过 camera.status，因此错误显示“状态暂不可读取”。这是展示权限集合与状态读取集合混用，不是系统真实拒绝。
- lib/ui/pages/settings.dart：读取状态时包含已实现的相机权限，即使当前设备能力尚未返回；界面仍严格按实际能力展示。仅查询 status，不调用 request，不扩大权限或猜测支持。
- test/ui_shell_test.dart：双平台覆盖迟到相机能力、准确已允许状态、断开隐藏及只读查询不触发授权。旧状态读取断言补相机枚举 1。
- 第一轮新增测试逻辑通过，但结束时平台调试变量未在 Flutter invariant 检查前恢复，两个夹具失败；改为 try/finally 恢复。首次全量运行已在修改前编译该夹具，仍保留两个失败记录，随后重跑修正版。

## 回归与交付

- 修复前 analyzer 零问题，上海时区完整 Flutter 1194 项通过。修复后权限定向 5 项通过；格式化与 diff 检查按实际命令记录。
- 1058 构建、修复后的完整回归、覆盖安装及最终状态见下方；未执行项仍保留待验。
- 私有日志、备份、截图、账号、实际健康值和设备标识不入 Git；提交只包含此次权限修复、模拟测试与脱敏记录。

## 1058 最终结果

- `dart format --output=none --set-exit-if-changed lib/ui/pages/settings.dart test/ui_shell_test.dart`：2 文件无变化；`git diff --check` 通过。`flutter analyze --no-pub`：零问题，13.8 秒。
- `TZ=UTC flutter test --no-pub --reporter expanded` 与 `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded`：分别 1196 项通过，2 分 33 秒 / 2 分 24 秒。权限定向 5 项通过。
- Node 工具测试 86 项：85 通过，Windows ACL 平台检查 1 项跳过；原生源码契约 29 项通过，共 115 项。QRing camera policy、QRing Foundation mapping、CoolWear policy 三个 Foundation 可执行测试通过，仅为合成输入验证。
- Python release 测试 33 项通过。Android 应用原生 XML 汇总为 11 套件 / 51 项，零失败、错误或跳过；最初不带 `:app:` 的 Gradle 命令还执行第三方 CameraX 测试，约 7 分钟未结束，主动中断该测试客户端（exit 130），不将第三方完整套件写成通过。随后单独执行 `:app:testDebugUnitTest --rerun-tasks`，18 秒 BUILD SUCCESSFUL，301 tasks executed；新 XML 仍为 51 项全通过。
- 所有构建使用生产 API define、空 JPush define、1.0.0 / 1058；iOS 串行 `flutter build ios --debug --no-pub`（172.7 秒）后 `--profile`（142.9 秒）均通过，Profile 60.1 MB。Debug 和 Profile 均严格验签；Bundle ID 为 cn.saydian.ring，UIDeviceFamily 仅 1。开发描述文件包含本机且未过期；完整 plist 转 JSON 遇证书二进制内容，改用明确字段读取验证，没有因此跳过签名门禁。
- Android `flutter build apk --debug --no-pub` 通过（211.1 秒）；Java 17 + `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub --target-platform=android-arm,android-arm64` 通过（167.2 秒，69.5 MB）。这是 QA 签名回归，不是应用市场发布包；本轮未安装安卓。
- 验签后的 Debug 单独保留在 `.build/1058-debug/Runner.app`，Profile 在 `.build/1058-profile/Runner.app`，不会拿后构建的 Profile 误当已安装 Debug。QA APK 位于 `.build/SayRing-1.0.0-1058-qa-release.apk`，SHA-256 为 `2f17dcbb6d0c7d0b933a1e5ba2b26ef5a9b741980474f17711522edf94366b42`。
- 停止已核实的本 App 旧 PID 后，重新备份 Library / Documents 成功约 12 MiB，私有目录 0700。`devicectl device install app` 覆盖安装 1058 成功；未卸载、未清库、未解绑，安装后旧登录、账号模式和绑定仍可读取。本轮不声称完整 Keychain 或全部健康数据逐条校验。
- 1058 用精确新 PID 启动并附加 LLDB，首次 Bonjour 记录取到了旧认证，Flutter 连接返回 HTTP 403；保留日志，停止这次尚未连接的 attach，改用最新服务认证重试成功。没有关闭认证或误判 App 崩溃。
- 新 Debug 实际 VM 可读、一个 main isolate，已连接真实 Flutter view；热重载 8 / 2228 libraries，1091 ms。当前 DevTools URL 已私有保存，Codex 打开请求返回 queued，不宣称已显示浏览器。原生 LLDB 与 Flutter attach 均保持连接。
- 1058 重新启动后 R21 自行握手 ready，未点重新连接。正常 UI 进入权限管理：蓝牙已允许、位置未允许、相机已允许，不再有相机状态暂不可读取；未发起权限请求。
- 正常入口进入 QRing 遥控拍照：实际 CameraController 已初始化、原厂遥控会话已开启，显示“摇动戴戒指的手，或点击快门”。只读取状态，未拍摄、未保存照片、未用模拟快门代替摇动；退出该页执行现有停止流程。
- 关于设备里的固件页显示实际固件版本，在线升级未开放；没有可信原厂固件及服务，不执行刷写。摇动拍照与相册保存、三轮距离及后台重连、CoolWear 对应实物、OTA 仍待验。
- 多层路由下只读 UI helper 最初匹配到多个保留的 BackButton，返回 not_unique 而未操作；限制到当前 ModalRoute 后正常返回设备页。未修改 App 导航源码或把此诊断选择错误宣称为 App 闪退。
- `/global/api/saydian-app/v2/auth/capabilities` 最终再次 HTTP 200；没有发送真实 OTP、上传新健康数据或修改服务端配置。
- 既有 App Store 审核、TestFlight、下载页、服务端和其他 App 本轮均未改动。只推送当前 Say Ring 分支，不把尚未全部硬件验收的修复标为 main 接受基线。
