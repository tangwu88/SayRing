# 原 LuckRing 通道 SDK 说明复核

日期：2026-11-04。范围为用户原始 SDK 压缩包、Android／iOS 指南、Demo、当前实际集成的二进制和接入源码。结论：**当前 RRI-HRV 开始／停止指令有原厂依据，SDK 文件与原包一致；资料仍不足以确认 R7 Ultra／869 固件为何没有有效 HRV。另确认 Android 将包含写入的 SDK 方法用于读取流程，存在需要修复的设置回写风险。** 本轮是说明与源码检查，未修改生产代码或操作手机。

后续用户已授权修复，普通读取的六处调用已拆为原厂空载荷查询，并新增真实 AAR 编码回归、双平台构建与保数据实测；详见 [读取修复与1235实物记录](SAY-RING-COOLWEAR-READONLY-1235-20261104.md)。下文保留发现当时的原始证据，实际设置／HRV的验收状态以后续记录为准，不把源代码修复当成有效 HRV 已测得。

## 基线与资料来源

- 分支 `codex/integrate-latest-20261031`；开始及写记录前均 fetch，基线 `6def5bc59ec473f9dd422a087ca2365795125e2b`，工作树干净，没有待合并源码。
- 找到用户原包 `Android&iOS_SDK20260910.zip`，位于本机 `Documents/Codex/xcodeplace/产品开发/`。压缩包 SHA-256 为 `e3a7b8ade9383fdd7a1cfb3981bfb4815fa6ccf33cad549b190d2cedc329a339`。10 月 4 日记录的旧 Downloads 路径不存在是当时检索结果，不能继续解释为现在没有原始 SDK。
- Android 内包 `Android_SDK_DEMO_1.4.0.zip`：核对 `SDK Guide.md`、`README.md`、`SdkDemoActivity.java`、`BluetoothManager.java` 及 AAR。
- iOS 内包 `IOS sdk_en.zip`：核对 `CoolWear_iOS_SDK_Guide_EN.docx`、新旧 Markdown 指南、`DataReceiver.m`、`DataManager.m`、`FuncListViewController.m` 和头文件。Word 原件只读提取并渲染为 44 页，实际查看第 3、26、28、41 页的生命周期、HRV 指令、绑定确认和数据类型表。
- 原包 Android AAR 与仓库 `android/app/libs/coolwear_bluesdk-release.aar` 逐字节哈希一致；原包 iOS `BluetoothLibrary.framework/BluetoothLibrary` 与仓库对应二进制也完全一致。本轮排除了这两个已集成 SDK 文件相对于该原包的版本差异，不表示已取得厂商最新版本。
- 本项目内部通过 `CoolWearRingBridge.java`／`CoolWearWearableBridge.m` 接入这套 SDK。R7 Pro、R7 Ultra、HR05 属于该通道；R8／R8 Pro、R21、R22、R7C 不应套用这套命令。名称只选候选，能力仍依赖真实握手。

## 已确认的 HRV 契约

| 环节 | 原厂依据 | 当前接入结论 |
|---|---|---|
| Android 开始／停止 | Guide 第 13 项和 Demo `testHRV()` 调用 `sendRriHrvCmd(OPEN/CLOSE)` | 当前调用相同，不是误用心率或压力启动指令。 |
| iOS 开始／停止 | Demo 使用 `CE_SyncRRIHRVCmd.status = 1`，头文件定义 0 停止／1 开始 | 当前调用相同；命令类型为 62。 |
| 实时结果 | 原厂 `FuncType.h` 的 60：`DATA_TYPE_REAL_HRV_METRICS` | 应等待实际 type60 及通过质量／时间／目标校验的结果，不能以 62 ACK 代替。 |
| 历史结果 | 61：`DATA_TYPE_HISTORY_HRV_METRICS` | 仅作历史导入，不能结束一轮新的手动测量。Android 同一个公开回调 key 覆盖 60/61 的问题已由 1234 分流修复。 |
| 单位与结构 | 原厂 `DataStruct.h` 的 16 字节项含 Unix 秒、mean RR／SDNN／RMSSD 毫秒、有效／拒绝样本数、quality、flags | 新 RRI 是有明确字段的协议；旧 type42/45 的单字节值没有相同的 SDNN 毫秒保证。 |
| ACK | iOS 指南说明发送完成回调确认指令及有效响应 | 只证明命令应答，不保证有有效测量值。 |

