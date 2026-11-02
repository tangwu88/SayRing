# 同步最新源码、Android正式包及手机安装1225

日期：2026-11-02，Asia/Shanghai。用户要求“更新本地，安装手机”，需要将新增共享初始化逻辑正常编译进Android后安装，不能复用旧1222。

## 输入与范围

- 修改前已阅读AGENTS、交接、最新实施日志、复盘及回归清单，执行状态/远端/fetch。工作区干净，本地67c21cd3711100216a4425b115731212a5d65f12，远端整合分支f9e2811174763a355bac34aee9c43a8906657bdf，0/2，可快进。
- 创建codex/checkpoint-android-1222-20261102保留原提交；git merge --ff-only origin/codex/integrate-latest-20261031成功，运行时代码固定f9e2811。新增7d06186修复可选步数目标阻塞初始化及共享状态处理；f9e2811为iOS上传记录。无需改写运行时代码、依赖或已有分支历史。
- 本轮Android1.0.10(1225)、cn.saydian.ring、原正式证书与Say Ring推送身份保持。正常Flutter/Gradle生产编译，不能重签旧QA包。证据目录Git外E:\SayRing-android-release-1225-20261102，交付E:\SayRing-market-artifacts-20261102\android-release-1225。
- 已识别唯一授权USB华为JAD_AL00，原App1.0.9(1222)，firstInstallTime为2026-10-30 14:29:25。计划同签名覆盖安装，不卸载/清数据/解绑/重置戒指。初检手机锁定、Dozing、stay_on_while_plugged_in=0；尚未改变手机设置或代输密码。若安装需要系统身份确认，由用户完成。
- 本轮不发布后台、下载站、iOS/Harmony或商店；首次绑定确实授权清理及新活动/睡眠等真实样本仍须独立验收，源回归/编译/安装不能替代完整戒指测量验证。

## 验证与安装

- `flutter pub get --offline`成功；`dart format --output=none --set-exit-if-changed lib test`295文件、0改动。运行时代码/依赖与HEAD无差异，Android原生与b0857dd无差异，git diff --check通过。
- 六组初始化/Android协议宿主夹具使用JAVA_HOME=本机JDK17、JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8运行，避免上版记录的GBK读取UTF-8问题；17项中12通过、5依赖Mac/Objective-C跳过、0失败。保留相机/电源/HRV保护反例；不把5项跳过写成iOS编译或实际设备通过。
- `flutter analyze --no-pub`零问题（80.8秒）。`TZ=UTC flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`1762项完整通过（3分47秒）。
- 同一完整Flutter命令，TZ=Asia/Shanghai：1762项全部通过（4分03秒）。宿主回归不等同于受影响iPhone的新账号实际数据验证。
- Android双ARM Debug正常编译成功（244.6秒）；保留既有插件Built-in Kotlin迁移及旧API警告，不为打包改变依赖或系统支持范围。
- Gradle `:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1 --offline -Ptarget-platform=android-arm,android-arm64`成功（3分20秒）。app单元任务实际执行，18份JUnit回执共81项、0失败、0错误、0跳过；依赖报告供最终ABI核验。
- Android正式Release正常生产重编成功（398.7秒）。apksigner确认原正式证书SHA256=81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de；aapt确认cn.saydian.ring、1.0.10(1225)、非debuggable。zipalign -c -P 16 4、生产Manifest/极光和双ARM ABI门禁通过，临时android/key.properties已清理。
- ELF检查43份，仍有2份旧ARM32库libDspConfig.so、libEcgAnaly.so的LOAD对齐不足16KB；保留供应商限制，不宣称全市场兼容或审核通过。
- APK72,650,561字节，SHA256=5d946eb5681cda058d36cd3df3e0ac15d35f36fc18d59acf76288dc8c8a837e2。已复制至交付目录并复核哈希，SHA256清单在同目录，产物及凭据不进Git。
- 安装前私有拉取手机原base.apk，哈希与1222交付01ece5236f5c7093363fcc50e205c03620c2f3f81f3803acdc900902a1314e0b一致，原正式证书核验通过，允许同签名覆盖。
- `adb -s <核验目标> install -r <1225正式包>`已发起，初次回读仍为1222；手机Dozing/锁定。唤醒并按实际屏幕尺寸上滑后，系统密码界面UI树为空，无法读取；未盲输密码，已请求用户本人解锁及完成可能的华为安装身份验证。尚未收到Success前不称安装完成；安装日志私有保存。
- 用户随后回复“已安装”。原安装日志回读Performing Streamed Install/Success；核验同一USB华为JAD_AL00系统包为1.0.10(1225)、非debuggable，firstInstallTime仍为2026-10-30 14:29:25，lastUpdateTime为2026-11-02 15:34:36。覆盖安装完成，未卸载、pm clear、解绑或重置戒指。
- 再次私有拉取已安装base.apk，SHA256与正式交付5d946eb5681cda058d36cd3df3e0ac15d35f36fc18d59acf76288dc8c8a837e2完全相同，确认原正式签名二进制已安装；证据保存在Git外installed-after-1225.apk，不上传Git。
- `adb shell am start -W -n cn.saydian.ring/cc.saidian.saydian_app.MainActivity`返回Status:ok、COLD；系统前台为该MainActivity。仅验证常规启动，未附加调试器、实际测量、拍照或修改戒指设置；不把启动核验等同于完整健康记录/蓝牙/新账号初始化验收。
- 本轮仅更新此安装回执；提交前fetch确认本地/远端均ae0113d，原记录和未验边界保留，无运行时代码改动，无需为文档重复整包测试。
