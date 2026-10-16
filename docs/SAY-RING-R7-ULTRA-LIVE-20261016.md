# R7 Ultra 真机连接、同步、活动与睡眠验证

- 用户授权在当前 iPhone / 既有绑定 R7 Ultra 上测试上述功能，发现问题直接修复。原用户确认昨晚没有佩戴戒指，故本轮不能宣称完整夜间睡眠采集验收；用户按测试要求已佩戴走约 50–100 步。
- 修改前 main 干净，fetch / ff-only pull 确认基线 `4e93664bb04c00873c09183f37e39c00f04b767b`，树 `aa0666662547f570f89011abbc61cea666d542c9`。
- 先正常停止本任务之前的 Debug 会话，不卸载；停止后的应用容器复制成功，43 个文件、32,496,227 字节，逐文件哈希保留在权限 0700 的忽略目录 `build/ios-r7-ultra-live-20261016/`。
- 计划使用明确验签的 Profile 集成测试包与 `tool/drive_ios_preserving_data.mjs --keep-app-running`；仅操作既有账号/目标，不解绑、不改监测设置、不生成健康样本。测试后覆盖安装正常 main 并恢复 Debug。
- 本轮测试入口覆盖真实 LuckRing/CoolWear 握手、电量新鲜度、页面手动同步、实际活动记录与详情、睡眠历史与空状态，以及三轮软件断开/页面重连。软件断开不等于物理远距离、蓝牙开关或后台完整验收。
- 初始源码核对发现 CoolWear 采用连接/校时触发厂商推送，需以真实数据包及每指标完整性判断同步；不能将校时 ACK 或空响应视为历史已完整读取。具体失败、修复、回归与产物结果随后追加，以实际日志为准。

## 复现与修复

- P1，实时活动丢失：1069 Profile 在真实 SDK 握手后收到 type 4 `REAL_SPORT` / `sportInfos`，但桥接仅处理 type 5 活动历史，导致走路后步数仍未入库。修复 `CoolWearHistory.h` 的严格活动包校验及 `CoolWearWearableBridge.m` 的被动投递，保留 SDK 时间、步数和来源；实时快照只开放实际读到的活动能力，不伪造历史能力或完整性。距离和热量量纲仍未确认，保留未知。
- P1，同步反馈失实：1069 首次手动同步在没有完整历史回执时显示“暂无新增数据”。修复 `app_controller.dart`，未收到、部分收到、当前活动已更新、明确空历史、超时分别处理；不完整历史仍返回失败并保留已读记录。
- 回归防护：同一 SDK 时间的累积步数增长不能被旧行覆盖，扩展现有 QRing 去重规则到 CoolWear v2；不影响其他供应商、旧格式、其他指标和更高质量记录。原始加密历史不删除。
- 1069 实机已通过初始既有账号/目标握手、电量、活动详情入口、睡眠概览，以及三轮软件断开/页面重连；最终因上述同步和步数问题失败。私有原始报告另存 `live-report-1069-before-fix-private.json`，不替换成修复后的通过报告。

## 本轮执行记录

