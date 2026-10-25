# Android 1144 下载发布记录（2026-10-25）

## 授权与范围

用户在完成Android实测后要求“上传更新”，随后明确选择“更新安卓下载页”。本轮仅发布Say Ring安卓1.0.6（1144）至既有下载后台并更新公开/down2；不变更其他产品、iPhone、HarmonyOS或服务端代码。开始前当前开发分支干净，fetch成功，HEAD与远端均为45046b990746b855e49e36842c679a72f7be4e30。

1144的功能修复、构建与设备证据见[SAY-RING-ANDROID-R12-R7PRO-20261025.md](SAY-RING-ANDROID-R12-R7PRO-20261025.md)。R7 Pro有效历史与修复后提醒实物触发仍未通过、R21未来睡眠日期仍待实物核对，本轮发布不改变这些验收结论，未新增“全部通过”的宣传。

## 发布前与安装包身份

后台会话可用，经“运营→客服与更新”选择唯一Say Ring App更新行，设置键为say_ring_app_update，公开已开启。旧Android为1.0.6（1137），文件say-ring-android-1792830855767-8381b578.apk，72046779字节，SHA256 041f6ea8f4a354b4269bf24e689de15a23b64ca5ae9a704503fd3945eebce424；旧文件保留，发布前配置私有备份于build/android-1144-download-publish-20261025/configuration-before.json。

本地正式包build/android-final-1144-20261025/SayRing-1.0.6-1144-release.apk重新核验：72063071字节，SHA256 44e88bfc1b6b32bad1e08f29efb70542c613b46ed7f47b9e522f9ad62730d8eb；apksigner verify通过，原证书SHA256 81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de。未重新签名或重新编译，也未上传Profile探针。

## 后台操作与纠正

首次行定位因把可访问快照中的空格当成DOM文本分隔而无匹配，未点击其他配置；改用唯一“Say Ring App 更新”文本限定行后成功。使用页面文件选择器上传原正式APK，等待后台自动计算文件名、字节数、SHA，全部与本地一致后才保存。

数字构建号控件的fill及Tab未使框架模型生效，读回仍1137，没有错误保存。检查控件真实类型/范围后，使用Android对应的增加数值按钮7次，读回精确1144。保存前核验三平台构建号依次1144/1130/1128、Android字节数与SHA、设置键均正确。点击“设为现在”，发布时间2026-10-25T13:58:55.974Z（北京时间21:58），再保存；页面明确反馈“已保存”。

新Android文件say-ring-android-1792936703085-ae4965b2.apk，公开路径：

https://app.saydian.cn/global/api/saydian-app/v2/support/app-package/say-ring-android-1792936703085-ae4965b2.apk

iPhone仍为1.0.4（1130），官方App Store链接仍https://apps.apple.com/cn/app/say-ring/id6816549943；HarmonyOS仍1.0.5（1128），原文件名、字节数、SHA和下载方式保持。未改其他配置行，也未删除旧包。

## 公开页面及线上包核验

新打开https://app.saydian.cn/down2，页面实际显示Android可下载、1.0.6（1144）、72.1 MB、正确SHA256和新文件链接；发布时间北京时间2026/10/25 21:58。iPhone卡仍1.0.4（1130）及原App Store链接。完整公开页面截图已保存并人工检查，无可见排版异常；截图只含公开下载信息，不含后台会员数据。

从上述公开链接完整下载线上APK，HTTP 200，无跳转，Content-Type为application/vnd.android.package-archive；实际72063071字节，SHA256与本地正式包逐字节一致。再次运行apksigner verify --print-certs通过，证书与原正式证书一致。回执build/android-1144-download-publish-20261025/online-verification.json，公开截图down2-1144-published.jpg，下载页作为浏览器交付标签保留。

本轮仅改后台发布元数据和本记录，不改App或网页源码，沿用45046b9的既有构建/实物结论，不重复编译和源码全量测试。针对本次变化完成本地原包哈希/签名、后台上传回执、保存守卫、公开页面与截图、线上完整下载哈希/签名、git diff --check；全部通过。历史旧包未删除，发布前配置可用于回滚。
