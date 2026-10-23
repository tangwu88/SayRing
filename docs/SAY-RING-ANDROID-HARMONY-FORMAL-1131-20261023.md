# 安卓与鸿蒙1.0.5（1131）正式包

## 请求、基线与边界

2026-10-23用户要求打包最新可用于上架的安卓与鸿蒙正式包。本轮只构建和校验，不安装手机、不上传应用市场、不修改线上后台、下载配置或会员/健康数据。包签名和格式通过，不等同商店审核通过或完整实物验收。

工作树 `E:\SayRing-market-release-20261005`，起点 `6ab75793f2a299589b2f0e079d3231d1796d19e7`。status干净、origin为tangwu88/SayRing；通过单次Git代理参数fetch/prune成功，包含最新开发分支 `1d2807b5b8f12645e99bb11ae554d871fd0e1b5a`，无待同步提交。创建独立分支 `codex/formal-android-harmony-1131-20261023`，保留原同步、鸿蒙、开发及main分支和其它工作树。

已读AGENTS、国际交接、修改索引、最新同步记录、Android/Harmony1128记录、Bug复盘与回归清单。沿用普通 `lib/main.dart`、生产API、客户端JPush标准通道、原商城编译配置、双ARM和原正式签名；不注入服务端Master Secret，不更改任何设备初始化、首次绑定清理或恢复出厂业务。构建号1131高于现有1128/1130记录，版本名仍1.0.5；Android由构建参数指定，鸿蒙AppScope和AppUpdateService同步更新1131，除此不改业务源码。

鸿蒙为独立ArkTS/ArkUI工程，当前没有QRing/LuckRing鸿蒙原厂SDK；其连接与新Flutter页面不能因本轮构建宣称可用。向用户明确此限制。鸿蒙构建Release后，先签内部HAP，再用项目级pack.info/pac.json官方打包并签完整APP，最后外APP和内HAP双验，未签中间产物不进入交付目录，以防991外签缺失回归。

签名、日志、产物仅存Git外 `E:\SayRing-market-artifacts-20261023\formal-1131`；不覆盖旧版。沿用原DPAPI/P12，不生成或轮换证书。预检查Android正式身份SHA-256为81F35CC98E023821425FEFAA0AA8DC998283BAABC161B5F9F5EC1295EE8CE5DE。鸿蒙官方证书链实际叶证书为C4F4B2AF305C338728D7172B845B4455D7CE1896EA0D40A28579FC1E56C28A3C，原P12私钥与此叶证书公钥一致，Profile为release/app_gallery、包名cn.saydian.ring.hm。

## 预检查失败及校正

一次读取GlobalConfiguration.ets路径不存在；实际共享配置是GlobalConfiguration.ts，已读取并确认国际域、产品和包名，不改配置。一次简化证书比较用X509构造函数读到证书链第一张根证书，误报与P12不匹配；改为逐张解析官方PEM链，确认P12匹配唯一发布叶证书。未改密钥、证书或已有完整叶证书验签门禁。磁盘检查C盘约1.8GB、E盘约18.4GB可用，构建缓存和临时目录沿用E盘，不清理用户文件。

## 验证与构建计划

Android依次prepare、analyze、UTC/上海全量测试、Debug、原生测试及Release依赖报告、正式Release、官方验签/包名版本/非debuggable/Manifest/ABI/16KB检查。鸿蒙双时区503项宿主测试、官方Release assembleApp、内HAP及完整APP签名与正反向验签。两个工程不共享构建输出；各自流程串行，不同时运行两个Flutter/Gradle任务。Windows不执行Xcode或macOS原生用例，前轮已知符号链接权限限制不通过修改系统权限掩盖。

实际命令、结果、失败与修正、产物大小/哈希、Git交付和未验收项将在完成后追加。没有本轮真实设备、OTP、支付、推送到达、健康采样或商店上传验收。

## 运行回执（续记）

Android使用Git外 `Run-Android.ps1`，复用上轮已验证的1126阶段脚本，在内存把输出根目录替换为本轮目录、构建号替换1131、测试并发替换4。生产构建复用既有 `Build-SayRingAndroid.ps1`，只在内存替换原默认版本名为1.0.5并加入既有 `SAY_RING_COMMERCE_ENABLED=true`。不修改原受保护签名脚本，不轮换密钥，不把DPAPI解密值输出到聊天或Git。

