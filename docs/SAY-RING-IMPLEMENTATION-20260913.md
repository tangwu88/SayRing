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
- 工具边界：中文路径中的 Dart/Flutter 命令仍可能无输出挂起，本轮不把挂起记为通过；提交后在 `F:\xcodeplace\say-ring` 英文路径执行格式、静态分析、双时区测试和 Android 构建。

## 下一阶段门禁

- 在英文最终路径执行格式化、`flutter analyze`、双时区全量 Flutter、Android Debug/QA Release、完整 HarmonyOS 宿主测试与可用构建；macOS/iOS 和真实 HarmonyOS 构建环境缺失时明确标记未执行。
- 继续把可见核心文案和图形改成戒指语境，并移除界面上的 SDK/供应商技术标签；能力未返回或 App 未接入时不展示入口。
- 在独立服务端工作副本增加规范设备来源、多设备样本身份和可选 `sourcePolicy=ringPreferred`；旧 App 不传策略时保持原行为，并回归原手表 App 契约。
- 取得真实 YC、V/TK 戒指后按“供应商 × 平台 × 型号/固件”各做至少三轮连接、同步、断开与重连。魔样必须先取得目标戒指 SDK、字段契约、授权和 HarmonyOS 资料。
- 仓库改为 Private 并回读确认前不推送；继承工作流默认不允许发布，签名、推送、支付、回跳和下载包必须按新产品重新配置。
