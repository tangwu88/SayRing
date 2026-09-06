# 2026-09-07 Android 双架构构建与只读关爱真机验证

## 范围与基线

- 在主线程分工下接管 Android P40 的包验证、同签名覆盖和 `integration_test/live_care_account_test.dart` 只读测试；不操作蓝牙，不选择、连接或断开手表，不操作 iOS/Harmony 手机。
- 代码基线 `c5a28e6`，当前多任务改动保留；本轮执行仓库认证 fetch，未在脏工作树 pull，也未修改签名密钥。
- 设备旧包为 `cc.saidian.app`、0.1.19（23）、minSdk 26、targetSdk 36、Debuggable。安装前只读取包和非隐私状态，不清应用数据。
- 主线程已在 UI 明确断开 ET488；本任务只读核对 Vep 保存连接为空，Yuc 保存设备标识/名称键不存在。Yuc SDK 初始化禁用自动重连，测试不主动扫描/连接。
- 集成测试不传账号密码，复用手机当前会话；日志只输出账号指纹、记录数量、指标状态和 UI 结果。关爱接口只读，不发邀请、不改变共享授权。

## 操作与验证记录

- 已检查集成入口：`AppController.production().initialize()` 会尝试恢复保存连接；因本机没有保存目标，可以继续无手表操作的关爱验收。如后续发现保存目标或自动重连迹象，立即暂停交回主线程。
- 正常 Debug 构建使用 `lib/main.dart`，显式 `--target-platform=android-arm,android-arm64`；QA Release 仅使用 `SAIDIAN_ALLOW_QA_RELEASE=true`，不声称正式发行。
- 包与日志保存在 `/tmp/saydian-android-qa.s2dwXg`。安装包签名必须与已装包一致；集成结束恢复正常 main 入口的同签名包。

后续结果按执行顺序追加；尚未执行项不得记录为通过。

## 构建与包门禁

- Debug 双架构构建成功（291.1 秒），QA Release 双架构构建成功（434.7 秒，64.6 MB）。均为 0.1.19（23）、同包名、同 Android Debug 签名；不是正式发行签名。
- 新旧包证书 SHA-256 一致：`1350168096373439fbb4fb80c0acd145f209e06310ddb658ce318d765525cb97`。只执行 `adb install -r`，系统按已知安装提示确认，不卸载、不清数据、不改系统全局安全配置。
- `normal-debug.apk` SHA-256：`5757fba9b91ad28ba69d94975c72488c0309f2b36ed258076105bfd52344f109`。
- `normal-qa-release.apk` SHA-256：`26fcbb8b42239d81cbe1ca9a2305f8450e9b4a6b5f98f3430eb9a23a35cf59c9`。
- 两包 V2 签名、最终 manifest、ZIP 16 KB 对齐、所有 ARM64 ELF LOAD 对齐通过。Release 的 15 个 armv7 / 16 个 arm64 库均完整，两个架构都包含 `libapp.so` 与 `libflutter.so`；旧包缺少 armv7 Flutter 运行库的问题已不出现在本次双架构产物中。
- Release ABI 门禁读取本轮真实 Gradle 依赖报告，通过固定版本 `jpush_flutter 3.5.1 / JPush 6.2.0 / JCore 5.5.2` 的唯一 `libjutils.so` arm64-only 例外。Debug 另有 Flutter 验证层 `libVkLayer_khronos_validation.so` 仅 arm64，不混入 Release。
- ARM64 的 EcgAnaly、abpartool、JL、JPush、SQLCipher 等厂商库 LOAD 均不低于 `0x4000`；Flutter/AOT 为 `0x10000`。未发现本产物闭源库 16 KB 对齐阻断；未实际运行 16 KB 系统，静态对齐不等于对应系统真机验收。
- 已有工具链警告：camera_android_camerax / jpush_flutter_android 仍应用旧 KGP；Android SDK XML 工具版本警告。当前构建成功，未来 Flutter/工具链升级需回归这些插件。

## 本轮发现与修复

