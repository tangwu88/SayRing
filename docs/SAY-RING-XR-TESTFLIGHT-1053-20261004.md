# Say Ring iPhone XR：1053/1054 TestFlight 替代安装

## 范围

- 用户要求在 XR 设备注册仍为 Processing 时寻找其他正常安装方式。仅 Say Ring，保留 cn.saydian.ring，不绕过签名、不卸载、不更换包名，不改现有 App Store 审核所选构建。
- 基线 c646edf，fetch 后当前分支与远端一致。运行时代码和原厂 SDK 未变；沿用已经完成双时区 1186 项及双端回归的 1053 源码，不把旧版 1016 当最新版。
- XR 已通过 USB 连接，开发者模式开启，锁状态读取为 passcodeRequired=false；应用列表没有 Say Ring 或 TestFlight。开发签名 / Ad Hoc 仍受苹果注册处理限制。

## 正常替代路径

- 采用苹果 TestFlight 内部测试。已创建“Say Ring 真机验证”内部群组，自动分发关闭；只添加当前已具备完整 App 访问权限的账户持有人，没有邀请其他人员或扩展任何人的角色权限。
- 群组创建与成员加入成功，初始为 1 名测试员 / 0 个构建。需加入处理成功的 1053 后才能安装，不把“群组已建”当作手机安装成功。
- 通过 App Store Connect 集成页核对现有团队上传密钥和真实 Issuer，再使用现有密钥；只读 API 对 Say Ring 返回 HTTP 200 和正确包名。此前旧记录将该密钥当作个人密钥及未验证 Issuer 的 401 不能代表此刻团队密钥不可用；本轮不新建、撤销、公开或扩大密钥权限。

## 构建、签名与校验

- 构建：flutter build ipa --release --no-pub --build-name=1.0.0 --build-number=1053 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY= --export-options-plist=.build/SayRing-1.0-1012-review-candidate-export/ExportOptions.plist。
- 使用既有 Production / 手动 App Store 分发签名及已批准的无推送设置，没有关闭生产门禁或改用 QA 签名。串行 archive 60.0 秒、IPA 导出 7.3 秒成功；归档显示 265.3 MB，导出显示约 41.2 MB。
- 实际 IPA 为 40,815,860 字节，SHA-256 909280518fc8f2627b24bc5802820f42992a5dc17da0f613935e331627d32c65；私有副本 .build/SayRing-1.0.0-1053-TestFlight.ipa。
- 归档 App 和导出 IPA 解包后的 App 均 codesign --verify --deep --strict 通过。实际包名 cn.saydian.ring、1.0.0 / 1053、UIDeviceFamily [1]，App Store Distribution profile、get-task-allow=false、beta-reports-active=true。
- 读取旧记录使用过的 SaidianWechatEnabled Info.plist 字段失败（当前文件无该键），未据此宣称新包微信入口状态。没有修改当前登录逻辑。
- Python 发布门禁全量 31 项通过（8.140 秒）；bundle 工具 Node 3 项通过。运行时代码未变，本轮不重复前一轮完整 Flutter / Android 构建；只增加这次正式签名 Release 归档、导出和苹果服务器验证证据。
- altool --validate-app 返回 VERIFY SUCCEEDED：0 errors / 1 warning；warning 90068 是从 2027 年 4 月开始需 iOS 15 的未来最低目标要求，目前 iOS 13 目标未被拒绝。本轮未为消除未来警告随意改最低版本。
- Flutter 还提示 SPM 插件兼容、WeChat 模拟器 arm64 和旧 LaunchImage 占位资源；实际 archive 与导出成功。启动 LOGO 的现有 storyboard 未在本轮修改，不能仅凭通用资源警告断言真机仍白屏。

## 上传与处理

- altool --upload-package 返回 UPLOAD SUCCEEDED：0 errors / 1 warning；2026-10-04 13:14:39（本机时间）完成，传输 40,815,860 字节 / 4.036 秒。只上传 TestFlight 候选，没有改绑 App Store 审核版本、重新提交或撤回审核。
- 上传后首次只读查询 /v1/apps/{id}/builds 使用该路由不支持的 sort 参数，返回 HTTP 400；移除 sort 后 HTTP 200，初次尚未出现 1053。这是“上传成功但后台处理尚未可见”，不是上传失败，不重复发送同一构建。
- 处理状态、加入测试组和邀请状态以之后的实际回读追加；没有新健康数据、账号凭据或手机数据上传到 Git。日志、密钥路径、API 私有回读、IPA、归档和截图仅保留在忽略目录。

