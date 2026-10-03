# 睡眠一致性与 AI 睡眠报告（2026-10-03）

## 基线与范围

- 客户端基线 `2a7a8c2a4942839db512a8131c79c4d977257d09`；fetch、ff-only 更新成功，工作树干净。
- 首页使用通用健康汇总，而睡眠日页使用已确认的 SDK 日期快照，导致同一日期时长不一致。历史详情同时显示通用解释和重复的长期趋势提示。
- 统一睡眠入口，增加明确标记的 AI 睡眠评分和报告入口；AI 不替代设备评分，不更改 SDK 原始值。
- 服务端复用现有 AI 配置、报告存储、Worker、授权和后台审计。仅在登录用户主动确认后上传选中日期的睡眠汇总及夜睡/小睡起止，分段原始时间轴仍保存在本机；游客模式不上传。
- 原始截图只读，真实健康记录、照片、凭据与构建产物不进入 Git。本轮不修改 App Store 审核中的包。

## 实施

- 首页改为完整本机确认睡眠查询，按 SDK 归属日和当前账号/设备读取；睡眠、历史详情与趋势使用同一投影视图。发生读取失败时保留同账号缓存并明确提示；账号和戒指变更立即清除旧结果。
- 时长统一按秒显示小时/分钟，睡眠历史页不再同时显示两个相似趋势提示卡。未知 SDK 汇总阶段不补零。
- 睡眠结构新增独立 AI 参考评分/报告入口，保持设备评分原值。每次新生成明确确认上传睡眠汇总及第三方分析；未同意不 POST，原始阶段留在本机，游客不上传。
- 复核当前已发布分析说明及版本后才提交授权；同一内容哈希对应同一报告，数据变更不借用旧分。独立开关与现有 AI 隐藏开关分离；账号变化、关闭开关与迟到响应有隔离。新增撤回分析授权入口。

## 逐次验证与失败记录

- 初次定向测试误引用不存在的 health_trend_ui_test.dart；同时旧 UI Fake 缺少新增 getter，旧小时小数断言与新小时/分钟格式不一致。补齐测试对象并更新目标语义。
- 第二轮定向 114 通过、5 失败：惰性列表可见项数量变化、旧历史测试未向本机存储插入睡眠记录。按实际卡片显示和本机数据源修正，未绕回旧汇总。
- 新增 AI 页首轮因对话框下方忙碌动画仍运行导致 pumpAndSettle 超时，改成有界泵进授权对话框；新 API fixture 起初写错 vault 方法与 code=0，改为现有 writeSession/code=200 契约。均保留失败记录。
- Analyzer 首轮出现 braces/async context 等 info，修正后最终 `flutter analyze --no-pub` 零问题。
- `TMPDIR=/private/tmp TZ=Asia/Shanghai flutter test --no-pub`：1068/1068 通过；`TZ=America/New_York`：1068/1068 通过。日志分别为 `/private/tmp/sayring-sleep-full-shanghai.log` 与 `/private/tmp/sayring-sleep-full-newyork.log`。
- 新增跨语言内容哈希固定断言后，`flutter test --no-pub test/sleep_report_input_test.dart`：7/7 通过。最终又加强既有首页测试：通用内存汇总故意与本机睡眠记录不一致，进入详情前直接断言首页采用本机记录。定向测试通过；加强后的最终全量回归另行补记。
- Foundation 原生合成回归：`xcrun clang -fobjc-arc -framework Foundation test/native/qring_record_mapping_test.m -o /private/tmp/sayring-qring-sleep-native-test` 后运行可执行文件，通过。不是实际戒指验收。
- Android 原生首轮 `:app:testDebugUnitTest` 因 Gradle 9.1.0 的 QRing transform 缓存内容被修改而在 mergeDebugAssets 失败。核对目标、进程和文件占用后，将唯一受影响的可重建缓存移至 `/private/tmp/sayring-gradle-transform.5kgdrA/qring-transform`，原 SDK 不变、缓存可恢复。重试成功；强制重跑 `./gradlew :app:testDebugUnitTest --rerun --max-workers=1`，37/37 原生测试通过，日志 `/private/tmp/sayring-sleep-android-native-final.log`。
- 加强首页断言后的最终 Analyzer 零问题（4.8 秒）。全量复跑在通过 281 项时遇到 `output.dill` 的 `No space left on device`，不是断言失败；保留 `/private/tmp/sayring-sleep-full-shanghai-final.log`。当时磁盘不足 200 MB，核实本项目已无 Android 构建及文件占用后，仅删除 `build/app/intermediates` 的 1.9 GB 可重建中间缓存，源码、SDK、测试结果、APK 和 Profile 均保留；释放到 2.1 GB。中断已经没有测试引擎运行的本轮测试进程后，降低并发重跑，结果另补。缓存通过重新构建恢复，不涉及用户数据。
- Flutter 中断首个测试后返回正常退出状态，原 shell 随即进入纽约时区测试；初次降低并发复跑因此启动重叠，发现后立即取消新复跑两个进程，保留 `*-final-v2.log` 的关闭阶段错误，未计为通过。等待原纽约全量完成，再单独串行补跑上海。原临时目录退出清理后可用磁盘恢复到 3.8 GB。
- 最终复验：`TZ=America/New_York flutter test --no-pub` 1068/1068 通过（1分51秒，`/private/tmp/sayring-sleep-full-newyork-final.log`）；随后 `TMPDIR=/private/tmp TZ=Asia/Shanghai flutter test --no-pub --concurrency=2` 1068/1068 通过（5分08秒，`/private/tmp/sayring-sleep-full-shanghai-final-v3.log`）。首页新断言、AI 单独确认、拒绝迟到响应及撤回授权均包含在最终全量中。

## 1025 构建与真机

