# 更新最新 Git 并重打正式包（2026-10-06）

## 范围和基线

- 用户要求更新最新代码并重新打正式包。本轮交付 Android APK 与原生 HarmonyOS APP/HAP，不安装手机、不部署后台、不提交应用市场。
- 正式构建工作树 `E:\SayRing-market-release-20261005`，分支 `codex/first-market-release-20261005`；fetch origin 成功，干净工作树从 `ae6e73d` 快进到 `ee8d8e630c8d70bc3b9200527d58a750e7c461c5`，纳入最新 QRing Android/iOS 真实解绑终态及 Flutter 失败保留绑定修复。
- 主目录 `E:\SayRing` 有既有 UI 文档空行删除，已定向 stash/备份后快进到 ee8d8e6，再 apply 原改动；文件 SHA256 与保存前一致，stash 恢复副本保留，不纳入本轮提交。
- 不改业务与协议。Android 使用构建参数 `--build-name=1.0.0 --build-number=1013`，不改 pubspec 中其他平台版本；鸿蒙仅递增 `AppScope/app.json5` 和 `entry/src/main/ets/services/AppUpdateService.ets` 的版本码 1012 → 1013，防止更新检测与包内版本不一致。
- 沿用 Git 外永久 Android P12、鸿蒙 P12/AGC release certificate/app_gallery profile。密码从受保护 DPAPI 读取，不提交密码、私钥、构建产物。

## 本轮检查（持续记录）

- `git status --short --branch`、`git remote -v`、代理 fetch、`git merge --ff-only origin/main`：成功。主目录历史签名记录尚未快进时读取失败，改在已同步构建工作树读取；未修改或删除主目录文件。
- 阅读根 AGENTS、handoff、bug retrospective、regression checklist、最新 QRing 修复及此前正式发行记录。
- `flutter pub get`、`flutter analyze --no-pub`：通过，Analyzer 无问题。
- 发布 Python：`python -m unittest scripts.release.test_release_gate.ReleaseGateTest -v`，19/19 通过；POSIX/Xcode helper 本轮不冒充 Windows 可执行验证。
- 鸿蒙双时区：`TZ=UTC node --test tests/*.test.mjs`、`TZ=Asia/Shanghai ...`，各 501/501 通过。
- 鸿蒙 Release：`hvigorw.bat --mode project -p product=default -p buildMode=release assembleApp --no-daemon`，成功 61.602 秒，35 执行/7 up-to-date。厂商 HAR 废弃 API/资源重复等警告保留，无放宽门禁。
- 独立官方 `hap-sign-tool.jar sign-app -mode localSign -signAlg SHA256withECDSA -compatibleVersion 17 -signCode 1` 正式签名。独立 HAP 与 APP 提取 HAP 都通过 verify-app，包括 codesign、permission-sign、摘要、release profile。
- APP 使用官方 packing 工具关闭 replace-pack-info/deduplicate-so，保留 HAP 签名；内部文件 `entry-default.hap` 与独立签名 HAP SHA256 完全一致。包内身份 cn.saydian.ring.hm / 1.0.0 / 1013 / debug=false。
- `TZ=UTC flutter test --no-pub --reporter expanded`、`TZ=Asia/Shanghai ...`：各 944/944 通过。
- Android Debug 首轮在 mergeDebugAssets 失败：QRing immutable transform `7d449599654a801d656c79251a8c1bc3` 的 workspace 内容与缓存元数据不一致。尝试隔离前检测到 Gradle daemon，先停止本机 Gradle daemon；移动整目录仍因 lock 被占用报错，但 workspace 已移到精确 quarantine 路径，原路径仅余 lock。未删除源码/证书，未修改缓存校验策略；重跑 Debug 成功（99.7 秒），重新生成可重建缓存。失败原文保留于本记录，重试日志覆盖前次构建日志。
- Android 原生：`gradlew.bat :app:testDebugUnitTest --no-daemon` 成功（105 秒）；读取 XML 32 项、0 failure/error/skip。
- Android 正式：本机受保护脚本调用 `flutter build apk --release --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.0 --build-number=1013`，生产模式、永久签名、标准 JPush 通道，313.4 秒成功；临时 key.properties 已清除。
- `apksigner verify --verbose --print-certs`、`aapt dump badging`、`zipalign -c -P 16 4`、`release_gate.py apk-manifest` 通过。APK cn.saydian.ring / Say Ring / 1.0.0(1013)、minSDK 26、targetSDK 36、双 ARM；证书 SHA256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de` 与之前永久正式包一致，不是 Debug 证书。
- `gradlew.bat :app:dependencies --configuration releaseRuntimeClasspath --no-daemon` 成功（38 秒），JPush 6.2.0/JCore strictly 5.5.2；`release_gate.py apk-abis --apk ... --dependency-report ... --pubspec-lock ...` 通过。只有既有锁定组合的 libjutils.so 精确单 ARM64 例外，未放宽对其他原生库的对称门禁。
- `git diff --check` 通过；提交前重新 fetch，origin/main 仍为 ee8d8e6。提交仅包含鸿蒙版本码两文件、本记录和索引，签名材料、日志、产物及用户文档改动不进入 Git。

## Android 交付

- `E:\SayRing-market-artifacts-20261006\SayRing-1.0.0-1013-release.apk`，69,044,934 bytes。
- SHA256：`1DFEA4442455C5D4BCFF2C8FA410F9C8603A70F69C7B9D062406DA1390D2995D`。
- 签名沿用永久证书，没有更改微信开放平台或后台极光配置。标准推送参数来自既有独立产品本机配置，不把后台 Master Secret 编译进包。

## 鸿蒙交付哈希

- `E:\SayRing-market-artifacts-20261006\SayRing-HarmonyOS-1.0.0-1013-release.app`：`FA7CC922A1D9ED6D9F13D354B479D8C443B1BF11DB0E6FBDD16166EFEB1C8020`
- `E:\SayRing-market-artifacts-20261006\SayRing-HarmonyOS-1.0.0-1013-release.hap`：`DE258A9C4368930DE839593C195BF9A333DB392E4021468C949EEECEBDDB0848`

## 未验收边界

- 本轮不安装手机、不操作戒指；QRing 另一手机重新发现仍需要真机验证，不能用单测/签名通过代替。
- Windows 无 Xcode，iOS Debug/Profile/正式包未构建。没有应用市场上传/审核、真实推送、登录与健康数据回归或线上部署。
