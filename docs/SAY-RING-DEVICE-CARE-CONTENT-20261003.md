# Say Ring 设备能力、同步、充电与关爱改进

## 基线与范围

- 2026-10-03：干净工作树，已 fetch origin，当前分支与远端为 92145b6448dd497c964e5fdb5f7ff72d15c6c114；origin/main 为 c31d618。只修改 Say Ring，iOS 优先，共享 Flutter/Android 回归，保留 cn.saydian.ring、现有数据与 App Store 审核。
- 修改原因：CoolWear iOS 缺分项历史读取；电池详情仅缓存、未知充电状态误报；首页/趋势部分测量入口未统一能力判断；中文百科语言标记错误；关爱记录界面与本人健康界面不一致。
- 修改范围：双端戒指桥接、域能力/电池/同步模型、App 控制器、百科分页、只读关爱健康展示与提示语。服务端百科语言编辑/中文发布由已获用户授权的服务端任务独立实施、验收。
- 原始 SDK 包和 Framework 保持只读；原厂示例资料不作为真实用户资料。完整数据流与能力支持分别验收，缺实物或样本标待验。

## 验证记录

- 结构：设备能力与分项同步、电池刷新、百科分页、远程只读看板；本机门禁、发布及真实设备证据分别记录，不混称通过。
- 当前 Mac 可用空间约 1.5 GiB；仅旧预构建 Profile 调试会话，无活动 xcodebuild。构建前再次检查空间与进程，按确认路径清理可重建中间产物，保留包、签名和日志。

## 本轮实现

- 能力：域模型增加可选 historyMetrics；忽略未知指标编码。首页、趋势与详情测量入口统一检查当前设备能力，无当前支持也无历史数据时隐藏；远程数据不受查看者戒指能力约束。
- CoolWear iOS：核对原始 DOCX、公开头文件和示例，按 5/6/8/40/47/61 拆分活动、睡眠、心率、血氧、皮肤温度和新 RRI-HRV；保留真实毫秒字段，不解释旧 heartNum。连接后仅同步实际时钟并打开传感器，不写示例年龄、身高或目标。
- 历史：按各类型 curItemCount/remainItemCount 去重、乱序归并、校验；25 秒有界采集后返回 records/statuses，type 9 和时钟 ACK 不作为完成信号。末包先到不提前结束；缺包保留有效记录，分项未知不宣称完整成功。不执行清空命令。
- iOS 距离/热量单位未在所供指南明确，暂只映射步数。睡眠只采用 START→WAKEUP 闭合且有真实时间戳的深/浅睡区间汇总；未闭合、冲突、未知阶段不补成睡眠。SDK 归属日期、REM/小睡和完整时间轴仍待真实协议样本核实，未宣称接通。
- 电池：双端真实查询、充电确认时间；超过 60 秒或断开显示未知，电量保留原更新时间。设备页前台 15 秒检查、前台恢复/重连刷新；与同步、测量合并排队，账号和设备代际拒绝迟到回调。Android null 不转成未充电，iOS 状态仅接受实际整数 0/1。
- 百科：分类失败不阻断成功文章；列表分页、刷新、重试及按 ID 去重。后台语言/中文复制由服务端独立发布，不跨环境兜底。
- 关爱：拆分我关注的/关注我的，独立只读数据源复用健康卡片、日周月趋势与日期选择；不写本人缓存。关系/权限减少、账号切换和过期清空视图并拒绝迟到响应；详情和记录弹层也受权限校验。远程睡眠仅展示真实云汇总，不构造时间轴或开启本人 AI/测量。
- 提示：无新增数据正常结束；真实部分缺包保留简短提示。其他设备数据仍拒绝并提示，不以“暂无新增”掩盖隔离错误。普通设备/关爱/报告提示精简，授权、上传范围和健康提醒保留。

## 测试与修复记录

