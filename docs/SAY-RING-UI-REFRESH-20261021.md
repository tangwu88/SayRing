# Say Ring 图形化界面优化（2026-10-21）

## 目标与基线

用户要求参考 QRing，全面提升界面美感、高级感，以直观图形代替密集文字。在现有 Flutter App 中实施，不另建替代网页。基线为 `41ba7ebfbb31d6c2eefaa63dc440fa135b2d62af`，开始前工作树干净，fetch 与当前分支 ff-only 已完成；工作分支 `codex/qring-visual-refresh-20261021`。

参考：QRing 官方 [App Store 页面](https://apps.apple.com/cn/app/qring/id6473672621) 的四张公开截图（本轮苹果目录返回 1.3.1）。借鉴其活动/睡眠分区、大数字、日期控制及趋势/阶段图。参考图的未知值不能作为真实健康样本，更不复制不存在的数据、评分或设备功能。预览使用独立合成数据，原用户数据不读取或改变。

## 计划与影响面

- 统一 `app_theme.dart` 卡面、颜色层级、边框、留白和操作尺寸，保持系统文字缩放。
- `pages/dashboard.dart` / `pages/sports.dart`：今日活动目标环、最近睡眠摘要、真实微趋势；核心数据置前，快捷入口和说明降级。今日数据必须从当日本地完整存储读取，跨日期最近记录不能冒充今日总量。
- `sleep_detail_widgets.dart` / `health_trend_page.dart`：总时长和阶段图主导首屏，保留日期选择、最新睡眠优先、原 AI 报告及同意确认；历史记录/解释可展开。
- `pages/devices.dart` / `pages/profile.dart`：图形化电量与能力入口，简化设备和个人信息层级；同步、重连、解绑、设置与订单入口保持可达。
- 百科阅读字号、商城原生交易、账号/权限/租约/模块门禁及真实 SDK 逻辑沿用。未知值保持未知，失败/未完成不显示成功。主页卡片用户顺序和隐藏配置继续生效。

## 验证计划与边界

保存相同合成样本、390×844 逻辑视口的前后 Flutter 实际组件截图，核对活动/睡眠/设备/我的。额外检查 320px 窄屏、200% 文字、无数据、历史日期、权限/账号切换、操作导航和语义标签。执行静态检查、定向与全量 Flutter 双时区、Android Debug/QA Release 和 iOS Debug/Profile。所有实际命令、失败与修复随结果追加。

当前用户暂时无法连接 iPhone；物理设备、真实蓝牙与新 UI 现场验收继续待办。本轮界面源码与构建验证不等于上传 TestFlight、商店审核或更新公开下载。

## 过程记录

- 产品设计上下文预检无已保存参考，使用当前源码与官方 QRing 截图；没有保存新的个人偏好。
- Web 工具无法打开苹果截图 CDN 图片，普通只读下载成功后在本机查看；四张参考留在忽略目录 `build/qring-ui-20261021/reference/`，不打包进 App。
- 查找旧 CI 文件时误用了不存在的 `.github/workflows/quality.yml`；后续按实际文件定位，不影响源码。

## 实施与首轮纠正

用户确认采用浅色高级感：暖白底、深色数字、蓝紫点缀。最终主背景暖白，卡片去大面积装饰渐变/阴影，保留蓝色主要操作，活动环使用蓝/青/暖橙，睡眠使用柔紫。

首页新增受账号/设备代次保护的完整当日活动读取、目标环和既有目标/趋势入口；在途读取合并通知，避免持续同步时重复排队并丢弃首轮结果。午夜、恢复前台、账号/设备/控制器更换会作废旧查询；退出页面解除监听、定时器和等待边界。健康指标按用户原顺序双列展示，大字/窄屏自动单列，单点和空集不伪造曲线。微趋势可按真实样本首末时间展开，并显示时间范围，不把局部样本冒充全天。

睡眠大数字与真实时间轴前置，阶段只绘制实际返回的类型，未知/未佩戴继续保留；完整开始/结束日期、逐段明细和参考说明展开可达。设备页新增按原始百分比或原厂刻度绘制的电量图，不将3/4格转成伪百分比；未知保持未知。主卡、功能、我的统计/服务均兼容大字，解绑确认和同步状态语义保持。

- 截图工具首轮缺少按钮字体与图片解码等待，已补齐本机字体覆盖；清晰 BEFORE 在生产源码修改前完成。原始样本含旧QRing v1活动，被生产校验拒绝，故同样样本的前后活动均为空；另以有效v2合成活动和多点记录提供有数据版，明确不作为用户实际健康或无线结果。
- 首次 analyze 将忽略目录中的 `.dart` 拼接源片段也当独立库分析（181项）及两个源码花括号提示，共183项；保留片段改为 `.source.txt` 并补块级括号，第二轮 analyze 零问题。
- 第一轮定向发现活动进度条语义值不能用“暂无数据/值与目标”替代数值百分比，已用可点击父语义描述真实数值、内部图形排除重复语义；也发现详情页复用新电量卡使 ListTile 尾部宽度过大，新增 compact 展示修复。
- 布局移动后更新旧视觉断言与实际滚动操作。第二轮测试曾误传 WidgetTester.ensureVisible 不支持的 alignment 参数，改用 Scrollable.ensureVisible；中文测试返回按钮改为实际 BackButton，展开说明点击前等待滚动布局稳定。设备测试将15秒轮询释放提前到主体finally，语义句柄亦按时释放。上述失败均保留在忽略日志，未删功能或跳过断言。
- 代码审查发现新活动读取若每250ms作废上一轮会使慢存储读取饥饿；改为一个在途读取、合并补读并立即展示已完成数据，新增阻塞首轮+连续通知的行为回归。旧账号及跨日请求继续隔离，不改变数据库/原始健康算法。
- 有数据截图发现全天横轴将仅数小时的微趋势挤成窄条；增加显式样本范围模式及真实起止标签。最后一轮新测试还修正语义句柄释放和同一时刻聚合后不造时间跨度的预期。

新增测试覆盖完整256条当日数据而非200条缓存、日界排除、无数据/重试、旧账号迟到、读取合并、窄屏2倍文字导航、原厂刻度/未知电量、模块能力隐藏、睡眠说明/时间图、显式远程空集及曲线边界。全量与构建结果将在实际完成后追加。

- 最终复核又发现同一读取取消 Future 长期复用会积累成功读取的监听闭包（P2资源生命周期）。在代次匹配的 finally 完成并重建 fence，旧代次不能清空新读。仅调整资源释放，不改值或数据范围；format 1文件0改动。此前全量双时区各1373通过，结果备份至 `checks-before-fence-cleanup/`，最终源码重新执行 analyze 和双时区全量。
- 工具离线契约共128项：127通过、1项Windows ACL在macOS按原平台条件跳过，0失败；Python发行脚本35项通过，测试中的模拟发布/拒绝日志不代表执行生产发布。

## 可复现命令与最终验证

运行于 Flutter 3.44.9 / JDK17，Node 使用既有本机运行时。完整输出留在忽略目录 `build/qring-ui-20261021/`，首次失败日志与旧检查快照均保留。

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
TZ=UTC flutter test --no-pub --concurrency=1 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn
TZ=Asia/Shanghai flutter test --no-pub --concurrency=1 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn
node --test tool/*test*.mjs
python3 -m unittest discover -s scripts/release -p 'test_*.py'
```

格式检查251文件0改动。最终运行的两个Flutter时区均使用全部测试，无过滤或新增跳过。主机UI测试使用真实组件、离线数据和模拟接口；不发送真实短信、支付、AI上传或修改生产配置。

构建统一参数：`--dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --build-name=1.0.5 --build-number=1123`，pubspec及公开版本不改。

```sh
flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 <统一参数>
SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub --target-platform=android-arm,android-arm64 <统一参数>
(cd android && ./gradlew :app:testDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline)
# 以下依次用 debug / profile；Configuration 对应 Debug / Profile
flutter build ios --debug --no-pub --config-only --no-codesign <统一参数>
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination generic/platform=iOS -derivedDataPath build/ios-qring-ui-1123 IPHONEOS_DEPLOYMENT_TARGET=15.0 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

验证包为QA/无签名构建，不替代已发布原签名Android包，不上传TestFlight或提交App Store，也不改下载页。本机iOS15最低版本仅为本次构建命令参数，原工程/Pods配置保持。

### 最终主机检查回执

- `flutter analyze --no-pub`：零问题，6.1秒。
- `TZ=UTC` 全量 Flutter：1373/1373，87.3秒。
- `TZ=Asia/Shanghai` 全量 Flutter：1373/1373，86.5秒。
- 工具契约127通过、1项Windows专用条件跳过；发行Python35通过（均在最终fence资源释放补丁前执行，该补丁只涉及Flutter状态管理；最终Flutter已覆盖）。
- 代码复核：匹配当前代次才释放读取等待并触发合并补读；旧账号/设备/日期迟到响应不覆盖新读取，dispose解除定时器和监听，超时保留重试。

### 最终实际组件截图

`after-final-original.log`、`after-final-populated.log` 两次真实Flutter组件截图测试均通过。按同一390×844逻辑视口分别保存原始样本6张和丰富样本7张；目检首页、滚动健康卡、睡眠、设备、我的、活动和趋势。四屏拼图 `say-ring-ui-preview.png`（1704×1038）用于展示，14个PNG文件哈希列于忽略目录 `final-capture-manifest.json`。旧图移至 `previous-capture/20261021-230314/` 保留。所有样本为本地合成，不使用真实账号、蓝牙或用户健康数据。

本轮目检：图标与中文无缺字，数值/图表层级与颜色一致；指标标题对齐，真实首末时间可见，功能与详情可滚动进入。预览缓存按生产 `MemoryHealthStore.recent()` 最新优先，示例最新值与曲线最近点对齐。该排序仅是截图夹具修正，未改生产数据排序。窄屏和2倍字体通过行为测试；尚无本版物理iPhone现场截图或无线测试。

### Android构建和实际产物

- 双ARM Debug构建25.7秒、显式QA Release构建63.0秒，均退出0。原生 `testDebugUnitTest` 离线任务通过（6.6秒，301个任务中8执行/293缓存，原生代码未改）；按Gradle缓存语义记录，不称为重新运行全部原生测试。
- 两个APK实际badging均为 `cn.saydian.ring` / 1.0.5（1123），min26/target36，含arm64-v8a与armeabi-v7a。Release不可调试；二者apksigner验签通过，证书为本机Debug身份 `7ed73f5a951a031f80fbc20c94b242000edea9e5b420aefb88c589508bedab46`，不是正式原证书。
- Debug：158947461字节，SHA256 `d64372135df93f8bcbb9cf419a0775b543f7c9589397eccb9d22e7208ffa9106`。
- QA Release：71980327字节，SHA256 `efc82e50f360edb8901f2147a1b281daf7b88464332be89110af3793cd419ab2`。
- 两包另存 `build/qring-ui-20261021/artifacts/`，实际badging/验签日志及JSON均保留。构建中既有Kotlin迁移/Gradle弃用提示为非阻断警告，没有为消除警告升级依赖。

### iOS构建和实际产物

- Debug config-only 7.9秒 + Xcode build 31.5秒；Profile config-only 9.0秒 + Xcode build 44.4秒，全部退出0并明确BUILD SUCCEEDED。
- `build/ios-qring-ui-1123/Build/Products/{Debug,Profile}-iphoneos/Runner.app` 的两份实际Info.plist分别核对：`cn.saydian.ring` / 1.0.5（1123）/最低iOS15。实际主程序与App.framework哈希及签名检查保存在 `ios-artifact-check.json`；本轮均无签名，不可作为已安装或可上传IPA。
- 既有Pods头文件、弃用与运行脚本警告保留，未修改原生依赖。构建过程无新失败。

## 交付边界

实现、最终全量检查、主要页面截图和本机双端构建完成。仅提交当前界面分支；iPhone暂不能连接，真实R12连接/同步耗时与本版物理机UI仍待验证，不将此分支升为已验收主线。没有修改线上开关、协议、下载地址、正式包、TestFlight或App Store。

Git运行源码提交后检查远端CI；云端结果单独记录，不用本机成功替代。

### Git同步与云端状态（2026-10-21T23:14:21+08:00）

运行源码与全部本机回执已提交 `484d6fc2e76c70b97389518a4992d2ea562bd58a`，远端分支 `codex/qring-visual-refresh-20261021`。GitHub对象树与本机暂存树一致：`8ed1030a9f35350b05f24450b522453264a1dd33`；fetch后ff-only对齐，HEAD与origin一致、工作区干净、ahead/behind为0/0，`git fsck --full --no-dangling`退出0。

[mobile-ci运行39623058637](https://github.com/tangwu88/SayRing/actions/runs/39623058637) 仍在运行：
- quality: in_progress；当前 Run TZ=Asia/Shanghai flutter test
- Harmony contracts (UTC): success
- Harmony contracts (Asia/Shanghai): success

云端尚未完成，不能称为远端CI全通过；后续Android/iOS任务须等待quality。该云端运行不影响上述已完成的本机检查事实，后续结果需另行核验。当前仅交付Git界面改动，真机/正式分发待办保持。此后只有验证记录更新，运行源码仍为484d6fc。
