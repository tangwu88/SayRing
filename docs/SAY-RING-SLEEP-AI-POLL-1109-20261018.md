# 睡眠 AI 查询恢复及 iPhone 1108 / 1109 续检

## 范围和同步

用户先要求更新代码，随后要求检查睡眠 AI 报告一直等待并与服务端联调。仅修改 Say Ring，不变更审核、其他产品、账号、上传范围或戒指设置。
修改前 fetch 成功：当前分支与远端为 `d36e68c`，包含主线 `4dee4e6`，没有待合入的主线运行代码。保留三处已存在的相机指导修复，不合并其他发布分支。

客户端修改为 `sleep_ai_report_page.dart` 及其合成测试。恢复只调用 GET；生成、重新分析、授权及上传仍需原有明确确认。
另保留逐页检查发现的名称修复：`DeviceFeature.camera.label` 统一为“相机遥控”，手势说明引用该标签，不改 SDK 指令。

## 复现和修复

原 card / page 在 queued / generating 时每五秒查询；任意一次 GET 异常取消 timer 后不再刷新，页面可能保留旧的生成中状态。
先新增两条 card / page 恢复测试，均失败。补丁保留 90 次自动查询上限，连续三次读取失败即暂停；回前台、手动刷新或重新进入可以恢复。

状态或正文读取失败均有限恢复，不重新提交分析。无法确认报告状态时不显示“尚未生成”或创建按钮，避免重复创建。
读取失败、暂停及生成失败分别显示；沿用账号、设备、日期和生命周期代次校验，丢弃迟到响应。

## 服务端联调

已联系现有“导入-app服务端”任务，由其负责服务端仓库；双方不交叉修改源代码。
真实 iPhone 正常 Profile 1108 只读打开已有报告：加载完成、无读取错误；VM 字段为 `failed`、`generationAttempts=3`，提示“本次 AI 分析未完成，未生成评分；请稍后重试。”。

此样本已经失败，不是仍在生成。未点击生成、重试、授权或撤回，没有为本次诊断新增向第三方 AI 的真实数据上传，没有伪造评分。
Profile AOT 未保留的字段不推断为空。独立诊断使用控制器内存会话 GET 返回 401，不替代 App 自身正常读取的结果，也不能据此认定登录故障；凭据不落日志或 Git。

服务端任务回报生产 revision `a5013f2`，已有单次 120 秒、最多三次尝试、退避及失败终态，接口契约无需改变。
该任务的睡眠/授权/供应商定向 86 项、API 23 项、契约 19 项通过，均为合成测试，不代表真实第三方成功。全 Worker 首次 121/122，通过前仍有陈旧 commerce 构建失败，重建又遇本机 ENOSPC；不记全套通过。

初期尚无生产错误码，不把通用失败提示当根因。随后用户在服务端任务登录受控后台，服务端完成只读 HTTP 200 回读并提供脱敏汇总：五条睡眠报告全部 FAILED，当前 QUEUED / GENERATING 为零，失败码均为 `sleep_ai:provider_busy`。
四条累计尝试三次，另一条累计十一次；手动重试不清零累计值，不能据此推断突破每轮上限。均为 `aiGenerated=false` 且没有 generatedAt。

当前服务端将上游 HTTP 429 或 5xx 映射为该错误码。因此历史故障属于供应商繁忙/错误响应，不是当前队列仍卡住；现有记录无法区分具体状态码或 Retry-After。
后台没有测试连接入口，也没有受控服务器执行通道用于固定合成探针，未获得“当前供应商已恢复”的证据，不能宣称新的真实分析会成功。没有服务端代码、配置、模型、生产数据或部署变更。

脱敏只读证据由服务端任务保存于 `/tmp/saydian-sleep-diagnostics-pwdVXh/production-readback.json`。不因本机空间不足推断生产故障，不通过放宽评分解析或重置队列掩盖供应商错误。

## 1108 真机续检

