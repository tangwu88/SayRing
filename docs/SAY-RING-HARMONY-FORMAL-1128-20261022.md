# 鸿蒙1128正式安装包与AppGallery包

## 范围、基线和限制

用户要求同时生成鸿蒙安装版与应用市场版，不要求本轮安装或上传市场。原工作树19abf2d、干净，fetch/prune成功，运行源码对应最新开发7ffa55e；新建独立分支codex/harmony-formal-1128-20261022，保留Android分支、原正式证书及其它工作树。

已读项目AGENTS、国际交接、回归/复盘及1128记录，并核对原生鸿蒙README与上轮1111整包验签记录。鸿蒙是独立ArkTS/ArkUI工程，不因Android/Flutter代码同步而具备新UI、首次绑定初始化或QRing/LuckRing SDK。已向用户说明仍无这两家鸿蒙原厂SDK，不宣称这些戒指可用。工程最低5.0.5/API17，不以Android APK冒充原生鸿蒙包。

仅将AppScope版本和AppUpdateService一致升为1.0.5/1128；从已验证b6efa40导入只读Verify-SayRingHarmony.ps1，保留外APP先验、内HAP再验、原发布叶证书/Profile/包名/有效期/版本/debug=false和HAP字节不变门禁。没有从旧分支混入其它运行代码。

沿用Git外原P12、发布证书和app_gallery/release Profile，不运行已弃用的明文Hvigor签名脚本。不更改后台、公开下载、会员/健康数据、市场资料或审核。产物和原始签名日志位于E:\SayRing-market-artifacts-20261022\harmony-1128，不提交密钥/Profile或包到Git。

## 流程和验收计划

鸿蒙双时区宿主全量测试后，用现有官方CLT/SDK执行Release assembleApp。先签内部HAP，再以官方项目pack.info/pac.json打包，最后单独签完整APP；最终同时做外APP和内部HAP官方验签，不能沿用只签HAP的旧991错误方式。未签中间APP单独放intermediates，不进入delivery，市场交付文件名明确release-signed.app。

最终提供正式HAP供原生鸿蒙受控安装验证、完整签名APP供AGC上传，以及交付说明/哈希。Profile为app_gallery，HAP是否可在特定手机侧载以系统校验和实际安装回执为准，不把文件生成或验签当成设备已安装；本轮无原生鸿蒙手机安装/AGC上传验收。

原Android源码及其最新两时区各1410/原生54/正式验签均无变化，沿用同源19abf2d回执，不为独立鸿蒙版本/只读打包门禁重复安卓或Flutter构建；Windows不能执行iOS构建。鸿蒙实际命令、结果、失败与校正完成后续记，不提前记通过。

## 实际构建与失败记录

- 原验签PS从b6efa40导入后，git hash-object与旧blob均为1e38e416b4b40b5c6bc8a73c9edbc7cceca0a822，未修改保护语义。
- CLT随附Node执行`node --test <tests目录全部.test.mjs>`，UTC503/503、阶段5.4秒；Asia/Shanghai503/503、阶段4.1秒，均零失败/跳过。仅进程TZ环境变化，不改系统时区，不是实物SDK验收。
- 现有CLT26.0.0.821及工程依赖，`hvigorw.bat --mode project -p product=default -p buildMode=release assembleApp --no-daemon`退出0、阶段65.9秒；Hvigor内部54.813秒，42任务（32执行/10缓存）。保留既有资源/弃用及无内置signingConfig提示，不以unsigned构建输出交付。
- 打包工具`--help`返回mode invalid退出1，不能用帮助请求当产品打包失败。随后直接用JDK javap读取本机官方ohos.CommandParser常量，确认真实参数为--pac-json-path；没有猜参数、改JAR或丢弃pac.json。
- 原受保护Sign-SayRingHarmony.ps1只在内存核对并替换两处文件名默认1.0.0为1.0.5，BuildNumber1128，先签内部HAP。其旧中间APP仅留intermediates/hap-sign，不是交付APP。
- 用本轮项目级build/outputs/default/pack.info和pac.json、签名entry-default.hap，官方app_packing_tool --mode app --replace-pack-info false --deduplicate-so false生成单独标记outer-unsigned的中间包，再用同一原P12/证书/Profile执行官方hap-sign-tool sign-app签完整APP。凭据只在本机受保护来源/进程内使用，不写源码、Hvigor配置或交付说明。

## 验签和最终产物

Verify-SayRingHarmony.ps1对最终APP先验外层签名，再提取内层HAP并验签；两层原发布叶证书SHA-256均为C4F4B2AF305C338728D7172B845B4455D7CE1896EA0D40A28579FC1E56C28A3C，Profile为有效release/app_gallery且包名cn.saydian.ring.hm。project pack.info、pac.json、版本1.0.5/1128、内部module debug=false及HAP字节不变全部通过。对本轮未签外层中间APP执行同一门禁，被外签检查实际拒绝；保留负向日志，不能以仅内HAP验签冒充整APP通过。PS AST检查和git diff --check的最终结果按收尾命令记录。

最终目录`E:\SayRing-market-artifacts-20261022\harmony-1128\delivery`仅交付：

- 安装验证HAP：SayRing-HarmonyOS-1.0.5-1128-release.hap，18,711,783bytes，SHA-256 F2C52686C3F6B3976C2C41ADAA734099912CBADB08AB5842CED4673DEB399F1F。
- 市场APP：SayRing-HarmonyOS-1.0.5-1128-release-signed.app，9,448,789bytes，SHA-256 F58CBA96EB6B4D79A5EAD854A10868A6F9D05325239AE7731FE0A86CEC147834。
- 交付说明：只传完整release-signed.app到AGC，不改后缀、解压或重新压缩；原生鸿蒙SDK和HAP侧载/Profile限制明确保留。

本轮没有安装鸿蒙手机、上传AGC、替换线上下载或执行真实戒指操作。991所涉外签缺失已在本地正反向门禁防护，但未实际上传时不声称华为已接受或审核通过。iOS、Android产物及个人/健康数据保持不动，私钥/密码/Profile/构建产物和原始日志不进Git。
