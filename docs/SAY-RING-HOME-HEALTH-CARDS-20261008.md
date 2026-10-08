# 首页健康卡片编辑

- 用户要求参考卡片编辑图增加首页显示配置并重新打正式包。基线 fetch 成功 a9c889e4ea8fef21a25b5a6ff9258397679195d8，干净构建工作树创建 codex/home-health-cards-20261008；其它主目录用户改动不触碰。
- 范围：Flutter 首页健康数据区新增编辑入口、独立已显示/未显示列表、显示隐藏、长按手柄排序和显式保存；返回取消不保存。保持科技风配色，不影响全部健康数据、原始记录、测量/设备能力、AI、后台参数或接口。
- 偏好按环境与稳定账号 owner 保存在已有安全存储，游客独立；账号代次及修订号拒绝迟到读取/保存。只有保存成功才更新首页。未知/重复字段规范化；隐藏指标不删除数据或清除换设备后的设置。睡眠隐藏同时隐藏首页独立睡眠快捷卡，其固定位置不参与健康数据区排序。
- 编辑器只列既有 shouldShowHealthMetric 允许的真实历史/已握手能力，不补默认能力；全部隐藏使用准确空态。初次默认保持原顺序全显示。
- 涉及 home_health_cards.dart、secure_vault.dart、app_controller.dart、home_health_cards_page.dart、pages.dart 与测试。无服务端/数据库修改。预计 Android 正式 1016；本轮未要求安装，不执行手机安装或健康操作。Windows 不具备 iOS 构建条件；原生鸿蒙独立实现未修改/打包。
- 文件搜索误用了 Windows glob 参数和不存在的测试文件，均只读失败，已改为目录搜索。

## 验证与失败修复

- `dart format` 仅格式化本轮 Dart 文件；`flutter test --no-pub test/home_health_cards_test.dart --reporter expanded` 最终 9/9 通过。覆盖默认/损坏配置、隐藏/恢复与子集排序、环境/账号/游客隔离、重启恢复、迟到读取和账号切换中保存、保存失败不更新首页且明确提示、退出取消草稿、不支持指标不展示，以及 320px/1.5 倍字体的首页与编辑入口。
- 初次测试编译失败：测试夹具误用了 HealthRecord 的 timestamp/value，改为已有 measuredAt/values 及必需元数据；另修复 nullable 回调。第二次失败为测试环境 namespace 不是 SHA-256，改为合规合成摘要；均只影响新增测试。
- 首次全量分析失败于缺少 if 大括号和新 Flutter 废弃 onReorder；改为 onReorderItem（索引由框架调整）并更新测试。失败日志保留为包输出目录的 flutter-analyze-initial-failure.log。重跑分析无问题。
- 构建命令：`E:\saydian-release-signing\Rebuild-SayRing-20261006.ps1 -BuildNumber 1016 -OutputDirectory E:\SayRing-market-artifacts-20261008\cards-1016`。该受保护脚本串行执行 pub get、analyze、UTC/Asia/Shanghai 全量 Flutter 测试、Android 双 ARM Debug、原生单测、已有生产证书正式构建及签名检查。正式 APK 与机器日志只放仓库外，不提交密钥/产物。
- UTC 和 Asia/Shanghai 全量 Flutter 测试各 961/961 通过，分析无问题。
- Android Debug 首次失败为既有 QRing Gradle immutable workspace 内容校验，不是本轮 UI 编译错误。确认无其它构建、停止本次 Gradle daemon 后，校验精确路径并仅将 `gradle-home/caches/9.1.0/transforms/7d449599654a801d656c79251a8c1bc3/workspace` 移到仓库外 `cards-1016/qring-transform-quarantine/workspace`，可以恢复；不删除 SDK/宽泛缓存、不禁用校验。原失败日志保留为 android-debug-initial-failure.log；以同参数加 `-ResumeBuild` 重跑 Android 门禁。
- 补充 `python -m unittest discover -s scripts/release -p 'test_*.py'` 在 Windows 失败；提供 Git Bash 路径后仍无法执行 `/bin/sh` 的 Xcode 测试和 POSIX 路径的原子部署测试，未修改或绕过相关门禁。可在 Windows 执行的 `python -m unittest test_release_gate.ReleaseGateTest test_release_gate.PushConfigTest` 21/21 通过；POSIX/Xcode 项待兼容主机执行，无线上发布操作。
- Android Debug 重跑通过（70.7 秒）、原生测试命令成功（1m36s）、正式 Release 构建通过（319.7 秒，约 66.1 MB）。受保护 Verify-SayRingAndroid 校验 v2 签名、16KB zipalign、包名 cn.saydian.ring、版本 1.0.0/1016、targetSdk 36、双 ARM、生产极光 manifest 均通过。临时 key.properties 由原脚本清理，不改变发布证书。
- 正式 APK：`E:\SayRing-market-artifacts-20261008\cards-1016\SayRing-1.0.0-1016-release.apk`；SHA-256 `F67194877B1D3B186F5BDEDD9F96A7DB4F88F8A46E2D1686C5B8375F43425B2E`。证书 SHA-256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`，证书 MD5 `09d14504fd119ae833b2aaaaeecc13fe`。
- 构建期间曾提前读取尚未产生的 production-build.log，属只读文件不存在错误，之后检查 Test-Path 再读取。源码未改动。
- `E:\saydian-release-signing\Verify-SayRing-20261006.ps1 -BuildNumber 1016 -OutputDirectory E:\SayRing-market-artifacts-20261008\cards-1016` 最终 ABI/依赖锁与原生测试复核通过：32/32 原生测试无失败/跳过、双 ARM，通过既有锁定 JPush/libjutils arm64-only 受控例外；APK 69,323,534 字节，临时 key.properties 确认不存在。
- 提交前 fetch 成功，HEAD/origin/main 仍为基线 a9c889e；git diff --check 无错误（文档 CRLF 提示不影响内容）。只暂存本轮 6 个 Dart 源/测试文件及 2 个文档；按项目交付约定非强推当前分支和 main，然后 fetch/ls-remote 验证相同提交，实际提交 SHA 以 Git 和交付消息为准。
- 提交后的再次直连 fetch 两次失败（Empty reply / Connection reset），尚未执行推送；改用本机已有 HTTP 代理 `git -c http.proxy=http://127.0.0.1:7897 fetch origin --prune` 成功，确认 main 未变化。只使用单次 Git 参数，不改账户或全局配置。
- iOS Debug/Profile/真机和原生鸿蒙本轮未执行；本轮不操作手机、不部署后台，不把 widget/模拟接口测试当成真机验收。页面已做窄屏 widget 检查，真实设备交互与市场审核仍待验收。
