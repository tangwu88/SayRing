# Android / HarmonyOS 正式包 1.0.2（1111）

## 范围、基线与保护

- 用户要求对刚同步的最新主线打安卓与鸿蒙正式包，不安装、不上传、不变更后台、在线清单或商店审核。
- 修改前status/remote/fetch成功，干净工作树在codex/sync-main-20261019；HEAD/origin/main为8e7541d074afc8fc8c6f23528c4069d5dbd94196。ff-only确认一致后新建codex/formal-android-harmony-1111-20261019。原手势与1106打包分支及另一个工作树文档修改保留，不自动合并尚未验收的手势代码。
- 已阅读AGENTS、国际交接、最新报告图形/睡眠轮询记录、复盘及回归清单。仅修改Harmony版本与更新检测为1.0.2/1111；Android传构建参数，不改运行时代码。Windows不构建iOS。
- 只从b6efa40恢复已验证的scripts/release/Verify-SayRingHarmony.ps1，不合并其它分支源码。该只读门禁先验APP外层、再验内部HAP，校验原发布叶证书/Profile、版本、包名、有效期和内部字节一致。
- 沿用原受保护Android及Harmony正式证书，不运行已弃用的Hvigor明文密码签名脚本；受保护磁盘脚本不改。签名脚本旧默认版本仅在内存严格核对替换次数后改为1.0.2。
- 1106已证实旧方式只签HAP再打APP会缺外层签名块：本次必须在官方打包并保留项目pack.info/pac.json后，对完整APP单独sign-app，再做内外两层官方验签。只有release-signed.app作为上架APP交付，未签外层中间包不进delivery。
- 产物/日志在E:\SayRing-market-artifacts-20261019\formal-1111，最终三包单独放delivery；不提交产物、密钥、原始健康/设备数据。鸿蒙仍缺QRing/LuckRing SDK，正式签名不代表连接功能可用或市场已验收。

## 执行记录

- 按实际结果追加；失败日志不覆盖，未执行不标为通过。
- Harmony UTC/Asia-Shanghai宿主测试各503/503（约4秒）；Release assembleApp成功55.844秒，42任务（32 executed/10 up-to-date）。保留SDK既有资源/弃用及无Hvigor内置签名配置警告；unsigned输出不作交付，随后用官方独立工具签名。
- 原受保护Sign-SayRingHarmony.ps1仅在内存替换文件名默认版本1.0.0→1.0.2（严格2处）并签内部HAP。保留项目级pack.info和编译器原始pac.json（准确文件名pac.json），使用官方packing工具、replace-pack-info=false、deduplicate-so=false生成中间APP；再以同一原发布证书/Profile对完整APP执行sign-app，最终文件名release-signed.app。
- Verify-SayRingHarmony.ps1实际验证1111最终APP外层与内层HAP通过，原发布证书与Profile匹配、有效期、release/app_gallery、cn.saydian.ring.hm/1.0.2/1111/debug=false及HAP字节一致均通过。对本轮外层未签中间APP执行同一门禁实际被拒，不能仅凭内层成功交付。导入门禁AST零错误，保护脚本/证书/私钥原样保留。
- 鸿蒙最终APP SHA256 90F78037558623458736834FA92201CFE0CE1C734F00E76EF3925A812926117F；HAP SHA256 B98CF3ABC6A6C52EBC6B75388D2E4C58D3CB6EB7FA69C47F6083BEE0F5239ECD。最终delivery没有缺外层签名的APP；真实AGC上传/审核仍未执行，不标为通过。
- Android `flutter analyze --no-pub`无问题（65.7秒）；UTC与Asia/Shanghai全量Flutter各1267/1267（65秒/53秒）。`flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.2 --build-number=1111`成功260.1秒。`:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1`合并一次Gradle运行成功3分28秒，避免重复配置；既有SDK/Kotlin/Gradle弃用警告保留，不更改工具链/依赖。
- 鸿蒙缺外层签名的中间APP已移到父目录的intermediates/并标记outer-unsigned，保留诊断而非删除；最终交付只用delivery中的release-signed.app，避免再次误传未签外层包。
- Android原生XML实际53项/0失败/0错误/0跳过；正式Release成功386.7秒，66.7MB。原受保护脚本严格内存替换默认版本后使用1.0.2/1111、原正式证书；cn.saydian.ring、min26/target36、双ARM、v2签名、zipalign16KB、生产JPush清单均通过，证书SHA256仍81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de。临时android/key.properties已移除。
- 发布Python ReleaseGateTest共21项通过；基于本轮releaseRuntimeClasspath的apk-abis通过，仅沿用已锁定JPush6.2.0/JCore5.5.2/flutter3.5.1 libjutils.so单arm64受控例外。Inspect-SayRingNative仅在内存替换报告目录，43个ELF实际检查，arm64全部16KB通过；原厂armv7 libDspConfig.so/libEcgAnaly.so既有4KB明确保留，不修改SDK二进制。
- APK最终SHA256 B101FF8FFCF0E37AD5927391A344EE29A3FC2937422B5BEFBF4F2063471F4BDF，69,931,571字节；签名APP 9,448,755字节；HAP 18,711,784字节。delivery三包复制后再次核对哈希一致，附交付说明、原签名指纹与未纳入手势分支的提示。未安装手机，未上传AGC，未更新在线下载或后台。
- 不把旧Mac QA/真机记录写成本轮Windows实测；本轮iOS和设备功能未执行。只提交两个版本文件、独立PS验签门禁、日志及索引；产物/证书/私钥/机器日志不提交，不自动合并其它分支或推main。
- 提交前再次fetch确认main仍8e7541d，diff检查通过，首个版本/门禁/记录提交6b22156。首次推送出现curl52 Empty reply、send-pack远端断连，不能将附带的Everything up-to-date当作推送成功。保留提交和包，使用同一远端/分支只读核对后以进程级HTTP/1.1重试，不修改全局代理、不强推。
