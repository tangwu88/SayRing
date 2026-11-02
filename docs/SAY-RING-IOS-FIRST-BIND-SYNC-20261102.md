# iOS 新会员首次连接 R8 后同步入口缺失

2026-11-02。客户端基线 `b0857dd1bc5385b74a4e27d49a67af238de1f2f7`，工作分支 `codex/integrate-latest-20261031`。用户报告另一台 iPhone 上的新注册账号连接 R8 后，设备页没有同步按钮，健康数据全部为空。该受影响手机不在本机现场，未读取其日志、账号或具体首次绑定回包。下述根因由生产逻辑与可复现回归确认，不能替代那台手机的实际修复验收。

## P1 根因与影响

现行规则为：没有任何终生绑定历史的新会员，首次明确绑定成功后才可清理戒指旧记录；已存在任何绑定历史的会员不清理。QRing 部分固件确认恢复出厂指令后，可能仍保持当前 BLE 连接。iOS 将这一条重置连接的历史与设置保持关闭，等待新的握手完成时间、个人资料及步数目标初始化；旧逻辑没有在收到确认后主动恢复这一步。

因此会出现「App 显示已连接，但初始化仍 pending」：原生能力将 `supportsHistorySync` 置为 false，设备页原本按这个值直接隐藏同步按钮，Dart 层同时阻断历史导入和健康事件。已连接页面又只在没有连接时提供重连入口，用户缺少继续完成初始化的操作。单纯放开按钮或直接接收旧记录会越过首次绑定的数据归属保护，不能作为修复。

新会员按既有要求成功清空戒指后，短期没有活动和睡眠记录可能正常：活动需要产生新样本，睡眠需要实际佩戴入睡。应恢复的是可完成的初始化、真实同步和操作入口，不能为新账号补造健康数据，也不能把暂无新样本视为同步链路已通过。

## 客户端修复范围

- `ios/Runner/QRingWearableBridge.m`：仅在精确账号/戒指的恢复出厂 ACK 已确认、初始化未完成且仍处于发出指令的同一连接代次时，发出布尔 `requiresReconnect=true`。未确认、迟到 ACK 或新握手代次不请求自动重连，不重复发送恢复出厂。
- `lib/services/app_controller.dart`：收到上述明确回执后，等当前连接操作释放，再对同一账号、目标和同步代次执行一次普通重连；保留同意、账号切换、显式断开、目标替换与过期回调保护。初始化完成才恢复历史同步。
- `lib/ui/pages/devices.dart`：初始化未完成时仍保留普通重连入口，进行中显示等待状态；保持用户此前要求的静默空数据体验，不展示内部供应商名称或初始化诊断文案。
- 回归覆盖同一连接 ACK 但没有断开、重复回执去重、连接未返回时排队、未知结果不自动重试、切换账号不跟随旧任务、初始化完成后恢复真实读取，以及设备页入口与等待状态。旧测试假控制器同步增加只读初始化状态，未修改账号或戒指历史。

## 服务端只读核验

