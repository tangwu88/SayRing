# Say Ring 安卓 1039 构建与真机启动

## 范围与步骤

- 用户本轮明确要求恢复 Android 构建、安装连接手机并启动调试。基线 `72b3f76707ec7eec83af2fc3f33c1746518b296e`，干净工作树 fetch/ff-only 一致；只操作 Say Ring，保持包名、账号、绑定及健康数据，现有 iOS 审核不变。
- 先核对目标手机、旧版本和签名；构建两种 ARM ABI 的 Android Debug 1039，校验包名/版本/签名，再尝试保留数据覆盖。签名不一致时禁止卸载旧包、清数据、换临时包名或绕过平台校验。
- 安装通过后通过 Flutter 真机连接取得进程/VM 证据和启动页面，检查崩溃及错误；不存在实际数据或戒指未连接时明确待验，不伪报硬件全部通过。源码若需修复则补测试和构建，记录后推送当前分支。

## 初始检查

- ADB 已授权识别华为 PPA_LX3，Android 10 / API 29，ARM64/ARMv7 支持；手机停留在系统桌面，存储约 44 GiB 可用。本机可用 4.0 GiB，无并发 Flutter/Xcode/Gradle 构建。
- 已安装 `cn.saydian.ring` Debug 0.1.21 (1004)，首次安装时间 2026-09-29 00:12:40；未卸载或读取私人账户数据库。安装清单/原 APK 只保留在忽略目录供只读比对。
- 旧包证书 SHA-256 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`，本机 1036 Debug 证书 `1350168096373439fbb4fb80c0acd145f209e06310ddb658ce318d765525cb97`，不相同。先查找用户本机/交接中原调试签名；不把签名冲突当作允许清空用户数据的理由。
- 前轮相同源代码双时区 Flutter 各 1142、iOS Debug/Profile 与隔离 QA Release 已通过，具体证据见客户端整理记录；本轮 Android 构建、安装和 VM 结果独立记录。

## 构建与安装检查

- 首次 Debug 构建失败：`:app:mergeDebugAssets` 检测到 Gradle 9.1.0 的单个 QRing AAR 转换缓存被修改。停止空闲 Gradle daemon 后，仅将明确报错的 49 MiB 缓存移到本仓库忽略目录隔离；原 AAR/SDK、源码、产物和签名文件未删改。重试 30.5 秒成功，首次失败日志保留。
- Debug `1.0.0 (1039)` 使用生产 API `https://app.saydian.cn`、空推送键构建。`aapt` 核对 `cn.saydian.ring`、主 Activity、`arm64-v8a` 和 `armeabi-v7a`；`apksigner verify` 通过。APK 158733813 字节，SHA-256 `ea8a203947162372c2571e09cf4f1ec31163ae4e77b43ca9bd40071bae336ed7`，忽略目录产物 `SayRing-1.0-1039-android-debug.apk`。Debug 包包含调试引擎，不能作为商店分发包或与 iOS Profile 减包结果比较。
- 新包签名确认为本机 `13501680…`，不匹配手机旧包 `99b006c6…`。对本机项目、用户 Downloads/Documents、Android/Gradle 目录及现有交接 ZIP/嵌套源码 ZIP 做只读签名文件名检查，未找到旧包签名私钥。APK 或公开证书不能恢复签名私钥，不借用其他产品上传密钥。
- 构建过程中目标手机从 ADB 列表消失；尝试启动既有 1004 时返回 `device not found`，随后停止等待设备的命令。未实际执行覆盖安装、卸载、清数据或替换包名；没有取得页面、进程、VM Service 或实际设备功能验收证据。
- 一次 Release 检查漏设模式变量，被 `verifySaidianReleaseMode` 按预期拒绝；未绕过门禁或修改生产配置。随后显式使用 `SAIDIAN_ALLOW_QA_RELEASE=true`，内部 QA Release 94.3 秒成功，保存 `SayRing-1.0-1039-android-qa-release.apk`。版本/包名/ARM ABI 与 Debug 相同，69340875 字节，SHA-256 `7ccce803b03703454bf4b748c9730a72c065f7aeb62d64e17eb997f6fdd71fc4`。使用本机 Debug 证书，不是生产商店签名，也不能覆盖旧 1004。
- 两包均通过 APK 签名、ZIP 完整性、16 KiB ZIP 对齐检查。ABI 门禁首次误用了不存在的 CLI 子命令，保留失败日志后按真实 `apk-abis` 命令重跑；不得把命令参数错误归咎于 SDK。Debug 的 Flutter Vulkan validation layer 为 ARM64 调试库，不满足正式分发 ABI 对称要求，不用 Debug 冒充可上架包。QA Release 仅 `libjutils.so` 为 ARM64 专有库，需既定 JPush/JCore 版本的依赖报告与 pubspec.lock 才能适用现有受控例外，初次未传报告被拒，随后补齐核验。
- Android 原生 `:app:testDebugUnitTest --max-workers=1` 本轮完成，8 套件共 39 项，失败/错误/跳过均 0；包含 QRing/CoolWear 映射、名称过滤、电池读取、时区和日志隐私。Gradle 总用时 1 分 1 秒。
- Dart 格式检查 204 个文件、0 改动；源码基线 `72b3f76` 的 GitHub CI quality 任务已成功，包含静态检查、双时区全量 Flutter、客户端契约及发布脚本测试。Android/iOS CI 当次查询仍运行中，不把未结束任务写成通过。本轮只改文档，不冒充重跑了全量 Flutter。
- 本轮 `flutter analyze` 6.9 秒通过，无问题。生产接口请求及健康上传未作为本轮检查执行，不操作账号或制造健康样本。
- QA ABI 复核通过：真实 Gradle `releaseRuntimeClasspath` 报告确认 `jpush_flutter 3.5.1 / JPush 6.2.0 / JCore 5.5.2`，脚本接受原有 `libjutils.so` ARM64 受控例外，其余两种 ARM 库一致。没有改门禁、删原厂库或修改推送插件来换取通过。
- 交付前再次 fetch，远端当前分支仍为 `72b3f76`；仅提交本轮两份文档，不改 main 或现有审核。最终 ADB 列表仍为空；不执行等待设备无限阻塞、无签名安装或卸载重装。