- prepare（`flutter pub get`）通过，10.2秒，锁文件未变化，不升级74个提示有新版的依赖。
- `flutter analyze --no-pub`零问题，83.2秒。
- `TZ=UTC flutter test --no-pub --concurrency=4 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`：1411项通过，95.8秒；Asia/Shanghai同命令1411项通过，74秒。TZ仅在子进程中设置。
- `node --test` 显式列出 `tool/*.test.mjs` 和 `tool/test_*.mjs`，并用 `--test-skip-pattern=^(offline handoff imports exact committed files and fails closed on corruption or existing targets|measures each byte once without following external symlinks)$` 明确排除前轮已证实受Windows符号链接权限阻断的2项夹具。结果125项通过、8项既有macOS原生用例跳过、0失败；排除的2项不是通过。不修改测试或系统权限。一次只读列举工具文件的PowerShell foreach后直接管道出现解析错误，改为数组子表达式后正确读取，未修改产品代码。
- 在scripts/release执行本机Python `-m unittest test_release_gate.ReleaseGateTest test_release_gate.PushConfigTest`：23项通过，0.536秒；真实平台发行工具与线上接口仍需单独验收。
- 鸿蒙使用既有官方CLT26.0.0.821、JDK17及现有SDK和依赖。Git外 `Run-Harmony.ps1 -Phase build` 复用已验证1128流程，仅替换输出目录和构建号。CLT随附Node执行tests目录全部.test.mjs：UTC503项、Asia/Shanghai503项均通过，阶段6.1秒、4.7秒。
- 鸿蒙 `hvigorw.bat --mode project -p product=default -p buildMode=release assembleApp --no-daemon`退出0，阶段104.8秒，Hvigor内部1分33.382秒，42任务（32执行、10缓存）。保留既有资源重复声明、弃用和unsigned构建阶段提示，不改依赖隐藏警告。
- `Run-Harmony.ps1 -Phase sign` 用原P12/叶证书/Profile签HAP，再以项目级pack.info/pac.json和签名HAP经官方app_packing_tool打包，最后官方hap-sign-tool签完整APP。`Verify-SayRingHarmony.ps1 -ExpectedVersion 1.0.5 -ExpectedBuild 1131`：外APP及内HAP官方verify-app均成功，原发布叶证书、有效release/app_gallery Profile、包名、版本、debug=false、pack.info/pac.json及内HAP字节不变均通过。
- 对明确标记outer-unsigned的中间APP执行同一门禁，被官方校验拒绝：`signature not found / No Hap Signing Block before ZIP Central Directory`，不把它交付市场。对应正、反向原始回执留Git外final-gate及negative-outer-gate目录。
- 鸿蒙冻结交付APP：`SayRing-HarmonyOS-1.0.5-1131-release-signed.app`，9,448,761bytes，SHA-256 `E8488184E04BBA13BBB81246C295CCAA67B8C1BB0EC8D3894EE512CBE3C429E9`；HAP：`SayRing-HarmonyOS-1.0.5-1131-release.hap`，18,711,792bytes，SHA-256 `63A4BE715886F27610A49504AC788BDEFD15DC73C1D87685EFDF586E64F79BBE`。复制到统一delivery目录后重新比对哈希一致，旧文件不覆盖。
- 只读GET国际 `/support/app-update?product=say-ring`，实际releases数组为Android1.0.5/1129、iOS1.0.4/1130、HarmonyOS1.0.5/1128，目标包名正确。本轮1131未写入此配置或公开下载。
- Android首次Debug由Windows PowerShell 5宿主启动，236.2秒时遇插件 `camera_android_camerax, jpush_flutter_android` 的Kotlin Gradle Plugin WARNING；该宿主将native stderr转换为RemoteException并按Stop中断，尚不能视为Debug完成。保留debug.log、results.json失败记录。只读检查确认原Gradle/Dart任务已退出后，改用PowerShell 7、显式关闭宿主native错误偏好，由Flutter实际退出码判定，按debug/native/release/verify继续；Debug新日志为debug-pwsh7.log，结果为resume-results.json，不覆盖失败记录、不升级插件或改业务代码、不同时启动两个Gradle任务。
- 切换PowerShell7后Debug成功，148秒，Flutter内部144.7秒；原生 `:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1` 成功，113.1秒，302任务（10执行/292缓存）。最终交付仍要通过SDK字节门禁，不能以此提前交付。

## 额外发现的Windows SDK副本编码问题（P2）

复现：在正常Windows构建后，执行 `node tool/verify_qring_sdk_copy.mjs android/app/libs/qring_sdk_1.0.0.76.aar build/app/generated/qring-sdk/qring_sdk_1.0.0.76-build.aar`。首次缺unzip，返回ENOENT；仅为该检查进程PATH加入既有 `C:\Program Files\Git\usr\bin` 后能实际校验，发现ProGuard中文注释损坏。期望只删除两条 `-printmapping map.txt`，其它内容保持一致；实际Gradle守护进程使用 `-Dfile.encoding=GBK`，Zip.filter默认编码使UTF-8注释转换成乱码，构建副本日期仍为旧缓存2026-10-14。原始SDK、其他AAR成员和二进制未改写，但严格文本门禁不能放宽为通过。

修复限于打包任务明确 `filteringCharset = "UTF-8"`，并在既有client_package_contract增加断言；先只加断言运行，3项中1失败/2通过（预期RED），原回执保留qring-utf8-red.log。等正在运行的原构建退出后再更改Gradle配置和串行重建Debug/原生/正式Release/验签，保留修复前候选包，不把它当最终交付。构建号、SDK内容、功能、协议、R8保护语义和原证书均不变。该小范围构建修正是本轮为满足既有SDK完整性门禁所需，不是新增功能。