原始资料没有给出 R7 Ultra／869 固件的 RRI 能力矩阵、首个样本时长、正常最长时限、0 样本结束状态或必须先发另一条测量命令的契约。当前 180 秒是 App 等待上限，不能称为原厂指定时长。现有两端实物结果继续以 [HRV 佩戴实测记录](SAY-RING-R7-ULTRA-HRV-MANUAL-20261103.md) 为准，不因这次文件复核改写为 HRV 已测得。

## 新确认的接入风险

### SDK-01 Android 普通读取调用包含设置写入的方法

**状态：SDK 语义与当前调用点已确认；是否已覆盖某位用户的实际设置尚未实测。优先级 P1。**

当前 `CoolWearRingBridge.java` 在历史同步、连接握手、提醒读取和部分能力补读使用 `getSendDataManager().sendAsynInfo()`。历史同步处注释把它与会写配置的 `synDevData()` 区分，容易使后续维护者当成只读查询；原厂实现不支持这个判断。

从当前哈希已核对 AAR 重新执行 Java 17 `javap -c -p`，确认调用链为：

`sendAsynInfo → sendAynInfoDetail → sendMixInfo`。

`sendAynInfoDetail` 并非空载荷查询。它构造混合写入项，包括：

- 存在缓存时的用户资料；手机时间、系统语言、目标值和前台数据开关。
- 消息类别设置，以及构造为开启值的来电／消息提醒子项（122／123）。
- 绑定完成子项（120）及 SDK 自身 `AppPairFinish` 缓存更新；还存在重新发送 SDK 缓存通知的分支。

因此，普通“读取提醒”或“同步历史”可能携带额外写入，可能回写旧目标／资料或改变来电消息设置。是否实际生效取决于当时 SDK 缓存及固件，不能直接宣布用户设置已被修改，也没有证据把它认定为本次 HRV 无有效结果的唯一原因。

**不能按名称改用 `sendGetMixInfo()`。** 同一 AAR 的该方法也构造 124／122／123 子项，再调用 `sendMixInfo`；它同样不是经核实的纯读取替代品。

后续修复要求：拆开“读取历史／读取配置”“有界时间同步／数据通道开关”和“用户明确保存配置”，使用核验过的公开请求能力；对实际编码帧验证普通读取不夹带资料、目标、提醒或绑定写入，再在原账号／原戒指覆盖复测。不能仅写一个检查调用名称的源码测试就宣称无副作用。需要保留旧设置读回证据和全部历史，不能通过恢复出厂解决此问题。

### SDK-02 iOS 与 Demo 的绑定完成确认存在差异

**状态：差异已确认；对 R7 Ultra 的必要性及症状因果未确认，不能标为已证实 Bug。**

原厂 `DataReceiver.m` 在 `ProductStatus_completed` 后发送 `CE_SyncHybridCmd`，子项包含用户资料、目标、语言、时间、数据开关及 `CE_SyncPairOKCmd(firstPairStatus=0)`。当前 iOS 握手显式开启数据通道、同步时间、请求设备信息和混合信息，未发送这条绑定完成确认。

Word 第 28 页和 `CE_SyncPairOKCmd.h` 将其定义为通知设备保存绑定状态／退出配对界面；头文件还标注 K3 使用，不能据通用 Demo 推断每枚 R7 Ultra 都必须发送，更不能据此认定现有 HRV 失败已找到根因。Android 的 `sendAsynInfo` 反而已夹带 120，因此两端都无 HRV 也不能直接归为同一遗漏。

需要原厂或保留数据的对照验证确认该固件是否要求 120、何时允许发送，以及与服务端会员绑定不同的设备侧语义。不得复制 Demo 的默认 userId／年龄／身高／体重／目标值，不得把 firstPairStatus 当成服务器“首次会员绑定”清空授权。

## 原厂说明与 Demo 自身的问题