- 首次把合并 XML 送入门禁时，SDK 注释中的 `${applicationId}` 被误认为未解析占位符；改用解析后的 XML 检查，真正的属性/文本占位符仍拒绝。
- 随后最终 APK 的 apkanalyzer 把安全资源输出为 `@ref/0x…`，原门禁写死 `@xml/name`，导致真实发布 CI 误失败。新增 `--resources`，仅按同一 APK 的 `aapt2 dump resources` 唯一映射核对，缺表、缺 ID、格式异常或歧义仍阻断；CI 同步提供真实表。门禁测试 21/21、两包实际检查通过，没有放宽安全配置。
- 首次关爱集成接口与列表通过，但详情 UI 断言失败：tap 后未 pump 新页面，即以“旧列表没有 Spinner”当作加载完成。修复测试等待条件，要求 `CareMemberPage` 实际挂载并无加载指示；小屏必要滚动到健康段，不改变接口断言、不修改生产页面。
- 修复后的集成脚本静态分析零问题；真机复测结果后续追加。

## 第一次真机只读结果

- 会话恢复成功，账号测试指纹 `01a8dd1d`（仅用于跨端对照，不是加密匿名化机制）；1 位关爱成员，4 条历史邀请均已处理，待处理 0。未传账号密码、未重新登录。
- 成员健康 10 项状态均合法：HRV 有 1 条记录，其余 9 项返回空记录；没有整体加载失败。只记录状态与条数，不记录成员身份和健康具体数值。
- 本次最终 UI 断言因上述等待缺陷失败，不记为整条通过；未执行蓝牙操作、手表连接或任何共享授权写入。

## 修复后真机复测

- `live_care_account_test.dart --no-uninstall` 第二次通过（1/1，设备测试 32 秒）。同账号指纹 `01a8dd1d`，成员/邀请/指标状态与第一次一致，实际列表、成员详情及健康段显示均通过，输出 `LIVE_CARE_UI:OK`。
- 集成 APK 签名另行复核与旧包一致；未传账号密码，不创建或修改任何关爱关系。保留 `care-integration-sanitized.log` 与 `care-integration-retest-sanitized.log`，只含指纹、状态、数量及测试栈信息。
- 读取 crash buffer 未见本应用 FATAL/ANR 记录；本项不是长时间稳定性保证。
- 已无损恢复已验证的正常 `lib/main.dart` Debug 包并正常启动，再交还主线程继续邀请及 W9S 硬件验收。不再操作该手机。
- 本批 Debug / QA Release 没有注入极光配置，推送禁用是本批构建选择，不能作为“外部缺少凭据”的证据；实际即时推送由主线程使用正确配置的产物另行验收。

## 已有本地配置的推送 Debug

- 手机交还主线程后，仅检查 ignored `.env.jpush.local` 的字段存在性和格式：AppKey 有效、channel 为 production；该文件没有厂家配置，当前工程没有华为 agconnect-services.json。没有把凭据值写进日志/Git，也没有假定其他安全存储不存在凭据。
- 选择明确的 `JPUSH_VENDOR_CHANNELS=none`，由 `prepare_push_config.py` 验证；只启用极光通用通道，不能据此验收华为厂商离线推送。
- AppKey 通过进程环境注入原生，通过受限临时 JSON 注入 Dart；构建后删除仅本次生成的临时 JSON，没有读取/修改签名私钥。
- 正常 `lib/main.dart` 推送 Debug 双架构构建成功（92.8 秒），产物 `/tmp/saydian-android-qa.s2dwXg/normal-debug-jpush.apk`，SHA-256 `dabe907e1d45b34bccb0c573f4096aa75669ca3257c72d7f8563112ddf4e093e`。
- 与旧包同签名、Dart 编译产物 AppKey 匹配、最终原生 manifest（按真实资源表）、双 ARM Flutter、ZIP 16 KB 全部通过。只报告匹配布尔与公开包哈希，不输出配置值。
- 本任务没有安装该推送包，也没有再次操作手机；由主线程确定现场邀请测试时机后无损覆盖并验证注册、收到、点击及前后台状态。

## 后续授权的推送真机接管

主线程随后明确把 Android P40 重新交给本任务，允许安装上述同签名推送包、通过正常系统 UI 开通知及配合真实邀请；本节不改变前段“当时未安装”的历史事实。

