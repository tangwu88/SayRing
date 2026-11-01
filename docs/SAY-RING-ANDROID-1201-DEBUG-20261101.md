# Android 1.0.8（1201）真机调试准备

时间：2026-11-01（Asia/Shanghai）。用户要求开启连接的安卓手机真机调试。起点为 `20c98a0117fd24740d8318ab02be9c397faddba2`，`codex/fix-client-audit-20261031` 工作树干净；检查远端后 `git fetch --prune origin`、`git pull --ff-only` 均成功且无更新。已阅读 AGENTS、国际交接和最近变更／测试记录。本轮没有修改 App 运行源码、版本、账号数据或设备数据。

## 设备发现边界

- `adb devices -l` 起初及准备完成后均为空，`adb mdns services` 没有无线调试设备；Mac USB 设备枚举也未发现安卓手机。故本轮**没有安装、启动、Flutter attach、DevTools、戒指连接或页面实测结果**。已向用户请求连接、解锁并允许 USB 调试，等待手机真实上线后继续；此前其他华为手机的安装和卸载授权不作为本台依据。

## 调试包准备与失败记录

1. 使用普通 `lib/main.dart`、本机受保护的 Say Ring 生产 Dart 配置，执行 `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.8 --build-number=1201 --dart-define-from-file=<本机受保护文件>`。首次失败：Gradle 9.1.0 transform 缓存引用的 CoolWear AAR `AndroidManifest.xml` 已不存在，同时 Kotlin 标准库解析大量报错；源 AAR 内的 Manifest 与 classes.jar 实际存在。未改仓库源码或 SDK 文件。执行项目 `./gradlew --stop` 后，原命令重试成功。首次失败日志和重试日志保存在 Git 忽略的 `build/` 下。
2. 将本次 Debug APK 用本机受保护的**原 Say Ring 发行 PKCS12**另存重签，密码仅由权限受限的本机文件传给签名工具，没有放入命令行文字、Git 或日志。官方 `apksigner verify` 的 v2/v3 验证通过，证书 SHA-256 为 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`；包名 `cn.saydian.ring`，1.0.8（1201），arm64-v8a／armeabi-v7a，Manifest `debuggable=true`，16KB ZIP 对齐检查通过。
3. 私有调试候选为 `build/android-device-debug-1201-20261101/say-ring-debug-original-signature.apk`，SHA-256 `2310b0c77b862385f431c88ea75b88a1007b9b3def5ffd3374da1024bccd5b32`。此包只用于同证书保数据真机附加调试，**不得发布到下载页或应用市场**。本轮未执行 `adb install`、卸载、清空数据或签名轮换。

## 手机上线后的门禁

- 先重新识别实际设备型号、Android 版本、用户空间、现有 Say Ring 包名／版本及证书；若签名不一致，停止覆盖，不依据别的手机授权卸载。
- 能保数据覆盖时，先私有备份可导出的本地容器，再用 `adb install --no-incremental -r` 安装并核对安装器终态、手机上实际 APK 签名／版本、原数据保留；随后附加 Flutter/DevTools，检查启动、页面和戒指连接。硬件及同步结果与主机编译分开记录。
