# HR01 健康监测与查找入口 1046 / 1047

## 原因与范围

- 基线 7a5fed0，本地和 origin 当前分支一致，改动前工作树干净。仅 Say Ring，固定 cn.saydian.ring，不改审核。原计划保留全部本机数据，但测试工具的默认清理违反了该约束；实际损失与恢复边界见下节，不能标记为数据保留验收通过。
- 1045 HR01 固件 758.2.1.9.0 实际 type 128 返回 onoff、hr24hOnoff、oxOnOff、time，功能位 hasHR24h/O2_auto_switch 已确认。iOS 未处理设置回包，没有实现读写，也未发布 health_monitoring 能力，导致入口隐藏。
- 原厂 YD_SyncAutoHeartCmd 头文件提供四字段写入，FuncType.h 确认 type 128；旧指南的手势回包编号不作为新 SDK 协议依据。原 SDK 和素材只读。
- 处理真实设置快照后才开放入口；定时心率、24 小时心率、自动血氧独立展示，后两项仍受真实功能位约束。睡眠自动识别，不伪造睡眠开关。
- 改一项保存另外三字节，time 单位未确认，不显示可修改间隔。读设置用 RequestAllInfo；写入 ACK 后重新读取，完整四字段一致才成功。
- 读写与测量、同步、电池互斥；连接代次/操作令牌/取消/超时丢弃旧回调。控制器禁用并发点击并拒绝换账号、换设备后的迟到保存。
- 新增 iOS-only 无心率预警返回 null，避免正常不支持项制造“部分项目读取失败”。Android原契约不变；共享 UI 增加真实存在才显示的 24 小时心率项目。

## 检查与实物验收

- `flutter analyze --no-pub` 初次为 2 条缺少花括号 info，已修正控制器与夹具，再跑零问题。Dart format、git diff --check 通过。
- `TMPDIR=/private/tmp TZ=UTC flutter test --no-pub` 和 Asia/Shanghai 各 1164 项通过；定向设置/账号/UI/桥接测试 99 项通过。新增真实 128 形状的映射、不支持项目、账号切换迟到保存、重复点击拒绝和三开关 UI 检查；均是合成输入，不能代替实物。
- `node --test tool/client_package_contract.test.mjs tool/measure_ios_bundle.test.mjs tool/test_coolwear_ios_integration.mjs tool/test_native_log_privacy.mjs` 30 项通过。Python release discover 31 项通过；Android `:app:testDebugUnitTest --max-workers=1` 40 项，失败/错误/跳过均 0。
- Foundation `clang -fobjc-arc -fblocks -framework Foundation` 对 CoolWear 策略和 `test/native/qring_record_mapping_test.m` 执行通过。第二次猜错 QRing 文件为 test/native_qring_mapping_test.m 编译失败，找到真实路径后通过；未删除失败记录。
- Android 双 ABI Debug 12.0 秒和内部 QA Release 54.6 秒/69.4 MB 构建通过，独立 APK 保存在忽略目录。两包均 cn.saydian.ring/1.0.0/1046，apksigner verify、zipalign -c -P 16 4 通过；未安装安卓，不声称安卓实物开关通过。

## 真机失败与修正过程

