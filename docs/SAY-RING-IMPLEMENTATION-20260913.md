# Say Ring 独立产品、戒指路由与阶段一验证

## 范围与边界

- 时间：2026-09-13（UTC+08:00）。
- 起始历史：国际版已核实基线 `9530387`；商城增强迁移提交 `4a97c61`。
- 开发副本：`F:\xcodeplace\国内电商\say-ring-work`；最终英文路径为 `F:\xcodeplace\say-ring`。
- 目标仓库：`https://github.com/tangwu88/SayRing.git`。检查时为空且为 Public；在网页明确改成 Private 并回读确认前，不推送 SDK 或源码。
- 原国际 App 和服务端脏工作区均保持原样。本记录中的自动测试不代表任一真实戒指、iPhone、HarmonyOS 真机、签名、推送、支付或上架验收。

## 已实施

1. 产品身份隔离：名称 `Say Ring`；Android/iOS `cn.saydian.ring`；HarmonyOS `cn.saydian.ring.hm`；本地存储命名空间加入 `say-ring`；更新清单增加 `product=say-ring`。
2. 首次启动仍使用国际版固定英文策略，保留英文、简体中文、繁体中文、德文、法文、西班牙文、日文、韩文资源。
3. Flutter 共用戒指路由：去除首尾空白并忽略大小写，`YC → Yucheng`、`V/TK → VEP`、`D → Moyoung`；未知设备不默认交给 VEP。扫描、连接、保存恢复和实时事件使用同一分类规则。
4. HarmonyOS 同步使用相同前缀规则，移除旧 W8/W9 型号白名单；扫描列表保持首次发现顺序，RSSI 更新不移动可点击行。
5. 当前没有合格魔样戒指 SDK：D 前缀可分类，但不进入可连接列表；提供的仓库是眼镜示例，不能作为戒指健康或 HarmonyOS 接入证据。
6. HarmonyOS 普通请求和报告二进制下载改为 `/global/api/saydian-app/v2`，仍限定 `https://app.saydian.cn`、禁止自动重定向，并保持报告 UUID 精确路径及 20 MiB 上限。
7. 玉成健康和运动记录 ID 加入规范化设备 ID 的 SHA-256 短摘要；同一设备重读保持幂等，两台设备同秒记录不再互相覆盖，ID 不直接暴露硬件地址。

## 修改与测试流水

### 03:40 商城增强迁移

- 原因：保留国际 App 当前未提交的商城/H5 对齐工作，不覆盖原工作区。
- 结果：迁入独立副本并提交 `4a97c61 feat: migrate global commerce parity`；27 项商城定向测试通过。
- 失败记录：首次迁移受 Git `safe.directory` 归属检查阻止；改用明确仓库级安全参数后完成。未修改全局 Git 安全范围。

### 03:53 Flutter 产品身份与戒指路由

- 文件/范围：`lib/services/wearable_routing.dart`、`wearable_bootstrap.dart`、`global_environment.dart`、更新服务、三端包配置、八语 ARB 与对应测试。
- 结果：先完成路由 28 项；扩大到身份、更新、存储、语言共 139 项，全部通过。
- 失败记录：沙箱内两次 `flutter pub get --offline`/`dart format` 无输出挂起，已终止；经授权在标准 Flutter 运行环境执行测试。中文路径运行 `flutter analyze --no-pub` 时分析器 LSP JSON 截断并报 `FormatException: Unexpected end of input`，属于工具/路径失败，不能记作静态分析通过；将在英文最终路径重跑。

### 04:05 HarmonyOS 国际路径与戒指路由

- 文件/范围：`GlobalConfiguration.ts`、`LegacySafeHttp.ets`、`WearableContracts.ts`、`WearableDiscovery.ts`、`VepWearableService.ets` 及宿主测试。
- 首轮结果：54 项中 4 项失败。1 项为相机权限文案已更新而旧断言未同步；3 项为报告测试使用国际路径、旧安全传输仍只允许 `/api/saydian-app/v2`。
- 修复结论：安全传输改为精确国际路径并更新语义断言，54/54 通过。随后戒指路由测试首次因 Node 对新增无扩展 TypeScript 导入无法解析而失败，改为复用既有纯契约模块并在测试中注册解析钩子；最终路由/发现 26/26 通过，相关设备与上传组合 48/49 仅该解析问题失败，修正后已定向复验。

### 04:24 玉成多设备记录身份

- 文件/范围：`yucheng_payload_mapper.dart`、`yucheng_wearable_bridge.dart`、映射测试。
- 结果：健康、运动、Flutter 路由与启动 22/22 通过；验证同设备不同大小写/空白得到稳定身份，两台设备同秒 ID 不同。
- 数据边界：不重写既有历史值，不按“同秒同指标”删除无法证明重复的原始记录。