- 主线程首次安装命令返回空失败信息；接管时包更新时间已变化，但未据此假定完整安装。再次使用同签名 `adb install -r` 成功，保留登录、关系和健康数据。
- 系统实际 `POST_NOTIFICATION` 为 `ignore`；进入赛电单应用通知设置，确认开关关闭后正常开启，复核为 `allow`。没有修改全局安全设置。客户端 `notificationPermissionEnabled=true`。
- 当前运行 SDK 的 registration ID 通过调试只读调用取得，仅落在本机权限受限临时文件；不在日志、聊天或 Git 记录其值。没有修改 alias/tags。
- 运行时 `pushDeviceRegistrationState=registered`；后台协作任务以官方只读 Device API 验证设备 HTTP 200、deviceFound=true，alias/tags为空。这是注册证据，不是通知投递证据。
- 基线：Android 关爱历史 5 条、待处理 0、关爱成员 1、消息未读 0；没有保存 Vep/Yuc 重连目标。本任务没有连接、断开或操作任何手表。
- 主线程随后明确授权 Android 向指定 iPhone 测试账号发出一次此前不存在方向的关爱邀请。通过正常关爱页面填写并单次点击“发送”：**2026-09-07 01:18:24 CST（2026-09-06 17:18:24 UTC）**；对话框关闭、客户端 errorMessage=null，没有设置健康共享或修改原关系。
- iPhone 的应用内待处理刷新由主线程监测；其当前 Profile 缺少 APNs entitlement，系统推送能力需要独立配置验证，不能把无签名能力时的投递失败直接归因服务端。
- 现场另发现 Android 关爱右上添加按钮缺无障碍名称，已告知主线程；主线程补“添加关爱”tooltip 并通过 9 项定向测试。当前手机仍为修复前包，后续新包需复验标签。

截至此记录，未声称 Android 前后台关爱推送全链路通过；没有群发、伪造健康预警或删除原关系制造测试条件。

## 单设备通知探针及最新客户端回归

- 主线程授权仅向当前 P40 发一个标准通知探针，使用当前账号真实已处理的邀请实体；不创建新关系、不修改共享、不发送健康值。再次核对 SDK 当前 registration ID 与受限私有文件一致，仅记录匹配布尔。
- 提供者请求时间 `2026-09-06T17:55:33Z`，HTTP 200；Android 系统 `mCreationTimeMs` 对应 `17:55:34.332Z`，约 1.3 秒进入系统通知。标题“通知联调测试”，正文“这是一条定向通知测试，请打开 App 查看。”符合本轮通用探针。
- `17:57:17.862Z` 正常点击系统卡片后，通知消失并回到原“远程关爱”页，但没有进入邀请详情。`17:57:21.513Z` UI 检查无目标页，不能记深链通过；当前仍是 01:01 构建的旧正常 JPush Debug 包。
- 只读运行时确认探针已解析并按实体合并到账号收件箱；`pendingNotificationRoute=null`、根导航空闲、邀请页面实例数 0。事件原本已读，所以不能从 readAt 推断 open 回调已经执行；原生日志没有保留对应文字，也不能据此证明没执行。
- 提供者确认只用 `notification.android.title/alert/extras`，没有 intent、URL、custom 跳转、message/data 双发；没有用手工页面导航冒充深链验收。
- 初始完整 `flutter analyze --no-pub` 零问题，UTC / Asia/Shanghai 全量各 **438/438**。日志留在同一 `/tmp/saydian-android-qa.s2dwXg` 的 `final-flutter-*`，不进 Git。
- 按主线程授权加 Debug 安全回调诊断：仅 native callback、Dart 解析布尔、事件类型、鉴权/导航门禁布尔与白名单路由枚举，不含 ID、账号、原始推送或凭据。同步去掉本次触及的 JPush helper 原始通知/参数日志。
- 诊断版静态分析零问题、通知关联 46/46；另新增生产 App “已读且已处理邀请，在 inactive→open→resumed 后仍跳转”回归并通过。当前全量理论增至 439，待最终锁源后重跑，不能把上次 438 记为新增用例已全量执行。
- 正常 main 双 ARM JPush Debug 编译成功（112.6 秒）；`final-normal-debug-jpush.apk` SHA-256 `5e9e9b442273e1b44b3fe1e5fcd21619c4de10a8bfd4581ef7f8c4bde783480b`。签名与旧包一致、ZIP 16 KB 通过；最终 Manifest 首次因检查进程没注入受保护配置而被门禁拒绝，注入同一已验证本地值后通过，没有放宽检查。
- 覆盖安装使用 `-r`，系统先提示来源风险，再提示应用备案状态未知；按用户本轮安装授权通过正常 UI 确认，不改全局权限，不安装推荐应用，不卸载或清用户数据。此系统提示应作为发行资料核验项，不自行认定已备案或未备案。

