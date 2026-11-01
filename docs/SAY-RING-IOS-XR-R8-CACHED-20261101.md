# iPhone XR / R8 缓存标识优先连接（1201）

时间：2026-11-01（Asia/Shanghai）。分支 `codex/fix-client-audit-20261031`，修改前提交 `29aabc1d8f9abb6f79a8868251d6a081a8947b9b`。此前已按项目要求检查分支、远端、工作树，更新并阅读最近实施记录、问题复盘和回归清单。本轮只处理添加戒指时的查找、精确连接与失败后搜索，不改变账号、健康记录、厂商路由或自动恢复的账号门禁。

## 现场证据与原因

- 目标为在线的 iPhone XR / 原 R8。用户报告 XR「设置 → 蓝牙」显示 R8 已连接，但不在现场，无法打开该页面进行当场目视确认。本轮原生只读探针在开始时读到：CoreBluetooth 按厂商服务、HID 服务和通用访问服务查询的**当前连接**数均为 0；用此前同一 XR、同一应用的私有备份中已验证的原 R8 UUID 查询系统缓存，则找到精确外设，状态为未连接、名称与 R8 匹配。普通 BLE 扫描未发现 R8。这说明当时有可尝试的精确缓存对象，不能把缓存对象或用户报告等同于实时无线连接。
- 当前 App 绑定已从 R8 切换为 R21。iOS 不能向 App 枚举所有历史缓存 UUID；旧版本也未保留多个曾成功连接的 UUID。因此本次实机测试从**先前同机私有备份**取回原 R8 的精确 UUID，只把它加入该账号的测试用历史候选列表；当前 R21 绑定、账号、健康库和戒指本身均未清除或重置。未来版本会在每次真实成功握手后自动保存最近 4 个同账号候选；不能据这次一次性测试声称所有旧安装会自动找回更早设备。

## 修改

- iOS 添加设备先查询系统当前已连接且名称可识别的戒指，再查询当前账号已保存的精确标识及最近成功连接记录；有候选时立即展示供用户选择，没有候选才扫描。历史候选只在同一账号和同一应用环境可见，且不参加静默自动换戒指。
- 对被选择的精确 UUID，先用 CoreBluetooth 缓存对象直接发起厂商连接与能力握手；缓存中没有这个 UUID 时，候选查询不再为每个旧设备串行等待 10 秒扫描。用户选择缓存候选但握手失败时，添加设备页自动开始附近搜索。只有实际握手成功才更新当前绑定。系统已连接候选增加 HID/通用访问服务查询；名称与厂商路由仍需核对，不能以系统缓存或蓝牙配对替代厂商握手。
- `wearable_bridge.dart`、`qring_wearable_bridge.dart`、`wearable_routing.dart`、`devices.dart`、iOS `QCCentralManager` 和 `QRingWearableBridge` 为本轮产品变更；`test/global_storage_isolation_test.dart`、`test/wearable_exact_recovery_test.dart` 等校验同账号历史、换号隔离与失败不改绑定。

## 真机与失败记录

1. 测试前通过 `devicectl` 私有备份 XR 的应用容器。首个测试入口人为关闭自动恢复，导致账号恢复上下文未建立，历史候选未显示，断言失败；这是测试入口与普通 App 生命周期不一致。恢复正常初始化后重跑，候选出现，原 R8 通过精确缓存 UUID 完成 SDK 握手并进入 `ready`，无需等待 BLE 广播扫描。该轮测试结果、原 UUID 和设备日志只保存在 Git 外的私有目录。
2. 加入“只查缓存”的候选参数和添加页缓存优先流程后，用签名 Profile 测试包在同一 XR 再测：候选 2 个，原 R8 精确候选存在；真实连接成功，`connectDevice` 用时 **3369 毫秒**；未走失败后的扫描路径。测试包通过 `tool/drive_ios_preserving_data.mjs --profile --keep-app-running` 原位运行，未使用会卸载 App 的默认 `flutter drive`。失败握手不覆盖原绑定有定向测试；添加页失败后自动搜索已实现，**本轮没有制造 R8 断电/离线来声称实物失败回退通过**。
3. 生成普通 `lib/main.dart` Profile 时，第一次 `xcodebuild` 因本机磁盘空间耗尽（`No space left on device`，Dart snapshot 写入失败）而失败；仅清理本轮可重建的测试 DerivedData 后重试成功。没有删除账号、手机容器、文档或 Git 内容。随后 Debug 串行构建成功；删除其可重建中间产物释放空间，保留普通 Profile 构件。
4. 将普通 Profile **原位覆盖**装回 XR 并启动，系统回读 `cn.saydian.ring` 1.0.8（1201），开发团队 `W7SXQ4A226`，签名核验通过。再次私有备份并比较 `Documents`：49→49 个文件，缺失 0；仅测试目录的 `proof.json` 被本轮测试更新，其他文档未变化。原生 SDK 最近连接标识从 R21 切回原 R8。首页能够打开；没有借本轮结果声称今日活动、睡眠新样本已同步。

## 回归与交付边界

- `dart format`、`flutter analyze --no-pub` 通过；定向 Flutter 71/71；全量 `TZ=UTC` 和 `TZ=Asia/Shanghai` 各 **1711/1711**；4 组 QRing 原生连接相关测试 **23/23**。Android Debug 与 `SAIDIAN_ALLOW_QA_RELEASE=true` 的内部 QA Release 均构建成功，未安装或发布 Android 包。
- iOS Debug/Profile 在本机 Xcode 27.2 串行构建和签名通过；只对本次构建临时设置 `IPHONEOS_DEPLOYMENT_TARGET=15.0`，未改仓库默认最低系统。Profile 已安装 XR；Debug 只构建，没有以独立 Debug 启动代替真机连接结论。没有生成 TestFlight 分发包、上传或提交苹果审核。
- 本次证明**已知精确 R8 缓存标识在 XR 上能够完成实际连接**，不能保证其他型号、无缓存、自然断连、锁屏/系统回收或长期稳定性。用户不在现场，无法复核 XR 系统蓝牙设备列表；旧的“近距离自然断连超过 6 分钟未恢复”仍是独立未闭环问题。首次连接新戒指仍需扫描和用户选择，不会靠型号名称猜 UUID。

## Git 同步说明

- 本机已做范围明确的提交，命令行 `git push origin codex/fix-client-audit-20261031` 因没有可用 GitHub 用户凭据失败，没有把它记录为已推送。改用已授权的 GitHub 连接将同一提交树写入远端，并以预期旧 SHA 更新当前分支；`git fetch` 后核对远端树与本地树完全一致，随后把本地分支快进对齐远端。未强推或修改 `main`。命令行凭据仍未恢复，后续普通 `git push` 可能仍需此路径或重新配置本机凭据。
