# Android 1.0.5（1128）正式包（2026-10-22）

用户授权最新Android原签名正式构建并同步`https://app.saydian.cn/down2`。源码为ca31f5f及随后仅Android TargetSettingRsp读取动作接口修正；普通lib/main.dart，非专项测试入口。新功能及主机回归、iOS不同产物边界见[首次绑定记录](SAY-RING-FIRST-BINDING-20261022.md)。不覆盖Windows同事分支，不提升未完整验收的main。

## 产物与检查

- 使用原受保护P12、原别名和密码文件，不创建新证书；原生产Dart定义/JPush客户端配置从Git外文件载入。临时ignored android/key.properties权限600，finally移除，已经复核不存在；不记录密码或推送值。
- 显式SAIDIAN_PRODUCTION_RELEASE=true、QA=false、emulatorDebug=false；版本1.0.5、构建1128、cn.saydian.ring；首方请求固定global realm且更新产品say-ring。原商城编译开关开启，付款/库存等服务端边界未绕过。
- 首轮Android Debug7.7秒失败于SDK没有isRead；实际固定AAR的javap确认MixtureRsp.getAction/ACTION_READ，保持读响应检查后修正。新目录android-v2重新构建Debug5.0秒、原生JUnit54项5.9秒均成功，测试零失败/错误/跳过。
- 正式双ARM APK构建42.8秒退出0，冻结文件`build/formal-android-1128/SayRing-1.0.5-1128-release.apk`，**72,030,115 bytes**，SHA-256 **41c0f8efb3eb79ae4630554fb846647a93869f5f8d6715034cf8ccb21277654e**。
- apksigner严格验证通过，证书SHA-256 **81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de**，与原正式1016/1121一致；不是Debug签名或旧包重签。
- apkanalyzer实际Manifest与aapt2资源、releaseRuntimeClasspath依赖报告、发行脚本apk-manifest/apk-abis均通过；无debuggable，包名/版本/生产推送配置与预期一致。Manifest检查首轮忘载入受保护环境而报缺JPUSH_APP_KEY/JPUSH_CHANNEL，保留失败日志，补原生产环境后同一APK检查通过。
- zipalign -P16通过；双ARM共43个.so，22个ARM64库llvm-readelf实际LOAD段均至少16KB。保留既有JPush6.2.0/JCore5.5.2的精确libjutils例外，不扩大豁免。没有在线Android硬件，本次不声称真机覆盖升级、实际SDK清空或各应用市场审核通过。

## 下载发布进度

公开清单原为Android1.0.5（1121）、iPhone App Store1.0.4（1120）、Harmony1.0.2（1111）；保留另两平台。已登录后台的Say Ring App更新专用表单选择1128正式APK，上传请求却因会话过期跳转`/admin/login`；未取得服务器成功生成的不可变文件地址，未保存版本配置。已请求用户恢复管理员登录，后续需重新上传、完整公网重下核对字节/哈希/原签名、保存前重读清单、仅改Android和共享发布时间，再回读API及下载页、保存并展示截图。未将本地成功构建写成公开下载已更新。

首次绑定服务端PR59已合并90acb7f，China部署仍在运行时不发布依赖它的客户端；上线后以公开readiness与兼容配置回读为准。未改生产用户、戒指数据、现有协议、App显示配置、US环境或iOS公开下载版本。