- 早期使用 `flutter drive --profile --no-pub --driver=test_driver/integration_test.dart --target=integration_test/ios_hr01_monitoring_test.dart --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY= -d <已注册 iPhone>`。测试入口不主动替换账号或健康记录，但工具默认清理会卸载整个 App，最终删除了本机容器；不得再次使用该命令。自动化入口不是最终生产 main 包。
- 首轮编译 95.5 秒，启动后实际入口和三个设置已读，但恢复检查失败，定时心率未恢复。立即保留失败日志并追加带确认回读的恢复重试；恢复运行实际确认定时心率回到原 true，另外两项原 false。临时测试恢复参数导致该轮反向断言失败，清理确认已完成；该参数已从最终测试源码移除，不成为设备默认值。
- 第三轮用实际 Switch 子组件及等待布局稳定验证点击，发现“刷新失败/戒指忙”，原始原因是设备页自动电量查询和设置刷新/保存互斥相撞。清理重试成功恢复三个原设置，不把此次测通单个指令当作完整开关验收。
- 修正：设置先保留唯一操作槽，已有电量查询结束后发送，后续电量/同步/测量不抢占；250ms 延迟检查只在当前连接和操作代次有效时继续，总超时读 18 秒/写 28 秒，取消会失效。仍不与主动同步或测量并发。增加队列/代次/有界等待契约，重跑实物验收。
- 一次 apply_patch 因上下文不匹配失败，缩小匹配范围后正确应用；一次 Android XML 位置查询失败，改查 build/app/test-results 后汇总确认 40/0/0/0。不把失败检查写成通过。
- 排队版实物测试三个开关均能切换，心率两项均已恢复；自动血氧恢复曾发生回读超时，清理过程最后的 SDK 原始状态已为原 false，但控制器最终仍显示 true，因此该轮失败，不记为整体通过。没有隐藏错误或宣称设备睡眠已解决。
- 继续收紧读取完成屏障：有效 type 128 与 RequestAllInfo 完成回调两者俱全才结束，任一缺失不释放成功。读和幂等四字节写各允许原 SDK 一次重试；包含电量等待的总超时读 28 秒、写 48 秒，仍有代次取消和严格回读，不反复无界发送。测试等待相应扩为 55 秒、总测试限制 8 分钟。
- 排队修正后再次全量 UTC 1164 项/100秒、Asia/Shanghai 1164 项/72秒通过，最终屏障版 Node 30 项和 Analyzer 零问题通过。Android与共享 Dart 生产源码没有再变更，APK来自同一共享实现。
- 最终实物、签名 main 包和安装结果待下节填写。私有日志、照片、账号、精确 UUID、健康值和 VM URI 仅在忽略目录。

## 两端超时与构建纠正

- 屏障版暴露 Dart 通用 30 秒超时早于原生 48 秒排队上限，抛出的 TimeoutException 未被设置控制器按 PlatformException 处理。该轮 38 秒失败，不能标为完成。
- iOS 设置写入等待 55 秒、读取 35 秒，其他方法和 Android 既有时限不变；所有真实命令超时统一转换为可处理的 COOLWEAR_OPERATION_TIMEOUT。新增假时钟回归：31秒仍等待，55秒后明确错误，迟到成功不能改变结果；4项定向测试通过。
- 添加 TimeoutException 处理时漏加 dart:async，第一次真机构建失败；补 import 后 Analyzer 零问题。Flutter drive 在失败后启动旧产物的回退行为被发现并立即中止，不把旧产物的启动算作新代码通过。
- 后续使用 `flutter build ios --profile --no-pub --target=integration_test/ios_hr01_monitoring_test.dart --build-name=1.0.0 --build-number=1046 <同生产配置与恢复测试参数>` 成功后，才 `flutter drive --profile --no-build --no-pub ...`；测试构建 60.0 秒、60.5 MB 成功。最终生产 main 不含恢复测试参数。
- 超时修正后 UTC 完整测试 1165 项/73秒通过，Asia/Shanghai 结果及最终实物按下节记录。编译过程中未清理共享缓存或并发 iOS 构建。

## 严重事件：默认 drive 卸载与恢复边界

- 实际发现手机 App 列表没有 Say Ring，启动返回 OSStatus -10814。核实安装的 Flutter 源码：默认 drive 清理不仅 stop，还调用 uninstallApp，失败也执行；本轮前几次测试触发了该清理，违反用户要求的保留数据约束。已明确告知用户并道歉，停止默认 drive。
- 未找到卸载前 SQLCipher 数据库、App 容器或 Finder MobileSync 备份。Keychain 中当前会话与精确绑定仍在；重新安装正常 main 1046 后账号会话存在，HR01 自动连接，云端健康摘要重新读取。旧本机独有睡眠时间轴不能确认恢复。服务端数据未被测试清理删除，不从摘要伪造丢失分段。
- 后续私有备份使用 devicectl appDataContainer 分别复制 Library / Documents，约 10MB，均在忽略目录。最初 source '.' 路径错误后改为明确目录成功。这是事件后的备份，不是卸载前恢复证据，也未完成 SQLCipher 恢复测试。
- 新增 tool/drive_ios_preserving_data.mjs：强制 --keep-app-running，要求明确已签名编译成功的 --use-application-binary，拒绝卸载参数。两项工具测试通过，AGENTS 加硬约束；正常 main 最终重新覆盖安装，绝不卸载。
- 1046 正常生产入口 Debug 23.8 秒、签名 Profile 53.2 秒/59.9MB，包名、构建号、iPhone-only、团队与 codesign 验证通过。实际安装并启动，读取到 HR01 已连接、固件与电量、健康监测能力。HR01 精确睡眠记录仍为 0，不能声称睡眠实物已解决。
- 1046 安全测试先独立 Profile 编译 32.1 秒/60.5MB，再通过保护工具运行。不把此前错误使用 --no-build 的二次编译或旧包回退当成新代码验收。测试等待真实应用壳；此前 No element 和蓝牙许可提示导致的失败保留，不算通过。
- 最新安全运行能读取三个真实开关，并切换心率/24小时心率；恢复保存仍出现“健康监测设置未确认，请刷新”，即便下一次刷新读到原值，也不能把保存链路判为稳定通过。最终结果继续记录，不掩盖错误。