实际 iPhone 15 Pro Max / iOS 26.6 / USB。安装前私有备份，开发签名正常 Profile 覆盖 1.0.2（1108），未卸载。
覆盖前后 Documents、Preferences 和数据库文件 SHA-256 一致；缓存与系统快照有变化，保留差异，不承诺完整 Keychain 恢复。

正常独立启动后原账号、资料、绑定和健康记录可读。R12（QRing，固件 `RT12_3.20.00_260730`）恢复精确绑定并新握手；不是三轮距离验收。
设备页连接正常，无已连接态重连按钮。健康监测加载完成并显示设置已同步，未写开关。手势说明正确显示“相机遥控”，未改模式。
首页与睡眠详情为同一保存样本，时间轴可打开真实分段起止与时长。没有新采集、原厂对照、小睡、充电、OTA 或拍照验收。

## 工具失败保留

一次指定 bundleId 的 WDA 会话即使 forceAppLaunch=false 仍试图启动根 App，导致当时 Debug 退出。随后只附加已安装 App，无卸载恢复。
改用无 bundleId 空根会话，只触摸已核对的前台 Say Ring。[官方 WDA 实现](https://raw.githubusercontent.com/appium/WebDriverAgent/v16.13.3/WebDriverAgentLib/Commands/FBSessionCommands.m)在 XCTest 判断根 App 未运行时仍会启动它。

旧点击端点 404 后改用 W3C 触摸；系统通知占前台时等待其自然消失，不操作通知或其他 App。
1107 增量热重载出现 ListenableBuilder 参数匹配错误，完整源码及测试未找到对应错误；正常 Profile 1108 未复现。具体增量编译原因未确认，不修改正确构造调用。

旧 LLDB 待退出确认时安装阻塞，一次过早启动返回旧进程；只有退出完成、安装成功、代理回读 1108 后的独立启动计为有效。
未用默认 flutter drive，不卸载、清库、退出账号或解绑。

## 检查和构建

1108 名称修复：格式化零额外变化；定向 6 项、双时区全量各 1259 项通过，分析零问题；桥接/策略 37 项通过，含主机 Foundation 91 断言及 Swift 类型检查。
1108 签名 Profile 64.9 秒、Debug 25.2 秒；Android 双 ARM Debug 316.7 秒。包名、版本、仅 iPhone、团队和开发设备均核对，不安装 Android。

1109 睡眠专项：新增两条复现先失败，修复后的睡眠页面及输入契约 28 项通过；含连续读取失败上限、正文失败及手动恢复，新增恢复用例断言零上传、零授权、零分析重试。分析零问题。
1109 首次 Profile 构建因磁盘满而失败，未用旧包冒充成功。同一时间服务端大构建已停止；核对 realpath / 无打开句柄后，仅删除本轮 Android `build/app/intermediates` 1.3 GiB 可重建缓存，保留 APK、冻结 iOS 包、源码及容器，空间恢复约 1.4 GiB。

文档首次写入也因磁盘满失败，释放上述缓存后重新创建。首次全量 Flutter 在同一磁盘满时段以 255 结束，日志未完成；不记通过，也不凭无错误尾行推断成功。已保留原日志并重跑。
实际全量、最终构建和安装结果见下文续验记录，失败与重试分开保留。
所有健康值、真实照片、唯一标识、认证路径、容器及原始日志仅保存在权限受限的忽略目录 `.build/ios-r12-pages-20261018-aSfDKv/`，不提交。

## 1109 续验记录

释放缓存后 Profile 重建成功，61.5 秒，59.3 MB；Debug 串行构建成功，57.6 秒。两者严格深验签通过：`cn.saydian.ring`、1.0.2（1109）、仅 iPhone、团队 W7SXQ4A226，开发描述文件包含本机。
冻结 Profile 后才构建 Debug，实际手机安装的是正常生产入口 Profile，不是 Debug 或测试替代页。

安装前分别保存运行中和停止后容器；精确核对前台 Bundle ID 与 PID 后只停止 Say Ring，再覆盖安装。InstallationProxy 回读确认 1109。
安装前后 Documents、Preferences 和数据库文件哈希一致；系统缓存有一处变化、快照有替换，保留完整差异。未卸载、清库、解绑或更换账号。

1109 独立启动首页正常，原账号头像昵称和真实睡眠概览可读。随后前台切到另一 App，UI 自动化守卫拒绝点击，暂停后续界面操作，不干扰用户、不把后台进程当作崩溃。
1109 的真实报告页回读及短暂断网后的端到端恢复尚未执行；有限恢复已由自动测试复现和验证，不能把合成测试当作真实供应商成功。

首次全量因环境退出未完成；释放空间后 UTC / Asia-Shanghai 两轮各 1264 项全部通过。37 项桥接/策略检查再次全部通过、无跳过；包括主机 Foundation 91 断言。
Android 1109 首次 Debug 构建找不到已消失的 Gradle 分发 JAR，失败 1.464 秒；重试中分发 ZIP 未找到，再失败 20.1 秒，Flutter 自动重试后恢复 Gradle。保留日志，未修改 Gradle 版本、依赖或原厂包；既有 Wrapper SHA-256 校验配置不变，实际成功记录见后文。

Gradle 冷恢复后编译完成，但本轮 Debug 在 `packageDebug` 再次因 ENOSPC 失败（496.6 秒），不是源码编译错误。重查仅余约 132 MiB。
没有其他 iOS / Flutter 编译且相关目录没有打开句柄，重新验签冻结 Debug 1109 后，仅删除本项目生成的 `build/ios/Debug-iphoneos`、`build/ios/iphoneos` 和 `.dart_tool/flutter_build`，约 1.7 GiB，可重建恢复。
保留冻结的 1108/1109 签名包、iOS 归档/IPA、真实数据副本、符号文件、原 SDK 和依赖锁；清理后约余 1.9 GiB，再次重试 Android 打包。未清理其他项目或全局 Gradle 缓存。

再次重试 Android Debug 成功，15.3 秒；APK 通过签名校验，aapt2 确认为 `cn.saydian.ring / 1.0.2 / 1109`、arm64-v8a 与 armeabi-v7a。独立冻结 QA Debug APK，不安装、不发布。
Android `:app:testDebugUnitTest` 成功，12 个 suite 共 53 项，零失败/错误/跳过；仅跳过已单独完成的 Flutter Debug 构建任务，不将该单元测试当作 Flutter 或真机验收。

Debug APK 和单测完成后，核对精确路径与无打开句柄，仅移除本项目 `build/app/intermediates/merged_native_libs/debug` 的约 963 MiB 可重建副本。保留原 SDK、stripped 产物和冻结 APK，空间恢复约 2.3 GiB。
随后执行双 ARM 内部 QA Release 构建；使用显式 `SAIDIAN_ALLOW_QA_RELEASE=true`，不作为正式分发包，实际结果如下。

QA Release 构建成功，110.3 秒，69.8 MB；签名及版本/双 ARM ABI 均核对为 1.0.2（1109），明确为 Android Debug 证书的内部 QA 包。原 SDK 构建副本核验 30 项未变，仅去掉映射输出规则。
为执行 Release 后 Debug 缓存回归，核对无打开句柄后仅移除 `merged_native_libs/release` 的约 349 MiB 中间副本，冻结 Release APK 保留。再次 Debug 成功，10.4 秒，并再次通过签名及原 SDK 副本核验。

结束时仍仅余约 121 MiB；全部构建结束、核对无打开句柄后再次清除本项目重新生成的 `merged_native_libs/debug` 963 MiB 副本。两种 APK、iOS 签名包及数据备份保留，不移除源 SDK 或发布档案。
格式检查五个修改 Dart 文件零变化，最终静态分析零问题（2.9 秒），`git diff --check` 通过。CI 仅测试/构建，不会自动上传或更改 App Store 审核。

## 同日继续：1109 真机只读恢复与当前上游拒绝

本轮起点为 `214e671`；fetch、干净工作树上的 main 快进检查均成功，没有新的运行代码。本轮只补联调记录，不重复构建、安装或改变审核。
该提交的主线 CI [39084279134](https://github.com/tangwu88/SayRing/actions/runs/39084279134) 和分支 CI [39084277619](https://github.com/tangwu88/SayRing/actions/runs/39084277619) 均为 completed / success。
主线 quality、Android、iOS 和双时区 Harmony 契约均通过。iOS 包括三种无签名构建及 RunnerTests 编译，不是实际 XCTest 执行、商店上传或真机业务验收。

InstallationProxy 再次核对实际 iPhone 15 Pro Max / iOS 26.6 / USB 上为正常 Profile 1.0.2（1109）、`cn.saydian.ring`；没有附加 Flutter Debug，旧 DevTools 地址不作为会话证据。
原账号、R12（QRing）连接和保存的睡眠样本仍可读。首页、睡眠时间轴和结构页使用同一样本；本轮不新增硬件采集、不改监测设置。

1109 实际睡眠页的 AI 卡从“报告读取失败，正在重试”变为“报告读取失败，点击刷新状态”，确认真实手机上的读取失败会停止自动重试。
只点击该卡读取已有报告状态：页面显示“网络不可用，请检查后重试”“暂时无法确认报告状态”，并进行有限的重新读取；没有生成分析按钮。
没有点击生成、重新分析、授权或撤回。未恢复到成功 GET 或报告正文，未人为切断网络，因此不记完整断网恢复或真实 AI 生成通过。

一次 AX 精确文字定位 20 秒超时，后续树查询也超时；期间只读前台回读为 SpringBoard，而 Say Ring 原 PID 仍存活，不能判作 App 崩溃。
先保存运行中容器副本，再前置既有 App；启动返回同一 PID。等待动画结束后确认 Say Ring 前台，改用已观察坐标和截图导航，不再查询 AX 树。
一次 Node 诊断脚本因混用 require / 顶层 await 失败，改为私有 mjs 后正常。收尾时前台守卫检测目标 App 不在前台，拒绝截图及点击，没有干扰其他界面。

Mac 对生产 readiness 的 curl / Node GET 在 TLS 阶段分别返回 SSL_ERROR_SYSCALL / ECONNRESET，没有 HTTP 状态；强制 IPv4 / HTTP1.1 仍失败。
只读代理设置无显式系统代理，DNS 返回合成地址；没有修改 VPN、DNS 或系统网络，也不能据此认定生产 API 停机或手机失败的确切网络原因。
该第一方读取失败与下述服务器侧供应商拒绝是两条独立证据，不能相互代替。

服务端任务随后在既有生产 Worker revision `a5013f254671d578f8bab95becfc371d192e50ce` 完成一次固定非健康文本连接探针：324 毫秒返回 HTTP 429、智谱业务码 1113，无 Retry-After、无正文结果。
[智谱官方错误码表](https://docs.bigmodel.cn/cn/api/api-code.md)将 1113 定义为“您的账户已欠费，请充值后重试”；[阿里云官方智谱接入文档](https://help.aliyun.cn/zh/model-studio/glm-zhipu)也列出相同含义。
具体业务码优先于通用 HTTP 429 分类：当前确认为供应商账户欠费拒绝，不应仅当并发限流等待。实际余额、合同及资源权益未查询，不推测具体欠费金额。

客户端文档工具打开智谱原文超时，服务端本轮直接读取官方原文为 HTTP 200；客户端另外读取阿里云官方错误表交叉核对，不将搜索摘要或社区文章作为结论。
探针脱敏证据独立保存在 `/tmp/saydian-sleep-diagnostics-pwdVXh/provider-live-probe.json` 和同名 PNG；历史只读报告快照保留，不能用当前探针替每条旧失败补写未记录的错误码。

此次未发送健康值或账号/设备标识，未创建/重试真实报告，未改数据库、配置、模型或供应商，未部署/重启/充值；拒绝后停止后续 AI 调用。
当前阻塞需账户所有者处理智谱计费/资源权益；处理后先做固定文本验证，再按用户明确确认的上传流程验收真实睡眠报告。仅连接恢复不算报告生成通过。
手机截图、容器、唯一标识及网络诊断保存在忽略且受限的 `.build/sleep-ai-followup-20261018-5lTI9t/`，不进入 Git。本轮文档差异检查通过，沿用同源码已完成的本地全量及远端 CI，不重复消耗构建空间。

## 同日后续：确认公共 HTTPS 入口故障

服务端任务收到后台打不开的新反馈，使用用户已登录的腾讯云终端完成服务器侧只读检查，并向客户端任务补充现场证据。
API、Admin、Postgres、Redis、MinIO 容器均 healthy，但宿主 `ss` 检查 80 / 443 没有监听；按已知 `saidian-gateway` 名筛选所有容器无结果。
服务器自身 curl `https://app.saydian.cn/admin/` 立即连接拒绝，已证明存在真实公共 HTTPS 入口故障。不能仅将报告 GET 失败归因于 Mac TLS、代理或客户端。

服务端另报 Mac 的 fake-IP 地址经 TUN，公有 DoH A 记录仍指向实际服务器；这是额外客户端链路因素，不抵消服务器无监听的证据，也不能说明入口已恢复。
内部容器 healthy 不等于公网可用；未知的是网关消失原因与恢复结果，不是是否存在公共入口故障。
以上为服务端任务回传的只读实测，客户端没有自行操作服务器；当前尚无恢复成功证据，不回写为已恢复，也不将两个故障合并为同一原因。

后续分开验证公共 HTTPS / admin 与 `/global/health/ready`、手机报告状态 GET，以及智谱计费处理后的固定文本连接；全部符合后仍须另验用户明确授权的真实睡眠报告生成。
网关定位和恢复由服务端任务在其既有授权范围处理；客户端仅补文档，不部署、重启、改网络或并行操作生产。AI 探针及真实报告继续保持停止。
本次文档基线 `01b6eb3`，fetch 和干净工作树快进检查成功；不改业务源码，不重复构建/安装/商店操作，文档 `git diff --check` 通过。

## 同日后续：网关恢复及客户端独立 GET 复核

服务端随后定位真实容器为 `saydian-gateway-1`，而非旧记录的 `saidian-gateway`。旧名筛选为空不能证明不存在其他名称的网关容器。
据服务端现场回报，该容器退出码 128，HostConfig 引用已不存在的 `saydian_default` 网络；这解释了当前启动失败，但未查明网络最初消失的原因或责任方。
原挂载配置在隔离 `nginx -t` 中通过，镜像 ID 未变。服务端在既有发布锁内用原 Compose、production.env / images.env，仅对 gateway 执行 `up --no-deps --no-build --pull never`，创建缺失网络并启动原网关。
没有重启 API、Worker 或数据库，没有修改模型、配置内容、维护开关或业务数据；这些恢复操作由服务端任务执行，客户端不交叉操作生产。

客户端本轮在同一 Mac 独立执行普通 GET：`https://app.saydian.cn/admin/` 返回 HTTP 200；`/health/ready` 和 `/global/health/ready` 均 HTTP 200、status=ready、database=ok，revision 均为 `a5013f254671d578f8bab95becfc371d192e50ce`。
此前同机 TLS 失败到本轮正常之间没有更改 DNS、代理或 VPN。fake-IP / TUN 不能作为本次服务器入口故障的充分根因；现在有公共入口恢复的实际 HTTP 证据，不再只凭容器 healthy 判断。
admin 入口 200 不代表已重新登录并逐页验证后台；readiness 通过也不代表真实 AI 报告生成成功。

手机前台守卫仍为 false，已拒绝截图和点击，没有切换其他 App、启动/重装 Say Ring。因此这轮未复验手机登录态报告 GET，不把公共 readiness 代替该验收。
智谱 1113 的计费阻塞独立保留，恢复后没有重启 AI 探针、授权、真实数据上传或报告重试。后续先处理计费并受控复验，再分别验收手机读取和明确授权的真实生成。
本次文档基线 `a8c0b02`；fetch 和干净工作树快进检查成功，`git diff --check` 通过。无业务源码/版本号变更，不重复构建、安装或改动商店审核。
