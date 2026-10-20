# Android 1.0.5（1121）原签名正式构建与下载更新

## 授权与源码

用户此前要求在本机生成正式Android APK并更新`https://app.saydian.cn/down2`，本轮提供原签名解锁材料。修改记录前工作树干净，fetch/ff-only后仍为`c105df7b481fdc763d0c8bcf245f45178c26efba`。运行源码与阅读优化提交`503ea25`一致；期间提交只有记录。包含最新原生商城、手势/连接/睡眠及百科适老阅读，不合并未完成硬件整体验收的main。

## 原签名与生产参数

- 原PKCS12已实际解锁，唯一条目`PrivateKeyEntry`、别名`say-ring-android-release`；条目证书与原公开CER、线上正式1016的SHA-256均为`81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。没有新建私钥或使用Debug证书。
- 解锁材料和生产环境仅存Git外受保护目录。构建按需生成600权限的ignored`android/key.properties`，finally移除；keytool用文件密码接口，密码及推送值不打印、不写Git或命令参数。
- 正常`lib/main.dart`，双ARM，生产API`https://app.saydian.cn/global`对应V2请求、更新清单`/global/api/saydian-app/v2/support/app-update`，固定`cn.saydian.ring`。显式`SAY_RING_COMMERCE_ENABLED=true`保留用户要求的原生商城；账号、价格、库存、支付能力检查不绕过。
- `SAIDIAN_PRODUCTION_RELEASE=true`、QA=false、emulatorDebug=false；原生产JPush客户端AppKey与线上实际Manifest一致、channel=production、厂商渠道明确none。没有使用服务端Master Secret，不能据此宣称真实通知送达。

## 实际构建和检查

- Flutter3.44.9 / JDK17 / Android build-tools36。`flutter build apk --release --no-pub --target=lib/main.dart --target-platform=android-arm,android-arm64 --build-name=1.0.5 --build-number=1121 --dart-define-from-file=<受保护生产JSON>`：**退出0，77.0秒**。不是给旧QA包重签名。
- 冻结产物`build/formal-android-1121/SayRing-1.0.5-1121-release.apk`，**71,832,499 bytes**，SHA-256 **61834ff3058d056ead83e1f55358d25e11d3c56ee86dac7f4e259c8fe85f4fe3**。
- 官方apksigner验证成功且与原正式证书相同；aapt实际包名`cn.saydian.ring`、版本1.0.5、构建1121、非debuggable；zipalign16KB通过。
- 本轮重新执行发布门禁单测**34/34**；实际releaseRuntimeClasspath报告退出0、6.4秒。apkanalyzer实际Manifest、aapt2实际资源表的`apk-manifest`通过；`apk-abis`通过，锁定JPush6.2.0/JCore5.5.2的精确libjutils例外不扩大。双ARM共43个.so，22个ARM64库实际llvm-readelf LOAD段均至少16KB；不将此静态检查当所有设备运行验收。
- 运行源码未变化，沿用同日本机最终Analyzer零问题、双时区各1347项、AndroidDebug/QARelease及53项原生、iOSDebug/Profile编译的实际记录，见[适老阅读](SAY-RING-ARTICLE-READER-20261020.md)。没有为文档和签名重复全量测试，也不把QA产物当本次正式产物。

## 登录故障插入处理

用户在构建期间报告AppStore1.0.4两种登录都显示暂不可用；已先暂停清单发布，查明新旧法律文档版本不配套。用户明确选择恢复原v3后，经过后台UI恢复原已审核协议，公开能力和正文哈希复验成功；详见[登录恢复](SAY-RING-LOGIN-LEGAL-RESTORE-20261020.md)。没有用另一个产品的文档或关闭同意检查解锁登录。

## 下载交付过程（持续记录）

通过已有登录的后台“Say Ring App更新”专用表单上传唯一正式APK，后台生成不可变文件`say-ring-android-1792460747254-a76ee307.apk`；实际表单返回大小和SHA-256与冻结产物一致。先完整公网重下并核验，之后才保存1.0.5（1121）版本配置。最终公开清单、重下和页面结果按实际完成续记，当前不提前称已发布。

iPhone仍为AppStore1.0.4（1120）、HarmonyOS仍1.0.2（1111），其链接/文件保持原值；不改其他App、账号数据、健康数据、服务器源码或苹果审核。App微信/支付宝收款仍未配置，商城真实购买及支付回跳未验收；没有创建生产订单、扣款、发OTP或重装手机。

日志、冻结APK、公网重下、配置快照和工具仅在`build/formal-android-1121/`，不入Git。

## 最终发布续记

- 不可变公网APK完整重下：HTTP200、无重定向，101.5秒；实际71,832,499bytes、SHA-256`61834ff3058d056ead83e1f55358d25e11d3c56ee86dac7f4e259c8fe85f4fe3`与本机冻结正式包完全相同。
- 保存前再次GET公开清单，data与初始快照语义完全一致，规范JSON哈希`a9626c492136adde796d9db98bad40a394b9e97cfb10a89057106d432bbabd51`；未观察到并发修改。该后台UI未提供CAS参数，不冒充执行了服务端CAS。
- 只在Say Ring专用表单将Android设为1.0.5（1121）、上传生成的APK地址/大小/哈希，并将共享发布时间设为此次更新时间；保存后公开API实际回读版本/构建/包名/状态和文件信息完全匹配。
- iOS、HarmonyOS两份release对象与保存前逐字段一致；audience、realm、schemaVersion及其他顶层值均不变。公开下载地址为`https://app.saydian.cn/global/api/saydian-app/v2/support/app-package/say-ring-android-1792460747254-a76ee307.apk`。
- 此为下载页直接分发正式签名APK，不是各Android应用市场已经审核/上架，也不是原生支付已接通或Android手机覆盖升级实测。
- 收尾文档首次追加的Python stdin遇到UTF-8解码错误，尚未写入文件；改为apply_patch补记，不重跑已通过构建或改动正式APK。
- 公开`/down2`刷新后实际显示Android **1.0.5（1121）/71.8MB/可下载**，按钮精确指向本次不可变APK；页面截图已查看，保存在主工作树`build/mall-download-20261020/down2-android-1121-published.png`。此网页原有“内部测试下载”分类不变，APK为原正式证书签名。
