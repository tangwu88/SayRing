# Say Ring 客户端整理与 iOS 包体积

## 范围与结构

- 基线 `3bee2fb994f74908e1f56732f98275d442abd3e8`，已 fetch、干净工作树 ff-only 回读一致。仅 Say Ring，iOS 优先，Android 本机打包后置；账号、绑定、数据库协议、所有 SDK 与现有审核不变。
- `pages.dart` 原 12277 行。百科、消息拆成独立库；登录、首页、健康、运动、设备、关爱兼容、个人、订单及设置按功能拆分为 library parts，保留旧入口/私有共享行为，不大改状态架构。提取共享提示组件和原样 HTML 文本清理，移除确认无引用的私有状态卡。
- 调整 Profile/Release Runner 的测试导出与构建后符号裁剪；Debug 原生测试保留。保留外部符号、Objective-C 元数据和 dSYM，不手工删 SDK 或 Framework，不移除运行时能力。检查 dSYM 与实际 Mach-O UUID 一致。
- 仅从 Flutter 打包清单移除已确认无运行引用的品牌锁定图，原图片文件保持只读。无损压缩先在本机试验，只有确证有收益且像素完全一致才采用，不通过降画质或删除功能虚报减小。
- 补可重复的 iOS bundle/IPA 字节统计和模块维护说明。代码分文件本身不承诺减包；只比较相同 Profile 构建配置，App Store 用户实际下载大小须由分发后的 thinning 报告确认。

## 基线与验证

- 1038 已留存签名 Profile app/IPA，独立安装证据见前一轮；本轮不把它当新代码验收。原主程序 `__LINKEDIT` 为 6586368 字节、Profile `ENABLE_TESTABILITY=YES`；关闭测试导出和符号裁剪的实际收益以重构后构建为准。
- 当前无本机 Flutter/xcodebuild/Gradle 任务，构建前可用空间 8.1 GiB，iOS 构建与全量测试串行。所有失败、修复、测试和实际包字节数继续追加。
- 手机上前轮存在用户正在输入的关爱表单；安装前只读确认，未保存输入仍在时不重启、不覆盖、不提交邀请，不伪报逐页通过。

## 开发模块入口

- `lib/ui/pages.dart` 现在是 55 行兼容入口；旧页面引用无需迁移。页面实现位于 `lib/ui/pages/`，按 auth、dashboard、health、sports、ai、devices、profile、settings、commerce、legacy_care 和 shared 分组。
- content、notifications 是独立库；共享提示在 `widgets/inline_notice.dart`，HTML 文本清理在 `html_text.dart`，API 图片 URL 解析在 `media_url.dart`。功能改动优先进入对应模块，不把业务逻辑重新塞回入口。
- 其他页面组暂用 `part` 保留同一 library 的私有访问；不是完全独立的依赖边界。继续拆分时，先把共享状态/组件抽成显式依赖，再转独立库，不为消除文件依赖改写连接和账号状态机。
- `app_controller.dart` 继续负责应用状态；原有 SDK 路由、各厂商 bridge、健康投影、加密存储、远程只读数据源保持原文件和协议。本轮不做未经验证的全局状态框架迁移。
- 源码品牌/文案审计现在递归读取本库的 local part/export，防止移动文件后测试假通过；新增旧入口类型一致性、共享 HTML/提示及打包契约。CI 增加包体积工具/构建设置检查，Debug RunnerTests 仍可使用 `@testable`。

## 资源与包统计

- 原 AI 图片保留，使用独立无损优化派生图。原图 1100372 字节，派生图 1005851 字节，减少 94521 字节；928×1695 完整 RGBA 字节逐一一致，不裁切/降画质。原图 SHA-256 和锁定图 SHA-256 已加入契约，不允许无意覆盖素材。
- `tool/measure_ios_bundle.mjs APP_PATH IPA_PATH Profile|Release [BASELINE_JSON]` 只读统计精确字节，区分 Runner、Flutter engine、Dart app、厂商 framework、Flutter assets 和其他文件；不跟随符号链接、不把 Debug 当减包基线，不跨构建模式比较。
- 1038 基线：app 66201103 字节、IPA 25456543 字节、Runner 14602832 字节、Flutter assets 1542294 字节。具体手机/包名/SDK必须人工核对一致；该工具不冒充 App Store 安装/下载大小或功能验收。

## 过程失败与纠正

- 第一次自动生成移动补丁使用相对路径，apply_patch 以工作区而非仓库为基准，失败且未修改源码；改为仓库绝对路径。第二次运动模块的结束标记已随健康模块移走，停止该补丁后改用当前源码标记。AI 移动补丁 trimEnd 导致空行不匹配，改为逐行保留完整区间；过大的合并补丁被输出上限截断，未应用，改为分模块补丁。未使用覆盖文件绕过失败。
- 拆分后初次 Analyzer 发现原私有图片 URL 函数跨百科/订单共享、独立库缺少 locale 扩展以及入口缺少消息 import；提取同一 URL 解析并补明确依赖，删除真正无用 import，复查无问题。
- QRing Foundation 命令误引用不存在的 `QRingRecordMapper.m`，编译失败且没有产生测试结果；此测试使用头文件内联实现，改用实际 `test/native/qring_record_mapping_test.m` 编译，PASS。CoolWear Foundation 策略测试 PASS；两者是合成边界测试，不是硬件验收。
- 定向 Flutter 31/31、首轮 UTC 全量 1141/1141、Node 原生/隐私/统计契约 25/25；后续最终资源版全量、构建和实际尺寸继续追加。

