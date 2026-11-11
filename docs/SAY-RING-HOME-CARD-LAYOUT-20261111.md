# 首页健康卡片空状态布局统一（2026-11-11）

## 请求与基线

- 用户反馈首页有数据与无数据的健康卡片样式不统一。本轮只调整共用 Flutter 卡片布局，不修改健康数值、判定、能力/权限门禁、同步、绑定、历史、设置或后台配置。
- 修改前 App 工作树干净；当前分支 `codex/u19s-android-connect-20261111`，本地与已抓取同名 origin 分支均为 `e69133ca821ff3e6990a8f08ae4e4574067f70aa`。已核对 origin 属于 `tangwu88/SayRing`，执行 `git -c http.proxy=http://127.0.0.1:7897 -c http.sslBackend=openssl -c http.version=HTTP/1.1 fetch origin --prune` 成功，无覆盖/强推/跨分支合并。
- 已阅读 AGENTS、INTERNATIONAL-HANDOFF、CHANGE-TEST-LOG 最近记录、REGRESSION-CHECKLIST 和 BUG-RETROSPECTIVE。Windows 不具备 Xcode，iOS Debug/Profile 不能执行；原生鸿蒙不是此 Flutter 组件，不宣称同时完成原生鸿蒙 UI。

## 原因与修改

- `lib/ui/pages/dashboard.dart`：原卡片按是否有当天记录切换最小高度，只有当天记录才插入趋势区，有记录才插入日期；因此当天/旧记录/空状态混排时高度与内容位置不一致。
- 改为统一标题、数值/单位、状态、趋势与日期区域。标题预留两行；数值与单位保持同一行、必要时缩放以适配窄屏；文字区域跟随系统字体大小。保持原圆角、白底与指标色彩，不采用 IntrinsicHeight 或动态改变列数。
- 无数据继续显示 `--` 和真实空状态；旧记录保留真实日期，不绘制今日曲线。趋势与日期区域只保留版面空间，不造值、不补零、不创建虚假曲线。当天真实趋势仍按原逻辑读取与展示。
- `test/qring_dashboard_visual_test.dart`：增加332/364dp、正常/放大字体的混合卡片测试，覆盖有真实趋势、旧记录、无数据、无数据变为新数据后所有卡片尺寸/位置稳定；保留原慢速下拉与趋势无伪造检查。

## 执行记录与验收边界

- 首轮两文件格式化成功。定向 `flutter test --no-pub --concurrency=2 --reporter=expanded test/qring_dashboard_visual_test.dart test/home_health_cards_test.dart --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`，59项通过；随后补强为真实两点曲线场景，须在后续全量重新验证。
- 探索时尝试读取 `lib/ui/widgets/health_metric_mini_chart.dart` 失败；实际组件位于 `lib/ui/health_trend_page.dart`，已按实际组件的趋势及时间轴保留高度，不计错误路径为验证成功。
- 后续静态分析、完整双时区 Flutter、Android Debug/Release、正式验签及 Git 结果继续追加。未运行真实测量或修改手机数据；本轮用户未要求安装，不把构建当作手机已更新。
- 外部构建/日志目录：`E:\SayRing-health-card-layout-1302-20261111`，不提交构建产物、签名材料或真实健康数据。
- 首轮流水线：协议/真实SDK41项、发布契约23项及格式通过；静态分析因新测试使用了可简化的可空集合元素写法报1条info，门禁按失败停止。已改用Dart可空元素语法，保留首次失败日志，随后从格式/静态分析继续，不重复已通过且源码未变的原生协议检查。
- 此组件亦被远程关爱只读详情复用，因此该页同样获得一致的卡片空间；授权数据来源、只读入口和指标门禁不变，须纳入完整回归。
- 补强后的首轮UTC全量中，新增332/364dp真实两点曲线测试各失败一次：趋势两端时间在窄栏换行，使既有迷你图内部Column溢出20px。其余2339项通过，不能将此轮记为通过。`lib/ui/health_trend_page.dart` 两端时间增加单行完整显示和按可用宽度缩放，不裁掉时间、不改点位或记录；待重新执行定向/完整回归。失败日志保留在 `utc-initial-failed.log`。

## 修正后验证

- 三个Dart文件格式检查通过，`flutter analyze --no-pub` 无问题；59项定向检查再次通过，包含真实两点曲线窄屏场景。
- 最终 `TZ=UTC` 与 `TZ=Asia/Shanghai` 分别执行 `flutter test --no-pub --concurrency=2 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`，各2341项全部通过，无跳过。原慢速下拉、字体放大、零/单点曲线、能力与关爱授权用例均包含其中。
- 提交前再次抓取origin成功，当前分支远端未移动，`git rev-list --left-right --count HEAD...@{upstream}` 为0/0。只看到其他U19分支更新，本轮不夹带合并。
- `:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1 --offline -Ptarget-platform=android-arm,android-arm64` 构建成功。后续附加Kotlin通知夹具首次因恢复脚本缺少 `PYTHONUTF8=1`，在Windows按GBK读取既有UTF-8源码时失败；未改App源码，补足本地环境后仅从两项夹具和构建继续，保留首次失败日志。
- 原生XML报告134项、失败/错误0；补足UTF-8环境后，通知快照与可选版本读取生产方法夹具各1项通过。
- 外部临时Flutter预览仅用虚构记录，未连接手机或真实服务。初稿默认测试字体显示方块，随后字体加载被测试虚拟时钟阻塞，已停止本轮自有预览进程；改在 `tester.runAsync` 内加载本机字体/图标后，预览1项通过并人工检查图像。332/364dp混排、完整时间、不造空数据趋势的判定以仓库回归测试为准；图片不当作真实测量验收，也不提交Git。

## 安卓构建交付

- 正常Main Android Debug/Release均成功，正式版本为 `1.0.13 (1302)`，包名 `cn.saydian.ring`、非debuggable。原正式证书SHA256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de` 验证通过；未更换签名或改应用身份。
- 清单/JPush、双ABI依赖、ZIP对齐和QRing SDK副本验证通过。既有两个32位SDK库仍是4KB ELF加载对齐，本轮未改厂商库，不把此UI调整说成所有市场已审核通过。
- 外部APK `E:\SayRing-health-card-layout-1302-20261111\SayRing-1.0.13-1302-release.apk`，74454129字节，SHA256 `69E46A84EAC8E28FA5641A030FB564ADB4CD04BD8A90C384ED72B26708CC9F94`。`android/key.properties` 已确认不存在；签名材料/产物未加入Git。
- 本轮未安装手机、未做真实测量、未更新后台或应用商店；Windows未执行iOS Debug/Profile及iPhone实机，原生鸿蒙页面不在此共用Flutter改动内。Git仅交付本轮3个Dart文件及实施日志/索引，保留其他U19分支工作。
- 源码与上述日志提交 `c03c715d928c682733e50e4d4308dfc48c07575a` 已成功推送 `origin/codex/u19s-android-connect-20261111`；随后 `git ls-remote` 独立读回相同SHA，工作树干净。本条仅追加交付证据，不改已验证源码或APK，不覆盖main、其他分支或生产版本。
