# 2026-10-25 R21断连及Android 1143真机安装

## 授权、源码与范围

用户要求断开XR与R21的连接，并在系统蓝牙忽略该设备；随后构建最新版Android并安装到连接的手机。源码基线91c4e8d4972962b0628c215f632aac5009f6d050，当前分支codex/device-search-help-1141-20261024。status干净、origin身份核对、fetch --prune及当前分支merge --ff-only均成功，无新远端提交。本次没有修改生产源码、生产配置或云端用户数据；构建包含已提交的R8 Pro路由修复和安全本地化API错误提示。

## XR应用内R21断连

物理XR在线，先以devicectl私有备份cn.saydian.ring容器。iPhone镜像显示无法连接，不能操作手机系统蓝牙；已请求用户在“设置→蓝牙→R21→忽略此设备”完成，用户回复暂时无法操作。系统配对删除保持待处理，不能用SDK回执替代OS配对删除。

一次性隔离Profile操作入口位于忽略的build/xr-r21-disconnect-20261025，未加入普通main。先读取原本地绑定，仅允许null或名称含R21的QRing目标；若当前原生详情返回其他型号则拒绝。未初始化自动恢复、没有扫描或连接新戒指。实际执行configureRecoveryTarget(null)、stopScan和disconnect；原生disconnect收到完成回调后，仅移除已核对的R21本地自动重连目标，并读回详情和目标均为空。未调用清历史或恢复出厂，也未修改云端终身绑定历史。会话owner前后不变。

Profile config 25.7秒、签名构建15.7秒成功，cn.saydian.ring/团队W7SXQ4A226/XR描述文件/get-task-allow及严格深度验签通过；App.framework SHA256 e29381ce57e5e35da0cb1f933cddc5a021f70162e1fbcfcaa5b21b9b67a33da7。使用tool/drive_ios_preserving_data.mjs、显式已核验Profile二进制和keep-app-running，正文All tests passed，driver退出0、25.1秒。报告nativeDisconnectAcknowledged=true、nativeConnectedDeviceAbsent=true、localTargetAbsent=true、hadLocalR21=true、sessionOwnerUnchanged=true、osBondRemovalVerified=false。

finally私有后备份1.3秒、恢复普通main Profile 5.6秒及launch 0.2秒均退出0。普通版仍为上一轮验证的内部1.0.6(1141)，不是苹果已提交的旧1141二进制；没有上传或改审核。XR未卸载、未清账号/健康数据。一次性入口执行后改名保留为.dart.txt，避免进入后续源码分析。

## Android正式产物

检测到华为PPA-LX3、Android 10。使用普通lib/main.dart、原受保护P12与本机生产环境/Dart定义文件，SAIDIAN_PRODUCTION_RELEASE=true、QA=false、emulatorDebug=false，双ARM；新版本1.0.6(1143)，包名cn.saydian.ring。临时ignored android/key.properties权限600，finally删除，原私钥/密码/推送配置不入Git或日志正文。未修改pubspec的历史默认版本，通过显式build-name/build-number确定此次安装身份。

- flutter build apk --release --no-pub --target=lib/main.dart --target-platform=android-arm,android-arm64 --build-name=1.0.6 --build-number=1143 --dart-define-from-file=<本机生产配置>，51.9秒退出0。
- 冻结产物build/android-install-1143-20261025/SayRing-1.0.6-1143-release.apk，72063071字节，SHA256 d3a5f5a1caa4341b201bd72cb6b8bf81fef5bb2d420f847369601834d0a056ae。
- apksigner verify通过，原正式证书SHA256 81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de。
- zipalign -c -P 16 -v 4、实际manifest/resources、releaseRuntimeClasspath、release_gate.py apk-manifest和apk-abis全通过；实际22个ARM64 .so的LOAD段均至少16KB，既有libjutils精确豁免不扩大。生产包无debuggable，包名/版本/生产推送配置按正式门禁核对。

## 签名阻断与用户明确许可

安装前先pull保存现装1055的APK和包元数据。首轮覆盖资格检查失败：现装1.0.0(1055)是旧Android Debug证书1350168096373439fbb4fb80c0acd145f209e06310ddb658ce318d765525cb97，与正式证书不同；本机debug.keystore也不匹配。原检查失败日志保留，未把正式包验签成功当成可覆盖。独立产物检查脚本随后通过全部门禁。

现装包不允许run-as（package not debuggable），没有取得可恢复的数据容器备份。已明确告知用户：卸载将清除此手机Say Ring本地数据及登录、云端不变。用户回复“允许卸载旧 Say Ring 并安装正式版”后，才仅对这台指定华为手机执行adb uninstall cn.saydian.ring；没有卸载其他App。保存的旧APK仅是二进制备份，不能恢复旧账号本地数据。

## 安装与启动结果

adb uninstall 0.9秒Success；adb install正式APK 83.8秒Success。过程中完成华为PC工具来源安装确认及安全查验，页面显示“未发现风险”。实际dumpsys回读versionName=1.0.6、versionCode=1143；从设备再次pull安装后的base.apk，SHA256与冻结正式产物完全一致。

首次am start返回ok但Activity字段短暂是安装器；另一次force-stop/cold-start返回ok时Activity字段短暂是桌面。未将这些过渡字段当成真实页面证明：后续独立截图确认Say Ring登录页完整显示，dumpsys window当前焦点和activity resumed均为cn.saydian.ring/cc.saidian.saydian_app.MainActivity，进程持续存活，当前进程日志未发现FATAL EXCEPTION/Fatal signal。手机号/邮箱入口可见，协议与年龄勾选保持未选，未登录、未发验证码、未连接戒指或执行首次绑定清理。

本轮只验证安装、身份和启动；不宣称Android登录、戒指连接、活动/睡眠同步或通知端到端已通过。未更新/down2或应用市场。本次生产源码与上一轮完整回归的91c4e8d一致，未重复改算法或全量测试；本记录与索引同步到当前开发分支，不提升仍有其他硬件待验项的main。APK、私有容器、截图、日志和签名材料均不入Git。
