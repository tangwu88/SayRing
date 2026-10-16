# QRing 路由、睡眠与健康监测设置

基线 main `6f53407318190660d8ffc1b027457648649423f9`，干净工作树，已 fetch / ff-only pull。用户 2026-10-16 新指令明确要求 R1/R2/R7C 与未匹配 R 前缀 QRing、首次最近睡眠、QRing 风格、原专用睡眠 AI 和监测频率。此前 iOS 活动/睡眠范围按本次指令窄幅扩展，仍过滤生理指标与设备评分、关闭通用 AI、手动生理测量、预警与风险。无发布/送审或下载页更改。

## 预期与问题

- P1 路由：旧 R7 子串把 R7C 路由到 LuckRing；R12/R18/R20 等漏判。按新优先前缀覆盖并保留其他已知通道；名称从不证明 SDK 能力，Harmony 缺 SDK 不回退。
- P2 睡眠：已有完整存储的最近睡眠查询，检查入口、设备切换与手动日期竞态；页面增加最近/指定日期提示，日期导航、总时长、阶段分布/时间轴、独立原 AI 报告。无样本不生成睡眠或评分。
- P1 设置：原有健康监测和频率能力被 iOS 产品门禁关闭；仅恢复实际设备返回的设置读写。写入必须串行、会话/设备守卫、读回一致，不把 ACK 当成设置成功。
- 视觉参考：QRing 商店页 https://apps.apple.com/us/app/qring/id6473672621 与 QRingStore 睡眠示例 https://qringstore.com/pages/app-info 。采用日期/总时长/分期结构，不复制商标、照片或示例评分。

## 实施与验证记录

本段随后逐轮追加实际命令、失败/修复、构建与真机证据。未执行项目不视为通过。

- 首轮静态检查修正 Dart 可选桥接接口显式转换和花括号；初始定向测试因新分布图窄屏大字体标签溢出失败，改为可换行文本后 111/111 通过。UTC 与上海全量各 1257/1257 通过；后增测试入口的一项冗余 import 已移除，静态分析零问题。
- Node 首次调用系统 PATH 无 node，改用已安装 Node 24.19 绝对路径。iOS 活动/睡眠策略和 CoolWear 集成 19/19 通过。QRing 原生名称 Foundation 夹具通过。
- 1081 Profile 测试入口构建/签名/资格通过，52.2 秒，24,092,506 bytes，SHA256 `5ae21141c32018f5cab6007fcf387cfb477836d9907a0ca9f82bb27d2c558245`。保数据 wrapper 实际启动后发现当前 owner-bound 目标已是 R21，旧 R7 Ultra 目标断言立即失败，未进入任何设置写入。没有重新选设备或更改绑定；改为本账号现有精确 QRing/LuckRing 目标测试 1083。辅助脚本替换首次因缩进匹配失败而停止，shell 意外重跑一次旧 1081 构建；不以其作为新验收。
- 数据备份：44 文件，32,578,931 bytes，仅保存在忽略/0700 目录。1081 前台检查是 Say Ring 自身页面，截图私有。
- Android 中间 1082 Debug 16.5 秒、QA Release 构建成功。后续 QRing 设置超时增加同连接代次隔离保护，最终产物改为 1084；中间包不作为最终交付。

- 1083 首次 drive 因上轮残留 iproxy 占用相同端口而 DDS 连接重置，未进入测试；停止该明确旧转发，改独立端口后实际连接成功。真实 QRing 握手、监测读取、页面打开和原开关读回恢复通过，但临时开关写入后读回仍为旧值，测试失败，不能作为设置通过。
- 核对 SDK 头文件和本地官方静态库的实际实现，发现 iOS 两参数 `setSchedualHeartRateStatus:interval:success:fail:` 内部调用完整接口并传入零报警阈值。修复为完整读取后原样保留两阈值和设备最小间隔，写入后再次完整读取校验全部字段。旧简化方法的 ACK 不再代表保存成功；此前那次失败尝试只采集了开关/间隔，没有原始报警阈值，不能声称其阈值已完整恢复。保留该限制，不凭猜测补默认阈值。
- 同时统一心率开关读取到同一完整配置接口，避免旧 getter 的状态不一致；超时隔离与迟到回调阻断补主线程同步完成。设备设置写入期间禁止并行刷新覆盖读回值。新测试包 1085、正常入口 1086 接续验证。

