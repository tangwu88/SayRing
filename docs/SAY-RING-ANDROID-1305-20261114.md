# 安卓最新代码正式打包 1305

2026-11-14（北京时间）。用户本轮仅要求打包最新版 APK，不安装手机、不修改公开下载配置或服务器。

## 基线与范围

- 独立仓库 `tangwu88/SayRing`，分支 `codex/u19s-android-connect-20261111`。开始时工作区干净，HEAD 为 `1d1a84a73dcc7c6b798b99a5f998a16ad16fed34`；联网 fetch 后快进至 `67b2ac1cad700a49914292ac3e33dd14a0da3931`。
- 远端新增提交仅更新 1304 构建与模拟记录。运行源码仍包含 `ff25f4d` 的安卓上传队列修复与原有 U19 血压补读、连接及首页卡片调整，本轮不修改运行源码。
- 正常入口 `lib/main.dart`，版本 1.0.14（1305），包名 `cn.saydian.ring`；使用本机受保护的原发行签名流程。构建脚本、日志和制品放在 Git 外 `E:\SayRing-android-release-1305-20261114`。

## 验证记录

- `dart format --output=none --set-exit-if-changed lib test`：350 文件，0 改动。
- `flutter analyze --no-pub`：通过。
- UTC `flutter test --no-pub --concurrency=2 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`：2,380 项通过。
- 首轮 Asia/Shanghai 全量运行发生宿主运行时内存映射失败，PowerShell 报 `Releasing the double mapped memory failed`；当时系统可用物理内存约 1 GB、可用虚拟内存约 1.4 GB。该轮未完成，不记为通过，原日志保留为 `shanghai-memory-failure.log`。降低测试并发至 1，并限制构建协调脚本的 .NET 堆后重新执行剩余检查，未修改测试断言或产品代码。
- Asia/Shanghai 重跑 `flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`：2,380 项通过。
- `:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1 --offline -Ptarget-platform=android-arm,android-arm64`：构建成功，25 个原生测试套件、134 项、0 失败。
- `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.14 --build-number=1305`（既有国际环境与商城编译配置）：通过；受保护签名脚本执行对应 Release 构建：通过。
- `apksigner verify --verbose --print-certs`：原发行证书 SHA-256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`；`aapt dump badging` 核对包名、版本号和非 debuggable；`zipalign -c -P 16 4`、生产清单/极光配置门禁、双 ARM ABI 门禁通过。临时 `android/key.properties` 已移除。
- QRing 原厂 AAR 与构建副本校验通过：30 个条目保持一致，仅移除 mapping 输出规则。43 个 ELF 中仍有继承的 2 个 armeabi-v7a 库 `libDspConfig.so`、`libEcgAnaly.so` 低于 16 KB LOAD 对齐；ZIP 对齐通过不能代替所有市场的原生库兼容性审核，本轮不改第三方二进制。
- 交付 `E:\SayRing-android-release-1305-20261114\SayRing-1.0.14-1305-release.apk`，74,454,129 字节，SHA-256 `6ABE72923E0B16C9E6D8300EA17BD5767D0E5084A040826AB97AF79535240AE3`。全部构建和 SDK 校验阶段成功；`git diff --check` 通过。没有安装实体手机、上传商店或修改公开下载页。

## 验收边界

本机为 Windows，不具备 Xcode，iOS Debug/Profile 未执行。本轮不开展实体戒指/手表测试，不改变绑定或健康记录；主机测试与签名验证不代表厂商实物或应用市场审核通过。