- 1068 首轮测试入口在挂载 App 后初始化时停滞，正常中断自身 drive；保留应用与数据，未认定产品通过。改为初始化设 45 秒边界、随后挂载，并增加不含用户标识的阶段日志；1069 实际完整执行。
- 新增真机入口 `integration_test/ios_r7_ultra_activity_sleep_test.dart` 与私有报告驱动 `test_driver/ios_r7_ultra_live.dart`。始终仅既有 owner-bound R7 Ultra；不解绑、不切账号、不生成样本、不做生理测量或设备配置写入。完整历史验收与当前活动保存分别记录，空回执不能通过“已是最新”的断言。
- 首轮定向 Flutter 测试因新测试误用 `HealthRecord.copyWith(id:)` 编译失败，改用既有 JSON 构造 API。第二轮 `no_data` 测试被 fake 的未实现查找功能异步错误干扰，等待该 probe 后隔离初始错误，再运行 56/56 通过。产品 API 未为测试扩展。
- Native Foundation 合成输入测试通过：type 4 合法/零步数、异常数字/计数/时间拒绝、实时快照不证明历史完成、历史状态不被覆盖。`clang -fobjc-arc -framework Foundation test/native_coolwear_policy_test.m -o <private>/coolwear-native-policy` 后实际运行通过。合成测试不等同真戒指睡眠采集验收。
- 既有 Node 源码契约第一次因 capability 投递从历史指标改为实际指标而失败；更新该边界断言后，`node --test tool/drive_ios_preserving_data.test.mjs tool/test_coolwear_ios_integration.mjs` 19/19 通过。`node --test tool/test_ios_activity_sleep_policy.mjs tool/test_native_log_privacy.mjs` 11/11 通过，原生真实策略及 Swift 导入检查仍通过。
- 静态分析初次报告上述测试 API 错误，修正后 `flutter analyze --no-pub` 零问题。UTC 与上海时区各 `flutter test --no-pub --reporter expanded` 1250/1250 通过。Android、修复后真机与正常入口构建结果待实际执行后补录。
- Profile 1070 以本轮测试入口构建成功，34.1 秒；严格深验签、cn.saydian.ring、1.0.1 (1070)、W7SXQ4A226 与目标设备资格通过。冻结 IPA 24,085,314 bytes，SHA256 `48cc84787c475d95853d7d3c218b396f843ae0f9e7dc0b0445468ad82aa686f9`。通过保数据 wrapper、`--profile --keep-app-running --no-pub --use-application-binary=<明确1070 IPA>` 启动实际复测。
- 1070 第一次在初始化 45 秒边界超时，未进入功能断言；第二次初始化成功，但首帧等待阻塞。一次前后台切换后进入真实 R7 握手，但后续帧再次停止；正常中断自身 drive，仍不卸载。不能把超时或中断当作修复后通过。测试入口调整为正式 main 的先 runApp 后异步初始化，并设 fullyLive 帧策略与单次等待 20 秒边界，1072 重新构建复验；没有通过伪造 resumed 状态、健康数据或 SDK 回执绕过断言。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py'` 35/35 通过；日志内拒绝错误包/跳转的输出属于预期负向用例，不代表生产环境被修改。
- Android Debug `flutter build apk --debug --no-pub --target=lib/main.dart --target-platform=android-arm,android-arm64 --build-name=1.0.1 --build-number=1071 --dart-define-from-file=config/ios-app-store-no-push.json`，51.5 秒通过。Gradle 原生测试第一次 offline 默认寻找未缓存 x86_64 引擎包失败；显式 `:app:testDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline --max-workers=1 --console=plain` 重跑 7 秒成功，XML 合计 51 tests，0 failures/errors/skips。
- Android QA Release 使用同版本/双 ARM/正式 main/无推送配置与显式 `SAIDIAN_ALLOW_QA_RELEASE=true`，81.9 秒成功；`apksigner verify --verbose` v2、`aapt dump badging` 的 cn.saydian.ring / 1.0.1 (1071) / 两 ARM ABI、`zipalign -c -P 16 4` 均通过。Debug 158,817,557 bytes，SHA256 `bcbbf688cea652a3cd18f8ea56acfcef7104adc46edd0ea5a35130b84c3f0d93`；QA Release 69,816,367 bytes，SHA256 `0f4c141e3425a69b3bb4f05d3d84075ad7ad4c6e3738de9526d39e1fa41228b9`。仅回归包，不替换 Android 1016 下载或 Windows 1066 正式签名包。
- iOS 正常 `lib/main.dart` Profile 1071 构建 25.7 秒成功，严格深验签；IPA 23,830,982 bytes，SHA256 `09288164a9d5c6034bfe28f2c7e7c6acaa78e05e8c1058686112f6a676866b39`。Debug 同版本/入口串行构建 20.8 秒成功，严格验签、原产品与团队、设备资格通过；IPA 57,934,468 bytes，SHA256 `54f0417edb9b265a7ac340f56d7eaefb9c7e6a01fcaeeae0315dc42a11c61b03`。构建命令仅替换 `--profile` / `--debug`、明确 `--target=lib/main.dart` 与 `--build-number=1071`，沿用最低 iOS15 的本地覆盖及 no-push 配置。测试后恢复此正常入口，不复用老 1067。
- 1072 Profile 43.3 秒构建、严格验签和设备资格通过，IPA 24,085,408 bytes，SHA256 `97526cc2e495d0ab1dc9a812ecc81b25ddd467e83050f88db18fbd3ede7e034a`。仍在初始握手后等待，正常中断，未宣称功能通过。1073 加入仅阶段/状态的 5 秒诊断心跳及活动查询 30 秒边界，启动延迟让场景有机会挂接；26.8 秒构建、签名和设备资格通过，IPA 24,081,915 bytes，SHA256 `6b8207b77d8867511d6bf4c7fa5bbded0a5053911f17339cb1314937d8b70e20`。首次编辑诊断 import 落到文件末尾导致格式化解析失败，移至顶部后修正；全仓 analyze 再查零问题。实际运行仍初始化超时，恢复前台时心跳显示 inactive。
- 使用 Xcode27 的 `devicectl device capture screenshot --device <本机> --destination <private>.png --quiet` 成功取得原生截屏；画面确认为本 App 的“正在为你准备”，没有密码、验证码或权限弹窗。先前仅靠 lockState/backlight 无法判断 App 激活状态，现按真实屏幕和生命周期日志诊断，不将该停顿归因于用户未解锁。
- P1，场景连接生命周期遗漏：自定义 `SceneDelegate` 建好窗口后未调用父类的 `scene:willConnectToSession:options:`。对照本机 Flutter 3.44.9 头文件及 [FlutterSceneDelegate 官方实现](https://api.flutter.dev/ios-embedder/_flutter_scene_delegate_8mm_source.html)，该父类回调负责场景连接的生命周期分发；补上此调用，让真实 UIKit 回调正常传递。是否消除本机启动停顿，以 1074 及正常 main 的实机结果为准，不手动注入 resumed 状态。
- 1074 的实际阶段日志进入 resumed、初始化、原绑定握手、活动读取完成、设备页面渲染和手动同步点击，随后记录 paused。原生屏幕确认此时其他应用在前台；这部分停顿属于测试运行条件中断，不能当作蓝牙/数据库死锁，也不能把全部停顿归因于场景回调遗漏。仅保留“其他应用在前台”的结构化结论，不保留与任务无关的屏幕内容。告知用户页面测试需要 App 持续前台后，以同一验签 1074 包重新测试；前次中断日志保留。原用户对“正在为你准备”的观察与先前 App 截图一致。
- 1074 在前台完整执行 76 秒：步数首次读取即存在，同步后仍存在且为正值；活动详情、睡眠概览与未知状态、三轮软件断开/页面重连全部通过。第一轮同步正确显示“活动数据已更新，历史记录尚未确认”，但紧接着第二轮报“设备已连接，但设备忙，请稍后重试”，故测试最终失败，没有把上述局部通过记成整轮通过；报告另存 `live-report-1074-battery-busy-private.json`。
- P2，连续同步撞上电量刷新：同步 finally 会刷新设备详情，原生电量读取尚未返回时第二次同步立即被拒。修改 `CoolWearWearableBridge.m`：先预留同步操作，再等当前电量读取释放队列，250 ms 重查、最多 8 秒，随后保持原 25 秒历史窗口；总时限在 Dart 的 35 秒内。连接/操作代次改变或取消后不再发命令，不清 SDK 队列、不伪造 ACK、不抢占测量/查找/设置写入。1076 以相同功能断言重新验证紧接着的两次同步。
- 最终原生策略与保数据门禁再次执行：`node --test tool/drive_ios_preserving_data.test.mjs tool/test_coolwear_ios_integration.mjs tool/test_ios_activity_sleep_policy.mjs tool/test_native_log_privacy.mjs` 30/30 通过；90 项原生活动/睡眠断言与 Swift 导入仍通过。后续改动限 iOS 原生场景/调度与真机测试诊断，Android 和已通过双时区 1250 项的共享 Dart 产品源码未变。
- 1076 Profile 构建 15.5 秒，严格验签与设备资格通过；IPA 24,081,873 bytes，SHA256 `5ba3fdc68187b78ae61e1e218f433107af178e6b81fc8d69fb05909f91d11f2f`。1074 本身 11.0 秒构建、24,081,844 bytes、SHA256 `6e785f7d70dbb6efb15af06cc001c99f9a98fee9ef1c152350af9eec50071753`。均经明确 Profile IPA 和保数据 wrapper 实际运行。
- 中间正常入口 1075 Debug 22.6 秒、Profile 36.1 秒构建且验签；因其后补充原生电量队列修复，不作为最终恢复包。此前 1071 同理，均保留为历史产物，不作为新构建失败的回退。最终正常入口改为包含全部修复的 1077，实际结果后续补录。

## 最终功能与产物验证

- 1076 完整实机测试在前台运行 102 秒，wrapper 退出码 0，`All tests passed`，14 个阶段检查、issues 为空。原账号与 R7 Ultra 目标保持一致，真实 CoolWear 握手、电量新时间戳、紧接着的两次手动同步、正步数入库/活动详情、睡眠概览与空状态、三轮断开/页面重连全部通过。通过报告另存 `live-report-1076-passed-private.json`，测试截图和原始 SDK 日志仅保存在忽略的私有目录。
- 两次手动同步都实际更新当前活动、显示“活动数据已更新，历史记录尚未确认”，第二次不再报设备忙。历史指标列表仍为空，`manualSyncConfirmedComplete=false`；该结果不是完整历史传输验收。测试显式要求未确认时不得显示“暂无新增数据”，没有把 `current` 改成 `complete`。
- 没有本枚戒指的有效睡眠样本，概览保留未知与佩戴后同步提示；原用户确认昨晚未佩戴。本轮只验收睡眠无样本行为，不宣称夜间采集、睡眠分期算法、远距离断线、蓝牙开关、强杀恢复或长期后台同步通过。
- 补充日活动汇总回归保护：`health_source_policy.dart` 在挑选每天累积记录前先调用同一去重规则，防止 ID 排序提前丢掉同时间戳较大的真实累积值。新增测试同时覆盖 QRing v3 / CoolWear v2 与正反返回顺序，定向 10/10 通过；这是合成增长场景，不把用户走路前后精确增加 50–100 步写成已测量。
- 上述最终共享 Dart 改动后，`flutter analyze --no-pub` 再查零问题；UTC 全量 1251/1251、上海时区全量 1251/1251 通过。1076 的全流程真机运行包含最终原生队列/场景修复；最后的日汇总选择顺序另由定向/双时区回归与最终正常入口检查覆盖，不冒称此前测试二进制包含之后的 Dart 改动。
- 中间正常 main Debug 1077 构建 22.3 秒成功；在补充日汇总回归后，交付入口进一步改为 **1079**，1077 不作为最终恢复包。1079 Debug Xcode 20.4 秒，连同冻结核验 42.4 秒；IPA 57,933,697 bytes，SHA256 `0c1482b025d21052dee3da97dc4bbea53e58cfa05d2de7d5f6b5895b7c69030b`。Profile Xcode 46.0 秒、连同冻结核验 57.4 秒；IPA 23,831,129 bytes，SHA256 `1231efef2d799de85e902eab21a61402f38aff8cf0e70f317158d7b4fcabfd2e`。
- 两个 1079 均明确 `--target=lib/main.dart`、1.0.1 (1079)、cn.saydian.ring、W7SXQ4A226，严格深验签、调试资格与当前设备 profile eligibility 通过；脚本在构建或核验失败时立即退出，不回退旧 IPA。最终安装、Debug 附加与 Git 回读结果待实际完成后补录。
- 最终共享源码再构建 Android 1079：Debug 12.0 秒，QA Release 62.9 秒成功；仍使用显式 QA 模式、同 no-push 配置、正式 main 与两 ARM ABI。QA Release 的 cn.saydian.ring / 1.0.1 (1079)、v2 签名、16 KiB zipalign 通过。Debug 158,813,473 bytes，SHA256 `8d0784d57f761c6cbb66f40610c08405af465a7e1691d26fae5ddbba015f7bc0`；QA Release 69,816,367 bytes，SHA256 `0358fc5c017d8ced52852fe73d12c2a8cb51086b12ff154652b0688e73eda5bf`。相同明确 ARM 参数的原生单测最终再跑 6 秒，51 tests、0 failures/errors/skips。未安装或发布这些 Android QA 包。

## 正常 App 恢复与交付边界

- 已通过 `flutter run --debug --no-pub --target=lib/main.dart -d <真机> --use-application-binary=.build/SayRing-1.0.1-1079-main-debug.ipa --host-vmservice-port=53767 --dds-port=53768 --pid-file=<private> --vmservice-out-file=<private> --dart-define-from-file=config/ios-app-store-no-push.json` 原位安装并保持 Flutter/LLDB 附加。CoreDevice 安装列表实际回读 cn.saydian.ring / 1.0.1 / 1079。没有卸载、清登录、清绑定或切账号。
- 使用本轮实际 VM URI 的 WebSocket JSON-RPC 读取运行状态：仅一个 main isolate、一个 AppController，root library 为 `package:saydian_app/main.dart`、PauseEvent 为 Resume；isAuthenticated=true、isBooting=false、原 R7 已连接、SDK coolwear、能力 ready、wellnessOnly=true、原目标正步数存在、heartRate 展示 false。确认恢复的是正常入口，不是测试壳。原生设备页画面可见 R7 Ultra 已连接、电量可读；该截图不扩大为持续前台或长期后台证明。
- 实际发送 `r` 热重载，`Reloaded 0 libraries in 307ms (compile: 18 ms, reload: 0 ms, reassemble: 64 ms)`；没有随后改产品源码，0 libraries 为预期。日志未出现 Lost connection 或 Unhandled Exception。Debug 会话保留运行；Debug 的稳定性仅按附加调试器状态判断。
- 本机 VM URI 文件实际为 WebSocket 地址：第一次辅助 HTTP 探针因 ws scheme 失败，改写成 HTTP 后探针超时；改用真实 WebSocket JSON-RPC 后立即成功。该辅助工具失败不等同 App 崩溃。DevTools 本地入口从真实运行日志生成，Codex 打开请求返回 queued，不冒称已展示。含认证参数的 URI 不进入 Git。
- 本地忽略脚本 `.build/run-sayring-ios-debug.command` 已更新到明确 1079 正常 Debug IPA 与本轮私有日志路径。初始容器备份、各轮失败/成功报告、签名描述文件、健康截图和 SDK 原始日志均保持私有；Git 只包含源码、测试及去标识的记录。
- `git diff --check` 通过；交付前 fetch 确认远端 main 仍与本轮基线一致。按既有授权保持仓库 Public，将本轮源码/测试/记录提交并推送 SayRing main；最终提交与同步状态以 Git 回读为准。没有修改下载页、Android 正式包、App Store/TestFlight 现有构建或审核。
