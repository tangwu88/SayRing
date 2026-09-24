# Say Ring 无屏戒指文案、LuckRing 样式与运动折叠

## 范围与基线

- 时间：2026-09-24（UTC+08:00）。
- 分支：`codex/rebuild-from-handoff`；修改前 HEAD：`c35308f5d5a4b7bbb82fcc230cb92912a5baef0f`。
- 用户目标：清理从智能手表 App 遗留的“在戒指端操作/确认/亮屏”等误导提示；保持 Say Ring 现有红金浅色调，按手机 LuckRing 的层级优化内外页；运动类型按可用宽度预览，点击“更多”后显示全部。
- 修改前工作树干净，本地分支相对最后已知远端领先 4 个提交。首次 `git fetch origin --prune` 在 2026-09-24 因 `Recv failure: Connection was reset` 失败；提交前重试成功，远端分支回读为 `eefa533f13cbe38a6b8d562b47ed4c0a209f57f2`，本地仍为领先 4、落后 0。未覆盖、未强推、未推送。
- 本轮不改健康值、SDK 算法、设备路由、服务端接口或数据库；未知值继续保持未知，运动模式仍只来自成功握手后的真实能力。

## 已实施

### 1. 无屏戒指提示语与能力入口

- 删除或改写“请直接在戒指上开始运动”“戒指弹出确认”“请在戒指上操作”“戒指端确认”“戒指保持亮屏”“贴合手腕”“在戒指上点击”等用户可见提示。
- 连接提示统一为：戒指充电激活、靠近手机、等待 App 显示连接成功；测量佩戴提示统一为贴合手指并保持静止。
- 运动提示明确为“佩戴戒指、由手机发起并保持连接”；设备不支持 App 发起运动时只说明能力状态，不要求用户操作无屏戒指。
- 即使继承的手表 SDK 错误上报能力，`显示样式`、`照片显示`、`屏幕设置` 三类入口也会在 Say Ring 的可见能力集合中被过滤；底层兼容代码保留，未删除原 SDK 能力。
- 中文简体/繁体、英文、德文、法文、西班牙文、日文、韩文同步更新，并重新生成 Flutter 本地化代码。

### 2. LuckRing 信息层级与现有色调

- 保留 Say Ring 红、金、浅灰主色；准备度卡由旧紫色改为红金渐变，设备图形改用品牌红。
- 全局卡片圆角、主要按钮圆角、内页大标题和底部导航层级统一；底部导航增加圆角浮层、阴影和红色选中背景。
- 健康趋势内页把日/周/月和日期切换收进同一圆角控制卡，减少零散控件感。
- 设备页未连接与已连接主卡使用同一品牌视觉；个人页原有头像主卡、统计卡和分组服务卡继续保留。
- 本轮只参考 LuckRing 的信息层级与操作密度，没有复制其深色主题，也没有恢复用户此前取消的深色四栏结构。

### 3. 运动模式响应式预览

- 运动区改为有状态折叠组件，仍使用 `availableSportModes`，不补造 SDK 未上报的运动。
- 宽度小于 360 逻辑像素或系统文字比例大于 1.25：两列，首屏显示 2 项。
- 普通手机：四列，首屏显示 4 项。
- 宽度至少 600 逻辑像素：六列，首屏显示 6 项。
- 可用运动数超过首屏容量时显示“更多运动”；展开后显示全部，并可点“收起运动”。展开使用 220 ms 尺寸动画，不改变运动启动、暂停、结束和记录逻辑。

## 修改文件

- 主题与页面：`lib/ui/app_theme.dart`、`lib/ui/pages.dart`、`lib/ui/health_trend_page.dart`、`lib/ui/prototype_pages.dart`。
- 能力与错误提示：`lib/domain/feature_models.dart`、`lib/services/app_controller.dart`、`lib/services/device_watch_face_market_service.dart`、`lib/services/yucheng_wearable_bridge.dart`。
- Android 原生提示：`android/app/src/main/kotlin/cc/saidian/saydian_app/MainActivity.kt`。
- 本地化：9 份 `lib/l10n/app_*.arb` 及生成代码。
- 回归：`test/say_ring_brand_contract_test.dart`、`test/ui_shell_test.dart`、`test/prototype_coverage_test.dart`、`test/device_watch_face_market_service_test.dart`。

## 验证流水

### 格式、本地化与静态检查

