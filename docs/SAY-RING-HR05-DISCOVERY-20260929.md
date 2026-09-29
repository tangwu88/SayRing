# 2026-09-29 HR05 戒指搜索与连接修复

## 原因、基线与范围

- 用户报告 LuckRing 可搜索并连接 HR05，但 Say Ring 添加设备页一直找不到。华为手机 LuckRing 页面显示“我的设备 (HR05) / 已连接”，系统蓝牙扫描记录中的目标名称为 `HR05`；不记录设备地址或健康数值。
- 修改前分支 `codex/home-health-device-update-download`，工作树干净，HEAD `2d5b42d393645967235cc92cf4e75b9b4decfd3e`；本地缓存的 `origin/main` 和同名分支均为该 SHA。首次 `git fetch origin --prune` 因 GitHub 连接重置失败，不能据此声称已取得最新远端；提交前需重试。
- Say Ring 的 Android CoolWear 桥只接受 `HR01`/`HR01-`，Flutter 路由同样不识别 `HR05`，所以即使 SDK 扫到广播也会被丢弃。原生桥的扫描和连接详情还把型号固定写为 `HR01`，会导致 HR05 被误标。
- 预期只增加已由同机参考 App 和系统扫描记录确认的精确 `HR05` 名称，继续拒绝其他未知型号；连接仍须真实 CoolWear SDK 设备信息握手，功能仍依赖设备回报与既有门禁，不根据名字伪造数值。
- 计划涉及 Android CoolWear 桥、Flutter 路由、名称测试、交接/路由约定和本记录；不改服务端 API、数据库、既有健康算法或其他厂商扫描规则。

## 修改与测试记录

- Android 桥只接受 `HR01`、原有 `HR01-` 和精确 `HR05`，扫描与连接详情按实际型号返回；历史与实时健康记录在桥接输出时保留实际来源型号，避免 HR05 记录被标为 HR01。Flutter 路由只把该名称交给 CoolWear；错误后缀和其他未知设备继续拒绝。没有扩大 QRing 或 Veepoo 的名称范围。
- `dart format` 处理两个 Dart 源码和路由测试。`flutter test --no-pub test/wearable_routing_test.dart`：19/19 通过，含 HR05 正确路由和错误 SDK 拒绝。`flutter analyze --no-pub`：0 issue。
- `android/gradlew.bat :app:testDebugUnitTest --offline --quiet` 首次因未设置项目已缓存的 `GRADLE_USER_HOME` 而缺 Flutter Android Debug 依赖，属于本机构建配置失败，不是断言失败；设置 `GRADLE_USER_HOME=E:/saydian/.toolchains/gradle-home` 和 `ANDROID_HOME=E:/saydian/.toolchains/android-sdk` 后原生测试 31/31 通过、0 失败、0 跳过。
- `TZ=Asia/Shanghai flutter test --no-pub -r compact` 与 `TZ=UTC flutter test --no-pub -r expanded`：各 892/892 通过。完整测试输出含 mock 网络日志，不代表真实后台接口验收。
- QA Release：`SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --target-platform=android-arm,android-arm64 --no-pub` 成功。APK 为 `cn.saydian.ring`、`0.1.21 (1004)`、69,964,398 字节，SHA-256 `507FC06D790799DC3A28EFBFD661AEE5D93E3864197FFB8994395373D7CC7421`；签名仍为 QA Debug 证书 SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，不是正式市场包。
- Android Debug：`flutter build apk --debug --target-platform=android-arm,android-arm64 --no-pub` 成功；APK 186,163,830 字节，SHA-256 `A2514DE061E2DDBFADD059E011960E491066E7A0959606D87F12227CD62E95EF`，包名/版本/双 ARM 架构及 QA Debug 证书核对通过。`node tool/qa_ios_frameworks.mjs` 通过；Windows 无法执行 Xcode/iPhone 编译与真机扫描。`git diff --check` 通过，仅有 Windows 自动行尾转换提示。

## 真机验收与剩余边界

- 华为手机安装 QA Release 使用 `adb install -r` 返回 `Success`；原 `firstInstallTime` 仍为 2026-09-19，说明是覆盖安装，未卸载或清除应用数据。暂时停止 LuckRing 后，Say Ring“添加设备”列表显示 `HR05`，同时 HR01 与 TK65 仍正常列出。
- 点击 HR05 后设备页显示“已连接”、设备实报电量和由功能位开放的健康监测入口；强制结束 Say Ring 再启动后，设备页再次显示 HR05 已连接、可同步，说明本次冷启动恢复通过。未记录 MAC 或个人健康数值。
- 安装后的首次点击测试被手机来电/短信界面打断；待其结束后重新进入 Say Ring 才确认上述连接状态。没有操作通话或短信。
- 本轮只验收 Android 搜索、连接、基础能力和一次冷启动恢复；未执行 HR05 健康历史写入、运动启停、压力/HRV 实测、跨端同步、iOS 编译/真机或正式签名发布。Android CoolWear 接入不能冒充 iOS 已支持。
- GitHub 首次 fetch 因连接重置失败；重试使用 HTTP/1.1 成功后，提交前再次 fetch，确认 `origin/main` 与当前开发分支均仍为修改前 SHA `2d5b42d393645967235cc92cf4e75b9b4decfd3e`，无他人新提交。源码和本记录提交为 `cd45f01`，`git -c http.version=HTTP/1.1 push origin HEAD:refs/heads/codex/home-health-device-update-download HEAD:refs/heads/main` 返回成功，两分支均由旧 SHA 普通快进到该提交。此处仅证明 Git 同步，不等于正式商店包或线上下载页已发布。