- 生产 API 定义：`--dart-define-from-file=config/ios-app-store-no-push.json`；双端固定 `--build-name=1.0 --build-number=1025`。应用源码完成后未再修改运行时代码。
- iOS 串行执行 `TMPDIR=/private/tmp flutter build ios --debug --no-pub` 与 `--profile --no-pub`，均成功。日志 `/private/tmp/sayring-sleep-ios-debug.log`、`/private/tmp/sayring-sleep-ios-profile.log`；Profile 65.4 MB。
- Profile 产物 `.build/SayRing-1.0-1025-Profile.app`，已核对 `cn.saydian.ring`、1025、`UIDeviceFamily=[1]`；`codesign --verify --deep --strict` 成功，开发签名 Team `W7SXQ4A226`。Runner SHA-256：`93a98de67f893486f815744b59348c2307902ae87c6f53747aeebb98b28e2241`。
- 对已连接 iPhone 15 Pro Max 原位覆盖安装及独立启动成功，没有卸载、清空健康数据或换包名。Xcode 设备列表和设备 CLI 确认 1025；启动后仍检测到该新安装路径的进程。
- Xcode 10:41 的实际手机截图显示首页睡眠概览为 5小时46分，与用户提供的该日详情相符；原账号头像、昵称及既有睡眠记录仍显示。截图只留在本机桌面，不进入 Git。未逐条核对全部历史记录，不能把首页检查说成全页验收。
- iPhone 镜像仍提示手机使用中，尝试连接后等待锁定，未绕过锁定或操纵相册。睡眠详情新页面、真实 AI 生成和报告回读仍需单独真机验收。
- Android：`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn JAVA_HOME=<本机 Temurin 17> GRADLE_OPTS=-Dorg.gradle.workers.max=1 flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64` 成功；`SAIDIAN_ALLOW_QA_RELEASE=true` 下 `--release` 成功（69.5 MB）。同样使用上述生产 API 定义和 1025 构建号。
- Android 两个 APK 的 `aapt dump badging` 均确认为 `cn.saydian.ring` / 1.0 / 1025，arm64-v8a + armeabi-v7a；`apksigner verify --print-certs` 及 `zipalign -c -P 16 4` 通过。QA Release 使用 Android Debug 证书，不是正式商店签名，本轮没有安装或声称安卓真机通过。
- Android 产物均在 Git 忽略的 `.build/`：`SayRing-1.0-1025-Android-Debug.apk` SHA-256 `1640d02672ecabcc52e8df76d7d413c6763d93c71a0b1f60168e5014b4bddd50`；`SayRing-1.0-1025-Android-QA-Release.apk` SHA-256 `b26461ff8f8e582a331c4cf9049dc93b02ec52a4e621b23487adb51ab04b5f3c`。

## 服务端交付与线上边界

- 独立服务端工作树 `赛电APP服务端-sayring-sleep-report-20261003` 以 `969a264639345e03ef3678d868c75cea289983bf` 为基线，原服务端脏工作树未改动。功能提交 `3d777486dec66b458eace0088ea8511134d28407` 已推送，经 [PR #15](https://github.com/tangwu88/saydianserver/pull/15) 合并为 main `50dd2abbbcad82323b7d6fef7310a4aa33a26713`。
- 服务端完成本地 typecheck、全量 test、build、工具/部署检查及 372 条接口文档核对。GitHub main CI `37090532123` 的 verify 已通过（含真实 PostgreSQL 并发、HTTP 授权兼容、备份恢复和实际运行镜像检查），auto-deploy 的 resolve/deploy 均成功；公开 `/global/health/ready` 回读 revision 为 `50dd2abbbcad82323b7d6fef7310a4aa33a26713`、database=ok。
- 新增授权接口 `GET /global/api/saydian-app/v2/health/sleep-reports/availability`、`GET /global/api/saydian-app/v2/health/sleep-reports`、`POST /global/api/saydian-app/v2/health/sleep-reports`。精确日期/设备哈希/内容哈希读取，写入必须持有当前分析授权；后台健康报告新增健康/睡眠类型筛选与睡眠分数显示。
- 线上 availability 未登录请求返回 401（不是伪装为开放接口）。后台实际进入“会员与健康 → 健康报告”，报告类型中可选“睡眠报告”，选择后显示“暂无记录”，未伪造示例报告。原生展开动作不支持只读组合框，改用文档支持的 DOM combobox 点击后成功；截图 `/private/tmp/sayring-sleep-reports-admin-20261003.jpg` 保留在本机，后台结果页留给用户。
- 新增独立 `say_ring_app_display.sleepAiEnabled` 开关，默认关闭，不改变其他 App 或原通用 AI 隐藏设置。起初后台会话失效，后来有效会话恢复；只通过后台正常设置开启睡眠入口并保存。重新打开编辑器确认睡眠开关=开启、其他 AI=隐藏；公开设置接口回读 `hideAi:true,sleepAiEnabled:true`，截图证据只存本机 `/private/tmp/sayring-sleep-ai-settings-20261003.jpg`。
- 通过后台核实现有第三方 AI 配置为 `https://open.bigmodel.cn/api/paas/v4` / `glm-5.3-flash`，显示已通过真实调用；未查看或修改密钥，也未据此声称本次睡眠报告通过。协议列表仅有两产品的用户协议/隐私政策，没有当前接口要求的已发布 `health_ai_analysis`；因此真实生成仍被保护性阻止。没有绕过缺说明/未同意门禁或自动上传本机记录。
- 没有以真实个人健康记录调用第三方 AI，不宣称真实评分、报告生成或手机报告回读已通过。需要当前已发布分析说明，再由账号用户在 App 主动确认上传；镜像占用仍阻断进一步手机点击验收。App Store 审核中的包和资料未修改。
