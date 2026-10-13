# Say Ring 安卓登录后巡检与首页标题修复

## 范围与问题

- 基线 `10ad96cc786fe11550372f70e9f31c02ecf05584`；工作树干净，fetch/ff-only 无更新。只操作 Say Ring，保留现有登录、绑定和健康记录，不操作 iOS 审核。
- 用户已自行登录并连接 R21。1039 Debug、华为 PPA_LX3、Android 10，进程和 Flutter attach 仍有效。截图确认进入真实健康首页与设备页，不以只读演示替代真实验收。
- P2：首页“健康数据”标题被截断。复现：360 逻辑像素左右的窄屏进入首页；标题、日期和操作横向争用空间。预期三项完整可读，实际标题带省略号。根因 `_SectionTitle` 内部对标题和副标题同时使用 Flexible、单行 ellipsis；仅按文字放大比例改行不能覆盖默认字体窄屏。
- 修改 `lib/ui/pages/dashboard.dart`：标题/全部数据一行，日期独立行，标题和日期允许换行；不改健康数值、SDK、API、绑定及存储。`test/ui_shell_test.dart` 增加 320/360 宽度、1/1.5/2 倍字体下真实段落截断和操作回归。

## 真机已观察与边界

- 真实设备页显示 R21 已连接、电量有返回、同步入口可用；已连接时无“重新连接”按钮。没有执行解绑、换环、恢复出厂或改变监测设置。
- 睡眠页可读，AI 报告入口出现“等待自动重试”；尚未读取到服务端终态，不宣称 AI 已恢复或生成成功。未代用户确认 AI 上传授权、提交生成或重试请求。
- 一次尝试点击设备同步后，后续截图发现手机已经切到系统蓝牙设置。不能证明同步点击实际被 App 接收，暂停 UI 操作，避免干扰用户；系统也显示 R21 已连接，但系统连接不单独作为 SDK 全部通过。
- 本轮真实截图、健康值、完整日志与 VM 地址仅保留在忽略目录。真实插电/拔电、三轮距离恢复、新测量、CoolWear 实物和两账号撤权仍待专门验收。

## 测试与构建

- 先定向验证新增窄屏用例，再静态分析、双时区全量 Flutter、原生/发布门禁与双端构建；iOS 构建串行。验证包递增为 1040，不卸载 1039、不重置手机账户或绑定。
- 测试、失败原因、重试、实际构建及手机最终状态继续追加；不把热重载或组件测试当成新版安装/硬件通过。
- 新增 4 项定向测试通过；`flutter analyze --no-pub` 4.9 秒通过；UTC 全量 1146/1146、26 项 Node 契约及发布 Python 31 项通过，bash -n/shellcheck 与格式检查通过。全量中的故障注入样例日志不视为真实线上故障。
- 空间降至约 991 MiB。已确认无活动构建且 lsof 未发现 app/intermediates 使用者；直接 rm 风格清理命令被工具拒绝，未执行。改用 Gradle `:app:clean` 正常任务，提前核对两份 APK 与独立留存 SHA 一致，保留原生测试 XML、混淆映射、native symbols 及 manifest 日志；清理只影响本项目可重建 app 构建输出，54 秒结束，空间恢复约 3.3 GiB。源代码、SDK、签名、原始素材和手机数据不变。
- 尝试只读 getVM HTTP 检查 3 秒超时，停止请求；既有 Flutter attach 日志和手机进程仍是已验证调试证据，不以 HTTP 超时断定 App 崩溃。
- 后续前台读取显示手机切到 `cn.saydian.app.global`，暂停所有主动手机点击/启动/覆盖，继续本机检查，避免与用户或其他调试接管互相切换；尚未完成本轮真实同步终态或 1040 页面验收。

## QRing 构建缓存根因与修复