1. 无凭证读取 `https://app.saydian.cn/global/health/ready`，返回 `ready`、`database=ok`，生产 revision 为 `7f3e816d83568622668537bd3467c24247b797f5`。`git fetch origin --prune` 后服务端 `origin/main` 为同一提交；只抓取并比较代码，没有部署或变更生产。
2. `GET /global/api/saydian-app/v2/support/app-display?product=say-ring&platform=ios` 返回五项只读指标 `heart_rate/hrv/blood_oxygen/body_temperature/stress` 均 true，租约 300 秒；`hideAi=true`、`sleepAiEnabled=true`，百科 true、商城 false。此公开配置不按新会员关闭；它也不代替真实设备能力。
3. 精确生产版本 `apps/api/src/devices/devices.service.ts` 与已检查本地源码一致。`POST /devices` 仅在 `product=say-ring`、`initializeFirstBinding=true` 且该会员全部终生绑定数量为 0 时返回 `firstBindingInitialization.shouldClear=true`。会员行锁串行处理所有设备上报；重复、已解绑或其他型号历史均返回 false，失败事务不发授权。该接口没有独立的「新会员禁用同步」字段。
4. 精确生产版本 `apps/api/src/health/health.controller.ts` 对 `say-ring/ios` 固定允许 `sleep/steps/distance/calories` 历史；五项额外生理开关不会关闭活动和睡眠。没有访问受影响用户的私有健康记录，不能由公开接口断定其实际已有多少样本。
5. 已有服务端单测包含首次授权、重复不清理、既往绑定保护及事务失败不授权。本轮尝试运行 `./node_modules/.bin/vitest run src/devices/devices.service.test.ts --maxWorkers=1 --testTimeout=15000`：首先 PATH 无 node，未启动测试；补用现有 ChatGPT bundled Node v24.22.1 后，Rollup 原生模块因不同 Team ID 的签名装载限制失败，仍未执行断言。没有重新安装依赖、修改原生模块签名或降低系统安全设置；不能把历史服务端测试记录写成本轮通过。

服务端暂未发现需要修改的证据。当前修复在客户端完成，不移除首绑授权、清空保护或用户数据归属检查。

## App Store 与实际受影响版本

中国 App Store 公开查询 `https://itunes.apple.com/lookup?id=6816549943&country=cn` 返回 Say Ring、`cn.saydian.ring`、公开版本 **1.0.9**，`currentVersionReleaseDate=2026-11-01T20:52:57Z`，即北京时间 **2026-11-02 04:52:57**。公开版本说明为「优化戒指连接与重新连接体验，改进设备功能页面显示，并修复部分已知问题。」因此当前商店用户可能处于仍含上述初始化问题的 1.0.9；公开 lookup 不返回构建号，也不证明受影响手机已经安装这一版本。

## 本轮验证与边界

- 原生生产方法回归：在未修复 HEAD 上先复现失败；修复后的 `tool/ring_initialization_intent.test.mjs` **4/4 通过**。包含真实 Objective-C 方法片段编译运行及布尔 codec 检查；这是宿主协议回归，不是实际对用户戒指执行恢复出厂。
- Dart/界面专项 **30/30 通过**。
- 首轮全量 Flutter **1753 通过、3 失败**：旧 fake 未提供新增 getter，造成类型断言失败。补齐测试假控制器状态后，最终静态分析 **0 问题**、全量 Flutter **1756/1756 通过**。保留首轮失败，不改写为首次即通过。
- iOS 普通 `lib/main.dart` Debug 与 `integration_test/ios_qring_r8_device_smoke_test.dart` Profile QA **1.0.9（1222）** 的 `xcodebuild` 均为 `BUILD SUCCEEDED`。本机真机构建命令临时设 `IPHONEOS_DEPLOYMENT_TARGET=15.0`；仓库默认 iOS 13 不改，不据此宣称 iOS 13 SDK 构建通过。
- QA 签名初查在受限环境返回 `CSSMERR_TP_NOT_TRUSTED`；获授权读取本机信任后，`codesign --verify --deep --strict` 通过，核验团队 `W7SXQ4A226`、包名 `cn.saydian.ring`、Profile 包含当前 XR。受限环境无法读取信任和实际签名无效不能混为一谈。
- XR Documents 私有备份成功，1222 QA 原位安装并实际接入 Flutter。该轮 smoke **退出 1，约 65 秒**：精确失败为测试第 80 行等待 `CameraPreview` 的 45 秒超时。此前登录、原 R8 精确目标连接/能力 ready、同步等待结束、电量、手势入口/设置非空读取、同账号同目标断言均通过；“同步等待结束”不是历史数据完整性证明。实际相机预览、遥控会话 ready 及后续断言未验收，不把整轮写为通过，也不把旧账号流程代替新会员首次清理后的实物验收。
- Android Debug **构建成功**；明确 QA 模式的 Android Release **构建成功，75.9 秒，72.1 MB**。这是 QA Release 编译证据，不是正式发行签名、安卓安装或发布验收。
- 为缓解磁盘空间，移除临时 QA IPA 的展开目录（保留 IPA），并清理两个此前已 clean 的旧 DerivedData 的模块/索引缓存。未删除私有备份或归档。普通 `lib/main.dart` Profile 1222 已构建成功、严格验签通过，并已原位安装、实际 launch 成功，测试专用入口已恢复为正常主入口；这不代表普通版新一轮所有功能均已实测通过。
- XR 测试后 Documents 私有备份也已成功。前后 Documents 均有 53 个文件，逐文件 SHA-256 对照无缺失、无变化。该目录比较不覆盖健康数据库等其它容器目录，不能宣称全部健康记录完整性已验证。
- Git HTTPS dry-run 推送因本机缺少凭据失败，改用官方 GitHub 连接工具同步同一分支；提交前另发现远端 `3ab3cea` 仅新增安卓正式包记录，予以保留合入，应用源码基线未变化。远端交付以最终提交/树比对为准；未改变发布状态。
- 本轮尚未发布新二进制、替换 TestFlight 构建或提交新的苹果审核。代码修复、构建、安装、受影响新会员实物验收、正式发布各自记录。

