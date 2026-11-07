# XR 1.0.12（1263）原位安装与实时调试

2026-11-07（Asia/Shanghai）。用户要求把最新修复版安装到连接的 iPhone XR 真机调试；继续保留已有数据，1261 正式版本不动。

## 已完成

- 当前分支 `codex/hr05-ios-recovery-1263-20261107`，开始时工作树干净，fetch 后仍为 `dcbebe11601d9761dc28121be8247dbc533105b8`。HR05 功能源码为 `8d3ac2a`，仅格式整理后的实际运行基线为 `34cd0a2`，没有改动产品代码。
- 只核对 USB 连接的 iPhone XR / iOS 18.7.10，原装 `cn.saydian.ring` 1.0.11（1259）。15 Pro Max 当时不可用，未对它操作。
- 原容器 119 个文件、12,327,068 字节已私有备份。终止的仅为本仓库两条 11 月 3 日遗留的 XR attach 会话；核对原安装路径后停止本 App 进程，再做静止态备份。未卸载、恢复出厂、忽略设备、修改戒指设置或切换账号。
- 用正常 `lib/main.dart`、原有生产配置构建 **Profile 1.0.12（1263）**，不是集成测试入口。配置 17.62 秒、签名构建 42.06 秒，均退出 0。构建保持本机既有 iOS 15.0 覆盖；这不是默认 iOS 13 兼容验证。
- 运行源码指纹 `bc73b387578a9ee73a2a903448e319f1ab0e535f69077b25eb93eaa01a4812e7` 与已上传 TestFlight 完全一致。严格签名、`cn.saydian.ring`、团队 `W7SXQ4A226`、XR 授权设备、正常 AOT、无 Debug 内核均通过。Flutter 引擎 UUID 与本机 Profile 引擎一致，区别于 Debug/Release；不能直接用重签前后的完整文件哈希判断引擎种类。
- `devicectl device install app` 原位覆盖成功，系统安装列表明确为 **1.0.12 / 1263**。启动前比较 Documents、Application Support 和本 App Preferences：**71/71 个业务文件内容相同，0 缺失、0 改写**。这个静态保留证明不替代启动后的账号接口、数据同步或无线验收。
- 构建生成的临时 Flutter 配置已还原；本轮未操作 App Store Connect、1261 审核/发布或下载页。

## 实时调试与首次失败纠正

- 已启动正常 Profile 进程并核对系统中的实际安装路径。首次 `flutter attach --profile --machine` 先等待 Flutter，后报 Lost connection to device，没有取得 `app.debugPort`。`app.started` 事件单独出现，不能写作已接通 VM 或页面正常。
- QuickTime 只查看 XR 画面，没有录制或代替手机触控。实际画面为 iOS 的 Software Update / iOS 18.7.11 ready to install，遮住应用。已请求用户在手机选 Later 并打开 Say Ring；没有触发 iOS 更新。
- 随后按当前本机 Flutter 的 `DebuggingOptions.getIOSLaunchArguments` 纠正启动参数，使用 `--enable-dart-profiling --enable-checked-mode --verify-entry-points --vm-service-port=0`，保留 VM 鉴权，重新启动等待 attach。初次使用了旧 `--observatory-port=0`，不能在没有成功对照时将它或系统弹窗认定为唯一原因。
- 后续预览变黑，尚未看到应用首页。系统只报告 passcodeRequired=false / unlockedSinceBoot=true，不据此推断 Say Ring 已前台就绪。目标 App 进程存在也不等于 Dart 初始化或首帧通过。
- 两次手工启动/attach 均未取得可用 VM 地址，保留失败记录。随后使用当前工具链的标准 `flutter run --profile --no-pub --machine --use-application-binary=<本轮已验签的 Profile Runner.app> --target=lib/main.dart` 安装启动同一个包；不是默认 flutter drive，没有卸载。由标准路径取得 `app.debugPort`、`app.devTools`、`app.started`。
- 通过 `getVM` 与系统安装路径对应的进程交叉核对：当前 VM 属于 XR 上实际安装的 1263 正常主程序，主 isolate 为 Resume，保留鉴权。内置浏览器 DevTools 明确显示 Connected app / Flutter native (profile build) / arm64 iOS，并保留该调试页。
- 用户随后确认已选 Later 并打开 Say Ring；`didSendFirstFrameEvent` 和 `didSendFirstFrameRasterizedEvent` 均变为 true。实际手机画面为“添加设备”，列表显示 R7 Ultra 与 R8。没有把缓存条目/扫描到的名称当作已连接，也未代选、解绑、重置或写入新目标。

## 启动后数据复核

- 标准启动后再次私有复制容器：原 71 个业务文件均存在，69 个内容相同，2 个有正常运行写入，未据此宣称数据丢失或仍逐文件完全相同。
- Preferences 唯一变化为旧 SDK 的 `QCLastConnectedIdentifier` 被移除；源码中的既有 `QCCentralManager` 断开流程会清理该项。这不是 HR05 本次新增修复的实物证明，也不能将 SDK 缓存等同于账号绑定；其他偏好未变。
- 另一个变化是健康数据库。使用现有只读 SQLCipher 读库工具对比安装前及启动后副本，密钥仅在当前精确 VM 的内存中读取并瞬时使用，不打印或落盘。只允许 `getVM/getIsolate/getObject/getInstances`，没有调用 App 方法、写 SQL 或访问其他进程。
- **原 448 条健康记录全部保留，启动后仍 448 条；0 缺失、0 payload 改写、0 指标/测量时间改写，所有原 owner 范围均保留**。当前 session 与存储 owner、活动健康 owner 均对应；不把这个归属证明当作新登录/云端接口或新戒指同步通过。读取前后加密备份文件哈希未变。
- 当前调试连接和前台扫描页已验收。15 Pro Max/HR05 持续连接、自动恢复、活动及睡眠同步仍需单独实测，不能以 XR 安装、448 条记录保留或主机检查代替。

## 命令与材料

- `xcrun devicectl list devices`、`device info apps`、精确安装路径对应的 `device info processes`；文件/结果仅私有留存。
- `device copy from --domain-type appDataContainer --domain-identifier cn.saydian.ring --source .` 备份；安装脚本在真实签名和每个业务文件一致性检查后才允许继续。
- 同源码 Profile 使用 `flutter build ios --profile --config-only --no-pub --target=lib/main.dart --build-name=1.0.12 --build-number=1263`，随后串行 Xcode 签名 build；没有重新运行功能测试或复用旧二进制冒充新构建。
- 两个本进程范围内的可选递归扩展属性清理分别超过 5 秒后终止；保留原属性。最终构建成功，临时配置恢复为原内容，未修改源码或移除功能。
- 上传源码 [CI 42314429620](https://github.com/tangwu88/SayRing/actions/runs/42314429620) 本轮只读确认 **quality、iOS、Android、两时区 Harmony 共五项全部成功**。这是主机回归/编译结果，不是 XR 页面或 HR05 无线验证。
- 构建/安装/保留/首次失败和后续 attach 日志在忽略的 `build/xr-1263-debug-20261107-f570yg_h/`；原容器位于用户私有 `Library/Application Support/SayRing/device-backups/` 下。账号/密钥/完整手机日志/画面不入公开 Git。
