# 合并共享更新与 Android 正式 1258（2026-11-06）

## 请求、基线与合并范围

用户要求“同步本地，安装到手机”，随后要求继续。本轮不改后台、不发布下载配置、不提交新的苹果审核、不恢复手动 HRV／手势测量实验。

- 修改前工作区干净，`origin` 为 `tangwu88/SayRing`。实际 fetch 后，本地 `bbc31a8d5a3ac8b854ad62b43adb53525f693119`，共享分支 `origin/codex/integrate-latest-20261031` 为 `215309b5c6aab5384f2747bb6cdee850214c94ad`。
- 保留 checkpoint 分支 `codex/checkpoint-before-1258-20261106` 后，新建 `codex/android-latest-1258-20261106`，以 `git merge --no-ff --no-commit` 合入共享分支的 7 个新提交，没有切到旧 main、覆盖本地修复或强推。
- 新共享代码包括 R7 睡眠概览只读入口、首页与内页排版、提示语和说明折叠、页面错误归属、周期按本地日历日处理等。已有 R7U 精确目标重连、未知 RRI 协议与已协商范围分开计数、逐包保存回执、R8 控制互斥与中文参考链接均保留。
- 冲突仅为两份日志／回归清单及 `test/ui_shell_test.dart` 在相同位置新增内容。保留双方测试和条目，周期双机同名摘要采用较新的生产验证说明，删除冲突标记；不以整文件选一方覆盖。控制器及设备页自动合并后核对了 `confirmedRanges`／`protocolChecks`、现有能力与账号护栏。
- Android 原生源文件相对 `bbc31a8` 无变化；未新增厂商命令或按设备名开放能力。共享的客户文案不把未知数据改为成功或零值。

## 验证、失败及修复

所有新日志、脚本、APK 和手机 XML 留在仓库外 `E:\SayRing-latest-1258-20261106`，不提交证书、密码、原始健康数据或产物。

1. `dart format test/ui_shell_test.dart`、`git diff --cached --check`、冲突标记检查通过。
2. 串行执行私有 `Invoke-1258-Checks.ps1` 的 prepare／analyze／utc／shanghai／debug／native／release／verify 阶段。`flutter pub get --offline`、`flutter analyze --no-pub` 通过；`flutter test --no-pub --concurrency=2 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn` 在 UTC 与 Asia/Shanghai 各 2057 项通过。
3. Android 双 ARM Debug 通过；`:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1 --offline -Ptarget-platform=android-arm,android-arm64` 通过，21 个 JUnit 文件合计 108 项、0 失败／错误。
4. 首次正式构建因 Java native mmap 申请约 225MB 失败，Gradle 进程退出；保留 `release.log` 和 JVM 失败记录，不把失败 APK 交付。检查时本机可用物理内存约 1.2GB、虚拟内存约 2.1GB。
5. 私有构建包装器将本轮 Gradle 堆限制为 1408MB，使用 SerialGC、2 个处理器与 128MB code cache，单 worker 重跑；不修改仓库构建配置或签名。进一步确认先前失败构建遗留的 Kotlin daemon 的父 PID 正是已退出的本轮 Gradle，且命令类确为 KotlinCompileDaemon，只终止这一孤立进程，未停止用户应用或其他项目。构建随后成功。没有以更换证书或包名规避构建问题。
6. 正式 APK `apksigner`、`aapt`、生产 JPush Manifest／资源门禁、双 ARM ABI、zipalign 与 ELF 检查通过；临时 `android/key.properties` 清理已确认。既有两个 ARM32 闭源库的 4KB ELF 边界不变，不宣称全部市场认可。
7. `node tool/verify_qring_sdk_copy.mjs android/app/libs/qring_sdk_1.0.0.76.aar build/app/generated/qring-sdk/qring_sdk_1.0.0.76-build.aar` 首次缺 `unzip`，补入现有 Git usr/bin PATH 后通过：30 个原条目保持一致，仅去掉构建用 mapping 输出规则。没有为本机环境修改 SDK 或测试断言。

## 产物与安装状态

- 普通原签名正式 APK：`E:\SayRing-latest-1258-20261106\SayRing-1.0.11-1258-release.apk`，73,503,405 字节。
- SHA-256：`3C670AA9270CFACD9AF6E2AB5F1BCE19D0BC2D3FFB8A02998A95D912DE6D85C6`。
- 包名 `cn.saydian.ring`，版本 `1.0.11 (1258)`，非 debuggable；原正式证书 SHA-256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。
- 已对原华为发起 `adb install -r` 保留数据覆盖安装。安装前实际版本为普通正式 1253，原 UID／首次安装时间已记录。当前手机为 AOD 息屏锁定，安装尚待本人解锁及华为确认，已请求用户处理；不得将正在安装写成已安装。后续版本回读和实机页面结果另补。

## 验证边界

Windows 本机未执行 iOS Debug/Profile 或鸿蒙原生构建；保留共享分支已有 1257 的实际记录，不冒充本轮双平台验收。有效 R7U HRV、周期离线清空队列等已知问题没有因本次合并变成已修复。此次安装验证只读页面，不实际发送验证码、付款、拨号、修改健康提醒或清除戒指数据。
