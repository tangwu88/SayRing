# Android 原正式证书导入与密码解锁待办

## 本轮范围

用户于2026-10-20提供`saydian-release-signing.rar`，用于继续此前授权的本机构建正式APK及更新`/down2`。修改记录前确认当前分支干净、fetch及ff-only成功，起点`b83f228ece02eed563ec96ccef2588e6939370fc`。没有修改业务源码、SDK、发布门禁、线上下载或iOS审核。

## 实际核验

- 原压缩包28,348bytes，SHA-256`60948eee7ed3535c4d0420317dbb4e067493586b5c2e389e05564c40b2961c67`；使用本机已有bsdtar列目录并检查绝对路径/父目录穿越，解压到Git外受保护目录。目录700、文件600，无符号链接，保留原包。
- Android材料包含`release.p12`私钥容器、公开CER和`password.dpapi.clixml`；Harmony材料保持未使用。只静态分析包内PS脚本，没有执行其指令。
- 公开证书SHA-256 **81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de**，与此前独立验签的线上Say Ring1016完全匹配；有效期2026-10-05至2056-09-27。此时尚未解锁P12，因此不把CER匹配说成已验证私钥条目或已签出新包。
- 包中既有Say Ring脚本包含有效格式的生产极光AppKey、production渠道及明确`none`厂商通道。与公开1016 APK的实际Manifest逐值比较，AppKey和channel一致；没有取用其他App或服务端Master Secret。
- 在Git外生成受保护的Android生产环境/Flutter定义JSON，固定`cn.saydian.ring`所属生产API、`/global` Say Ring更新端点及商城显式编译开关。用现有`prepare_push_config.py --vendors none --expected-package cn.saydian.ring`检查，退出0；不代表真实推送送达，也不代表微信/支付宝App商户已接通。

## 当前阻断及已准备步骤

密码仅以Windows DPAPI SecureString保存，绑定生成材料的原Windows用户上下文，当前Mac没有解密材料。没有猜密码、导出系统凭据、重建证书或以Debug签名替代。已通过会话问题请求用户在原Windows账号导出，并将密码留在这台Mac的受保护本机文件中，不发送到聊天。

已在Git外准备`Export-AndroidSigningPasswordForMac.ps1`：仅读指定DPAPI文件，在原Windows账号中创建新文件；写密码前先将文件ACL限制到当前用户；不覆盖已有文件、不输出密码，并在finally归零BSTR。本机现有PowerShell仅执行Parser语法检查，退出0；没有在Mac运行Windows解密。

恢复时：先读取本机密码文件并限制权限，用keytool的文件/环境密码接口解锁原PKCS12，确认PrivateKeyEntry及证书匹配，然后按正常生产模式重新构建1.0.5（1121）。不能只给推送关闭的旧QA产物重签名冒充生产重建。最终还须核对真实包名/版本/正式证书、非Debug、zipalign16KB、Manifest/ABI，上传不可变APK并公网重下验哈希后，才更新Say Ring Android下载配置；iOS/Harmony及用户数据保持原状。

本轮只有记录变更，未重复上一轮已通过的双时区各1347项或双端编译；没有宣称新正式APK、同签升级实测、支付或下载页发布成功。所有P12、密码、AppKey、私有环境和原脚本均不入Git。
