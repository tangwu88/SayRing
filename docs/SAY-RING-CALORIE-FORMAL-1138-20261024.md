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

## 安装完成回执与失败的实物复测

- 用户回复已安装后，原adb会话返回Success。手机实际cn.saydian.ring为1.0.6(1138)，lastUpdateTime=2026-10-24 18:26:33；firstInstallTime仍为本轮基线2026-10-24 16:48:38。只做覆盖安装，没有卸载/清数据。
- 拉取更新后的已安装base.apk，SHA256精确匹配144CF805CF4E99C3EEF38BC9B818F77417511A55A83C9B75B55D5CB52AA0299F正式产物，不是旧1137或QA包；与旧APK比较，Dart AOT和DEX内容哈希确有变化，未仅凭版本号认定实际产物。
- **热量真机验收未通过**：首页仍显示旧异常千卡，没有单位待确认；趋势仍绘制异常数值，详情仍显示kcal。先记录此现象，随后显式停止/冷启动本App（不清数据、不解绑）复测，结果相同，排除仅是热进程/页面未刷新。不能把已安装和宿主测试通过写成修复已在真实数据生效。
- 详情记录数安装前后均1，首次安装时间不变，原登录页面未出现、既有首页可访问；没有以清库或隐藏记录解决问题。但未导出加密数据库，不能宣称已逐字段验证整个数据库完整性。最终返回本App首页，进程仍在。
- 只读追踪：保护函数当前仅覆盖特定vendor/rawVersion且要求MeasurementSource.wearable；全局云端解析对缺measurementSource的数据保留imported，iOS原始记录还存在v2协议版本。这些是未覆盖形态的代码证据，不是本机这一条记录真实元数据已读回。UI仅提供戒指历史来源说明，不能凭连接的型号或数值大小断言它必定是某SDK/v1，也不能直接把imported改成wearable。
- 复核本地加密库完整payload序列化、路由来源映射、SDK适配与包入口，未找到足以证明该条真实记录vendor/source/rawVersion的只读导出渠道。实际元数据、精确单位倍率和后续修正仍待补充隐私安全诊断；本轮未再猜测除数、扩大来源黑名单、改历史或擅加生产调试输出。
- 路径检索再次遇到Windows将glob作为字面路径及猜错路由文件名，改为rg --files/明确文件后继续，不是编译或应用故障。无功能源码变更，不重跑同源码全量检查冒充新增验收。

最终结论：正式包生成、保数据覆盖及实际包核验完成；热量问题仍未闭环，main、线上下载和商店均不推广。实际失败结果随日志推送开发分支，不能沿用上一轮自动化页面测试替代此实物失败。