## 1047 查找设备入口

- 用户将右侧“查看设备”更正为“查找设备”：健康监测 AppBar 复用现有 DeviceFeaturePage/findWatch，不另建详情页、不自动扫描或替换绑定。
- 入口随真实能力变化；断开、功能未接通或忙时禁用。普通权限页不显示；按 SDK 与 integratedFeatures 判断，不按 HR01 名称强开。CoolWear 原包提供 YD_SyncFindDevCmd/onoff，但目前 iOS 桥接未验通、真实 HR01 能力没有提供查找标志，维持禁用，不将通用原厂示例当成本枚戒指实测通过。
- 新 UI 测试首次漏传 DeviceCapabilities 必需 metrics，编译失败；补空集合后三项定向测试通过，覆盖不支持禁用、已确认支持跳转、断开失效、权限页无入口。原始日志私有保存。

## 最终本轮验证与未验边界

- 1047 Analyzer 零问题；UTC 全量 Flutter 1167 项/97秒、Asia/Shanghai 1167 项/67秒通过。Node 合同与防卸载工具共 32 项、Python release 31 项、Android 原生 40/0/0/0，以及双 SDK Foundation 合成测试通过；不代替物理查找提醒。
- 1046 保护工具测试 7分42秒结束，值切换和回读原值的断言通过；但三项恢复都产生保存未确认错误，该测试没有在刷新前断言保存结果，因此不得记为无错误验收。已加强测试：刷新之前必须明确“设置已写入戒指”，后续真实验证不能靠刷新覆盖超时；强化版本轮尚未再跑。
- 测试结束 devicectl App 列表确认 1046 仍存在。再次私有备份当前 Library/Documents 后覆盖安装正常 main 1047，安装成功，未卸载。这不能恢复之前丢失的本机独有睡眠明细。
- 1047 iOS Debug 无签名构建 59.3 秒；Profile 签名构建 55.9 秒/59.9MB。包名 cn.saydian.ring、1047、UIDeviceFamily[1]、团队与设备包含/开发调试权限核对通过，codesign deep/strict 验证通过，App 与 dSYM UUID 一致。
- 产物复制最初猜错 dSYM 在 iphoneos 目录失败，找到 Profile-iphoneos 后正确保存并核对。构建尚未完成时先验签读到旧 unsigned Debug，报未签名；等待最终签名包成功后才安装，不拿前次失败当成验签通过。
- Flutter run 首次误加 build-name/build-number，CLI 返回 64，未启动；改用明确已验签 binary，不含 run 不支持的参数。首次 VM 读取发生在安装启动尚未完成，No VM service；后续启动结果继续记录，不把安装成功等同于持续调试通过。
- 本轮文档一次跨文件 apply_patch 上下文不匹配失败，拆分精确补丁成功。私有材料不提交。现有 App Store 审核、其他两款 App、服务端和健康数值未改。
- 1047 Android Debug 22.8 秒、内部 QA Release 75.7 秒/69.4MB，双包 apksigner verify 与 zipalign 16KB 检查通过，包名/版本 1047 符合；本轮未安装安卓。iOS 正常 Profile 显式 binary 启动 14.5 秒完成，实际 App 列表确认 1047，VM 只读确认当前会话仍在、HR01 自动完成连接/能力/电量/固件读取；当前 HR01 没有精确睡眠记录。
- 1047 查找入口的支持/断开门控和跳转已由 Widget 测试覆盖，正常 main 真机启动并显示健康首页；未对 QRing 做物理响铃/振动验证，HR01 查找未接通，保持禁用。不把新按钮构建、值切换测试或完整测试数量当成所有型号实物功能通过。
- 本轮更新为待完成的验证实现，不提升 origin/main 为验收基线。仍需解决监测保存确认超时、HR01 查找协议/实物提醒和真实睡眠样本。仅本机历史损失仍未确认可恢复；不能因此删去事故或伪造数据。
