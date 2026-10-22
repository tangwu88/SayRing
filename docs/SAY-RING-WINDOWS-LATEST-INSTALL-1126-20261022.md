# Windows 最新源码同步与1126正式包安装

## 范围与基线

2026-10-22用户要求同步代码到本地并安装手机。本轮默认同签名覆盖安装、保留本地数据；没有新的卸载授权，不因过去一次卸载请求再次清数据。仅Say Ring，不改服务端、公开下载、市场审核、证书或其它App。

起点`E:\SayRing-market-release-20261005`、`845e3bc`，工作树干净。执行status、remote、fetch/prune成功；最新main为`0e35006`且可快进，先`git merge --ff-only origin/main`同步十项更新，再创建独立记录分支`codex/windows-main-install-20261022`。本轮fetch同时发现开发分支又有两项新提交，已向用户说明后通过ff-only同步`origin/codex/qring-visual-refresh-20261021`，最终源码`930ecda4262f05010aa409376c1dd7d3fe9a328b`。不覆盖其它工作树或提升远端main。

阅读AGENTS、国际交接、Bug复盘、回归清单、1125/1126实施和实物记录。新代码包含最新紧凑布局、手势图形引导、震动款型号候选和设置只读排队；实际能力/账号/设备门禁保留，不把iPhone实物记录当Android验收。

## 计划与安装前现场

仅新增本记录和索引，不修改业务源码；用既有Windows受保护正式签名流程构建普通`lib/main.dart` Android 1.0.5（1126）、双ARM、生产API和JPush身份，并保留1121的原生商城构建参数。运行静态检查、全量双时区Flutter、Android Debug/Release、原生及发布检查；Windows无法执行iOS构建，已有Mac回执不是本机重跑。

已确认ADB唯一手机JAD-AL00、旧包cn.saydian.ring/1.0.5（1121）、首次安装时间2026-10-20 10:58:24。手机起初锁屏，已请用户本人解锁及确认可能的华为安装验证，不代输密码、不绕过系统校验。构建失败不安装旧二进制；签名不匹配停止，不自行卸载。完整健康库备份/数据内容比较、戒指采样、支付和真实验证码不在本轮验收内。

## 实际结果

使用Git外`E:\SayRing-market-artifacts-20261022\install-1126\Invoke-LocalChecks.ps1`串行运行各阶段；此包装器仅配置本机工具链，原受保护构建脚本只在内存中将build-name替换为1.0.5并增加原生商城参数，不在磁盘修改原签名脚本。

- `flutter pub get`退出0，26.4秒；没有升级锁定依赖。`flutter analyze --no-pub`退出0，93.7秒（工具内部90.4秒），零问题。
- 首次发布工具全类34项执行，Xcode shell类在Windows缺少POSIX解释器而出现22个子用例WinError2；这不是Android产品失败。保留原日志，改跑本机可执行的`ReleaseGateTest`和`PushConfigTest`共23项，全部通过；Xcode类不标本机通过。
- 补读旧1111分支文档时文件不在当前主线返回路径不存在；未恢复旧文档或混入1111签名门禁，不影响最新源码构建。
- 安装前从唯一目标手机只拉取当前APK（不是健康数据备份），官方验签确认当前1121也是原正式证书SHA-256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`，与拟构建新包身份相同。拉包和读取系统元数据不证明本机数据库备份或所有内容保留。
- 串行完整Flutter回归：`TZ=UTC flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`，1390/1390通过、阶段218.1秒；`TZ=Asia/Shanghai`同命令1390/1390通过、阶段187秒。TZ为进程环境配置，不改Windows系统时区或手机时间。
- 双ARM Debug构建退出0、阶段278.9秒（Gradle274.9秒）；实际aapt确认`cn.saydian.ring`、1.0.5/1126、双ARM和debuggable。仅作编译回归，不安装这个Debug包。保留既有Kotlin迁移警告，不为消警告升级依赖。
- `:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1`退出0、阶段182.1秒，302任务中10执行/292缓存；独立读取JUnit XML共54项、失败/错误/跳过均0。保留实际Release依赖报告供最终ABI核验。

## 正式构建、门禁与产物

- 原受保护签名脚本通过本用户DPAPI读取原证书密码，临时生成ignored key.properties并在finally移除；结束后独立Test-Path为false。生产模式true、QA false、正常lib/main.dart、原生商城参数true、原JPush客户端身份/channel production、厂商通道none。没有读取服务端Master Secret或创建新证书。
- 正式Release阶段退出0、318.3秒（Gradle308.2秒），1.0.5/1126双ARM；冻结在`E:\SayRing-market-artifacts-20261022\install-1126\SayRing-1.0.5-1126-release.apk`，72,014,067bytes，SHA-256 `16d839eb782dd50501bb5fffe63db5282fbe018ffe3c5556a744c2657e38a9f5`。不是旧包改名或Debug重签。
- 验证阶段退出0、9.4秒。官方apksigner v2通过、正式证书与手机旧包相同，aapt实际包名cn.saydian.ring/1.0.5/1126/min26/target36/双ARM/非debuggable；zipalign16KB通过。实际Manifest、资源表和生产JPush门禁通过，ABI门禁结合本轮Release依赖报告和pubspec.lock通过；保留JPush6.2.0/JCore5.5.2精确libjutils例外，未扩大其它库豁免。
- 实际检查43个ELF库，所有ARM64满足16KB；既有ARM32 libDspConfig.so与libEcgAnaly.so仍4KB，不能声称43个库全部16KB。

## 覆盖安装与真实系统回执

只执行指定唯一Android设备的`adb install -r <已验证1126正式APK>`，没有uninstall、clear、-d降级或-grant-all。发起时手机锁定，已请用户本人解锁/核对安装及身份确认；随后原安装进程直接返回`Performing Streamed Install / Success`。没有绕过系统检查、代输密码或在等待期间启动第二个并发安装。

独立`dumpsys package cn.saydian.ring`回读versionCode1126、versionName1.0.5，无debuggable；首次安装时间仍2026-10-20 10:58:24，更新时间2026-10-22 11:39:02。该时间不变证明不是卸载重装，不等于完整健康库内容/登录/绑定已逐项比较。没有声称做过原生私有数据备份或所有内容验收。

系统随后回读deviceLocked=0；`am start -W -n cn.saydian.ring/cc.saidian.saydian_app.MainActivity`返回Status ok、COLD、TotalTime784ms，真实PID及系统resumedActivity均匹配目标Say Ring。只验安装及启动，不执行额外UI、健康采样、提醒写入、OTP、支付或解绑调试；截图/页面内容未检查，不把Activity成功当全页面可用。

## Git收尾和未验收事项

构建完成再次fetch/prune成功，运行源码仍与远端1126开发分支`930ecda`一致（0/0）。仅提交本记录及索引；`git diff --check`通过，原另一个`E:\SayRing`工作树的用户文档修改保留，未覆盖其main。远端main或原1121远端分支不自动提升，本轮记录推送独立Windows安装分支，实际推送回读以Git输出为准。

本机完整检查已通过的仅为上述项目。iOS Debug/Profile及实物回执来自既有Mac实施记录，本机Windows不重跑或冒称通过；Xcode shell类平台限制保留。没有重新打鸿蒙包、发布市场、改线上下载或服务端配置，也不把已安装正式签名包当市场已审核通过。完整功能、蓝牙/传感器及支付等仍需独立验收。签名材料、临时key.properties、安装包和原始本机日志不提交Git。
