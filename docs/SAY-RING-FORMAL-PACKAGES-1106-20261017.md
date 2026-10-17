# 最新代码 Android / HarmonyOS 正式包 1106

## 范围和基线

- 用户要求使用最新代码重新打两端包，指Android APK与鸿蒙APP/HAP；不安装、不上传市场、不替换在线下载、不修改后台/证书/真实数据。
- 修改前status/remote/fetch成功，干净工作树与当前远端开发分支均df60205a4c01885e29e7c5255ef829fade53c724；origin/main为4dee4e6且已包含在该开发分支中。ff-only检查无新增，再创建codex/formal-android-harmony-1106-20261017。不丢弃尚未合main的最新手势修改，不覆盖另一工作树的用户文档。
- 已阅读AGENTS、国际交接、修改索引、最近手势记录、前两次正式打包记录及跨模块复盘/回归约定。
- 两端统一1.0.2/1106；仅修改Harmony AppScope/app.json5和AppUpdateService.ets的版本名/构建号，Android用构建参数，不改Flutter/iOS源码。沿用Git外原永久Android和Harmony发布证书/Profile；不运行已弃用的Hvigor明文密码签名脚本。
- 鸿蒙旧1013报991仍未找到确定根因。本机实际APP内HAP验签通过，release/app_gallery Profile有效且包名/封装名称一致，不能声称换构建号修复991。本次最终APP重新提取HAP验签并核对元数据/证书/Profile；实际AGC上传仍待独立验收。
- 鸿蒙没有QRing/LuckRing SDK，不扩大能力；Android实体下滑仍待验。Windows无iOS编译条件，本轮也未要求iOS包。
- 产物/机器日志仅在E:\SayRing-market-artifacts-20261017\formal-1106；不提交密钥、包、真实健康数据。串行构建，保留失败日志，不清缓存或停止他人进程。

## 执行记录

- 检查与构建结果按实际执行追加，未完成不写为通过。
- Harmony `TZ=UTC node --test tests/*.test.mjs`及Asia/Shanghai各503/503；`hvigorw.bat --mode project -p product=default -p buildMode=release assembleApp --no-daemon`成功57.952秒（42任务，32 executed/10 up-to-date）。保留厂商弃用、资源、未配置Hvigor内置签名警告；随后用既有独立官方sign-app签名，不交付unsigned输出。不执行已弃用的Build-SayRingHarmony.ps1。
- 受保护Sign-SayRingHarmony.ps1仅在内存替换文件名中的1.0.0→1.0.2（严格检查2处），原正式P12/Profile不变，磁盘脚本不改。首次直接签名和APP打包成功；但与编译器APP比较，发现旧脚本没有保留项目pac.json，且使用模块级pack.info。项目与模块pack.info内容等价但格式不同。本次以项目级build/outputs/default/pack.info和编译器原始pac.json重新官方打包，独立已签HAP不重写；这只是消除封装差异，不认定为旧991根因。
- 最终封装命令使用`app_packing_tool.jar --mode app --hap-path <staging>/entry-default.hap --pack-info-path <repo>/harmony-native/build/outputs/default/pack.info --pac-json-path <out>/project-metadata/pac.json --out-path <final.app> --force true --replace-pack-info false --deduplicate-so false`。首次把pac文件提取为compiler-pac.json后传入，官方工具拒绝`pac-json-path is invalid`；核对SDK参数校验必须文件名精确为pac.json，复制到专用project-metadata/pac.json后重试成功。首轮日志和中间产物保留在交付目录之外的构建父目录，不覆盖失败记录。
- 最终APP包含entry-default.hap、项目pack.info和pac.json；APP提取HAP的SHA256与独立HAP一致，官方verify-app成功；module.json及pack.info均为cn.saydian.ring.hm/1.0.2/1106/debug=false。Profile release/app_gallery/同包名，Profile中的原发布证书SHA256仍C4F4B2AF305C338728D7172B845B4455D7CE1896EA0D40A28579FC1E56C28A3C。
- Harmony最终APP SHA256 A4D6FB98777AC5F0FAB4A665C3B7CCB05A223BF9F79349F69896C55C729B92B0；HAP SHA256 96E418E8903F7C18F02814F8FF036D8876967AA77E730554D575A4676679C005。后续同类打包须保留项目级元数据，不能只重跑旧独立签名脚本便声称已完成最终封装校验。
- `flutter analyze --no-pub` 无问题（53.4秒）；`python -m unittest scripts.release.test_release_gate.ReleaseGateTest -v` 21/21通过。测试输出中的其它域名是固定测试夹具，不是正式包请求配置，实际正式包仍锁定Say Ring国际环境。
- `formal-1106/delivery`仅放最终APK/APP/HAP及交付说明；原始日志、编译中间包、stage、证书输出在父目录，不将中间APP作为交付物。

## 991 复现与外层 APP 漏签修复（取代此前的鸿蒙交付结论）

