# Say Ring Android 1059：后台上传与下载页

## 范围和基线

- 用户要求将最新版 Android 安装包上传后台，使 https://app.saydian.cn/down2 可下载安装。本轮只更新 Say Ring Android 下载资源，不改 iPhone / HarmonyOS 配置、Health、旧赛电 App 或 App Store 审核。
- 客户端基线 85cb8afc8834f8d7166eca4e050c2e0ad85514f5；fetch / ff-only pull 确认已最新，工作树干净。运行时代码为 4fd0568 的 1059 修复，不重新改写或编造新版本。
- 服务端 content-locale checkout 只读核对，main / origin/main 均 a9a884a6b74eaf5a3a60d82f4214ef7452f60f92；未修改服务端源码、部署、供应商、凭据或数据结构。
- 公开页面实际标记“内部测试下载 / 内部测试版”。沿用现有 QA Release 包和签名，仅作为该内部测试入口，不冒称 Google Play、应用市场正式包或生产发行签名。未发现本机正式 Android 签名配置，未创建或更换密钥、关闭发布门禁。

## 安装包验证

- 原文件只读核对并保留；1059 构建日志确认 assembleRelease 563.5 秒成功。独立只读副本 `.build/SayRing-1.0.0-1059-internal-test.apk`，69,521,379 字节。
- SHA-256：905d031936df7c5448bb3b9a234799ef35eb1dac1879e9bc64076f7e2a22c408。
- aapt2 确认 cn.saydian.ring / Say Ring / 1.0.0 (1059)，Android 最低 API 26、target 36，两个 ARM ABI；Manifest 没有 application-debuggable 项。apksigner verify 通过，签名为现有 Android Debug 证书；不能据此称为生产签名。
- `zipalign -c -P 16 4` 退出 0。ABI 门禁最初因缺少 Gradle dependency report 拒绝；保留失败日志，Java 17 运行 releaseRuntimeClasspath dependencies（8 秒成功）后重查通过。受控 libjutils.so arm64-only 例外核对 JPush 6.2.0 / JCore 5.5.2 / jpush_flutter 3.5.1；不跳过 ABI 校验。
- Python 发布门禁 33 项通过，7.572 秒。上一轮同源码的双时区各 1196 Flutter 测试、原生与构建详见 [1059 重连记录](SAY-RING-IOS-RECONNECT-1059-20261005.md)。本轮只上传既有包和改下载元数据，不重复改源码、不将旧实物结果扩展为全部型号已通过。

## 后台上传与公开校验

- 使用已登录后台“客服与更新 → Say Ring App 更新”的 APK 上传器；保持其他产品设置不变。上传完成后自动回填文件名、URL、大小和哈希，未在上传中提前保存可用配置。
- 服务器文件：say-ring-android-1791166049047-1c6f5986.apk。
- URL：/global/api/saydian-app/v2/support/app-package/say-ring-android-1791166049047-1c6f5986.apk。
- 上传返回大小和哈希与本机一致。AX stepper 的整数 Value 有浮点舍入，实际 input.value / Details 为 69521379；读取真实输入值确认，没有将错误舍入值发布。
- 公网全文件请求 HTTP 200，Content-Type 为 application/vnd.android.package-archive，Content-Length=69521379，ETag 为原 SHA-256，attachment 文件名正确；完整下载 69,521,379 字节，SHA-256 与原包一致，下载副本 apksigner verify 退出 0。不是仅 HEAD 或首段字节检查。
- 修改前已保存三个产品的公开清单快照；保存后须按 data 对比，避免请求 ID / 包装时间造成误判。
- 10:10:00（CST）后台保存完成，只有 Say Ring App 更新行的更新时间改变。公开清单回读 Android cn.saydian.ring / 1.0.0 / 1059 / available / direct / 大小、哈希和精确 URL 均一致。
- 验证脚本最初误用旧发行清单的 latest_version 等字段，失败；按真实 DownloadManifest 的 versionName、buildNumber 和 destination 元数据修正后通过，不改服务端数据掩盖脚本错误。Health / 原 App 完整 data、Say Ring iOS / HarmonyOS release 均与发布前快照一致。
- 公开页面重新加载已显示“Android 版 → 可下载 → 1.0.0（1059）→ 69.5 MB → 下载 Android 版”，实际 href 指向上述已全文件验证的 URL。保留内部测试版、安装指导与健康用途说明；截图 `.build/1059-down2-android-proof.png`。
- 本轮仅通过既有后台上传/保存，未进行服务端代码部署，因此不声称新的 CI 或生产 revision 已发布。客户端记录提交到当前分支；最终提交与远端同步结果由 Git 回执核对。

## 边界

- APK、上传/下载日志、公开清单快照和截图保留在忽略目录，不进入 Git。不上传账号凭据、照片或健康记录。
- 本轮未安装手机、解绑、清库或操作真实戒指；下载可用不等于新一轮安装/功能真机验收。
- 旧占位配置有备份，不删除任何旧包；iPhone 的现有版本与 TestFlight 链接保持原值，不顺带修正其他平台资料。
