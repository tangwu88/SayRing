# Android 1.0.2（1101）正式构建准备

**当前状态：1101 双 ARM Debug 编译/身份核验通过；正式签名 APK 和下载页发布尚未完成，等待原正式签名配置的 Mac 可读取路径。不能把当前 Debug 包发布为正式更新。**

## 用户范围与基线

- 用户要求“安卓版也构建更新”，并确认“生成正式 APK，并同步更新 /down2 下载页”。版本与 iOS 对齐为 **1.0.2（1101）**，Android 包名继续 `cn.saydian.ring`。未授权应用市场审核，不启用继承的发布自动化。
- 开工及交付前 fetch / ff-only 均确认干净 main 与 origin/main 为 `7adc5cedaf828234b8e366a6be244fe4b2858512`。阅读 AGENTS、交接、正式 1066 记录、发布/回归约定和最新 1101 交付记录；本轮没有修改产品源码、供应商参数或默认平台版本。
- 同一运行源码的完整回归已在 [QRing 手势记录](SAY-RING-QRING-GESTURE-20261017.md) 中完成：Flutter 双时区各 1259、Android 原生 53 等。此次只构建新的版本参数并验证产物，不重复执行没有源码变化的整套功能测试。

## 编译和正式签名阻断

- 使用本机已安装 Flutter 3.44.9、JDK 17、Android SDK；没有另装工具。先确认没有同仓库构建进程及 Android ADB 真机连接。
- 命令：`flutter build apk --debug --no-pub --target=lib/main.dart --target-platform=android-arm,android-arm64 --build-name=1.0.2 --build-number=1101 --dart-define-from-file=config/dev.json.example`，**43.7 秒 / 退出 0**。
- 独立复制的 Debug APK：158,827,713 字节，SHA-256 `b9d76b4389e29882c688ccf32099f3d55386a97dd734a621efa2db26b5727fee`。aapt 实际回读 `cn.saydian.ring / Say Ring / 1.0.2 / 1101 / minSdk26 / targetSdk36 / armeabi-v7a + arm64-v8a`，Debuggable=true；官方 apksigner 验签通过，但为本机 Debug 证书，不是正式签名。
- `android/key.properties` 不存在，当前环境也没有生产签名密码/别名和 JPush 生产参数。历史原正式材料保存在 Windows `E:\saydian-release-signing`，受保护脚本使用原永久证书。已请求用户提供 Mac 可读取目录或共享路径，且明确不在聊天发送密码。
- 定向文件名查找没有找到 Say Ring 原正式证书；范围过宽的只读卷扫描主动中止，未读取无关个人文件正文。找到的调试证书、OpenHarmony 工具证书和其他产品材料不作为 Say Ring 正式签名使用。没有生成替代身份、绕过生产门禁或将 Debug 包当正式包上传。
- 用户随后要求先安装 iOS，已完成 [1101 真机保数据安装](SAY-RING-IOS-DEVICE-INSTALL-1101-20261017.md)，原 Android 正式发布请求继续保留。

## 下载发布准备

- 公开清单 HTTP 200，保存 Say Ring、Health 和原 App 的更新前快照。当前 Say Ring Android 为 **1.0.0（1016）**；iPhone 为已上架 **1.0.1（1064）**，HarmonyOS 为 coming_soon。只准备更新 Say Ring Android；没有将待审 iOS 1101 写入公开下载页。
- 从现有公开地址完整下载 1016：**69,323,534 字节**，SHA-256 `f67194877b1d3b186f5bdedd9f96a7db4f88f8a46e2d1686c5b8375f43425b2e`，与现有清单完全一致。下载限制同源 HTTPS 重定向，校验完整文件而非仅 HEAD 或首段。
- 官方 apksigner 对现有 1016 验签成功，证书 SHA-256 为 **`81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`**，与历史正式 1066 相同。新正式 APK 必须匹配这一身份，才能保留用户数据覆盖升级。
- 下载后台当前为登录页，未读取或填写密码、未修改后台配置、未上传或发布文件。临时登录标签已关闭；原用户 App Store 标签保留。获得原正式签名目录、生成和验证正式 APK 后，再完成原后台登录与上传/保存，并从公网完整下载核验 SHA、签名及其他平台/产品配置保持原值。
- 私有产物、原安装包、签名回执与公开清单副本在 `build/android-formal-1101-20261017/`，不进入 Git；当前编译通过不代表正式签名、下载页更新、市场审核或 Android 戒指真机验收已经完成。