新包安装完成和第二次单设备探针结果随后追加；主线程已明确授权第二次且唯一一次新 event ID，原已处理实体不变。没有自动重试发送或群发。

### 本轮暂停点

- 新诊断代码与已处理点击回归纳入后，完整 UTC / Asia/Shanghai 均 **439/439 通过**；完整分析零问题。最终定向分析和差异格式检查也通过。正常 Debug 产物包含本次诊断，后续新增的测试不改变 App 产物内容。
- 系统来源/备案步骤完成后，P40 显示“请输入锁屏密码继续安装”。这是机主身份验证，不是可静默开启的 App 权限；未猜密码、未绕过验证，已交主线程请用户本人完成。
- 检查时旧包 `lastUpdateTime=2026-09-07 01:07:26`，首次安装时间仍 `2026-08-30 18:52:53`。安装命令仍在等待，不能记录为新包已覆盖；第二次探针也尚未发送。
- 临时手机 UI dump 已在解析后删除（仅本次创建的四个 XML）；本机原始截图限制为当前用户可读，不进 Git。没有删除应用数据、联系人或健康记录。

## 最终双 ARM QA Release 与统一归档

- 主线程再次明确授权只构建、归档和核验 Android，不操作 P40。基线仍为 `06ec474` 加当前锁定工作树；先安全 fetch，脏工作树不 pull。开始磁盘 9.3 GiB，结束 8.1 GiB，没有清源码、缓存或既有产物。
- 显式 `SAIDIAN_ALLOW_QA_RELEASE=true`、`SAIDIAN_PRODUCTION_RELEASE=false`；正常 main、双 ARM、已有受保护 JPush 配置、厂商通道 none。没有修改生产签名门禁或读取私钥。
- QA Release 编译成功（82.2 秒，64.7 MB）；构建输出的通用 QA 警告提到推送可能关闭，但本包实际配置已注入并经最终 Manifest 校验，不将该通用文字误记为真实禁用状态。
- 当前系统 Python 首次元信息核验因 `hashlib.file_digest` 不存在失败；改为兼容的分块 SHA-256 流读取，重跑完成。没有更换 Python、放宽校验或忽略失败。
- Debug 与 QA Release 均以排他复制/APFS 克隆安全导出 `artifacts/three-platform-20260907/android/`，原临时产物保留。目录已被 Git 忽略，附 `README-QA.md` 和 `SHA256SUMS`，没有把凭据或完整 Manifest 放入交付目录。
- Debug：`Saydian-Android-QA-Debug-JPush-0.1.19-build23-20260907.apk`，153895216 字节，SHA-256 `5e9e9b442273e1b44b3fe1e5fcd21619c4de10a8bfd4581ef7f8c4bde783480b`。
- QA Release：`Saydian-Android-QA-Release-JPush-0.1.19-build23-20260907.apk`，64661852 字节，SHA-256 `a9fb61a7bdf13de3602f4cc52ce4000014f5c425246d494e28fef7bfcb1af7f2`。
- 两包版本均 `cc.saidian.app / 0.1.19 (23) / minSdk 26 / targetSdk 36`；Debuggable 分别 true/false；证书 SHA-256 均与旧包 `1350168096373439fbb4fb80c0acd145f209e06310ddb658ce318d765525cb97` 一致，仍是 Android Debug 签名，不是正式签名。
- 两 ARM Flutter 均完整，Release 两 ARM AOT 均完整。Release 原生库 15/16，只有固定 `jpush_flutter 3.5.1 / JPush 6.2.0 / JCore 5.5.2` 的 `libjutils.so` arm64-only 例外，使用本次重新生成的 Gradle RuntimeClasspath 报告通过 ABI 门禁。
- 两包 ZIP 16 KB 静态对齐及所有 ARM64 ELF LOAD 不低于 16 KB 均通过；Debug 独有 Vulkan 验证层不混入 Release。没有 16 KB 系统真机运行结论。
- QA Release 最终包名/版本/权限/推送 Manifest 门禁通过。核验工具的“Production APK verification passed”只表示检查规则通过，不改变显式 QA 包性质；不得称正式发行完成。
- P40 仍保留安装身份验证现场，本批未操作设备。新 Debug 安装和点击待复验，第二次单设备探针未发送；QA Release 未安装。这些待验项随包 README 保留。