### 04:31 英文路径格式与静态分析

- `flutter pub get --offline`：通过，使用锁定依赖；仅提示 5 个不兼容约束范围之外的新版本，没有升级依赖。
- `dart format --output=none --set-exit-if-changed lib test`：首次失败，准确发现 4 个需格式化文件；执行标准格式化后提交 `571725a style: format Say Ring routing sources`。
- `flutter analyze --no-pub`：英文路径可稳定执行；首次发现 2 个旧真机测试仍引用已移除的 `YuchengDeviceClassifier`，另有 1 个可改用普通赋值避免的集合空值风格提示。已统一改用 `WearableDeviceClassifier` 的 YC 前缀规则，并修正风格提示；待紧接着复验。

### 05:21 Say Ring 品牌与戒指用户文案收口

- 文件/范围：八语 ARB 及生成资源、Flutter 品牌/通知/更新/报告文案、Android/iOS/HarmonyOS 原生兜底提示、戒指路由服务和品牌契约测试。
- 结果：核心品牌统一为 `Say Ring`；扫描、连接、同步、运动、健康测量及设备错误提示统一使用戒指语境；静态表盘、屏幕等入口仍必须经过真实能力门禁，不能因存在翻译资源而展示。
- 新增回归：`test/say_ring_brand_contract_test.dart` 检查 9 份 ARB 的产品名与关键品牌字段，并防止高频设备提示重新出现各语言的 watch/手表用词；HarmonyOS 服务源码增加旧中文品牌和“手表”兜底文案禁入断言。
- 失败记录：HarmonyOS 全量首次在机械文案替换后出现 3 个旧正则断言失败，并使 2 个依赖旧超时提示的测试等待未释放；同步更新为“账号或戒指已变化”“旧戒指指令尚未结束”后，设备会话 56/56、全量 481/481 通过。该现象是测试钩子未命中新文案，不是 SDK 运行时死锁。
- Flutter 回归记录：英文路径格式检查首次发现新契约测试 1 处排版差异，格式化后 155 个文件均合规；新增契约首次运行发现三份中文目录的“还没有账号”遗漏产品名，统一改为“还没有 Say Ring 账号”并重新生成本地化代码。静态分析在修正前已通过，最终全量结果见后续记录。
- 工具边界：中文路径中的 Dart/Flutter 命令仍可能无输出挂起，本轮不把挂起记为通过；提交后在 `F:\xcodeplace\say-ring` 英文路径执行格式、静态分析、双时区测试和 Android 构建。

### 06:08 戒指路由夹具、显示文案与全量回归

- 原因：首次完整 Flutter 回归在提交 `6cc75eb` 上暴露 38 个失败；主要是旧测试夹具仍使用无供应商前缀的设备名，以及界面断言继续使用“手表/表盘/手腕”。这些失败会掩盖“未知设备必须安全拒绝”的新路由边界。
- 文件/范围：`global_wearable_restore_test.dart`、`yucheng_wearable_bridge_test.dart`、设备/健康/商城 Widget 测试；Flutter 用户可见设备提示、健康解释、显示样式页面、八语 ARB 与生成资源；`say_ring_brand_contract_test.dart`。
- 修复结论：恢复和玉成测试数据改用真实路由前缀（V/YC），并把已废弃的 W8 型号白名单测试改为验证任意 YC 前缀戒指均可进入玉成握手。戒指佩戴提示改为“贴合手指”；表盘类用户入口统一为“显示样式/照片显示”，内部协议键和厂商原始字段保持不变。
- 防复发：9 份语言目录的全部用户文案禁止重新出现对应语言的 watch/watch-face 用词；核心戒指页面与服务禁止出现“手表/表盘”。原始服务端报告、商品名、SDK 返回名称和国内版不可达兜底值不做篡改。
- 测试结果：路由/玉成定向 35/35；主要 UI 与业务流程 86/86；品牌契约 5/5；Flutter 全量 UTC 914/914、`America/New_York` 914/914；HarmonyOS 宿主测试 481/481，均通过。
- 失败记录：中文路径执行 `flutter analyze --no-pub` 时分析服务器再次因 LSP JSON 截断退出（`FormatException: Unexpected end of input`）；这是工具/路径失败，不能计为静态分析结果，需在英文最终路径复验。沙箱内 Flutter 因无法写 SDK 锁文件出现多个 `cmd.exe` 空转；仅停止本任务遗留空转进程，改在授权的标准 SDK 环境运行，未停止 Gradle/Android 服务。
- 格式门禁：同步至英文路径后，155 个 Dart 文件中仅 `say_ring_brand_contract_test.dart` 有 1 处标准换行排版差异；已用当前 Dart formatter 修正。formatter 随后的匿名遥测时间戳写入因沙箱权限被拒绝，但源码格式化本身已经完成；最终路径需再次以只读模式确认 155/155。
- 后续待验：英文路径格式和静态分析、Android Debug/Release 实际构建；iOS/macOS 与 HarmonyOS HAP 工具链；真实 YC、V/TK 戒指三轮连接/同步/断开/重连；魔样目标戒指 SDK、服务端 `ringPreferred` 多来源契约，以及仓库 Private 状态和首次推送。

