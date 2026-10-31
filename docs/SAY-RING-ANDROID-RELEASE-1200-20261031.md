# Android正式包1200

## 原打包请求的初检（随后被用户取消）

- 用户要求打包最新安卓正式包；本轮只构建交付，不安装手机，不更新下载站、后台或应用市场。
- 修改前工作区干净，当前 `codex/integrate-latest-20261031` 本地/上游均 `7c8aeff879aae8c4d450e5a91a94ed19573422e9`。fetch成功，共享开发分支仍为已合入的 `2c12a363f832750efa071cab91640cbc791cb6f9`；完整保留R22温度、重连、同步、独立关闭和力度修复。
- 已阅读工作约定、国际版交接、最近整合日志及发布限制。`git diff --exit-code 7c8aeff -- lib android pubspec.yaml pubspec.lock config`通过。
- 同源7c8aeff刚完成静态零问题、定向78项、UTC/Asia-Shanghai各1713项回归、Android Debug和QA Release编译；Android原生输入与1198检查点相同，Gradle复用了同源81项回执。复用这些准确同源结果，不为纯正式签名打包再次重复全量测试；正式构建及最终产物门禁重新执行。

## 取消记录与本轮需求

- 上一次生产构建中用户要求“先不打包”：已停止该构建的专属编译进程，退出码1为主动取消；finally清理完成，android/key.properties不存在，没有1200成品APK或手机/发布操作。取消日志保留在Git外release-cancelled.log，原两份未提交文档完整备份在cancelled-docs-checkpoint。
- 用户随后要求：设备页增加重新绑定时清理手机蓝牙配对的说明；R8/R21/R22查找戒指不要再提示响铃或振动；优化后重新打包。版本1200此前未完成、未分发，本轮仍使用1.0.7(1200)，必须重新检查修改后的源码。
- 修改前再次fetch成功，本地/上游仍为7c8aeff；保留整合分支、原安卓检查点及共享iOS分支，不覆盖或强推。
- lib/ui/pages/devices.dart：直接展示现有分平台重新绑定说明，并加入“连接说明”详情。正常已绑定用户先尝试重新连接；重新添加且搜索不到时，明确系统设置→蓝牙→取消配对/忽略此设备再搜索。搜索帮助沿用同一说明，不改变解绑/恢复/扫描协议。
- lib/ui/prototype/device_features.dart：QRing复用既有commandOnly查找展示和指令发送反馈；R8/R21/R22不再宣称响铃或振动，不按型号猜测物理反馈。SDK开始/停止、能力校验与计时均保持原逻辑。
- lib/ui/prototype/shared.dart：查找功能说明改为发送查找指令，无物理响应承诺。仅Dart界面文案与展示调整，不改后端、原生协议或健康数据。
- 三文件dart format通过（1文件重排）；git diff --check通过。未新增仅复述文案的单测；静态分析及既有完整回归、Debug/正式Release随后记录，早先同源结果不替代本轮改后验证。

## 本轮修改后验证

- `flutter analyze --no-pub`：零问题，37.5秒。
- `flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`，TZ=UTC：1713项全部通过，2分55秒；包括原有搜索帮助的Android/iOS窄屏大字体关闭返回与不重启扫描用例、查找开始/停止协议回归。
- 同一完整Flutter命令，TZ=Asia/Shanghai：1713项全部通过，3分06秒。
- Android双ARM Debug正常编译通过，188.5秒。Gradle原生检查 `:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1 --offline -Ptarget-platform=android-arm,android-arm64` 成功，2分35秒；本轮`:app:testDebugUnitTest`实际执行，18份JUnit报告共81项、0失败、0错误、0跳过。
- 读取JUnit报告时第一次检查了android/app/build/test-results旧路径，没有文件；随后使用实际Flutter输出build/app/test-results/testDebugUnitTest汇总，未把空结果当作通过。插件Built-in Kotlin迁移和旧API警告保留，未为本轮文案修改升级SDK。
- `git diff --exit-code 7c8aeff -- android ios lib/services lib/domain pubspec.yaml pubspec.lock config`通过，确认原生SDK、服务、数据处理、依赖及正式配置没有变化。
- 实际真机/声光振动响应本轮未测试，不以提示修改宣称物理查找能力通过；Windows没有Xcode，无法执行iOS Debug/Profile。没有安装手机、解绑或修改系统蓝牙。

## 正式构建与检查

- 版本1.0.7(1200)，包名保持cn.saydian.ring。使用受保护的既有正式P12证书和本机DPAPI凭据，通过正常Flutter/Gradle生产构建；不重签QA产物，不更换证书或包名，不输出密钥或密码。
- Say Ring极光公开AppKey使用已确认的应用身份，生产通道；不混用其他App的推送参数。
- 构建证据及安装包保存在Git外 `E:\SayRing-android-release-1200-20261031`。正式Release生产重编成功，292.1秒；没有复制/重签QA产物。受保护签名配置已正常清理，android/key.properties不存在。
- apksigner验签通过；正式证书SHA256为 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`，与既有1198相同。aapt确认cn.saydian.ring、1.0.7、versionCode1200且非debuggable；zipalign -c -P 16 4通过；正式Manifest/JPush与双ARM ABI门禁通过。
- ELF实际检查43份库，仍有2份旧ARM32库的LOAD对齐小于16KB：armeabi-v7a/libDspConfig.so、libEcgAnaly.so。记录为既有供应商限制，不把zipalign通过或正式签名等同于全部原生库兼容、全应用市场受理或审核通过。受控极光arm64-only libjutils.so依赖例外沿用，不扩大豁免。
- 成品大小72,634,177字节；SHA256 `776d63f09b3322c2feb4785a2792daa9620053b539fa486606eb2f73b4673ce3`。交付副本位于 `E:\SayRing-market-artifacts-20261031\android-release-1200\SayRing-1.0.7-1200-release.apk`，复制后复核哈希；不提交二进制、生产凭据或真实健康数据。
- Windows不能编译iOS；远端XR/R8无线稳定性未验收、原厂R22手动皮温未验证等既有边界保持。只交付Android正式签名包，不把签名等同于上架审核通过。
- 提交前再次fetch成功，当前上游仍为7c8aeff，共享分支仍为2c12a36；只提交本轮三份Dart源码与两份实施文档，推送当前整合分支，不改原分支、主线、后端或线上配置。git diff --check通过。