### 命令简表

以下简表列主要命令和关键参数；日志位于 Git 忽略的 `build/first-binding-20261102/`，私有设备备份不进入 Git。

| 检查 | 主要命令/关键参数 | 当前结果 |
| --- | --- | --- |
| 原生初始化回归 | `node --test tool/ring_initialization_intent.test.mjs` | 原 HEAD 反例失败；修复后 4/4 通过 |
| 首绑控制器专项 | `flutter test --no-pub test/device_connection_reporting_test.dart` | 30/30 通过 |
| 全量 Flutter | `flutter test --no-pub` | 首轮 1753 通过/3 个旧 fake 失败；修正后 1756/1756 通过 |
| 静态分析 | `flutter analyze --no-pub` | 最终 0 问题 |
| 普通 Debug iOS | `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination generic/platform=iOS -derivedDataPath build/ios-xr-r8-1215-20261101/DebugDerivedData IPHONEOS_DEPLOYMENT_TARGET=15.0 SAIDIAN_DEVELOPMENT_TEAM=W7SXQ4A226 build` | 普通 main，BUILD SUCCEEDED |
| Profile QA iOS | 同上，`-configuration Profile`；Flutter 配置入口为 `integration_test/ios_qring_r8_device_smoke_test.dart`，版本 1.0.9（1222） | BUILD SUCCEEDED |
| QA 严格签名 | `codesign --verify --deep --strict`，目标为本轮 Runner.app | 初次信任读取受限；授权后通过 |
| XR 保留数据驱动 | `node tool/drive_ios_preserving_data.mjs`，使用本轮签名 Profile IPA 与 `--keep-app-running` | 安装/Flutter 接入成功；相机预览等待超时，退出 1 |
| Android Debug | `flutter build apk --debug --no-pub` | 构建成功 |
| Android QA Release | `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub` | 构建成功，75.9 秒，72.1 MB；未发布 |
| XR 普通版恢复 | Profile 构建入口恢复为 `lib/main.dart`；严格验签后原位安装并 launch | 1222 普通主入口恢复成功；不扩大为整轮功能通过 |

## 后续验收

在确有授权的新会员首次绑定场景中，确认最多一次清空指令；明确 ACK 后完成普通重连、新握手和设置初始化，设备页同步入口恢复，真实新活动记录能够导入。无睡眠样本时保持空值。未知或迟到 ACK 必须继续保守处理，不能自动再次清空；原会员、换账号、目标替换、退出登录及显式断开均不得触发错误恢复或清空。
