# Say Ring App Store Connect 上传：1059

## 范围和基线

- 2026-10-05，用户要求上传最新构建。目标为 Apple App Store Connect 的 Say Ring（6816549943），固定包名 cn.saydian.ring。
- 基线 4fd0568a09b43370c8640d4b2bc24619b578f685，分支 codex/macos-update-20260930。开始时工作树干净；fetch / ff-only pull 确认已最新。线上最新有效构建为 1055。
- 运行时代码不变，沿用 1059 重连修复源码。只上传新的发行候选，不修改现有审核所选构建，不重新送审、撤回或宣称已上架；不改其他 App、服务器、销售地区、测试组或账户权限。

## 检查与构建

- 上一轮同源码的静态分析、双时区各 1196 项 Flutter 测试、Android 原生 51 项及双端构建见 [1059 重连记录](SAY-RING-IOS-RECONNECT-1059-20261005.md)。本轮不修改代码或以发行归档替代硬件验收；真实远离、后台、HR01 和原缺回调现场仍待验。
- 重跑 `python3 -m unittest discover -s scripts/release -p 'test_*.py'`：33 项通过，10.896 秒。预期负例错误输出不代表整套失败。
- 最初 `node --test tool/test_bundle_ios_ipa.mjs` 因文件不存在失败，记录保留；纠正为 `node --test tool/measure_ios_bundle.test.mjs` 后 3 项通过，50.813542 毫秒。
- 串行执行 `flutter build ipa --release --no-pub --target=lib/main.dart --build-name=1.0.0 --build-number=1059 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY= --export-options-plist=.build/SayRing-1.0-1012-review-candidate-export/ExportOptions.plist`：archive 81.5 秒，导出 8.1 秒，成功。
- 使用既有生产 /global 配置、手动 App Store Distribution 签名；无 QA、签名绕过或集成测试入口。Generated.xcconfig 确认 lib/main.dart，既有用户批准的推送关闭设置未变。
- Archive App 和 IPA 解包 App 均 `codesign --verify --deep --strict` 通过。实际 cn.saydian.ring / 1.0.0 / 1059，UIDeviceFamily=[1]；分发描述文件 Say Ring App Store Distribution，get-task-allow=false、beta-reports-active=true。
- 两个 HealthKit 用途说明存在，无 HealthKit entitlement。供应商 SDK 警告不等于本版本读取 Apple 健康数据。
- 产物私有副本 `.build/SayRing-1.0.0-1059-AppStore.ipa`：40,838,173 字节，SHA-256 a248da93c29b901df794040bc3f251e2d64483695237e6579cf784aed1746d9c。
- 未瘦身 App 48,404,282 字节；本地 IPA 约 41 MB，不作为实际 App Store 下载大小。Flutter 的 SPM、WeChat arm64 模拟器兼容和旧 LaunchImage 占位提示保留；既有启动 storyboard 未改，不根据通用警告断言实机白屏。

## 苹果校验和上传

- `xcrun altool --validate-app` 使用既有团队 API 密钥，2026-10-05 09:54:08（本机 CST）返回 VERIFY SUCCEEDED，0 errors / 1 warning。
- 90068：从 2027 年 4 月起上传需最低 iOS 15，本包当前最低 iOS 13；本次未被拒绝。未为消除未来提醒随意提高用户最低系统要求。
- `xcrun altool --upload-package` 使用既有密钥上传精确 IPA；随后工具等待中断，续接时原进程已退出，日志没有最终 UPLOAD SUCCEEDED，不能编造该命令退出码或传输时间。
- 2026-10-05 10:01 后实际 App Store Connect UI 已出现 1.0.0 (1059)，创建时间 09:58，状态“正在处理”，证明苹果收到了本包。同期公开 API builds 精确过滤仍为空，是尚未生成可用 Build 实体，不能当作上传失败。没有重复发送。
- 上传详情只有警告：90068 最低系统未来要求，以及 90683（原厂 SDK 引用后台定位 API，缺 NSLocationAlwaysAndWhenInUseUsageDescription）。本轮未新增后台位置模式或权限；警告不是处理失败，但需保留后续审查事项，不宣称全部警告消除。
- 密钥、签名详情、私有日志、IPA 和截图仅在忽略目录；不提交设备标识、照片、凭据或健康数据。

## 验收边界

- 上传传输、苹果处理、可测试、审核通过和公开上架分别核对；本轮不自动绑定审核版本或邀请测试员。
- 正式分发包不是手机开发调试包，本轮没有覆盖手机、卸载、解绑或清空数据。
