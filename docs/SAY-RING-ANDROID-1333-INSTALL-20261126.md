# 2026-11-26 最新合并代码安卓正式构建与安装1333

## 用户范围与基线

- 用户在本地同步完成后明确要求将最新版安装到手机，本轮追加正式Android构建和保留数据覆盖安装，不发布下载、不上传市场、不部署服务端、不推送远端。
- 源码基线5aa6ddecc975d25601462054d261bc1d24b45169，保留b2c3072的首次摘要误报修复及f9c0604功能更新。构建前工作区干净，status/remote/fetch、交接、实施记录和回归边界已核对；远端功能分支是当前HEAD祖先，没有遗漏源更新。
- 指定目标是已授权USB调试的原华为JAD-AL00。包管理器实际读回旧版1.0.15（1321）、lastUpdateTime=2026-11-25 18:41:13。仅操作cn.saydian.ring，不卸载、不解绑、不切换账号、不重置戒指。
- 刚完成的本地合并静态分析通过，UTC/Asia-Shanghai全量各2539项通过，见SAY-RING-LOCAL-SYNC-20261126.md。本轮未改运行源码，不重复已经通过的全量测试。

## 正式构建

- 新产物标记1.0.16（1333），构建参数覆盖版本，不改pubspec原始版本。构建入口基于已有签名构建脚本，仅替换版本、构建号和专用输出目录，不打印签名凭据。
- Git外专用产物目录E:/SayRing-android-1333-20261126，串行运行Invoke-Checks.ps1的debug、native、release、verify。保留生产first-party API、商城定义、JPush production及既有原正式证书，禁止QA Release代替正式包。
- native阶段只生成当前releaseRuntimeClasspath依赖报告供最终ABI门禁使用，不等同重新执行原生单测。合并未修改Android原生代码/依赖锁；iOS原生修改在Windows不编译，不宣称本次实机验收。
- Debug/Release、APK签名、包号/版本/非debuggable、ABI与运行库、ZIP/ELF对齐的最终结果在完成后补记。已有ARMv7 DSP/ECG库4KB ELF对齐例外保留，不能宣称所有市场16KB验收。

## 最终构建与安装结果

- Android Debug通过，assembleDebug 231.5秒；当前依赖报告通过。正式Release成功，Flutter构建约564.8秒；R8优化阶段耗时较长但持续计算，未中断或改用旧包，本轮无构建失败。
- 最终APK：E:/SayRing-android-1333-20261126/SayRing-1.0.16-1333-release.apk，76437332字节，SHA256=e44243754a4be2757af5b4478b8b14c46706ff9bcdab9a97f6f617dc07946f3d。
- apksigner核实原正式证书SHA256=81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de，包号cn.saydian.ring、versionName=1.0.16、versionCode=1333、非debuggable。production manifest/JPush、ARMv7/ARM64运行库门禁和zipalign -c -P 16 4通过，ELF报告保留既有ARMv7 DSP/ECG 4KB例外。android/key.properties已清除，签名材料与APK均不提交Git。
- adb install -r返回Performing Streamed Install / Success，系统包管理器实际读回versionCode=1333、versionName=1.0.16及lastUpdateTime=2026-11-26 10:08:53；安装回执和版本读回保存在Git外专用目录。未卸载、解绑、切号、重置或清数据。
- 使用系统resolve-activity取得本包真实入口后执行am start，启动请求成功。未代用户测量、开启手势、清理戒指、重新生成旧账号首次摘要；启动与系统版本核验不代表戒指实测通过。
- 随后系统窗口核实前台为cn.saydian.ring/cc.saidian.saydian_app.MainActivity。记录提交前的首次fetch因TLS unexpected EOF失败，未因此改变已安装结果或覆盖任何代码；保留错误后重试。

## 安装边界

- 构建期间不操作手机界面。正式APK验签通过后才使用adb install -r保留数据覆盖安装，华为安全确认和身份验证由本人完成，不越过密码界面。
- 最终以系统包管理器读回1.0.16（1333）作为安装成功依据；设备连接/数据测量本轮未验收。运行源码仍是本地合并5aa6dde，本记录单独提交本地，不推送远端，不修改线上更新清单。
