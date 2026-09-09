# Android 真机搜索不到手表修复

## 修改前

- 基线：`f8c3a85cb3d43f7d13b8edd63f168f7eacf39e8e`；`git fetch origin --prune`、`git pull --ff-only origin main` 后本地与远端一致，工作树干净。
- P1：华为 PPA-LX3 / Android 10 上打开添加设备，蓝牙开启且 App 定位权限已允许，但系统 `location_mode=0`；页面反复显示“未发现设备”。预期应指出定位总开关关闭，并提供直接恢复入口。
- 原生 Veepoo 已校验定位服务，但共享控制器只检查权限，玉成扫描仍启动；控制器还将 `LOCATION_SERVICE_DISABLED` 映射为泛化权限文案。共享前置检查和页面恢复入口缺失。
- 范围：Flutter 搜索控制器、搜索页、八语提示和回归测试；不改 SDK 扫描筛选、型号路由、健康算法或接口协议。
- 预期：Android 11 及以下定位关闭时不启动两路扫描，显示定位说明及设置按钮；设置返回自动重试；Android 12+ 不要求定位总开关。
- 官方依据：[AOSP Bluetooth Low Energy](https://source.android.com/docs/core/connect/bluetooth/ble) 明确说明定位关闭会关闭扫描，Android 12+ 的 `neverForLocation` 授权路径除外。

## 验证记录

- `adb devices -l`：物理手机在线；App PID 2217 存活。`dumpsys package`：前台精确/粗略定位权限均 granted；`dumpsys bluetooth_manager`：ON；`settings get secure location_mode`：0。
- 使用系统定位设置页复核后定位为 3；未更改账号、清除数据或连接未知手表。
- `cmd location help`：该 Android 10 厂商系统不支持此 shell 子命令，改为打开系统定位设置页。
- PowerShell `rg test/*test.dart`：Windows 不展开路径通配，改用 `rg ... test -g '*test.dart'`。
- 用户随后明确确认“已经搜索到了设备”；定位总开关再次读取为 3。该现场结果确认本次找不到设备的直接原因，未调整扫描过滤或按手表名称放行。
- 共享控制器新增定位/权限独立状态，在两路 SDK 前检查 Android <=30 定位服务；原生定位关闭异常也保留准确状态。
- 搜索页新增对应八语标题/说明及系统设置入口，返回此页后只自动重扫一次，未开启仍保持明确指引；Android 12+ 沿用附近设备权限且不增加定位要求。
- `flutter gen-l10n`、限定两个修改文件的 `dart format`：通过。

## 回归与失败保留

- 新增 `test/device_scan_prerequisites_test.dart`：13 项，Android API 29/30/31、权限拒绝、定位重试、原生异常兜底、系统设置返回一次重扫、普通前后台不重扫、375×812 / 1.0、1.5、2.0 字号。
- 第一次静态检查在测试文件编写中运行，报测试夹具缺少 `debugDefaultTargetPlatformOverride` 导入；最终移除不必要的平台覆盖，沿用 Flutter 测试默认 Android。
- 首轮 Widget 回归因平台覆盖触发框架校验；大字体下列表为懒加载，改为 `scrollUntilVisible` 验证按钮实际可达。
- 两个定位设置返回用例曾失败：mock 的 MethodChannel 回调内 `expect()` 在生命周期异步守卫内抛错，控制器捕获为平台异常。改为回调内显式参数判断、外部断言结果；保留真实控制器及生命周期逻辑，不修改产品代码或弱化断言。
- 夹具收口前的全量 UTC 回归：647 通过 / 2 失败，均为上述新定位设置返回用例。之后定向 `flutter test test/device_scan_prerequisites_test.dart --no-pub --reporter expanded`：13/13 通过。
- Release：`SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub --target-platform=android-arm,android-arm64 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=QWEATHER_API_KEY=`，202.5 秒通过，65.0 MB；内部 QA 签名，未发布。
- Debug：`flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --dart-define=SAYDIAN_API_BASE_URL=http://127.0.0.1:8082 --dart-define=SAYDIAN_ALLOW_LOCAL_DEBUG_API=true --dart-define=QWEATHER_API_KEY=`，26.5 秒通过；隔离本地接口参数仅供当前联调。
- 真机使用既有 Flutter Debug 会话 `r` 热重载：22/2196 库、4567ms，保留手机正在填写的资料和现有手表会话。此操作更新当前运行代码，没有覆盖手机持久安装包；生成的新 Debug APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`。
- 热重载后 App 进程存活、定位模式 3、`adb reverse` 8082 有效；最近 1200 条目标进程日志致命模式匹配数 0。
- 本轮定位关闭前置拦截/设置返回由自动化覆盖；定位开启后的真实发现由用户现场确认。未为了重复演示而关闭正在使用的手机定位或中断手表同步。
- iOS Debug/Profile 不能在当前 Windows 主机编译，本轮未本地执行；源码提交后由已有 macOS CI 检查，不能借用旧提交结果声称本轮通过。
- 最终 `TZ=UTC flutter test --no-pub --reporter expanded`：649/649 通过（33 秒）；`TZ=Asia/Shanghai` 同命令：649/649 通过（37 秒）。
- 最终 `flutter analyze --no-pub`：No issues found（18.2 秒）；`dart format --output=none --set-exit-if-changed lib test`：119 个文件、0 改动；`git diff --check` 通过。
- Android `gradlew.bat :app:testDebugUnitTest --no-daemon`：BUILD SUCCESSFUL（1 分 22 秒）；JUnit XML 确认 15 项、0 失败/错误。保留既有 KGP、Gradle 弃用告警。
- 提交前再次 `git fetch origin --prune`，ahead/behind 仍为 0/0。仅提交本轮控制器/搜索页、八语及生成资源、新回归测试和两份记录；本机截图、日志、APK 不入 Git。