## r2：最终推送原生日志隐私收口

- 最终复审发现 JPushHelper 仍有历史 `android.util.Log` 输出缓存注册标识、注册回调、完整结果 map、消息对象及异常原文；`JPushInterface.setDebugMode(false)` 并不控制这些直接日志。上一段构建成功不能作为日志隐私完整通过。
- 本轮先检查工作树并使用仓库专属认证安全 fetch；仍以 `06ec474` 加共享工作树为基线，不覆盖并行修改。最小删除 helper 中旧日志及无用 TAG，仅保留 `FLAG_DEBUGGABLE` 保护内的 open/receive 类型与 Dart/channel readiness 布尔，不改事件、缓存或返回逻辑。
- 新增原生日志白名单回归：全文件只允许这一条受 Debug 标志保护的安全日志；禁止直接打印、堆栈输出及其他原始参数日志；固定调用方仅 open/receive。通知关联三文件 **57/57**、完整 `flutter analyze --no-pub` 零问题、`git diff --check` 通过。
- 两种正常入口包重新串行编译并以 `-r2.apk` 命名；上一版两包及原哈希原位保留，禁止把新包覆盖为旧哈希或声称已安装。本轮不再操作 P40 的锁屏密码安装确认，不重发探针。
- 后续构建和最终产物校验结果见本节追加；在取得真实结果前，不沿用上一版包验证值。

### r2 构建与核验结果

- 正常 Debug 14.8 秒、QA Release 43.9 秒编译通过，仍为双 ARM、相同本地 JPush 配置及明确 QA 模式；磁盘余量 7.9 GiB，没有清理或覆盖原交付包。
- Debug r2：153895216 字节，SHA-256 `17069e5c907620a96b830ca34d5497c89b374db0004b726050fc1b0b032915c5`。
- QA Release r2：64661852 字节，SHA-256 `4e5af7c761b9ecee667f15ee42b10f7f75e3fe1c8682271d07012af3e606d2c5`。两包大小恰与原版一致，但二进制内容和哈希不同，不以大小判断是否重编。
- 两包包名/版本/minSdk/targetSdk/Debuggable 与上版一致，APK 签名验证与旧证书比对通过；最终 Manifest/资源表门禁、ZIP 16 KB、所有 ARM64 LOAD 16 KB 静态验证通过。Release 用新 Gradle 依赖报告再次通过受控 JPush ABI 门禁，两 ARM Flutter/AOT 完整。
- Debug 直接反编译验证 helper 只余一条安全日志。Release 初次按原类名查询失败；当次 R8 做了类合并，按真实映射定位后确认 `ApplicationInfo.flags & 0x2` 与条件跳转在 `Log.i` 前；Release Manifest 为 `debuggable=false`。未用原类名查询失败冒充日志已移除。查询帮助时该版 apkanalyzer 不支持 `--help`，改用已返回的参数说明，没有修改工具。
- 四个包及全部独立哈希保留；README 已区分原版/r2。主线程随后发现关爱权限 fallback 需最小修复，因此 r2 现作为中间包，等该修复锁源再生成最终 r3。当前不占 Flutter 锁，不安装、不改变 P40 现场。

## r3：关爱拒绝优先与最终 QA 重编