修正前的首轮正式Release315.4秒、验签7秒通过，但不满足SDK完整性门禁，因此仅保留为Git外 `android/candidate-before-utf8-fix.apk`，不放delivery；72,030,451bytes，SHA-256 `D0DD4BDBBFC2BB6E0A6490D22438116DD752F9372BA28A1FDDFB5213F31C702F`。修改Gradle前重新fetch成功，远端开发仍1d2807b，确认上一轮进程退出且key.properties已清理后才继续。

UTF-8修正后client_package_contract三项全部通过（GREEN）；全部可运行工具用例复跑125通过/8跳过，原2项符号链接用例仍明确排除。重新构建Debug通过，182.7秒（Flutter内部176.2秒），`verify_qring_sdk_copy.mjs` 实际验证30个文件成员完全一致，唯一允许变化为移除两条mapping输出指令。原始AAR固定SHA-256继续由契约门禁校验，不修改原厂SDK。最终重建使用Run-Android-Utf8.ps1，阶段日志和结果使用独立utf8后缀，不覆盖之前失败或候选回执。Flutter业务源码与测试源码从已通过两轮1411项的基线起未再变化，Android变动只有构建过滤编码及对应Node断言，鸿蒙变动只有版本号。

## 最终安卓构建与正式验签

最终原生阶段99.5秒，302任务（6执行/296缓存）；读取本轮JUnit XML独立统计12个suite共54项，失败、错误、跳过均0。ReleaseRuntimeClasspath报告为native-utf8.log，用于同轮ABI门禁。

最终正式Release216.4秒、Flutter内部203.2秒，普通main、1.0.5/1131、双ARM，SAIDIAN_PRODUCTION_RELEASE=true且QA/emulator开关false。保留插件KGP迁移警告，不把警告改写为已解决。正式Release后再次对SDK副本执行逐文件门禁：30成员一致，仅移除两条mapping输出规则，证明重建及R8后未改变厂商代码。

最终verify阶段6.4秒通过，实际apksigner v2验签成功；正式证书SHA-256 `81F35CC98E023821425FEFAA0AA8DC998283BAABC161B5F9F5EC1295EE8CE5DE`，SHA-1 `F1446D0AE226EBBED240083EB1143BFEC48F200E`，MD5 `09D14504FD119AE833B2AAAAEECC13FE`，与原正式身份一致。实际aapt包名cn.saydian.ring，1.0.5/1131，min26/target36、双ARM、无debuggable。zipalign -c -P 16 4、实际Manifest/资源表、生产JPush及同轮Release依赖ABI门禁均通过；保留原JPush6.2.0/JCore5.5.2的精确libjutils例外，不扩大豁免。

实际检查43个ELF，所有ARM64满足16KB；既有ARM32 libDspConfig.so和libEcgAnaly.so仍4KB，不能宣称全部原生库均16KB。未修改厂商二进制。Android临时android/key.properties在finally清理，结束后Test-Path=false，原P12、DPAPI和正式证书保留。

最终交付APK `SayRing-1.0.5-1131-release.apk`：72,030,451bytes，SHA-256 `F119719347A02557F537C5AE1139B3C1D2FA6DD60E4B83879138DDF47EF0852F`。与修正前候选的大小相同但哈希不同，不以旧包代替。复制至统一delivery目录后重新比对哈希一致。

## 最终交付、Git与未验收项

统一目录 `E:\SayRing-market-artifacts-20261023\formal-1131\delivery` 只放最终APK、完整双签release-signed.app、正式HAP、交付说明和SHA256SUMS.txt，不放debug、修复前候选、未签中间包、私钥、密码、Profile或原始签名日志。鸿蒙上架只提交完整release-signed.app，不解压、重新压缩或改扩展名；HAP是受控安装验证用，app_gallery Profile的实际侧载接受情况仍以手机为准。

本轮仅提交本构建记录/索引、鸿蒙两个版本字段及Android编码任务/Node断言这6个显式文件，并推送独立formal分支；不提升main，不改开发/旧正式分支。提交前再次fetch核对远端，结束核对远端SHA与工作树；实际提交以Git历史及交付回执为准。构建产物不进Git。

Windows未执行Xcode/iOS构建或8项macOS原生夹具；2项符号链接夹具保持环境阻断，不计通过。当前请求不包含安装、实物调试或市场上传，因此没有本轮手机、真实戒指、登录/OTP、付款、推送到达、后台修改、公开下载切换或AGC接受回执。本地签名/格式门禁通过不等同全部业务验收、991已获华为后台接受或市场审核通过。鸿蒙仍没有QRing/LuckRing原厂SDK，不能将这些型号用于声称功能完整的上架验收；此限制及正式HAP的侧载限制在交付说明明确保留。
