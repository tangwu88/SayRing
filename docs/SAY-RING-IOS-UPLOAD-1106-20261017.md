# iOS 1.0.2（1106）构建与上传

**最终上传状态（2026-10-17 18:13 CST）：1.0.2（1106）已成功上传，苹果后台已收到并显示“正在处理”。最新手势界面和滚屏分支在 Mac 双时区完整回归、iOS Debug/Profile、Release 归档及 Apple Distribution 分发签名核验均通过。处理完成、测试分发、Beta/App Store 审核和上架不等同于上传成功；本轮尚无这些后续完成回执。**

## 范围与源代码

- 用户要求“完成后，构建苹果新版本并上传”，同时明确安卓版暂不生成包。此次不构建 Android APK、不改 `/down2` 下载配置。
- 原主线 `4dee4e66d1afc362b9a5b8bf08ced603c91dde5a` 与已上传 1101 运行代码相同；远端最新手势/滚屏分支 `codex/ring-screen-scroll-20261017` 为 `df60205a4c01885e29e7c5255ef829fade53c724`。检查 status、remote、fetch，干净 main 的 ff-only pull 无新变更；读取 AGENTS、国际交接、最新实施记录、复盘和回归约定。
- 已给出代码范围选项，并告知按推荐项准备包含最新手势界面的构建；用户随后明确确认“纳入最新手势界面和滚屏改动”。本次冻结 df60205 为输入，不将该分支所有实体功能标记为已验收，不擅自把它快进为主线。
- 同机存在使用旧预编译二进制的 XR Flutter 调试会话。为避免修改其配置，使用独立 Git 工作树 `codex/ios-upload-1106`；没有停止、卸载或清理该会话及手机数据。应用托管工作树工具首次报 invalid reference，没有返回可用路径；改为在已确认 SayRing 仓库执行显式 `git worktree add`，源提交核对一致。
- 本次版本 **1.0.2（1106）**、Bundle **cn.saydian.ring**、团队 **W7SXQ4A226**、iPhone / iOS 15 起。用构建参数设置版本，不改继承的 pubspec 默认版本、应用身份或厂商 SDK。
- 包含最新手势控制页、独立使用说明和只读滑屏练习；QRing 继续真实能力、expectedMode CAS 和写后读回，Android 的 HID 配对实现不会移植为 iOS 系统输入注入。既有活动/睡眠、监测设置及专用 AI 授权范围不变。手动生理测量、生理指标展示/同步、医疗预警、疾病风险、通用 AI、设备睡眠评分继续关闭。
- 上游 HR05 的实体下滑仍未验收，本轮不把 UI、命令发送或主机测试替代该项；iOS 最新界面与实体手势、其他目标 App 的现场效果也未重新实测。既有 1101 的 R21 音乐确认不作为 1106 实体滑屏证据。

## 本轮实际验证

独立目录使用 Flutter 3.44.9、Xcode 27.0（27A266a）及现有锁定依赖；所有 iOS 构建串行，不清理其他目录。私有日志和产物在原工作区忽略目录 `build/ios-store-1106-20261017/`，不提交安装包、签名 Profile、密码、设备标识或健康记录。

| 命令 / 阶段 | 结果 |
| --- | --- |
| `flutter pub get --offline --enforce-lockfile` | 成功，1.5 秒；锁文件无变更 |
| `flutter analyze --no-pub` | 无问题，6.6 秒 |
| `TZ=UTC flutter test --no-pub --reporter expanded` | 1283/1283，39.5 秒 |
| `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded` | 1283/1283，30.8 秒 |
| `node --test tool/*.test.mjs` | 87 通过、1 跳过、0 失败，0.9 秒；不把跳过视为通过 |
| `node tool/test_ios_activity_sleep_policy.mjs` | 2/2，2.6 秒 |
| 首次 iOS Debug | 0.1 秒 / 退出 1，独立目录缺少被忽略的 `config/ios-app-store-no-push.json`，尚未开始编译 |
| 补齐原本机配置后的 iOS Debug | 40.8 秒 / 退出 0 |
| iOS Profile | 74.5 秒 / 退出 0 |
| Release config-only | 3.9 秒 / 退出 0 |
| Xcode Release archive | 67.4 秒 / 退出 0，`ARCHIVE SUCCEEDED` |
| App Store Connect export | 1.0 秒 / 退出 70，`No Accounts` 和无 Distribution 私钥 |