- 初轮 analyze 发现桥接返回格式误改到扫描和测试替身参数遗漏；均修正，扫描保持 DeviceInfo，分项结果仅用于 syncHealthData。
- 首轮默认时区全量 1129 通过、3 失败：旧 UI 文案/不支持睡眠卡断言与新行为不符；修正断言。明确 UTC 首轮 1133 通过、1 失败：其他戒指超时记录被误归为空数据；恢复显式拒绝并保留账号/设备隔离断言，不弱化门禁。
- 定向回归 154 项通过。最终 `TZ=UTC TMPDIR=/private/tmp flutter test --no-pub --reporter expanded` 和 `TZ=Asia/Shanghai ...` 各 1134/1134 通过，日志 `.build/device-care-1036-flutter-UTC-final.log`、`...-Shanghai.log`。
- `node --test tool/test_coolwear_ios_integration.mjs tool/test_native_log_privacy.mjs` 21/21；Foundation CoolWear 策略、历史批次/闭合睡眠/电池边界测试 PASS；QRing Foundation mapping PASS。均为本机合成/契约测试，不能替代固件验收。
- 收尾复查再次修正乱序末包提前完成风险，并添加源契约断言；DataType 改为严格整数。Native Node 21/21、Foundation 再次 PASS；Flutter 源码未变。
- iOS Debug 1036 串行构建，收尾修正后 12.7 秒成功；codesign deep/strict 成功，包名 cn.saydian.ring、构建号 1036、UIDeviceFamily=[1]。留存 `.build/SayRing-1.0-1036-Debug-final.app`，不把 Debug 独立启动当稳定性验收。Profile、Android 与安装结果继续追加。
- 清理仅本仓库已结束的 Android/iOS 中间文件与已核对 WorkspacePath 的 ModuleCache；保留原 SDK、签名、归档、安装包和数据。删除的缓存可重新构建，不删除源文件或设备数据。

## 真实验收边界

- iPhone 15 Pro Max 已被 devicectl 识别连接；镜像显示“因连接期间 iPhone 被使用，iPhone 镜像超时”，因此当前不能声称逐页操作通过，不自动锁定用户手机。
- 未完成本轮真实插电/拔电、三轮物理距离恢复、各厂商/型号逐项同步对比、两账号撤权 UI 检查；无对应实物和真实样本的项目保持待验。
- 保留现有 App Store 审核，不上传或替换审核构建；仅提交本分支实现和验证结果，完整实物验收前不把此轮视为已验收主线。

## 1036 构建与覆盖安装回读

- `flutter analyze --no-pub` 零问题；`dart format --output=none --set-exit-if-changed lib test` 通过。`python3 -m unittest discover -s scripts/release -p 'test_*.py'` 31/31；bash -n、shellcheck、actionlint 均退出 0。发布测试的负向样例不会实际发布。
- Profile 1036 64.7 秒成功（66.2 MB），与 Debug 同一 Flutter/原生源码和生产 API 配置，JPUSH_APP_KEY 为空。开发签名 W7SXQ4A226/get-task-allow=true，Associated Domains 保留 app.saydian.cn，UIDeviceFamily=[1]；并未将 App Store 分发包当调试包。
- Profile 留存 `.build/1036-profile/Payload/Runner.app`，IPA `.build/SayRing-1.0-1036-Profile-debug.ipa`；SHA-256 `4adfe0c929de022c62e177790ad9257c1ae8e73594a2463955b5ad96b563a34b`，ZIP 完整性校验通过。停掉此前仅本任务的 1035 Flutter 会话后，用 `flutter run --profile --no-pub --use-application-binary=... -d <已核对 iPhone>` 覆盖启动，不卸载。
- devicectl 与 Xcode 安装清单确认 Say Ring / cn.saydian.ring / 1036；只读 getVM 返回 VM 和 1 个 main isolate。Xcode 真机截图确认进入我的页，原账号登录、原健康记录和设备在线状态仍在。私人截图/日志只留本机，不进入 Git。
- Android Debug 1036（arm64-v8a、armeabi-v7a）93.6 秒构建成功；aapt 包名/构建号正确，apksigner verify 成功（v2）。APK 留存 `.build/SayRing-1.0-1036-android-debug.apk`。内部 QA Release 和原生测试后续追加；当前 ADB 无设备，不标记 Android 安装通过。
- 磁盘构建期间降到 141 MiB；先留存本轮输出，确认无活动编译后仅清理本仓库 app/intermediates 和 iOS Profile 中间文件及对应 DerivedData Build/Intermediates.noindex，恢复约 1.5 GiB。开发 Profile 调试会话使用预构建包，不并发编译或清理未结束的产物。

## 收尾睡眠边界修正与 1037