- 修复后静态分析零问题，UTC 与上海全量各 1257/1257；最后设置并发刷新用例定向 14/14，睡眠/报告/控制器组合 58/58。原生契约最终 37/37，实际 Foundation 策略 91 断言及 Swift 导入通过；Android 原生 51 tests、0 failures/errors，鸿蒙路由主机 20/20，发布校验 Python 35/35。主机检查不代替实物能力验收。
- 1085 Profile 53.5 秒，24,088,019 bytes，SHA256 `bc9f8337016dcad5906f2620d1fecca09499ed04038f40ca2ce2395604e09557`；两次测试因 App 进入后台、首帧 pump 20 秒超时而失败，尚未进入设置写入，不能声称 SDK 修复已实测。外部前台画面偶然捕获到其他应用后立即删除截图，仅保留“Say Ring 不在前台”的诊断，不读取或保存其内容。
- 中间 1084 正常 Debug 43.3 秒、Profile 95.3 秒均构建/验签；最终产品源码 1086 Debug 45.9 秒、57,937,745 bytes、SHA256 `ca239b27233efe013e7f91c6924971f40bf5fff5940de9f32660abbaf15b5048`，Profile 92.8 秒、23,837,105 bytes、SHA256 `eba9734fda55a260b394d49637d3a10414006b616cb33cb6baf16152e0278cfc`。均正式 main、cn.saydian.ring、1.0.1、W7SXQ4A226、严格深验签和设备资格通过，不使用旧包回退。
- 1086 正常 Debug 的 VM 初次快照因字符串默认截断而 JSON 解析失败，补 getObject 完整读取。调试器同步调用监测方法恰逢 Flutter 构建帧，引发 setState/ChangeNotifier 通知时机异常，Flutter 自身错误堆栈解析又不能处理 `AppController.Eval ()`；该辅助操作不作为产品通过证据，停止该调试会话，回到 Profile 正规测试。保存了中断前真实开关/间隔，用仅测试用显式参数在同一现有 owner-bound 目标恢复，绝不作为产品默认值。
- 1087 仅改测试驱动：先等待真实 resumed/framesEnabled 状态后启动初始化，移除会在后台错误超时的单帧 pump，仍由 7 分钟测试/9 分钟驱动总期限约束，不伪造生命周期。宿主在测试等待前台阶段仅激活一次 cn.saydian.ring。1087 Profile 54.4 秒、24,086,771 bytes、SHA256 `9bec7f3c9776e6e7fbd5db4574a3d8dbd13a0ccb3ca122c67a834b7d5d024270`，签名/设备资格通过。

- 1087 修正前台等待后，真实握手成功；恢复开关时完整读回仍不一致，未继续功能断言。1089 增加仅含设备配置的私有错误详情后确认，紧跟写入的读回是 SDK 全零默认值，与随后正常读取的非零配置矛盾。核对官方库实际实现：接收器允许延迟的写 ACK 直接结束读取；新 `interval:` 重载还序列化零保留/最小间隔字段。
- 最终原生改用头文件明确以分钟为单位的 `timeInterval:` 选择器，只写开关/间隔；每个同命令响应后留出清理间隔，最多三次完整读回，逐项核对实际开关/频率/设备最小间隔/两报警阈值。没有把全零回执当设备配置，也不重发未知状态的写入。1091 为中间构建，最终验证用 1093。
- **1093 真机通过**：Profile 34.4 秒、24,092,936 bytes、SHA256 `bb399beda155a60bb1939df64949edc8b61c016f4d4ce893efec9c4fa6e8acf8`。保数据 wrapper 退出 0，应用实际测试 29 秒，11 个阶段，`All tests passed`；既有 R21 / QRing 真实握手、健康监测入口、开关修改和新鲜完整读回、频率修改和新鲜完整读回、原开关/频率恢复均通过。只操作原有 owner-bound 精确目标，不解绑或按名称采用新目标。
- 睡眠实物页面确认首次显示已有的最近记录，并非今天空白；前一天选择后不会自动跳回，点击“最近一次”恢复最近记录。已有真实睡眠明细和 sleep AI 服务配置均存在。没有现场采集新的整夜样本，没有生成/上传第三方 AI 分析；报告生成继续要求专用已发布授权和用户明确确认。本轮不能宣称睡眠算法或 AI 供应商端到端验收。
- 1093 设置截图拍摄于刷新后的帧尚未绘制之时，显示读取中；成功和恢复判断依据为等待完成后的原生/控制器读回断言，不把该瞬时图当最终就绪状态。截图与报告仅保存在忽略的私有目录，Git 不包含实际健康值/账户标识/设备标识/调试认证 URL。
- 最终正常 iOS **1094**：Debug 42.5 秒、57,938,445 bytes、SHA256 `af3008085fe9cfd5e48f6018fb8d4d2dfe01fa82bc39218db58517e9ccb08ae2`；Profile 47.4 秒、23,837,142 bytes、SHA256 `d74b0ebb829eb5790ad56e39f0c72dce87e66ed9582657b77e8c202e94b7df7b`。正式 main、原 bundle/team、严格签名与设备资格均通过；最终与 1093 相同产品源码，差异仅为正常入口/构建号，未包含测试恢复参数。
- 最终 Android 1086（其后变化仅 iOS 原生与测试驱动）：Debug 32.0 秒、158,820,533 bytes、SHA256 `3b60a54638d41122ee76fbdefc3776c864f2cd528cfe9da544c8aac790755601`；QA Release 118.7 秒、69,832,751 bytes、SHA256 `f56438624f17095d9e226b0e9b409e214bae4d2fc311acc2f8da0f0af484b7be`。包名 cn.saydian.ring / 1.0.1 (1086)、签名与 16 KiB zipalign 均实际核验通过；不安装、不发布这些 QA 包。
- 工作跨至 2026-10-17，正在以已验签正常 1094 Debug 原位恢复并保留调试附加；仓库匿名 API 回读 Public / main。最终 Git 同步与运行状态以收尾核验补录为准。未修改下载页或提交 App Store/TestFlight。


