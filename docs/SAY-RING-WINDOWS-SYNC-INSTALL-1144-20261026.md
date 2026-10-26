# 2026-10-26 Windows同步最新开发代码与Android1144覆盖安装

## 授权与同步

用户检查更新后要求更新本地代码并安装手机。本轮只同步既有开发代码和安装已发布的正式Android包，不开发功能、不更新后台/下载配置、不发布商店，不卸载、不清数据、不解绑/重置/代绑戒指。

开始时E:\SayRing-market-release-20261005工作区干净，当前codex/login-camera-r7ultra-1136-20261024及所跟踪远端为d16872378d168cc99ac6b38ffec739d6c1ed7865。fetch origin --prune成功，最新开发分支origin/codex/device-search-help-1141-20261024为829f6813e7dc98a72449d4066f7b7e214d753878，HEAD相较其0/12。执行git merge --ff-only该远端分支，成功无冲突快进12个提交至829f681，保留原历史，不强推、不改main。

已阅读当前AGENTS、国际交接及最新实施/发布记录；新AGENTS明确R8 Pro改走QRing，取代之前例外，遵守原设备握手与owner绑定保护。1144发行源码提交45046b990746b855e49e36842c679a72f7be4e30至829f681仅有发布文档/索引变化，没有新增产品源码，故使用其既有正式包而非重新编译或误装旧QA。

## 手机与安装包核验（后续结果逐项追加）

ADB唯一授权手机Huawei JAD-AL00，cn.saydian.ring安装前1.0.6(1138)，firstInstallTime=2026-10-24 16:48:38，lastUpdateTime=2026-10-24 18:26:33。初检已解锁，无需卸载或更换签名。实际安装后再核对时间、版本和包哈希，不能把已发起安装写成成功。

从原发布记录指定的HTTPS同源路径/global/api/saydian-app/v2/support/app-package/say-ring-android-1792936703085-ae4965b2.apk下载，拒绝重定向。期望字节72,063,071，SHA256=44e88bfc1b6b32bad1e08f29efb70542c613b46ed7f47b9e522f9ad62730d8eb；仅在完整下载、哈希、原正式证书81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de、包名cn.saydian.ring及版本1.0.6(1144)、非debuggable与16KB zipalign核对通过后安装。私有文件存Git外E:\SayRing-market-artifacts-20261026\sync-install-1144，不提交APK、身份、健康UI或会话数据。

本轮不把原记录中R7 Pro历史/提醒触发、R21睡眠日期等未通过项写成已完成；仅安装启动检查不代表全部硬件或健康数据验收。本轮没有产品源码/依赖变更，不重复构建或将之前回归冒充新执行。

## 本轮实际结果

- curl经本机代理获取指定公开文件，HTTP 200、有效URL仍为原同源HTTPS路径，没有重定向；实际字节72,063,071和SHA256完全匹配原发行记录。apksigner verify核对原证书通过，aapt核对cn.saydian.ring、1.0.6(1144)、非debuggable通过，zipalign -c -P16 4通过。未重编、重签或上传文件。
- adb -s唯一授权手机 install --no-incremental -r正式APK返回Success。手机系统实际显示Say Ring安装成功，未操作其他推荐应用或修改安全设置，无需用户再次确认。dumpsys核验versionName=1.0.6/versionCode=1144，lastUpdateTime=2026-10-26 09:33:39；firstInstallTime仍为安装前2026-10-24 16:48:38，未卸载、未清应用数据。
- 再拉取更新后本App的base.apk至Git外，SHA256精确匹配44e88bfc1b6b32bad1e08f29efb70542c613b46ed7f47b9e522f9ad62730d8eb，证明实际安装的是本轮核验正式产物，而非仅版本号相同的QA/旧包。
- am start -W显式启动MainActivity为COLD、约774ms，App进程存在；实际UI进入今日活动首页，没有验证码/密码登录页。不将无登录页等同于全量云端鉴权回归；没有导出加密健康数据库或逐字段核验完整容器。未做新的扫描绑定、同步/测量/手势或设置写入，因此不改变既有硬件未验收结论。
- 过程没有下载、签名、安装失败，也没有产品源码改动。git diff --check和发布前远端守卫核对后，仅提交本日志和索引并推送当前开发分支；不提升main、不改线上后台或下载清单。
