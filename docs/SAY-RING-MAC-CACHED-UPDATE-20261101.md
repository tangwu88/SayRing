# Mac 合入最新缓存连接修复

## 范围与输入

用户再次要求更新。本轮仅更新本地 Say Ring 代码并做合并回归，不安装手机、不操作后台或商店，不改真实账号、绑定或健康记录。

起点为干净的 `codex/integrate-latest-20261031` / `6f96c43d021ce42afcc4307ad2f08dbcb027d2b7`。fetch 后当前跟踪分支无更新，但独立修复分支新增至 `6115305`，包含 `5d06e1a` 缓存连接修复及测试/记录。两侧12/4提交分叉，不可用快进覆盖。

先建立 `codex/checkpoint-mac-sync-20261101-6f96c43`，再 `git merge --no-ff --no-commit origin/codex/fix-client-audit-20261031`。唯一冲突为记录索引，保留双方所有条目；产品源码自动合并，无重置、强推或丢弃改动。

## 合并边界

新增同账号精确缓存候选优先、最近成功设备的手动候选及失败后搜索。只有实际SDK握手成功才改当前绑定；历史候选不参加静默换环。保留原有owner、环境、厂商名称与真实能力校验，不以系统连接或缓存替代握手。

`git diff --cached --exit-code HEAD -- android lib/domain/device_history_sync.dart lib/domain/wearable_sync_result.dart lib/services/local_health_store.dart`通过，保留整合版Android原生、R22历史检查点和温度相关领域逻辑；`git diff --cached --exit-code origin/codex/fix-client-audit-20261031 -- ios`通过，原生iOS与输入修复版一致。

## 首轮失败与更正

- Node连接回归首次41/42，旧断言仍要求缓存外设已是connected。新版本明确允许用户选择精确但未连接的缓存UUID，故该断言不再适用。
- 只调整该测试：检查精确UUID、已知名称校验、cacheOnly边界、候选准备不得静默连接或写绑定；保留精确扫描、取消及不删除绑定断言。改后42/42、零跳过。
- 本机缓存缺失100个锁定hosted包以及固定Git插件。离线pub恢复失败；未恢复依赖时的Analyzer545项及Flutter编译错误属于缺包，保留日志，未冒认产品回归失败或成功。停止本轮无效测试任务后恢复依赖。
- 两次正常全历史Git克隆（含HTTP/1.1重试）及一次普通浅取回均在Gitee传输中断，early EOF；未升级、替换厂商插件或改锁文件。固定提交的filtered浅取回成功，提交实读为 `5ca3050d7170509d386f548fcae7d5f8b457febf`。
- hosted包通过官方`dart pub cache add <name> --version <locked-version>`恢复，100/100成功。厂商插件以相同原始远端及精确Git对象恢复本机缓存，排除非依赖的示例目录；没有伪造Git提交或使用其他版本。直接克隆部分对象库时的missing-promisor-object错误保留，随后改为复制已验证的本机Git对象及正规稀疏检出。

## 最终检查

- `flutter pub get --offline --enforce-lockfile`最终成功，`pubspec.yaml`和`pubspec.lock`与起点一致，没有版本升级。
- `dart format --output=none --set-exit-if-changed lib test integration_test/ios_read_only_page_walkthrough_test.dart integration_test/ios_xr_other_ring_scan_test.dart`：295文件、零变化。
- 依赖恢复后`flutter analyze --no-pub`零问题，8.5秒；前述545项缺包错误没有覆盖或删掉。
- 全量`flutter test --no-pub --concurrency=1 --reporter expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`：UTC与Asia/Shanghai各1722项通过，分别2分30秒和2分17秒。
- 七组Node连接/相机/历史/日志隐私回归最终42/42，零跳过。它们含实际Objective-C方法的宿主夹具，但不是无线设备验收。

## 原生缓存与构建回执

本机原生SDK和Gradle缓存也缺失，不能用旧安装包替代新源码编译。插件版本始终为原固定提交，没有用空库、删模块或改业务代码消除环境报错。

先按Git树验证35个原生资源；5个直链因SSL或403未完成，继续使用原公开Git仓库的正常对象读取。大文件SDK通过官方Git对象接口取回，校验为10,536,424字节、Git对象 `20c959a99e09ffe079b717b3ff9026b365bf4385`。私有辅助脚本首轮NUL前缀转义错误导致拒绝导入，修正为明确的零字节后验证通过；并非SDK损坏。

剩余头文件和资源分批取回。首轮未匹配Git的promisor读取参数而失败；按Git官方实现使用noop协商与stdin输入后成功，单批网络超时另行仅重试该45个对象。最终正常稀疏检出完整依赖目录，SDK文件实读哈希匹配，示例目录不参与构建。未修改全局网络配置、Flutter SDK或原始压缩包。

- iOS首次及缓存恢复后第一次重试仍缺YCProductSDK/JLAudioUnitKit等模块。原因是Pods项目在SDK文件未恢复时生成，继续保留失败日志。
- 原依赖下执行`pod install --project-directory=ios`成功，24个pods，重新生成项目；Pod锁文件没有变化。
- 随后串行`flutter build ios --debug --no-codesign --no-pub --build-name=1.0.8 --build-number=1203 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`成功，Xcode80.1秒。
- 同参数`--profile`成功，Xcode63.3秒，68.0MB；实际Info为`cn.saydian.ring`、1.0.8(1203)、UIDeviceFamily=[1]。本轮未修改最低系统版本，保留SPM及微信模拟器架构警告。
- 两份均为无签名编译验证，不是可安装的开发签名包或App Store分发包。未使用其证明冷启动、调试附加或真机无线连接。

Android首次等待下载项目指定Gradle9.1.0，本轮中止仅自己的下载进程后，从官方地址断点恢复同一分发包。多次有限超时记录保留；最终SHA-256严格匹配原wrapper配置 `a17ddd85a26b6a7f5ddb71ff8b05fc5104c0202c6e64782429790c933686c806`，才放入本机缓存，未改wrapper版本。

Android Debug在线重试仍在恢复Maven依赖，超过本轮等待窗口后正常中止，仅取消本次构建。离线`:app:assembleDebug :app:testDebugUnitTest`10秒内明确失败：缺kotlin-compiler-embeddable2.2.20、kotlin-stdlib2.2.20、kotlin-reflect1.6.10的jar缓存。它们不是客户端源码编译错误，但本轮Android Debug、QA Release及JUnit门禁均不能记通过；没有交付或退用旧APK。

## 交付边界

本地代码合并及可执行的Flutter/宿主检查、iOS双模式编译已完成；Android原生构建仍待依赖恢复，不声明整体验收或发布完成。只提交当前开发整合分支供后续验证，不推进main，也不改变App Store/TestFlight。

用户随后明确“先苹果版本，安卓暂时不编译”，此指令优先于通用双端构建门禁：Android尝试与缺包结果只保留为此前记录，不继续编译或补跑；当前已无本轮Android构建进程。提交使用`[skip ci]`，避免推送再触发仓库的自动双端构建；不关闭仓库工作流或改变其他任务设置，也不把本机结果写成云端CI通过。

提交前再次fetch，当前上游仍为6f96c43、修复分支仍为6115305，无新的远端分叉。检查原iOS输入及原整合版Android/历史领域文件均保留，冲突列表为空，格式和差异检查通过。保留双父合并与本地检查点，只推当前整合分支，不强推或推进main。

私有下载/工具日志留忽略目录；原始素材、SDK压缩包和其它项目保持不动。未将原输入分支XR真机结果冒称本轮实测；自然断连、无缓存与长期稳定性仍沿用原待验边界。