## 最终资源版验证与 1039 Profile

- 加入 Flutter 解码器像素一致性回归后，模块契约 5/5；最终 UTC 和 Asia/Shanghai 全量各 1142/1142。全 lib/test 格式检查零改动、Analyzer 无问题、git diff --check 退出 0；Node 契约 25/25、发布 Python 测试 31/31、shellcheck 与 bash -n 通过。
- 119 个原页面/组件类核对完整；仅删除无引用 `_StatusCard`，共享 `_InlineNotice`/`_ArticleTile` 改为显式公共组件。SDK bridge、账号、健康存储和依赖锁文件未改。
- 1039 Profile 串行构建 44.2 秒成功，生产 API `https://app.saydian.cn`、JPUSH_APP_KEY 为空（保持现状）。codesign deep/strict 通过，cn.saydian.ring / 1.0.0 (1039) / UIDeviceFamily=[1]；开发签名 get-task-allow=true，不是 App Store 分发包。
- Runner 的 __LINKEDIT 从 6586368 降到 629344 字节；实际 Runner 从 14602832 降到 8542816 字节。dSYM 和 Mach-O UUID 均为 `5F804609-5199-3622-AC45-3CDE6184734C`，原 1038 符号也已保存到忽略目录。
- 同为 Profile、相同 Info-ZIP 压缩等级的新 IPA 为 24067386 字节（22.95 MiB），基线 25456543 字节（24.28 MiB），减少 1389157 字节 / 5.46%。未压缩 app 从 66201103 到 59929196 字节，减少 6271907 字节 / 9.47%；Flutter assets 减少 211889 字节，厂商 framework 与 Flutter engine 字节数完全一致。
- 新包 `.build/SayRing-1.0-1039-Profile-debug.ipa`，unzip -t 完整性通过，SHA-256 `f39ed97aa03e6ce3c218f0e5c3eb85b22d6ef677d48c8aca335a5c91e05a3839`；比较结果 `.build/1039-size-comparison.json`。压缩变化不冒充正式商店包或用户实际下载变化。
- Xcode 只读回读当前手机仍为 1038，截屏发现用户正在另一 App 操作；不切换、不强启、不提交表单，1039 真机安装/冷启动尚未做。Debug、原生 XCTest 编译与 QA Release 构建后续串行补充；现有审核保持不动。

## Debug / 原生编译 / Release 边界

- 1039 Debug 签名构建 35.5 秒成功，deep/strict 验签和留存 ZIP 完整性通过。`xcodebuild -configuration Debug -sdk iphoneos -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build-for-testing` 返回 TEST BUILD SUCCEEDED，证明原 `@testable import Runner` 可编译；未在忙碌手机执行 XCTest，不写运行通过。
- 初次 `SAIDIAN_ALLOW_QA_RELEASE=true flutter build ios --release --no-codesign` 因本机未提交的 Local.xcconfig 对 Release 固定正式模式而失败：Production iOS Release cannot disable code signing。正式签名门禁按预期生效；不删改 Local.xcconfig、不修改发布校验脚本，不为无签名构建放宽正式发布约束。
- 串行重试改用 Xcode 命令行明确 `SAIDIAN_PRODUCTION_RELEASE=false SAIDIAN_ALLOW_QA_RELEASE=true CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`，覆盖仅本次 QA 构建；使用 Flutter 已生成的 Release 1039/生产 API 编译配置。结果后续追加。
- 工具补充损坏基线校验后最终 Node 契约 26/26。Flutter 插件提示既有 CocoaPods/SPM 迁移及 WechatOpenSDK Apple Silicon 模拟器架构不支持；本轮为真实 iPhone arm64 编译，不通过删 SDK 消除提示，后续插件升级需独立回归。
- 本机 Android 构建/安装按用户最新优先级后置；共享 Flutter 回归已执行，原有 Android CI 不移除。CI 新增结构/包统计工具契约，但远端本次流水线尚待提交触发，不能冒称已通过。

## 交付收尾

- 明确隔离的 QA Release Xcode 重试最终 BUILD SUCCEEDED；记录 `.build/client-cleanup-1039-qa-release-xcode-retry.log`，其中命令行参数证明 Production=false、QA=true。这是无签名编译回归，不是正式 Release 上架验收，也未上传或改变本机正式签名配置。
- 最终源代码与构建信息同步核对：所有 32 个暂存文件都属于本轮，无 `.build`、本机签名配置、真实截图、健康数据、凭据或验证包进入 Git。提交前再次 fetch，当前分支远端仍为基线 `3bee2fb`，无需覆盖/强推其他改动。
- 1039 Profile 签名验证包和配对 dSYM 留在 `.build/1039-profile/`，手机仍保留 1038；用户操作中没有覆盖安装或启动新版本，不把自动测试、符号裁剪或编译通过冒称真机逐页/固件验收。