- 首次直接执行 `flutter gen-l10n` / `dart format` 失败：Flutter/Dart 未加入当前 PowerShell PATH。改用 `E:\saydian\.toolchains\flutter\bin\flutter.bat` 和同目录 `dart.bat` 后成功。
- `flutter gen-l10n`：通过；9 种语言生成代码已更新。
- Dart formatter：相关源码和测试格式化通过。
- 禁用词源码扫描：`在戒指上开始运动|戒指弹出确认|请在戒指上操作|戒指端确认|戒指保持亮屏|贴合手腕|在戒指上点击` 在戒指用户路径中 0 命中。
- `flutter analyze --no-pub`：通过，`No issues found`。
- `git diff --check`：通过；仅有 Git 对部分文件未来换行转换的提示，无空白错误。

### Flutter 自动化

- 定向品牌、能力、表盘服务与 UI：87/87 通过。
- 新增防回归：无屏戒指禁用提示扫描；屏幕专属能力不可见；430×932 普通手机首屏 4 项并可展开全部；320×760 窄屏首屏 2 项。
- `TZ=UTC flutter test --no-pub`：873/873 通过。
- `TZ=Asia/Shanghai flutter test --no-pub`：873/873 通过。

### Android 原生、构建与包体

- 原生单测首次使用错误的 `JAVA_HOME=...\jdk17`，Gradle 明确拒绝；修正为 `...\jdk17\jdk-17.0.20+8`。
- 全工程 `testDebugUnitTest` 首次因工程在 E 盘而 Pub 缓存依赖在 C 盘触发 Gradle `this and base files have different roots`；通过将 `PUB_CACHE` 统一到 `E:\saydian\.toolchains\pub-cache` 解决跨盘配置。
- 全工程测试随后进入第三方 `camera_android_camerax` Robolectric；其日志提示 Android SDK 36 需要 Java 21，而本项目工具链为 Java 17，长时间无进展后中止。该第三方套件不记为通过。
- 项目自身 `:app:testDebugUnitTest`：通过；5 份 XML、23 项，失败/错误/跳过均为 0。
- Android Debug：构建成功，`app-debug.apk`，186,131,449 字节，SHA-256 `2DB38DD3A15191DA319B486252FD18748C5301C83E73356E0538FF0753592C3D`。
- Android QA Release：以 `SAIDIAN_ALLOW_QA_RELEASE=true` 构建成功，`app-release.apk`，69,332,540 字节，SHA-256 `CDE4EA2C985A88A63D25C65ADF58AAC7A8461FB3E127F407F879FB56087DB368`。
- 两包均为 `cn.saydian.ring`、`0.1.21 (1004)`、minSdk 26、targetSdk 36；`apksigner verify --print-certs` 通过。当前 Debug 与 QA Release 都使用 Android Debug 证书，证书 SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，不能作为生产上架包。

### 华为真机

- 设备：`JAD-AL00`，ADB 序列号 `L2E0222510006851`。
- 为避免 BLE 争用，安装前只停止 LuckRing 进程，不解绑、不清数据。
- Debug APK 以 `adb install -r -d` 覆盖安装成功；包信息回读为 `cn.saydian.ring`、`0.1.21 (1004)`，更新时间 2026-09-24 10:12:40。
- Say Ring 正常启动且进程存活；首页真机回读确认品牌红金准备度卡、LuckRing 式分组层级、新底部选中态以及现有心率/血氧数据正常显示。
- 准备下滑验证“更多运动”时手机进入通话界面；为避免抢占用户操作停止真机注入。因此本轮“更多运动”的点击由两种尺寸 Widget 测试覆盖，真机点击展开/收起仍需通话结束后补验。
- 未执行真实运动开始/停止、健康测量写入、OTA、联系人或不可逆设备操作。

## 接口与平台边界

- 本轮没有更改请求地址、参数、Token、上传、同步、登录或数据库契约；既有接口自动化随 873 项全量测试通过。
- 没有真实调用短信、支付、健康写入或生产数据变更；自动化通过不等于供应商或生产接口联调通过。
- Windows 无 Xcode/CocoaPods/codesign，iOS Debug/Profile 构建与 iPhone 真机未执行；不能用 Flutter 测试或 Android 构建替代。
- 未推送 Git，未部署线上，也未发布 APK。

## 待验收

- 通话结束后在当前华为手机真机下滑到运动区，验证普通分辨率首屏 4 项、“更多运动”、展开全部、收起以及无布局溢出。
- 佩戴 HR01 并保持近距离时，分别启动一项户外和一项室内运动，核对 SDK 回调、暂停/结束、运动记录同步；未经该流程不能声称所有运动真机可用。
- 使用 macOS/Xcode 串行执行 iOS Debug/Profile 构建，并在真实 iPhone 验证相同文案和响应式布局。
- 正式分发前必须配置生产签名并提升版本号；本轮 QA Release 为 Debug 证书，不得发布商店。
