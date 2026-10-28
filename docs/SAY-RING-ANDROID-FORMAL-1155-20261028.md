# 2026-10-28 最新Android正式包1155

## 范围与源码

- 用户要求打包最新正式安卓版，本轮只重新生成正式签名APK；不安装手机、不发布下载配置、不上传市场或改后台。
- 已读AGENTS、国际交接、复盘/回归清单及最近三端模块显示、1153/1154构建和实际安装记录。工作树起始干净，当前开发分支为codex/login-camera-r7ultra-1136-20261024。
- 首次完整fetch连接重置；HTTP/1.1定向fetch当前分支及main随后成功。开发分支本地/远端均775dc87dc6e47949f3bdb901bd3c32a221f386de，ahead/behind=0/0；main=0e350063d727678b2dab8d9e61abf8edec51fd11，无main独有提交待合入。保留当前开发基线，不重置/强推或提升含未验收硬件功能的main。
- 相对本日通过全部mobile-ci40627341857的源码0163ec71fc3880f384a040de8c975589ecff8f6b，只有三端模块记录文档变化，运行源码、依赖锁、签名和第三方库未改。复用本日Analyzer零问题、Flutter两个时区各1556/1556、Android Debug/Release、iOS云端及鸿蒙验证的证据；本轮不将它们描述为重新执行。
- 本次用既有受保护DPAPI正式签名runner重编1.0.7(1155)，输出到Git外独立formal-1155目录，不用旧包改名。既有产品cn.saydian.ring、国际API/update地址、生产JPush和商城模块守卫保持原配置。

## 构建与产物核验

- Release重新编译成功，assembleRelease耗时312.2秒；构建时仅有既有Kotlin迁移/Java弃用警告，未升级依赖或绕过失败。随后原生releaseRuntimeClasspath依赖报告成功（1分44秒）；本轮不是重新执行Android单元测试。
- 新APK原正式证书验签通过，证书SHA256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`；实际cn.saydian.ring/versionName1.0.7/versionCode1155、无debuggable，生产Manifest/JPush、armeabi-v7a和arm64-v8a ABI门禁及zipalign -P16通过。
- ELF复查仍有原两项32位厂商库libDspConfig.so/libEcgAnaly.so的16KB对齐限制，没有写成已解决；不将正式签名等同于所有市场审核通过。没有修改库或供应商算法。
- 构建过程不输出/提交签名密码或私钥，临时android/key.properties须在结束后检查已清除；APK、依赖/签名日志和配置留在Git外。
- 完成后实际确认android/key.properties不存在；Git差异只有本记录和索引，git diff --check通过。

## 交付

- APK：`E:\SayRing-market-artifacts-20261028\formal-1155\SayRing-1.0.7-1155-release.apk`，72063783字节。
- SHA256：`35687f8b9b1473558ae4cdc1f00036742f5663f3fa13da716b02028ddaed36c9`；同目录保存SHA256SUMS.txt、build-receipt.json及Release/native/verify日志。
- 本次未安装手机、未发布下载页、未上传应用市场或变更后台。1154的原有实物验收仍是1154回合，不冒充1155本轮新实测。
