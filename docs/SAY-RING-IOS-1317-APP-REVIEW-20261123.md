# Say Ring 1.0.15（1317）苹果送审记录

日期：2026-11-23。用户明确要求构建新的苹果版本并提交审核。本次准备可正式送审的发行包，保留原正式版本与手动发布方式。

## 源码及范围

- 分支 `codex/say-ring-support-sleep-20261114`，开始提交 `b1412ec6811131b081373e4114f56a675ac623bf`。工作区干净，已 fetch，当前分支与 upstream 一致；另一个分支新增项为独立排查记录，没有把其分支差异重复混入。
- 运行源码与上一轮 1316 相同，不新增阈值、后台监测规则或设备功能。正式版 1.0.14（1303）在 App Store Connect 显示可分发、手动发布；创建独立 1.0.15 草稿，构建使用 1317。
- 与正式版相比，说明新增在线客服/常见问题、日周月睡眠报告及分期图交互、邮箱注册登录与连接/历史读取改进。审核备注保留真实限制：部分 U19 固件最新血压结果尚缺可靠实物读回；个人阈值仅比较新完成的有效手测，血压阈值、后台连续监护和未经实测的送达不宣称完成。

## 本轮检查与构建

- `dart format --output=none --set-exit-if-changed lib test` 通过；`flutter analyze --no-pub` 无问题。
- `TZ=UTC` 与 `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded --concurrency=3` 各 2,472 项通过，耗时 92.60 秒、88.44 秒。
- `python3 -m unittest discover -s scripts/release -p test_*.py` 35 项通过。本轮不重复未改动源码已通过的 Android/native 构建；既有证据见 [1316 记录](SAY-RING-CODE-SYNC-IOS-1315-20261122.md)。本轮不是新增真机测量/同步验收。
- 使用正常 `lib/main.dart` 和既有第一方生产定义；Release config-only 17.77 秒，独占 Xcode Release archive 62.14 秒，均退出 0。构建前后运行内容哈希一致，生成配置已恢复。
- 实际 Bundle ID `cn.saydian.ring`，版本 `1.0.15`，构建 `1317`，团队 `W7SXQ4A226`。正常 arm64 AOT、无 Debug kernel，归档及保护副本严格验签通过。
- 归档留样：`~/Library/Developer/Xcode/Archives/2026-11-23/Say Ring 2026-11-23 21.45.18 1.0.15-1317.xcarchive`。原始记录与实际上传 IPA 位于 `build/ios-appstore-1317-20261123.mkjnb4ia`。
- 分发参数 `method=app-store-connect`、`destination=upload`、`manageAppVersionAndBuildNumber=false`、`testFlightInternalTestingOnly=false`。这是可送正式审核的发行上传，区别于原 1316 的内部测试专用包。
- 实际上传包 39,596,305 字节，SHA-256 `407b54f3797f65b2325d324eb1b8c4037ff5bdfdfa7b110801d5bea5f3d59fd7`。重新解包严格验签，App Store provisioning、禁止调试、生产 APNs、归档 UUID 相同均核对通过。
- 北京时间 21:51:09 返回 `Upload succeeded`，随后 `Uploaded Runner / EXPORT SUCCEEDED`。15 项原厂 SDK 缺少 dSYM 为非阻断警告，厂商框架崩溃符号解析仍有限制。

## 资料核对

- 简体中文更新说明、产品描述和英文审核步骤已在新的 1.0.15 草稿保存；原审核登录/联系方式保留，不将密码、电话或验证码写入 Git。
- 当前隐私标签已包含客户支持、照片或视频、诊断、标识符、健康/健身等类别及账号关联范围；既有隐私政策 URL 返回 200，并涵盖客服、媒体和诊断说明。第一方在线客服公开配置返回 200 且已启用。
- App 合规原有 ICP 与非受监管医疗设备声明保留。页面新增的中国大陆安全评估、AIGC 资料仍显示缺少信息；原页面给出现有 App 的 2027-01-31 期限。没有伪造证明、备案或宣称不使用现有 AI 功能，实际是否阻断本轮提交以下方苹果结果为准。
- 1.0.15 手动发布保持选中，不修改地区、旧正式构建、评分、外部测试或内部组自动分发。

## 苹果处理与审核结果

- 北京时间约 21:57 观察到 1317 处理完成，构建 ID `046916f9-4ed4-4215-a314-e76b6c586bd9`。按实际标准加密填写本次出口合规，沿用已核对的现有法国未分发范围；不更改销售地区。
- 正式版构建选择器中 1317 可选，1316/1309/1308 的内部测试专用包不可选。选定并保存 `1.0.15（1317）`，再次核对手动发布选中后执行「添加以供审核」，苹果校验通过。
- 随后执行本次新版本的最终「提交以供审核」，苹果返回「已提交 1 个项目」。进入官方审核详情页，明确显示 `iOS App 1.0.15 / 1.0.15 (1317) / 等待审核`。
- 提交日期：苹果页面显示 **2026-11-23 22:00（北京时间）**。提交 ID `1fcc3ac0-87e3-4c74-bfbb-2ff4bbc87803`，详情 `https://appstoreconnect.apple.com/apps/6816549943/distribution/reviewsubmissions/details/1fcc3ac0-87e3-4c74-bfbb-2ff4bbc87803`。
- 最终截图 `build/ios-appstore-1317-20261123.mkjnb4ia/app-review-1317-submitted.jpg` 和只读状态记录已私下保存。已上传、已处理、可用于正式审核、已关联及已提交均分别确认；当前是等待审核，尚非获批或公开发布。
- 本次没有撤回旧正式版、变更审核账号/销售范围、启用自动发布或更改测试组。中国大陆安全评估/AIGC 两项实际尚缺资料，但没有阻断本次审核提交；需在苹果给出的期限前补充真实材料，不计为本轮已补齐。
