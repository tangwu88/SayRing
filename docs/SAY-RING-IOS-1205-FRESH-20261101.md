# Mac 最新代码整合与 iPhone 全新安装 1205

## 来源与用户边界

2026-11-01 开始于干净的 `codex/integrate-latest-20261031` / `63d3c1c`。fetch 后本分支无新增，但 `origin/codex/fix-client-audit-20261031` 更新至 `74b868a`，仅新增 XR 巡检记录及精确已记住目标的测试保护。建立 `codex/checkpoint-ios-resume-20261101-63d3c1c` 后合并；唯一冲突为记录索引，双方条目全部保留。

产品 `lib/ios/android`、版本锁文件与起点一致；未把另一台 XR 的实物结果算作本轮 iPhone 15 Pro Max 验收。Android 保持暂停，没有构建、安装、上传商店、改下载页或服务端开关。

本轮用户随后明确：“手机上的数据不需要恢复，全新安装，以后本地都不需要考虑备份恢复数据”。已在 AGENTS.md 追加该指令，覆盖本项目本地手机安装调试的默认备份/恢复前置要求；既有备份、原始素材、其他 App 和云端数据不删除。保留明确签名包和测试结束装回普通 main 的安全约束。

## 安装前状态及范围变更

在线设备是 USB iPhone 15 Pro Max（iOS 26.6，已解锁）。最初系统 apps 查询和 devicectl 均确认 `cn.saydian.ring` 已不在安装列表；没有将“运行状态 1”单独当作已安装。无法导出当前容器，保留 ContainerLookupErrorDomain -1 的失败。

在用户上述新指令到达前，曾按原保数据要求核验上一轮 24 个文件的哈希，并将其中数据库和偏好两文件恢复到新装的临时巡检包。私有恢复脚本第一次目录语义理解错误，产生 Library/Library；原文件未改，回读发现后修正到容器根，两文件哈希匹配，并只移除了本脚本刚创建的错误副本。该阶段不是本轮最终交付状态。

用户改为全新安装后，明确只卸载本设备上的同团队 `cn.saydian.ring` 临时 1205，再装新签名巡检包；没有再次导出整个容器，也没有恢复数据库或偏好。旧备份保持原状。iOS Keychain 的系统持久化与账号云端回读不等于从本机备份恢复；本轮未替换账号或清服务器数据。

## 构建与签名

正常固定包名 `cn.saydian.ring`，1.0.8（1205），开发团队 W7SXQ4A226，仅 iPhone，生产 API 根 `https://app.saydian.cn`。本机 Flutter 3.44.9 / Xcode 26.6，iOS 构建串行：

- 第一份 `--profile --target=integration_test/ios_read_only_page_walkthrough_test.dart --no-pub --build-name=1.0.8 --build-number=1205 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`，68.1 秒。
- 普通 `--debug --target=lib/main.dart`，其余同参数，28.4 秒。
- 修正巡检判断后重新编译 Profile 巡检包，88.9 秒。首份 App 保留，新包独立冻结，未覆盖原工件。

三份均经过深度验签及实际 Info/provisioning 检查：包名、版本、UIDeviceFamily=[1]、get-task-allow、当前设备授权及有效期符合；Profile 的 App/Runner 符号 UUID 匹配，普通 Debug JIT kernel 存在。保留既有插件 SPM、微信模拟器架构警告，没有为消除警告改依赖或最低系统版本。

## 巡检失败与修正

首次巡检在首页后 `Bad state: No element`。真实产品首页仅在当前设备确认支持睡眠时显示睡眠概览；脚本却无条件搜索该入口。修正测试按 `shouldShowHealthMetric(sleep)` 判断：不支持时明确断言入口不存在并记录未开放。百科同样按公开模块 lease 判断，不以隐藏绕过本应存在的入口。只修改巡检，不改产品能力、公开开关或健康值。

修正后全新安装巡检进入 15 个可用页面：健康首页、全部健康数据、远程关爱、健康百科、运动总览、消息、设备、我的、个人资料（只读）、单位、账号、权限、反馈、客服、关于。结束时因新增 SemanticsHandle 的框架清理检查失败，不能把到访页面当作整轮通过。未禁用句柄验证；停止本任务既有 WDA UI 测试会话及其 USB 转发后，使用同一签名包隔离重跑。

所有物理巡检均通过 `tool/drive_ios_preserving_data.mjs --profile --no-uninstall-first --use-application-binary=<已验证冻结App>`，强制 keep-app-running；不执行隐式失败卸载，不自动选择其他戒指，也不测量、拍照、改资料/监测/手势或注销账户。

## 宿主检查

- 合并后静态分析成功；修正测试后再次静态分析成功（4.8 秒），dart format 无改动。
- `TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact`：1722/1722，2 分 15 秒。产品源码不变，该轮覆盖同一产品代码；未将它说成双时区实物验收。
- `node --test tool/drive_ios_preserving_data.test.mjs tool/qring_history.test.mjs tool/qring_recovery_state.test.mjs tool/qring_capability_handshake.test.mjs`：19/19。是宿主协议/合成回调测试，不是戒指自然断连或完整历史实测。

签名包、符号、失败日志、测试证明和调试端点只存忽略目录 `.build/ios-resume-20261101-gcyDcv`。本记录不包含真实健康数值、账号、照片或完整设备标识。

## 最终实物结果与普通 App 回装

同一修正版签名 Profile 隔离重跑通过，15 个当前可用页面全部到访，原句柄结束检查保留且未再失败。未再混用 WDA 页面查询；巡检期间出现后台暂停，通过正常 `devicectl ... process launch --activate cn.saydian.ring` 恢复同一进程前台后继续，最终 1 分 43 秒整轮成功。一次通过不能反推之前没有失败；两个原始失败和隔离重跑日志均保留。

巡检结束后，只停止已核验的本 App 测试进程，原位装回同源码正常 `lib/main.dart` Debug 1.0.8（1205），没有第二次清除新数据、备份或恢复。使用明确已验签的冻结普通 App 启动 Flutter Debug，独立本机调试宿主持续保存私有日志，未将测试入口留给用户。

普通 Debug 实际收到 app.started、热重载 code=0、DevTools HTTP 200。首次只读 VM 检查超时，正常激活应用后再读成功；当前普通 App 原生 PID 与 VM PID 相同，main runnable=true、Resume，实装开发 entitlement 和 1205 版本正确。当前本机健康缓存为 0、没有同步/测量中状态或当时接口错误；系统保留的同账号登录仍有效，没有用测试账号替换。这与本轮最终“不恢复旧本机数据”的要求一致。

当前没有连接戒指，真实能力未就绪，因此心率、HRV、血氧等受能力限制入口、睡眠概览没有计作页面缺失，也没有开启不支持的测量。设备实际测量、自然断连恢复、完整睡眠/历史和 AI 报告仍待有明确实物目标后单独验收；本轮不宣称修复了上一轮 R12 的部分历史确认问题。

手机当前保留正常 Debug 和运行中的调试宿主；独立桌面冷启动不是本轮结论，Debug 需要 Flutter/Xcode 连接。没有把此前 1204 的符号、VM 或后台连接状态作为本次证据，也没有将已冻结的巡检 Profile 当作可日常使用的普通入口。