- 补齐配置时逐字复制原 1101 发布用的本机配置，JPush 仍禁用；不降低生产门禁。首次失败日志保留，后续从失败构建阶段续跑，不重复已通过的完整测试。
- 三种构建均用正常 `lib/main.dart`、`--no-pub --build-name=1.0.2 --build-number=1106 --dart-define-from-file=config/ios-app-store-no-push.json`。Debug/Profile 额外 `--no-codesign`，属于编译验证，没有部署手机或冒充正式分发包。
- Release 先 `flutter build ios --release --config-only`，再 `xcodebuild` Runner / Release / generic iOS / 独立 DerivedData / `-jobs 2` 归档。沿用已验证的 iOS 15 本机覆盖与自动开发签名，通过导出阶段转换为分发签名；不能把归档的开发签名说成 Apple Distribution。
- 归档路径为独立工作树 `.build/SayRing-1.0.2-1106.xcarchive`。实际 Info.plist 回读包名、版本、iOS 15 和 iPhone 设备族一致，严格 deep codesign 验证通过；Profile 团队 W7SXQ4A226、application-identifier 正确。归档 `get-task-allow=true`，尚未成功导出分发 IPA。
- 已核对本机仅有 Apple Development 签名身份；Xcode 命令行账号桶数量仍为 0。没有生成替代证书、提取令牌或绕过签名；本轮不重复此前已经失败的账号刷新/重启循环，直接请求使用此前有效的原生 Organizer 上传路径。

## 早期苹果后台核对与上传阻断

- 本轮只读核对 App Store Connect：既有 **1101 的 TestFlight 状态为已批准**，关联原内部/公开组；没有点击通知测试员。App Store **1.0.2（1101）仍正在等待审核**。Beta 批准不等于 App Store 批准或已上架。
- 已向 Xcode 打开今天 17:27 创建的 1106 归档，请用户核对版本、Bundle 和团队后选择 `Distribute App → App Store Connect → Upload` 并在原生窗口完成认证。打开命令返回 0 不代表已选中归档或上传成功。
- 后续须取得原生上传结果，并从苹果后台单独确认收到 1106、处理状态及合规。没有使用 1101 的成功回执作为 1106 证据；本轮没有撤回或替换既有 App Store 审核，没有修改商店资料、销售地区、推送通知或后台生产配置。
- 以上时点上传仍受阻；没有将当时状态写成已上传、已进入 TestFlight 测试或已提交新审核。后续恢复过程和最终回执见下文。

## 原生归档选择纠正

- 用户回复“正在上传”后，先观察到 Xcode 17:30 新分发日志、签名打包及上传步骤。最初仅凭日志时间把它当成本次流程的进展，尚未取得目标身份；这不能作为 Say Ring 上传证据。
- 随后对日志引用的临时 IPA 仅回读应用身份，实际为另一产品 `cc.saidian.app / 1.0.1（1025）`，立即停止读取该产品内容，告知用户并请求取消。没有复制、发布、删除该包或修改另一 App 的后台状态；原生误选不归入 1106 成功记录。
- 为减少选择歧义，将同一 1106 归档复制到 `~/Library/Developer/Xcode/Archives/2026-10-17/Say Ring 1106 2026-10-17 17.27.09.xcarchive`，只把归档容器 Name 改为 `Say Ring 1.0.2 (1106) — cn.saydian.ring`，不改应用内容或签名。复制后严格 deep codesign 再次通过，签名可执行文件 SHA-256 与原归档完全相同；Finder 已明确标出这份文件。
- 用户随后明确回复“已取消 1025 上传”。重新对标准目录中的 1106 严格 deep codesign 及 Info.plist 核验通过，向 Xcode 再次打开该归档，等待从正确归档发起 Say Ring 上传。后续只能按实际 `cn.saydian.ring / 1.0.2 / 1106` 的包身份和苹果回执核验，不能再以日志时间、上传中的口头状态或另一产品的成功回执替代。