- 主线程锁定关爱授权/字符串业务状态码修复，完整 Flutter UTC / Asia/Shanghai 各 **456/456**、分析零问题。具体回归见 `IMPLEMENTATION-LOG-20260907-CARE-AUTHORIZATION.md`；r3 纳入这组修复，不再把总表回退用于绕过单项明确拒绝。
- 重编前安全 fetch，当前 HEAD `32948ae` 加锁定的 Flutter 工作树；不覆盖并行修改、差异格式检查通过。等待主线程完成 iOS config-only 并明确释放 Flutter 锁后，才开始 Android Debug → QA Release；不触碰 iOS 配置、活动缓存或手机。
- 沿用相同受保护 JPush 配置与明确 QA 构建模式，双 ARM、正常 main 入口。产物以 `-r3.apk` 排他复制，原版与 r2 四包及哈希原位保留；开始磁盘 7.8 GiB。
- 本轮最终包校验结果后续追加；P40 安装身份验证、系统通知点击和真实关爱拒绝场景仍须最终包现场复验，不以自动化替代。

### r3 最终核验

- Debug **10.3 秒**、QA Release **27.6 秒**构建通过，正常 main、双 ARM，Flutter 锁及时交还主线程。没有清理或修改 iOS 活动缓存。
- Debug r3：181259194 字节，SHA-256 `12588df45e1379e96623578de0ee4a414f80493e30340d440d0e13704fbaf034`。
- QA Release r3：64661920 字节，SHA-256 `4a705725b16f5e5d560d8d9b2d27f8698ce5b4e1e8a359a7984094ad07a435f7`。
- 两包 APK 签名校验通过，证书 SHA-256 均仍为 `1350168096373439fbb4fb80c0acd145f209e06310ddb658ce318d765525cb97`；`cc.saidian.app / 0.1.19(23) / minSdk26 / targetSdk36`，Debuggable 分别 true/false。QA Release 仍是 Debug 同签内部测试包，不具备正式发行签名。
- 使用各自最终 Manifest 与实际资源表验证包名、版本、推送和受限权限通过；Release 新 RuntimeClasspath 报告核验两 ARM ABI，仅允许锁定 JPush/JCore 的 `libjutils.so` 例外。Debug 15/17 个原生库，Release 15/16；两个架构 Flutter 均有，Release AOT 均有。
- 两包 ZIP 16 KB 及全部 ARM64 ELF LOAD 16 KB 静态验证通过。Debug 与 Release 均直接检查编译后的安全日志，Release 按本次 R8 映射定位后确认 Debug 标志条件跳转；不含 helper 历史原始参数日志。没有 16 KB 系统或新包安装真机结论。
- Debug 比 r2 增约 27 MB；逐 ZIP 条目与偏移核实为增量打包在 shader 条目前保留约 27 MB 空隙，条目压缩内容总量只增 1879 字节，签名区正常。不是重复业务素材或误混入另一架构。为保持已验证签名/产物身份，不对成品手工重压缩；Release 无此增量。
- README 已指向 r3，原版/r2 四包均保留，六包 `SHA256SUMS` 各自验证；所有原始 Manifest、凭据和诊断原文仍留本机受限目录，不进入交付或 Git。
- r3 本批只构建/校验，不操作 P40、不输入或绕过锁屏密码、不卸载、不清用户数据、不发送推送。本轮最终安装、通知点击和授权撤销真机回归仍待主线程继续。

### r3 一次安装收尾（主线程追加授权）

- 主线程随后授权仅处理 P40 的旧安装挂起并一次覆盖最新 r3。只读确认 PID `81376` 确实已等待约 50 分钟、指向旧 `final-normal-debug-jpush.apk`；只中止这个已核对的进程，并在其系统认证页点“取消”，避免用户迟到确认装回旧包。
- 再次复核 r3 Debug 证书与旧包相同后，仅执行一次 `adb install -r`。通过正常系统 UI 的来源风险、备案状态未知及已知风险确认，没有点击推荐应用、修改全局安全设置或绕过认证。
- 最新 r3 安装再次到达“请输入锁屏密码继续安装”，停止操作并交主线程请机主本人在手机输入。没有读取密码框内容、猜测密码或继续重试；等待中的新安装会话为 `43978`，对应最新 r3 而非旧包。
- 此时应用首次安装时间仍 `2026-08-30 18:52:53`，最后更新时间仍 `2026-09-07 01:07:26`，不能记为新包已覆盖。原账号、健康数据及设置没有清除；仅删除本次创建并已解析的安装页临时 XML。
- 没有发送第二次探针。只有确认最新包安装完成后，才能协调单设备通知点击复验；手动打开目标页不能代替通知深链结果。

