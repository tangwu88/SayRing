# Android 首次上架签名与极光版本锁定（2026-10-05）

## 原因与范围

用户要求重新生成用于首次应用市场提交的正式签名 APK。上一候选包 JPush 6.2.0 动态依赖 JCore [1.0.0,) 实际解析 5.5.7，与 release_gate.py 已批准的 5.5.2 原生 ABI 精确例外不一致，apk-abis 门禁失败。

修改 third_party/jpush_flutter/android/build.gradle：排除 JPush 自动 JCore、显式 strictly 5.5.2；补 scripts/release/test_release_gate.py 防漂移检查。实际 Gradle 输出使用 `{strictly 5.5.2} -> 5.5.2`，旧解析器误读为空集合，因此 release_gate.py 增加此报告格式的解析，仍只批准相同精确版本，且覆盖漂移/解析失败用例。不改业务、后台、接口、健康算法，也不放宽发布门禁。

## 修改前 Git 与构建边界

- 独立仓库 tangwu88/SayRing，工作树 E:\SayRing-market-release-20261005，分支 codex/first-market-release-20261005。
- 工作树干净，HEAD 与 origin/main 均 c31d618adc6be5e83b88331b6800d6aa8c7023ed。
- 初次 git fetch origin --prune 连接重置；用本机代理重试成功，git merge --ff-only origin/main 返回 Already up to date。
- Android 身份 cn.saydian.ring，构建指定 1.0.0 (1010)，保留最新黑白图标；新永久发布证书与前一 1009 候选相同。
- 密钥、密码和 key.properties 仅在本机受保护目录，产物不进 Git；后台 Master Secret 不进入客户端。

## 验证记录

- `flutter analyze --no-pub`：零问题。
- 初次 `flutter test --no-pub --reporter expanded` 在下载 sqlite3 Windows native asset 时网络超时，未执行测试；配置本机代理重试后 UTC 和 Asia/Shanghai 各 940/940 通过。
- 初次 `python -m unittest discover -s scripts/release -p test_release_gate.py`：31 项中 Xcode shell 相关用例出现 22 个子用例错误，原因 Windows 无 `/bin/sh`。没有将其标为通过；针对可执行的 ReleaseGateTest 全部 19/19 通过，Xcode shell 和 iOS 构建仍未执行。
- 本机受保护脚本执行 `flutter build apk --release --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.0 --build-number=1010 --dart-define-from-file=config/dev.json.example` 并注入推送 AppKey、production channel、独立永久签名，成功（280.2 秒）。未关闭 production 门禁；厂商专用通道明确未配置，不能写厂商离线推送验收通过。
- QRing 缓存在前轮 APK/AAB 构建后会再次触发 immutable workspace 校验，本轮构建前把已经确认的具体 hash 目录移动到工具链 qring-transform-20261005-final-apk 隔离目录。没有删除源码或密钥，缓存仍可恢复。
- `apksigner verify --verbose --print-certs`：成功，RSA4096/v2 正式签名，证书 SHA256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。
- `aapt dump badging`：cn.saydian.ring / Say Ring / 1.0.0 (1010)，minSdk 26、targetSdk 36、双 ARM。
- `zipalign -c -P 16 4` 与 `release_gate.py apk-manifest`：通过。
- `gradlew :app:dependencies --configuration releaseRuntimeClasspath --console=plain --no-daemon`：成功，JPush 6.2.0、JCore strictly 5.5.2，已对真实产物执行 `release_gate.py apk-abis`，通过。首次在依赖报告尚未生成完毕时检查得到空集合，随后等待报告完成；strictly 格式误读按上述修复并重验。
- NDK llvm-readelf 对 APK 43 个原生库检查：所有 arm64-v8a LOAD 段至少 16KB，对未整页 RELRO 末尾检查页内尾部与下一可写 LOAD 无重叠（只计段尾模数的初版脚本错误把链接器留白也当冲突，已修正，并保留为静态检查而非运行测试）。armeabi-v7a 的 libDspConfig.so 和 libEcgAnaly.so 为 4KB，32 位设备兼容保持，不冒充全部 ABI 全库 16KB。
- 正式 APK 已独立保存：`E:\SayRing-market-artifacts-20261005\SayRing-1.0.0-1010-release.apk`，69,044,934 字节；SHA256 `e9d0ace896a5da37ea0517b7ae5cc5da90210baad4ee370fdb6f811ad5f1932a`。
- `gradlew :app:testDebugUnitTest` 首次因未设置 ANDROID_HOME 导致 Flutter 子任务找不到 SDK；配置环境后的第二次在 mergeDebugAssets 遇到同一 QRing immutable workspace 错误。隔离该具体缓存后第三次执行 `gradlew :app:testDebugUnitTest :app:assembleDebug -Ptarget-platform=android-arm,android-arm64 --console=plain --no-daemon`：成功（2 分 9 秒），Android 原生 8 个测试套件合计 32/32，通过，双 ARM Debug 编译通过。正式 APK 已在此之前独立复制，不会混为 Debug 产物。
- `git diff --check`：通过，只有 Windows LF/CRLF 提示；生成的 ignored key.properties 已移除，密钥不在源码目录。

## 未验收边界

Windows 无 Xcode，本轮不改 iOS 且不能执行 iOS Debug/Profile；用户当前只要求安卓 APK，没有安装手机或真实健康/推送联调授权。本轮不提交应用市场审核、不发布下载清单、不修改生产后台。新永久证书对应的微信开放平台签名登记仍需平台管理员确认。

正式证书 MD5（微信 Android 应用签名）：`09D14504FD119AE833B2AAAAEECC13FE`。正式签名包首次安装/同签升级、微信回跳、标准极光注册和通知送达、戒指实测与商店资料审核仍应单独验收，不把静态检查、主机单测和构建成功当真实业务已接通。旧 1009 AAB 不在本轮重构建范围，不能拿它代替新 1010 APK。

源码仅提交当前 codex 分支供审阅，不强推、不以本机结果宣称 CI 或线上发布通过；main 和后台均未变更。