- 用户再次上传1106仍报991。进一步核对官方Hvigor SignApp任务与签名工具，发现此前只签HAP再打APP，遗漏了最终APP外层sign-app。此前“内部HAP通过”只是内层证据，不足以作为最终上架包验收；PAC不是此次已证实根因。
- 对此前交付APP直接运行`hap-sign-tool.jar verify-app -inFile <APP> ...`实际退出1，明确`signature not found / No Hap Signing Block before ZIP Central Directory`。这证实包本身漏外层签名，但AGC其它校验仍须实际回执，不继续把检查范围不足表述为无法定位。
- 使用原受保护P12、原发布证书和release Profile对完整APP再次官方sign-app，输入与输出分离，无换证书/私钥，无改源码或内层HAP。新文件为SayRing-HarmonyOS-1.0.2-1106-release-signed.app，官方外层verify-app成功；重新提取内层HAP后verify-app也成功，且与独立HAP字节哈希完全一致。
- 新整包签名APP SHA256 **54295433380650BBAC751E5310AEDBA05958D8BA9BF023135DCF01B14754E7FE**，为唯一有效最终APP交付物。前述A4D6...仅是缺外层签名的中间包哈希，不再交付。已将delivery中旧release.app移动到父目录rejected-unsigned-outer-1106.app保留诊断，未删除；用户已收到新的release-signed.app下载路径。
- 新增`scripts/release/Verify-SayRingHarmony.ps1`，无凭据、无签名/上传动作，只读验收输入包；必须先验完整APP外层，再验提取HAP，核对原发布叶证书与Profile证书、有效期、release/app_gallery/包名、版本、Debug=false、项目元数据和HAP字节保留。输出要求新建独立诊断目录，避免覆盖失败日志。以后交付前强制运行，不能用仅内层验证代替。
- 新门禁初次误取官方输出第一张根证书的摘要而误拒正确包；实际证书链顺序为根、叶、中间证书。已改为解析PEM链、基于BasicConstraints选唯一非CA叶证书，并与Profile内发布证书双向比较，保留首次失败日志。修正后正确新APP通过，旧外层未签APP被明确拒绝；后续更多拒绝用例按实际追加。
- 最新脚本AST零语法错误；实际正确包正例通过，旧外层漏签、错误ExpectedVersion、错误ExpectedCertificateSha256、传入其它版本独立HAP共4个反例均按预期拒绝。测试不是模拟Java验签，均针对真实本机包调用官方工具；没有重签或修改输入包。具体输出目录gate-final-positive与各gate-negative-*保留。
- Android重新全量：UTC 1283/1283（75秒），Asia/Shanghai 1283/1283（64秒）；双ARM Debug使用1.0.2/1106构建成功259.8秒；`gradlew.bat :app:testDebugUnitTest --no-daemon --max-workers=1`成功3分2秒，XML63项/0失败/0错误。Flutter和Android运行时代码未因签名门禁调整而变化。
- Android正式Release原受保护脚本构建成功279.2秒（66.6MB）；版本1.0.2/1106、cn.saydian.ring、min26/target36、双ARM、原正式证书SHA256 81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de、v2签名、16KB zipalign及生产JPush清单通过。临时android/key.properties已移除。APK SHA256 62FA47CC0752B3B0C3600B8AFEDA13A1B7C012AF68B28F18E00375B7BE7F1147。
- 交付目录的交付说明列出三份最终文件、哈希和原正式证书指纹，鸿蒙明确只上传release-signed.app。本轮未安装、未上传、未修改在线清单/后台。未来发布必须先跑Verify-SayRingHarmony.ps1对完整APP和内部HAP双验，不仅凭文件名或内层成功放行。
- 新生成`releaseRuntimeClasspath`报告成功1分41秒；`release_gate.py apk-abis --apk <1106.apk> --dependency-report <本轮报告> --pubspec-lock pubspec.lock`通过，保留原锁定JPush6.2.0/JCore5.5.2/flutter3.5.1的libjutils.so单arm64受控例外，不放宽其它库。
- Inspect-SayRingNative.ps1仅在内存改本轮报告输出目录，磁盘脚本不改。实际检查43个ELF，arm64均16KB通过；原厂armv7 libDspConfig.so/libEcgAnaly.so仍为既有4KB，明确保留而不是写成全部通过。临时签名配置已清理。
- 最终delivery文件大小：APK 69,849,787字节；整包签名APP 9,448,803字节；HAP 18,711,787字节。三个包复制后重新核对哈希一致；没有保留缺外层签名的APP在delivery中。
- 最后fetch确认main仍4dee4e6、最新手势远端仍df60205；另一个同事新增的iOS上传分支不属于本轮Android/鸿蒙范围，不合并、不修改。git diff --check和新PS门禁AST均通过。仅版本两文件、新门禁、日志和索引提交当前打包分支；由于实体下滑等尚未验收，不自动快进main。