- Asia/Shanghai 全量最终也为 1146/1146。首次 1040 Debug 7.9 秒失败，`:app:mergeDebugAssets` 报 QRing 的 immutable transform workspace 已被修改；保留失败日志，不通过关闭校验掩盖问题。
- 对比前轮隔离缓存与当前缓存，仅 `map.txt` 不同。原厂 AAR 的 `proguard.txt` 含两条 `-printmapping map.txt`，Release 的 R8 写盘目标相对 AAR 展开目录，污染不可变缓存；原文件 SHA-256 为 `0021886ae500740945cf76e61d750812b96ff54d51fd0c32ebe77083862326d4`。
- 修改前再次 fetch，远端无更新；工作树仅本轮修改，先将完整 diff 及未跟踪记录备份在忽略目录，不在脏树 pull。`android/app/build.gradle.kts` 新增可重复的 build-local Zip 任务，仅移除这两条输出规则，保留所有 keep/优化规则；版本变更导致两条规则不匹配时明确失败。依赖使用该任务的 archiveFile，原始 SDK 只读，正常 AGP app mapping 继续保存。
- 新增打包契约后 Node 27/27。实际生成副本逐个校验 30 个文件条目，只有 `proguard.txt` 内容变化且仅删除两条映射输出；所有 classes、资源和 native 字节一致。未改 App 接口、账号、健康数据或 iOS SDK。
- 将同一逐条校验固化为 `tool/verify_qring_sdk_copy.mjs` 并纳入 Android CI；Release 后再次构建 Debug 验证缓存不被污染。原包作为输出副本的负例被正确拒绝；初次 shell 使用 zsh 保留只读变量 `status` 出错，改用专用变量后负例检查成功。初次 Foundation 文件搜索使用不存在的 README 通配符被 zsh 拒绝，重试显式文件后两个 Objective-C 合成测试均 PASS。
- 修复后 Debug 42.0 秒、QA Release 109.5 秒成功；Release 后 Debug 4.3 秒成功，不清缓存、不关闭不可变校验。两包均为 cn.saydian.ring / 1.0.0 (1040)、ARMv7/ARM64，与 1039 Debug 签名证书一致；apksigner、unzip 完整性及 16 KiB zipalign 检查通过。QA Release 是本机 debug 签名测试包，不是正式分发或商店包。
- SDK 原包 SHA 回读未变，生成副本在 Release 后再次逐文件验证通过；正常 app 的 mapping.txt 已生成，移除 consumer 写盘指令没有丢失应用符号。`actionlint .github/workflows/ci.yml` 通过；远端 CI 尚未运行，不能以本机检查冒称线上通过。
- Android 原生 8 个 suite、39 项测试，failures/errors 均为 0；Gradle 单测及 releaseRuntimeClasspath 回读 12 秒成功。实际 QA APK 的 ABI 门禁通过，仅接受锁定 jpush_flutter 3.5.1 / JPush 6.2.0 / JCore 5.5.2 的既有 libjutils ARM64 例外，没有新增 ABI 缺失或删库。
- Debug APK SHA-256 `edd00ddaacebbe400d24020fd3908ca6aa64f1750995a54682d2d8652005d5e6`；QA Release `b2f099a10cd437cc1465eb4c3e53b965246e8608d2915476c2896f2d58851f49`。构建后源输出与独立留存逐一一致，随后保留测试 XML、mapping、native symbols、manifest 日志及 SDK 构建副本，以正常 `:app:clean` 清理仅本项目中间产物，4 秒成功，空间由约 843 MiB 恢复约 3.1 GiB，手机不变。

## 本轮交付状态

- iOS 1040 Debug 34.3 秒、Profile 58.5 秒串行无签名编译通过，cn.saydian.ring / 1.0.0 (1040)、UIDeviceFamily=[1]、arm64；未安装到 iPhone，不是签名验收或 App Store 包，不改变现有审核。既有 CocoaPods/SPM 及 WechatOpenSDK 模拟器 arm64 不支持提示保留，不删 SDK 绕过问题。
- 最终 Flutter 源码与双时区各 1146 项通过的版本一致；后续仅 Android 构建规则、只读校验工具及 CI/记录变更，相关 Node 27 项、脚本语法、实际 Debug→Release→Debug 构建和 native/ABI 已回归。两个 iOS Foundation 测试使用合成输入，未在真实 iPhone 执行 XCTest，不声明硬件全部通过。
- 独立留存 `SayRing-1.0.0-1040-debug.apk` 与 `SayRing-1.0.0-1040-qa-release.apk` 在忽略目录，签名与 1039 一致，后续可覆盖安装；本轮手机仍是 1039，进程 21970 / 既有 Flutter attach 保持，前台仍为另一 Health App。没有强行抢前台、覆盖、退出账号、清数据或断开绑定，因此 1040 新布局真机验收未完成。
- 待验：AI 报告终态与真实同步；新布局实际手机显示；三轮距离重连、充电插拔、CoolWear 实物、两账号关爱撤权及资料上传。仅把已验证修复提交当前 Say Ring 分支，不推进 main、不上传或改审核，不把当前构建/自动测试写成这些真机项目通过。
