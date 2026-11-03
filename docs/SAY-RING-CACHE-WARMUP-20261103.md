# 当前Android开发目录缓存重建

2026-11-03，Asia/Shanghai。用户针对“下次打包会自动重建缓存，首次编译可能稍慢”的说明，明确要求提前重建缓存。

## 版本、范围与边界

- 本轮仅预热当前Windows实际开发目录E:\SayRing-market-release-20261005，源码HEAD为edd8d2c72191ad10ffba9a53b7b15bee60c09c57、对应当前已交付Android1.0.10(1231)。保持原手机与交付APK，不安装、发布或切换业务版本。
- 修改前读取AGENTS、交接、最新记录、复盘与回归清单并核对status/fetch。远端已多出6ab7e00功能修复；用户本轮只要求重建缓存，不将新功能混入本轮构建，也不将6ab7e00当作已在此电脑编译或真机通过。
- 仅当前项目重建编译中间文件、Flutter构建和测试缓存；旧工作副本保持清理状态。源文件、Git历史、签名、SDK与历史归档均保留。19点前只读进程检查未见正在执行的Gradle/Flutter构建。
- 依赖解析使用现有离线缓存；Gradle2GiB堆、单worker、UTF-8只作用于Git外私有包装脚本，原签名脚本和项目配置不修改。Debug/Production Release均用原CLI版本1.0.10/1231预热，Release签名临时文件仍由finally清理。
- 既有正式交付E:\SayRing-market-artifacts-20261103\android-release-1231\SayRing-1.0.10-1231-release.apk的基线SHA256为bd1e41adc73dec89fbbc96bcdf040308a7bc46546009b9eedc17f93b871b5a19，必须保持。
- Windows不具备本机iOS/Xcode缓存预热能力；本轮不宣称iOS/Harmony原生重建。单个产品身份测试用于建立测试编译缓存，不冒充重新执行完整1851项回归或关闭已知缺陷。

## 执行与结果

- 私有过程/日志/预热产物在E:\SayRing-cache-warmup-20261103。flutter pub get --offline通过（8.3秒），Debug/Release/产物门禁/测试缓存按顺序执行，结果完成后补记。
- 为不改变当前开发目录的业务版本或造成其分支分叉，操作记录使用同一Git仓库的独立稀疏文档worktree和codex/cache-warmup-20261103分支，仅记录操作。初次no-checkout后稀疏索引尚未读入，status显示缺失；在全新空记录目录执行read-tree -mu HEAD初始化后清洁，仅物化docs。没有对当前项目执行reset/clean或删除源文件。

## 完成回执

- Debug正常构建通过（包装294.1秒、Flutter Gradle任务290.8秒），Production Release通过（包装396.6秒、Gradle383.6秒）。新产物签名、包名/版本、生产Manifest、ABI和对齐门禁通过（7.9秒）；不将原有ARM32库对齐限制或已知业务问题冒充关闭。
- flutter test --no-pub --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn test/product_identity_test.dart实际6项通过，用时20.4秒，build/test_cache已生成。没有重复执行完整业务测试或进行真实戒指、照片、支付、AI或健康上传。
- 源码HEAD仍edd8d2c，git diff HEAD -- lib android ios pubspec.yaml pubspec.lock config零差异；build/app/intermediates、.dart_tool/flutter_build、build/test_cache均实际存在。临时key.properties已清理，原正式交付APK的完整SHA256仍为bd1e41adc73dec89fbbc96bcdf040308a7bc46546009b9eedc17f93b871b5a19，没有替换交付文件或安装手机。
- 为验证用户要求的下次编译缓存收益，用同版本、同参数再次正常生产构建，实际成功154.7秒（Gradle143.7秒），相较本轮首次Release396.6秒缩短约61%。这是当前源码和相同配置的实测，不保证未来改动源码/依赖后仍有相同耗时；复跑后签名临时文件已清理，原交付文件哈希未变。
- 首次预热前E盘空闲21230067712字节，完成后18816475136字节；约重建2.25GiB当前工作缓存，旧工作副本没有恢复缓存。原始过程记录、日志和本轮缓存验证产物在Git外E:\SayRing-cache-warmup-20261103。
- 仅将本操作记录推送独立文档分支；当前开发工作树没有切换或合并远端业务代码，仍保留原版本。操作记录工作树仅稀疏物化docs，未复制SDK或恢复旧项目编译文件。
