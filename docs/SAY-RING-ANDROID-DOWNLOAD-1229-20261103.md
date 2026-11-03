# Android 1.0.10（1229）正式包与下载页

2026-11-03。用户要求将最新 Android 版本更新至赛电戒指下载页。源码与远端均固定在 `fa5a8981cd0374121604f6cc42b5f4b0eca44be4`；运行时代码为已验证的 `a7fcf7a`。本轮不改客户端源码、数据库、绑定、设备设置或 SDK，不安装手机。

## 正式构建与核验

- `flutter build apk --release --no-pub --target=lib/main.dart --build-name=1.0.10 --build-number=1229 --target-platform=android-arm,android-arm64 --dart-define-from-file=<本机原有正式配置>`，正常生产构建 94.1 秒成功。使用原 P12 和生产推送配置，不重新签名 QA/Debug 包。临时签名属性文件只在构建期间以私有权限存在，完成后移除；密码和原始配置不进入 Git。
- `apksigner verify --print-certs` 确认原发行证书，证书 SHA-256 为 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`。完整下载线上旧 1202，字节数、SHA-256、正式证书均与旧清单相符，并与本次证书匹配。此项支持同签名覆盖升级，不代替每台手机的数据保留验收。
- 包名 `cn.saydian.ring`，版本 `1.0.10`，构建号 `1229`，非 debuggable。生产 Manifest、推送标识、双 ARM ABI 与 `zipalign -c -P 16 4` 均通过。ABI 例外用本次离线 Gradle `releaseRuntimeClasspath` 依赖报告与锁文件核对；未变更依赖或供应商库，不把 APK 对齐等同于所有旧 ARM32 库对所有市场和系统的兼容。
- 初次产物检查误将 `aapt dump xmltree` 文本作为 XML 输入，检查失败；改用 `apkanalyzer manifest print` 后，资源检查又因误用 `aapt` 而失败。按门禁要求使用当前 APK 的 `aapt2 dump resources`，配合真实 XML 重新检查通过。两次失败保留于本机日志，未绕过门禁、修改安装包或重新编译客户端。
- 产物 72,682,993 字节，SHA-256 为 `e69b1d46f6ca3d68302e2861979ad79956357a8e1ced8834338ee2dbfdfbf878`。私有交付副本与构建文件的摘要一致。
- 相同运行时代码的完整回归与云端五项成功记录见 [相机/同步复查](SAY-RING-READ-BUSY-SYNC-20261103.md) 和 [GitHub 检查](https://github.com/tangwu88/SayRing/actions/runs/41485601557)。本轮只构建发布，不重复执行无源码变化的全量测试，也不把此前待完成的 R7 Ultra 活动/睡眠实物验收改成通过。

## 下载发布

- 发布前公开 Android 为 1.0.8（1202）。后台会话过期，用户在现有管理后台重新登录后继续。
- 编辑明确标为 `say_ring_app_update` 的记录，上传本次正式 APK，填写 Android 1.0.10（1229）和当前发布时间。上传完成后核对服务端返回的字节数、摘要与正式包一致，再保存。
- 以打开编辑器时的最新公开清单为基线保留其他平台，避免覆盖用户刚更新的 iPhone App Store 配置；另保存其他两个产品的公开清单用于发布后对照。
- 分片上传完成后，后台返回文件 `say-ring-android-1793678767780-9044560e.apk`，字节数和 SHA-256 均与正式包一致。公开配置保存时间为北京时间 12:14，页面随后实际显示 1.0.10（1229）、72.7 MB、可下载及对应摘要。
- 保存前再次对照公开清单，确认上传期间没有其他下载配置改动；保存后公开 API 回读中的 iPhone、HarmonyOS 与基线逐字段一致，其他两个产品清单也完全一致。公开页面截图保存在本机证据目录。
- 从公开地址完整回下载 72,682,993 字节，SHA-256 与本地正式产物完全一致。再次执行 `apksigner verify --print-certs` 和 `aapt dump badging`，确认原发行证书、`cn.saydian.ring`、1.0.10（1229）、非 debuggable。公开链接为 `https://app.saydian.cn/global/api/saydian-app/v2/support/app-package/say-ring-android-1793678767780-9044560e.apk`。此时才判定下载更新完成。
- 回下载地址不支持 Range 请求，验证流程按 HTTP 200 正常回退为单一完整下载。初期传输较慢时短暂对照另一下载客户端，随后停止重复传输；原完整下载最终成功。没有改服务端、重传安装包或用响应头代替完整文件核验。

证据与安装包保存在本机忽略目录 `build/android-download-1229-20261103/`，正式副本保存在用户私有的 SayRing `release-artifacts/android-1229-20261103/`。不提交安装包、管理员会话、生产密钥或手机数据。
