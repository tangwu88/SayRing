# 2026-10-24 热量单位保护1138正式构建与保数据覆盖复测

## 授权和基线

用户同意建议，要求重新打正式包、覆盖安装后复测。本轮仅Android，不卸载、不清数据、不解绑、不重置戒指，不发布商店或更新线上下载清单/后台。源码基线07ecc55a06e95ae0850ae7d6b06056e19c840113；开始时工作区干净，fetch origin --prune成功，与所跟踪分支0/0；干净状态merge --ff-only上游返回Already up to date。不推广main，保留待厂家确认的热量倍率和此前R7完整历史/手势边界。

已复核AGENTS、国际交接、最新单位修复/1137记录以及回归约束。同源码上一轮analyze零问题、两时区各1450/1450、原生60/60、Node21/21、Python23/23及Debug/QA Release通过；本轮不修改功能源码、依赖或重复把旧测试称为新测试。正式构建使用原受保护签名脚本与生产门禁，不能复用上轮Debug签名的QA产物。

## 安装前现场

ADB仅一台已授权Huawei JAD-AL00，屏幕亮、未锁定；现有cn.saydian.ring为1.0.6(1137)。本轮读取的firstInstallTime和lastUpdateTime均为2026-10-24 16:48:38，与更早日志时间不同；不能把早前安装时间冒充本轮基线，也不猜测期间外部操作。后续只比较本轮安装前后时间、实际签名与包哈希。

## 构建和验收（待完成后逐项续记）

Git外Build-Formal1138.ps1复用已验模板，版本1.0.6(1138)、双ARM、标准生产JPush及原证书；仅将无依赖变动的pub get在调用层设为offline，避免此前在线解析阻塞；不修改受保护签名器或降低门禁。依赖报告、正式Release、验签/包信息、16KB对齐/ABI/ELF检查、安装与页面真实结果分别记录。原始健康UI/设备证据只保存在Git外，不提交真实健康值、账号、MAC或会话。

已知修复边界：首页热量/目标/趋势显示单位待确认而不是猜测kcal；原始记录保留。准确倍率仍待厂商协议，覆盖安装通过不等于热量已校准或全部戒指功能验收。

## 安装前确认与构建过程

- 已拉取本App的已安装base.apk到Git外，仅核验包身份；SHA256仍为041F6EA8F4A354B4269BF24E689DE15A23B64CA5AE9A704503FD3945EEBCE424，apksigner证书SHA256为81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de，与1137正式归档一致。不因安装时间改变猜测原因。
- 初次检查前台是微信而非Say Ring，没有操作微信；随后手机锁屏，用户经异步问题明确回复已解锁，再显式打开Say Ring取得安装前首页/热量详情。旧版仍显示原异常千卡，详情仍有记录和曲线；原始UI仅留Git外，后续复测对照本轮现场，不拿清库后的空态冒充修复。
- dependencies阶段执行gradlew.bat :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1成功，约1分40秒；离线pub依赖解析成功。未升级或改写依赖锁，既有Kotlin插件迁移警告保留。正式Release仍在执行，未提前计成功。

## 正式产物门禁

- 正式Release构建成功，assembleRelease约269.4秒；cn.saydian.ring、1.0.6(1138)、双ARM，原证书SHA256为81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de。apksigner、aapt、zipalign -c -P16 4、生产Manifest/JPush及ABI门禁通过，不是上一轮QA签名。
- ELF检查43个库，64位全部通过16KB检查；沿用两个ARM32库libDspConfig.so、libEcgAnaly.so的既有4KB边界，以及锁定JPush/JCore下libjutils.so的已审ABI例外，未放宽检查或升级SDK。
- 产物E:\SayRing-market-artifacts-20261024\calorie-unit-1138\android\SayRing-1.0.6-1138-release.apk，72,046,779字节；SHA256=144CF805CF4E99C3EEF38BC9B818F77417511A55A83C9B75B55D5CB52AA0299F。签名器finally已移除临时android/key.properties。未把密钥、产物或原始UI提交Git。

## 安装进行状态（不是完成回执）

已对唯一授权手机执行adb install --no-incremental -r正式产物。普通系统“继续安装”后进入华为Say Ring安全检测页；只核对并操作该App的底部继续按钮，没有点击推荐应用的安装或修改安全设置。系统提示未查询到ICP备案信息，本轮不据此推断实际备案法律状态或更改备案资料。远程点击后页面仍未改变，已请求用户本人确认底部继续安装及可能出现的身份验证；版本仍需安装终态后复核，不提前记完成。