## r4：取消无逐项授权保障回退与最新 QA 候选

- 主线程在 iOS r3 上完成的 HRV 关闭回读/接收方重新进入仍显示记录，是现场撤销验收失败，不把此前自动化成功当现场通过。经生产 API 反例定位，Flutter 单项空/不可用仍可能从无类型日总表补回数据；此轮移除仅远程成员读取的预读/回退及残留摘要合并，正常逐项记录、本机记录和非健康活动路径保留。
- 具体失败与修复见 `IMPLEMENTATION-LOG-20260907-CARE-METRIC-AUTHORITY.md`。最终定向 73/73、UTC / Asia/Shanghai 完整各 **463/463**、分析零问题，锁源后开始重编。单项端点若撤销后仍返回记录，本修复不能替代服务端鉴权。
- 重编前安全 fetch，HEAD `3d330b1` 加锁定的 Flutter 工作树；保留全部并行改动。主线程明确释放 Flutter CLI 后，正常 main/双 ARM/相同受保护 JPush 配置及 QA 模式串行 Debug **10 秒**、QA Release **27 秒**构建通过。没有改生产签名门禁、源码或其他手机。
- Debug r4：153895216 字节，SHA-256 `25c167cd02fc494318e4247e899921ac85ac4e01eb3eb2407b49a75883f0bba4`。
- QA Release r4：64645536 字节，SHA-256 `37b45f31b4ca986bbe03c4ee457d5b7355bc0fdbf611a93608be130869c21591`。
- 两包实际 `cc.saidian.app / 0.1.19(23) / minSdk26 / targetSdk36`，Debuggable 分别 true/false；证书 SHA-256 仍为 `1350168096373439fbb4fb80c0acd145f209e06310ddb658ce318d765525cb97`，与旧包一致。QA Release 不是正式签名发行包。
- 两包实际 Manifest/资源表门禁、APK 签名、ZIP 16 KB、全部 ARM64 ELF LOAD 16 KB 通过；Release 以新 RuntimeClasspath 报告通过受控 `libjutils.so` 例外，双 ARM Flutter/AOT 完整。直接验证当次 Debug helper 与 R8 映射后的 Release 安全日志，Release 仅在 Debug 标志条件下输出布尔信息。旧六包保留，最新以 `-r4.apk` 排他导出，README/八包 SHA256SUMS 更新。

### r4 安装唯一一次尝试与暂停点

- 主线程允许只处理 P40。只读确认旧 r3 安装 PID `37898` 挂约 25 分钟且包更新时间未变；精确中止该进程，并正常点“取消”旧 r3 认证。没有误停整个 ADB 服务或其他设备。
- 校验 r4 同签名后只发起一次 `adb install -r`。正常确认当前 App 来源/备案风险，不点击推荐应用；只在安装器页读取操作按钮，进入认证 Activity 后不读取密码框或进一步尝试。
- 当前等待的是最新 r4：PID `66458`、工具会话 `26132`。系统为华为机主认证 Activity，需要用户在手机完成锁屏密码验证；未绕过/猜测密码，未卸载/清数据或重复安装。
- 当前实际已安装应用最后更新时间仍 **2026-09-07 01:07:26**、首次安装仍 **2026-08-30 18:52:53**；r4 未完成安装，不能称 r3/r4 客户端已在 P40 实测。已停止手机操作并交主线程。
- 本轮未发送任何通知探针，临时安装器 XML 在解析后仅删除本次创建的文件。待用户完成安装后仍须核对实际 APK 身份、账号数据、冷启动、通知点击及真实授权撤销/恢复；自动化和构建不替代这些现场结论。
- r4 文档及八包哈希校验已完成。主线程随后确认组合关爱 API 跨账号迟到响应的生产合成反例，另交 API 任务实施最小归属防御；没有把该反例写成已发生真实账号泄露。r5 待锁源重编，r4 保留中间候选，当前 r4 认证页保持，不再操作 P40。结束时磁盘 5.8 GiB，没有继续清缓存或源码。