## 可复现检查命令

```sh
flutter analyze --no-pub
TZ=UTC flutter test --no-pub --reporter expanded
TZ=Asia/Shanghai flutter test --no-pub --reporter expanded
node --test tool/test_qring_monitoring_integration.mjs tool/test_ios_activity_sleep_policy.mjs tool/test_qring_camera_integration.mjs tool/test_qring_reconnect_integration.mjs tool/test_coolwear_ios_integration.mjs tool/test_native_log_privacy.mjs tool/drive_ios_preserving_data.test.mjs
node --test harmony-native/tests/wearable.test.mjs
python3 -m unittest discover -s scripts/release -p 'test_*.py'
# android 目录，JAVA_HOME 指向 Java 17
./gradlew :app:testDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline --max-workers=1 --console=plain
# 真机必须先私有备份、独立构建/验签 Profile，设备 ID 仅在本机设置
FLUTTER_BIN=flutter node tool/drive_ios_preserving_data.mjs --profile --keep-app-running --no-pub -d "$SAYRING_DEVICE_UDID" --target=integration_test/ios_owned_ring_sleep_monitoring_test.dart --driver=test_driver/ios_sleep_monitoring.dart --use-application-binary=.build/SayRing-1.0.1-1093-integration-profile.ipa --host-vmservice-port=62767 --dds-port=62768 --dart-define-from-file=config/ios-app-store-no-push.json
```

构建始终显式 `--target=lib/main.dart`（测试包则为上述 integration target）、`--build-name=1.0.1`、对应构建号、`--no-pub` 和 `--dart-define-from-file=config/ios-app-store-no-push.json`；iOS Debug/Profile 串行，Android 双 ARM `--target-platform=android-arm,android-arm64`，QA Release 显式 `SAIDIAN_ALLOW_QA_RELEASE=true`。本机 Flutter/Node/Java/Ruby 使用已安装绝对路径；不在记录中放入账号、设备 UUID 或 VM 凭据。先前未采集报警阈值的限制仍保留，后续成功测试逐次完整读回确保本轮写入保留其当时值。

- 正常 1094 Debug 已原位恢复并附加 Flutter/LLDB；只读 WebSocket VM 核验一个 main isolate、一个 AppController、root 为 package:saydian_app/main.dart、Resume。已登录、启动完成、真实 QRing/R21 能力 ready，sleep AI 配置开启、通用 AI 仍隐藏、生理指标仍不展示。应用实际安装版本从 CoreDevice 回读；没有卸载、清登录/绑定或替换用户健康记录。调试会话继续保留。

- 正常 1094 的实际只读运行回读：authenticated=true、booting=false、qringConnected=true、capability=ready、sleepAiConfigured=true、generalAiHidden=true、physiologyShown=false。CoreDevice 安装列表回读 cn.saydian.ring / 1.0.1 (1094)。实际热重载 `Reloaded 0 libraries in 321ms`，无随后产品源码更改、无 Lost connection 或未处理异常。Git 本轮包含实现、回归与失败/修复记录，原始推送回执保存在本机忽略目录；交付以远端 fetch 回读一致为准。