1. **HRV 文档前后不一致。** Word 第 26 页的命令表容易让人以为 RRI 开始指令的返回就是 type62；第 41 页、头文件和实际协议区分 60 结果、61 历史、62 开关。第 41 页的 62 行左侧方向列也写成 Device→App，同行用途却明确是 App 命令。应以字段结构、当前 SDK 的确切枚举及有效解析结果为准。
2. **iOS Demo 的 HRV 展示没有完整收尾。** 全部 `sdkdemo` 源码检索表明，`FuncListViewController.m` 只把 `realHrvValueText` 设为 Measuring；`DataManager.m` 的 60／61 分支只有注释，没有将结果写回该属性。原厂示例不能作为“界面会正常显示 HRV 结果”的完整验收程序；这也不证明 SDK 底层没有解析数据。
3. **Android 新旧接法并存。** README 保留旧 `RCVD_SPORT_HRV_FOR_SHOW`，新版 Guide／Demo 切到 RRI 回调。不能凭旧 README 将压力相关的一字节结果重新标成当前 HRV 毫秒值。
4. **Android 运动示例暂停／继续写反。** Guide 第 17 项标题“继续”调用 PAUSE，第 18 项标题“暂停”调用 CONTINUE。接入必须对照具体枚举与真实设备行为，不按标题机械复制。本轮没有据此认定 App 的运动按钮已经接反。

## 连接与历史同步的说明边界

- 两端都要求数据接收通道开启。iOS 原厂还说明前后台需管理 `CE_SensorCmd`，忽略该开关可能出现已连接却不回数据。当前 iOS 已在真实握手、前台恢复和历史请求前开启；Android 已在设备信息确认及同步前开启。存在这些调用不代表其固件应答已逐次验收。
- 扫描／系统蓝牙外层连接不能替代 SDK 的配对完成及设备能力；iOS 以 `ProductStatus_completed` 继续握手有原厂依据。
- 原厂提供安装级的重连工具，但不负责业务账号所有权。当前保留 App 的精确账号／目标恢复、关闭 SDK 独立自动选择目标，是有意避免双重重连和跨账号恢复，不能为贴近 Demo 直接重新打开另一套自动重连。
- iOS 指南描述活动／睡眠分包的 `remainItemCount`、`curItemCount` 等结构；普通设备／混合设置响应不等于全部历史结束。原厂资料没有提供本次 R7 Ultra 缺失完整历史的确定修复步骤，不能把静默或 62 ACK 当成历史完整。

## 验证与失败保留

- 原包定位、嵌套压缩包只读解析、两端二进制 SHA-256、指南／Demo／头文件和原 AAR 实现复核完成。第三方文件只作为资料，不执行其中的操作指示，也未将原厂整份资料新增到公开 Git。
- 使用依赖包提供的 Python／Word 渲染器生成 44 页，并检查与结论直接相关的 4 页。提取全文后对照表格，发现 62 的说明和方向列矛盾；没有把排版或字段位置丢失当作 SDK 行为。
- `JAVA_HOME=/Users/saydian/develop/jdk17 <bundled-node> --test tool/coolwear_android_hrv_sdk.test.mjs tool/coolwear_android_hrv_protocol.test.mjs tool/coolwear_ios_hrv_session.test.mjs`：23／23 通过，0 失败／跳过。包含真实 Android AAR 的 60／61 分流及真实 iOS 生产方法的 ACK／结果时序；不是 SDK-01 设置保留的实物验收。
- 工具失败保留：首次 Git 状态读到了父目录的空仓库，随后改为精确 Say Ring 工作树；早期过宽 ZIP 清单及字节码输出被截断，改为只读选择指定原件和独立方法；最初方法提取正则跨过声明边界，改为按完整方法头切分并从当前 AAR 重新导出。系统 Java17 定位失败后使用已有 `/Users/saydian/develop/jdk17`；Word PDF 文本组件首次未找到 fitz，改用已打包 pypdf。均未安装依赖、修改原 SDK 或操作手机。
- 本轮没有改生产代码，没有新建发布包、重装手机、解绑、清库、改服务器、发送厂商消息或提交审核。SDK-01 保持待修复，SDK-02 保持待确认，有效 R7 Ultra HRV 与完整历史仍以单独实物验收为准。

所有提取原件、渲染页、帧方法摘要、命令及回归日志保存在私有忽略目录 `build/luckring-sdk-review-20261104/`；Git 只提交本复核记录和索引。