## 1053 后台失败与 1054 修复

- 1053 本机校验和上传成功，但苹果后续处理失败。UI 的两条 90683 明确指出缺少 NSHealthShareUsageDescription、NSHealthUpdateUsageDescription，不能把传输成功当作可测试构建。
- 只读 nm 确认已打包的 CoolWear BluetoothLibrary.framework 引用了 HKHealthStore、HKSampleQuery、HKQuantitySample 等系统 HealthKit 符号；本 App 原生代码没有 HealthKit 读取/写入调用，两个 entitlement 文件均未启用 HealthKit。原 SDK 不修改，不通过伪造开放健康功能来修复。
- 修改 Info.plist 与 8 个现有 InfoPlist.strings：准确说明 SDK 包含健康读写接口，本版本不读写 Apple 健康数据，拒绝不影响戒指功能。新增两个发布门禁测试，检查基本用途、全部语言唯一条目、英文一致及没有新增 HealthKit entitlement。
- 仅为修复已获授权的最新包正常安装递增到 1054；登录、绑定、数据、云接口、SDK、权限请求流程和现有审核包保持不变。新构建与后台处理结果按实际执行追加。

## 1054 回归与构建证据

- Info.plist 及全部 8 个 InfoPlist.strings 的 plutil -lint 通过；git diff --check 通过。Python 发布门禁 33 项（8.348 秒），Node 22 项，Foundation CoolWear / QRing 合成策略测试均通过；不作为硬件数据证据。
- flutter analyze --no-pub 4.8 秒零问题。TZ=UTC / TZ=Asia/Shanghai flutter test --no-pub --concurrency=1 各 1186 项，分别 115 秒 / 112 秒通过。
- ./gradlew :app:testDebugUnitTest --max-workers=1 成功 8 秒；XML 汇总 48 tests / 0 failures / 0 errors / 0 skipped。首次误查 android/app/build/test-results 返回路径不存在，按实际构建输出改查 build/app/test-results，未跳过统计。
- 相同生产 API / build 1054 的 Android Debug / 内部 QA Release 编译分别 11.1 秒 / 46.4 秒通过，QA Release 69.5 MB；未替换安卓手机当前 1053，未当作市场正式签名。
- iOS 串行 App Store Release archive 61.2 秒 / export 8.1 秒，另 Debug / Profile unsigned 编译 30.5 秒 / 71.7 秒通过；Profile 66.3 MB，仅作编译回归，不能安装 XR。全部生产入口未更改。
- 新 IPA .build/SayRing-1.0.0-1054-TestFlight.ipa：40,816,920 字节；SHA-256 1284d290dde4396e7223bf3e78c646d2d5ab7e910a74e35e583386ea9d36e566。1053 IPA 和原 archive 保留，不丢弃失败证据。
- 新 archive 和导出 IPA 解包后的 App 均 codesign --verify --deep --strict 通过。实际 cn.saydian.ring / 1054 / UIDeviceFamily [1]，两个健康用途说明及简体中文翻译均存在，get-task-allow=false、beta-reports-active=true，实际签名 entitlement 无 HealthKit。
- 1054 altool --validate-app 在 13:28:04 返回 VERIFY SUCCEEDED / 0 errors / 1 warning，仍是 90068 的未来最低 iOS 版本提醒。最终后台处理需另外核对，不把该校验当作处理通过。
- 1054 altool --upload-package 在 13:30:39 返回 UPLOAD SUCCEEDED / 0 errors / 1 warning，40,816,920 字节传输 2.844 秒；既有 TestFlight 群组保持人工选包，未替换当前审核构建。
- XR 只读应用查询明确增加 --include-default-apps 并按精确包名查询，修正默认只列开发 App 的遗漏风险；结果有 App Store，没有 TestFlight 或 Say Ring。使用 devicectl --payload-url 请求 App Store 打开官方 TestFlight 页面，命令成功启动 App Store；未自动点击获取、接受条款或声称下载已完成。

## 安装边界

- TestFlight 安装需在 XR 上使用苹果官方 TestFlight App 打开测试邀请。此分发包不能用 devicectl 直接当开发包安装，也不能用于 LLDB / Flutter Debug 附加。
- 本轮尚未从 XR 应用清单核对到 1053；尚无安装、冷启动、登录、戒指连接和手势功能的 XR 真机通过证据。