## 首次构建轮次的交付边界（后续安装见下文）

- 仅新增本轮构建/检查记录，客户端源码仍为 `72b3f76`；账户、绑定、健康数据库和 iOS 审核不变。
- 新版真机安装与启动尚未完成：需要手机恢复 USB 调试连接，以及与旧版 1004 匹配的原签名文件。保持数据的覆盖路径未满足前，不自动改为卸载重装。
- 手机当前安装版本最后一次可读证据为 1004，不将构建成功写成已安装 1039；二维码/戒指连接、测量、同步、充电和各页面回归仍待实物验收。

## 手机重新连接后的覆盖尝试

- 用户确认手机已连接后重新核对：同一华为 PPA_LX3 处于 ADB 已授权状态，原 0.1.21 (1004) 仍安装，安装/更新时间仍为 2026-09-29 00:12:40。Git `36fefb8` 工作树干净，fetch/ff-only 无更新。
- 执行不卸载、不清数据的 `adb -s <目标序列号> install -r .build/SayRing-1.0-1039-android-debug.apk`；手机弹出 PC 工具安装风险确认。按本轮安装授权仅选择“继续安装”，未关闭系统安装保护、未授予额外权限。
- 系统最终返回 `INSTALL_FAILED_UPDATE_INCOMPATIBLE: Package cn.saydian.ring signatures do not match previously installed version; ignoring!`。这次是实际覆盖安装失败证据，不再仅是证书预检推断；日志/截图保存在忽略目录，未进 Git。
- 安装尝试进行中的一次回读仍为 1004；随后最终回读发现旧包已不在安装列表。手机本地日志记录 `PACKAGE_FULLY_REMOVED`，本任务未执行卸载或清数据命令，不能由此保证原本机数据保留；不把中间回读误写成最终手机状态。USB 连接正常，尚未启动新版。
- 用户随后明确回复“卸载重装”，允许转为全新安装。确认旧包已移除后无需重复卸载，开始安装 1039 Debug；不再承诺旧登录、绑定或本机记录可恢复。原 APK 留存不等于有可恢复的健康数据库备份。
- 既有构建/39 项原生测试仍按前节证据，不为记录更新冒称再次全量回归。新版本页面、进程及 VM 调试结果另行追加。

## 用户授权重装后的安装与调试

- 第二次安装返回 `Performing Streamed Install / Success`。真实包管理器回读 `cn.saydian.ring / 1.0.0 (1039)`，API 26 最低、目标 API 36。手机安装时间读数为 2026-10-03 12:55:15；手机时钟与 Mac 日期不一致，保留原读数不伪改。旧签名冲突没有被绕过，只是在用户授权重装、原包已移除后完成安装。
- `adb shell am start -W -n cn.saydian.ring/cc.saidian.saydian_app.MainActivity` 返回 Status ok（已在前台的实例收到启动 Intent）；真实进程 PID 21970，前台 Activity 为 Say Ring。`flutter attach -d <目标序列号>` 文件同步 6.7 秒，已取得 Dart VM Service 与 DevTools 调试 URL，保留运行中的调试连接。
- 真机截图核对登录首屏、Say Ring LOGO、手机号/邮箱入口、并排年龄/协议勾选、创建账号/忘记密码和公开只读演示入口显示。未点击登录、发送验证码、修改账号或接入戒指；不能据此宣称登录接口、全部页面或真实 SDK 功能通过。
- 启动日志有 Android KeyStore code 7 警告，但 FlutterSecureStorage 随后报告安全算法迁移成功、迁移 0 项；没有捕获 Dart 未处理异常、E/flutter 或 FATAL EXCEPTION。复查进程 PID 与前台均保持，登录页可见。迁移成功不证明旧登录/健康记录恢复。
- 通过 Codex 请求打开本机 DevTools，工具返回 queued；证明已建立可用调试 URL，不把 queued 当成浏览器页面已经加载。URL/真实截图/完整日志均留在忽略目录，账号、凭据与健康数据未进 Git。
- 最终本轮完成的是 1039 Debug 安装和真机调试连接。原本机数据恢复、账号功能、真实戒指扫描/握手/同步/测量/充电与逐页交互仍为独立待验；iOS 与现有 App Store 审核未操作。