## 账号恢复与正式分发包

- 用户确认选择原账号/团队及自动签名后继续。在 18:03 原生分发流程的实际 Root/Payload/Runner.app 中回读 **cn.saydian.ring / 1.0.2 / 1106 / Say Ring**，确认目标正确；只按这一流程继续诊断，没有把其他产品同时发生的分发日志作为本项目证据。
- 该次打包在为 `sqflite_sqlcipher.framework` 远程签名时失败：苹果返回 HTTP **404 / RESULTS_UNAVAILABLE / Error while generating code signature**，本地 DeveloperAPIServiceErrorDomain Code=5。此错误在 pipeline 日志，critical 日志为空不能据此视为分发成功。未移除数据库加密、改闭源框架或把错误猜测成应用功能缺陷。
- 再次通过 `defaults export com.apple.dt.Xcode -` 仅统计账号元数据，命令行已能读到 **1 个**开发者账号；不读取或保存登录凭据。此时接手命令行重试，未要求用户再次反复刷新/退出账号，也未重新编译应用。
- 同一原始 `.build/SayRing-1.0.2-1106.xcarchive` 使用既有 export-options（app-store-connect / automatic / W7SXQ4A226 / manageAppVersionAndBuildNumber=false）重试导出到独立 `1106-export-retry1`：**89.7 秒 / 退出 0 / EXPORT SUCCEEDED**。第一次导出和原生远程签名失败日志保留，不覆盖。
- 正式 IPA **38,060,835 字节**，SHA-256 **`57798df2c61bc9bd1a692df34fefff90358fc2b58c2c58eb96875b65514b5c1e`**。ZIP CRC、实际 bundle/版本/iOS 15/iPhone 设备族、严格 deep codesign 全部通过；实际为 **Apple Distribution**，团队 W7SXQ4A226、get-task-allow=false、beta-reports-active=true，无开发设备列表或企业 Profile。
- 分别比较正常 Runner 与 Flutter AOT App.framework/App 的 Mach-O UUID，均与本次源归档一致；不把旧版本、测试入口或仅匹配文件名的包作为本轮正式包。完整私有回执存 `verified-store-ipa.json`。
- 核验通过后，从同一源归档使用 destination=upload 的既有上传配置执行 `xcodebuild -exportArchive -allowProvisioningUpdates`。该流程会再次导出上传，不宣称上传重导出包与上述本机导出 IPA 逐字节相同；版本自动变更明确关闭。

## 最终上传回执

- 命令行上传 **198.1 秒 / 退出 0**，实际日志返回 **Uploaded Runner / EXPORT SUCCEEDED**。没有在成功后重复上传；所有前期失败与本次成功日志均独立保留。
- 上传有 **15 项厂商框架 dSYM 缺失警告**，不阻止本次接收，但会限制相关闭源框架的崩溃符号化；未将其记为零警告或修改厂商二进制。
- 18:13 CST 从 App Store Connect 的 **Say Ring / App ID 6816549943** 独立核对：上传记录为 **1.0.2（1106）/ 正在处理 / Oct 17, 2026 6:12 PM**。该行 ID 为 `bb8fb95f-f90b-46a5-9cb7-bf6e1f70c640`，不是另一产品或 1101 的回执。
- 正确应用的上传列表截图已保存并实际查看，清晰显示名称、1106 和正在处理；只留忽略的私有构建目录，未将会话、签名资料、安装包或个人记录提交公开 Git。`upload-receipt.json` 保存命令与后台两类证据，不能仅凭原生“正在上传”状态写接收成功。
- 本轮完成用户要求的构建与上传。苹果后续处理、出口合规、1106 测试组/公开测试或新审核尚未完成；未撤回/替换既有 1101 App Store 审核，未点击通知测试员或新增邮箱邀请，未更新 `/down2`、其他产品配置或 Android 包。
- 此次仅交付既有分支的 iOS 构建及记录，不重复没有运行代码变化的整套测试、不为上传安装手机或更改设备设置；未重新声明实体双向滑屏、其他固件或目标 App 已通过。
