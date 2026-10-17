# iOS 1.0.2（1106）构建与上传准备

**当前状态：Mac 双时区完整回归、iOS Debug/Profile 编译和签名 Release 归档通过；App Store Connect 导出因 No Accounts 与缺少本机分发私钥失败。1106 尚无上传成功回执，已打开新归档并请求用户通过 Xcode Organizer 完成上传。**

## 范围与源代码

- 用户要求“完成后，构建苹果新版本并上传”，同时明确安卓版暂不生成包。此次不构建 Android APK、不改 `/down2` 下载配置。
- 原主线 `4dee4e66d1afc362b9a5b8bf08ced603c91dde5a` 与已上传 1101 运行代码相同；远端最新手势/滚屏分支 `codex/ring-screen-scroll-20261017` 为 `df60205a4c01885e29e7c5255ef829fade53c724`。检查 status、remote、fetch，干净 main 的 ff-only pull 无新变更；读取 AGENTS、国际交接、最新实施记录、复盘和回归约定。
- 已给出代码范围选项，并告知按推荐项准备包含最新手势界面的构建。本次冻结 df60205 为输入，不将该分支所有实体功能标记为已验收，不擅自把它快进为主线。
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

## 苹果后台与待完成项

- 本轮只读核对 App Store Connect：既有 **1101 的 TestFlight 状态为已批准**，关联原内部/公开组；没有点击通知测试员。App Store **1.0.2（1101）仍正在等待审核**。Beta 批准不等于 App Store 批准或已上架。
- 已向 Xcode 打开今天 17:27 创建的 1106 归档，请用户核对版本、Bundle 和团队后选择 `Distribute App → App Store Connect → Upload` 并在原生窗口完成认证。打开命令返回 0 不代表已选中归档或上传成功。
- 后续须取得原生上传结果，并从苹果后台单独确认收到 1106、处理状态及合规。没有使用 1101 的成功回执作为 1106 证据；本轮没有撤回或替换既有 App Store 审核，没有修改商店资料、销售地区、推送通知或后台生产配置。
- 上传是当前唯一外部阻断；记录保留为待完成，不写已上传、已进入 TestFlight 测试或已提交新审核。