- 发现原生分批睡眠可能过早发布阶段汇总、同一结束时间的修订会生成第二条 ID。睡眠改为等待 25 秒窗口和完整有效批次，非法时间/阶段值保持 partial；稳定 ID 以设备、指标、结束时间和来源组成，修订更新原记录。只有已闭合的深/浅睡汇总可保存；不据缺包估算睡眠。
- syncSnapshot 保留实际观察到的异常批次状态，即使它不能开启设备能力，也不得消失或伪报全部完成。其余指标继续保留校验过的有效超时记录。
- 收尾仅 iOS 原生和契约测试变更，Flutter/Android 源码与双时区 1134 项通过的快照一致。Node 最终 21/21、Foundation PASS；iPhone 验证包增为 1037，Android 对应未改变的共享源码仍为 1036。
- 1037 Debug 首轮因 NSCocoaErrorDomain 640 / errno 28 磁盘耗尽失败，日志完整保留；不是 SDK 编译错误。无活动编译时清理本项目 .dart_tool/flutter_build、hooks_runner 和 build/test_cache 等可重建内容后重试，Debug 54.8 秒成功。Profile 首轮 95.5 秒成功，最后的异常批次状态修正后串行增量重建，最终包/安装结果另追加。
- 为避免空间耗尽，本轮 1036 两份 Debug、此前 1030 Debug 和 1037 初轮 Debug 的 .app 先压缩为同名 .app.zip（1036 首轮名为 Debug-initial），unzip -t 成功后移除未压缩副本内文件；内容和签名可由 ZIP 还原，未丢弃安装包。原始素材/SDK/签名配置不变。
- Android QA Release 1036 114.4 秒成功，aapt 确认包名/版本及两种 ARM ABI；apksigner v2 和 16 KiB ZIP 对齐均通过，仅内部 QA 签名，不是正式商店包。Debug SHA-256 `0d30b305e2b4d01b279c12736f56d9efbc7df9a63703a3d233648eb0573f4a4d`；QA Release `262910e626ec282e2a637786420532f850fb43c477607a9e09d5de684de6ad7c`。
- `JAVA_HOME=...temurin-17 ANDROID_HOME=.../Android/sdk ./android/gradlew :app:testDebugUnitTest -p android --max-workers=1` 38 秒通过，8 份 XML 合计 39 项，失败/错误/跳过均为 0；日志和报告保留。
- 用户最新要求：先优化 iOS，Android 排后；已执行的 Android 回归保留，之后停止 Android 工作。
- 最终 Debug Xcode 编译/签名 49.2 秒通过，但 Flutter rsync 复制 kernel_blob.bin 时再次 errno 28 失败，保留失败日志；已安装 Profile 不受影响。确认无 xcodebuild/clang/swift-frontend 后清理已核对的 Xcode 全局 ModuleCache.noindex（651 MiB、仅可重建 PCM 模块缓存，不含源码/SDK/签名），再重试完整 Flutter 构建。
- 仓库当前公开；遵照用户此前“先不用管仓库状态，正常推送代码，最后我会改变”的明确指示，仅推送无私人数据的本分支变更，不改仓库可见性或其他发布设置。
- ModuleCache 清理尝试期间路径发生变化、返回目录不存在；后续空间回收至 934 MiB。最终完整 Debug 重试 17.6 秒成功、deep/strict 验签通过，留存 `.build/SayRing-1.0-1037-Debug-final.app.zip`，ZIP 完整性通过；此前失败日志未覆盖。
- 最终 Profile 增量 14.0 秒成功、deep/strict 签名通过，cn.saydian.ring / 1037 / UIDeviceFamily=[1]。`.build/SayRing-1.0-1037-Profile-debug.ipa` SHA-256 `005c9f35cd541c2af35cd4fecca8a891fda2912183b086f6aad12126fd15468e`；ZIP 完整性通过，25.7 秒原位安装启动，清单确认 1037，getVM 返回 VM、1 个 isolate，调试保持连接。未卸载或清除数据。
- 服务端 PR #21 已合入 53a2bde；原始内容备份和发布演练通过。自动发布 37132383753 的镜像传输仅校验 2/44 分片，线上 /global/health/ready 仍为 36197ef、zh-CN 文章仍为 0；实际中文发布与 App 回读不标通过，服务端继续原任务处理，未另启并行部署。