### 06:29 英文路径门禁、Android 构建与安装边界

- 执行位置：`F:\xcodeplace\say-ring`。`dart format --output=none --set-exit-if-changed lib test integration_test` 检查 155 个文件、0 个需修改；`flutter analyze --no-pub` 返回 `No issues found`。这证明英文路径静态门禁通过，也确认中文路径中的 LSP 截断不是源码诊断结果。
- Android Debug：使用显式 `SAYDIAN_API_BASE_URL=https://app.saydian.cn`、国际 V2 更新清单和空天气密钥构建成功，耗时 147.6 秒。APK 为 `app-debug.apk`，68 位/32 位 ARM，大小 156,236,402 字节，SHA-256 `BFC0E2229F35F57DD4E5C2D0DABBBDB92CC010C417C1069807C78A025C5130F7`。
- Android QA Release：首次命令把 `--release` 误写成 `--releaselease`，Flutter 立即拒绝参数；修正命令并显式设置 `SAIDIAN_ALLOW_QA_RELEASE=true` 后构建成功，耗时 262.9 秒。APK 为 `app-release.apk`，68 位/32 位 ARM，大小 68,863,068 字节，SHA-256 `F93C18D4F49CC82DAA454ADDBA1A8DC1874FC5F1D995C438A5F6ADE61EE87D97`。该环境变量只允许生成内部 QA 包，不代表生产签名或上架验收。
- 包体核验：Debug/QA Release 均为包名 `cn.saydian.ring`、版本 `0.1.21 (1004)`、minSdk 26、targetSdk 36、标签 `Say Ring`；两包均通过 APK Signature Scheme v2 校验，证书 SHA-256 为 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`。Release 含 `arm64-v8a` 和 `armeabi-v7a` 的 Flutter/App 动态库。
- 域名核验：Release 二进制字符串中第一方地址仅发现 `app.saydian.cn`、国际商城路径、国际更新路径和产品标识 `say-ring`，未发现旧 `.cc`/`.com` 第一方域名。`vphband.com:9001` 仍作为厂商表盘服务存在，属于已单列的第三方服务，不视为第一方回退。
- Android 原生单测：`:app:testDebugUnitTest` 构建成功；4 份结果文件共 16/16，通过且无失败、错误或跳过。现存 Kotlin Gradle Plugin、Android Gradle Plugin 与 Java API 弃用提示为后续升级项，不是本次失败。
- 真机安装：在线华为 `PPA-LX3`（Android 10）尚未安装 `cn.saydian.ring`；覆盖安装 Debug APK 时手机端拒绝安装授权，ADB 返回 `INSTALL_FAILED_ABORTED: User rejected permissions`。本轮没有卸载、清数据、修改联系人/显示样式或执行 OTA，也没有因此产生真实戒指连接验收证据；需用户在手机端允许安装后再继续。
- 平台边界：当前 Windows 主机没有 `xcodebuild`，不能执行 iOS 编译、签名或真机测试；也未找到 `hvigorw`、`hvigor`、`hdc`、`ohpm`，因此 HarmonyOS HAP 构建未执行。481/481 的 HarmonyOS 宿主测试不能替代 HAP 或真机验收。

## 下一阶段门禁

- 手机端允许安装后，安装已校验的 Debug APK，并用真实 YC、V/TK 戒指执行连接、同步、断开和重连；Android 自动门禁已通过，不用重复归因于源码。iOS/macOS 与 HarmonyOS HAP 工具链缺失，继续明确标记未执行。
- 继续把可见核心文案和图形改成戒指语境，并移除界面上的 SDK/供应商技术标签；能力未返回或 App 未接入时不展示入口。
- 在独立服务端工作副本增加规范设备来源、多设备样本身份和可选 `sourcePolicy=ringPreferred`；旧 App 不传策略时保持原行为，并回归原手表 App 契约。
- 取得真实 YC、V/TK 戒指后按“供应商 × 平台 × 型号/固件”各做至少三轮连接、同步、断开与重连。魔样必须先取得目标戒指 SDK、字段契约、授权和 HarmonyOS 资料。
- 仓库改为 Private 并回读确认前不推送；继承工作流默认不允许发布，签名、推送、支付、回跳和下载包必须按新产品重新配置。