## r5：关爱组合读取归属防御与最终包

- 主线程锁定关爱组合读取账号/Controller 代次防御及迟到 401 阻止旧凭证刷新的修复，定向 **90/90**、UTC / Asia/Shanghai 各 **480/480**、完整分析零问题。具体反例、失败过程和安全边界见 `IMPLEMENTATION-LOG-20260907-CARE-READ-SESSION.md`。
- r5 只解决组合查询归属防御，不替代后台逐指标授权。主线程 r4 iOS/r11 Harmony HRV 关闭回读后仍显示记录的现场 P1 继续保留；未获得该次原始响应，不认定后台具体状态码或宣称服务端修复。
- 修改/重编前安全 fetch，当前 HEAD `790c2de` 加锁定 Flutter 工作树，保留全部并行改动；等待主线程完成 iOS config-only 释放 Flutter CLI 后再构建。正常 main、双 ARM、同一受保护 JPush 配置、显式 QA/非生产模式，Debug **10.9 秒**、QA Release **28.8 秒**通过。
- Debug r5：181259325 字节，SHA-256 `e8284f2fa34a84d354eefea3320b9f0b19955e4d0b43864679ed641e91b1359f`。
- QA Release r5：64661920 字节，SHA-256 `37b3e235419801bb721622ed96fa1e485092cf8bf99904a6cfa6bf9ef12f127c`。
- 两包实际 `cc.saidian.app / 0.1.19(23) / minSdk26 / targetSdk36`，Debuggable 分别 true/false；APK 签名验证与旧证书 SHA-256 `1350168096373439fbb4fb80c0acd145f209e06310ddb658ce318d765525cb97` 比对均通过。QA Release 仍是内部 Debug 同签，未修改生产签名门禁，不称正式发行。
- 各自最终 Manifest/实际资源表门禁、ZIP 16 KB、所有 ARM64 ELF LOAD 最小对齐与偏移/虚址 16 KB 同余均通过。Release 新 RuntimeClasspath 报告验证双 ABI 与锁定 JPush 唯一例外；两个架构 Flutter 完整，Release AOT 完整，Debug/Release 原生库数分别 15/17 与 15/16。
- 当次 APK 直接反编译核对安全日志，Release 按当次 R8 映射验证 `ApplicationInfo.flags & 0x2` 条件跳转；不保留 helper 原始注册标识/完整消息/异常输出。Debug 较 r4 增大来源于 ZIP 条目间 27362099 字节空隙，条目数 1051 不变、压缩内容只增 2170 字节、签名区仍 4096 字节，不手工改写已签名包。
- 最新以 `-r5.apk` 排他复制；原版至 r4 八包完整保留。README、十包 SHA256SUMS 及兼容签名文档仅 Android 行/段更新，不触碰其他端记录。

### r5 一次安装与最终现场状态

- 只读确认 P40 的旧 r4 安装 PID `66458` 仍挂约 18 分钟、目标确为 `-r4.apk`。精确停止该进程并正常取消旧认证，未停止 ADB 服务或其他手机。
- r5 全部校验后只发起一次 `adb install -r`，正常通过赛电安装来源/备案风险确认，没有选择推荐应用或修改全局系统安全设置。认证页面不读取/输入密码，也未猜测或绕过机主验证。
- 当前待确认的是最新 r5：PID **90120**、工具会话 **85390**。系统停在华为机主认证 Activity，需要用户本人在 P40 完成锁屏密码验证；已停止手机动作，不再重试。
- 实际应用最后更新时间仍 **2026-09-07 01:07:26**，首次安装仍 **2026-08-30 18:52:53**；r5 未安装完成，旧版及原账号数据保留。没有发送任何新推送探针、操作手表、卸载或清数据；仅删本次已解析的安装器临时 XML。
- 最终包身份、覆盖后登录/健康数据、冷启动、通知点击与关爱撤销/恢复仍待安装后真机验证；不得以 480 项自动化或打包成功替代。
