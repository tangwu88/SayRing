# SD-RING-R7Ultra LuckRing 路由

## 修改原因与边界

- 用户确认蓝牙广播名 `SD-RING-R7Ultra` 属于 LuckRing 系列，需要由现有 CoolWear SDK 通道发现和连接。
- 仅接受去除首尾空格并忽略大小写后的精确名称 `SD-RING-R7ULTRA`；不放开整个 `SD-RING-` 前缀，未知型号继续拒绝。
- 名称只决定尝试哪个 SDK，不代表设备能力。连接成功、设备信息握手和真实功能位返回后，App 才展示相应功能。
- 当前项目提供的 CoolWear SDK 仅接入 Android。本轮不在缺少 SDK 的 iOS、鸿蒙端伪装支持，也不修改服务端、健康算法或接口。

## 修改范围

- Flutter 统一设备分类器新增精确名称路由。
- Android CoolWear 原生扫描过滤新增该名称，设备型号显示为 `R7Ultra`。
- Flutter 与 Android 原生策略测试覆盖大小写、首尾空格、错误后缀及错误 SDK 来源。
- 更新 SDK 使用说明、项目设备路由约定和长期修改记录。

## 验证记录

- 修改前执行 `git status --short --branch`、`git remote -v`、`git fetch --prune origin`，确认 `main`、`origin/main` 均为 `e9393546a2811c3beb979523acfc2e1e5cd4b486`，工作树干净且 ahead/behind 为 `0/0`。
- `dart format` 仅处理本轮 3 个 Dart 文件；`git diff --check` 通过。
- `flutter test --no-pub --reporter expanded test/wearable_routing_test.dart`：26/26 通过。覆盖精确名称、大小写/首尾空格、错误后缀、错误 SDK 扫描结果过滤以及连接后操作锁定到 CoolWear 通道。
- Android 原生名称策略首次执行未进入测试，失败于既有 QRing Gradle immutable workspace 校验。停止本次唯一 Gradle daemon 后，只把报错的精确缓存目录移到仓库忽略的 `build/cache-quarantine/` 可恢复隔离目录；未清理整库、SDK 或其它缓存。按相同命令重跑通过。
- `flutter analyze --no-pub`：零问题。
- `TZ=UTC flutter test --no-pub --reporter compact`：961/961 通过。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter compact`：961/961 通过。
- `android/gradlew.bat :app:testDebugUnitTest`：32/32 通过，无失败、错误或跳过；包含新增 CoolWear 名称策略测试。
- `flutter build apk --debug --target-platform=android-arm,android-arm64`：通过。Debug APK 188,615,299 字节，SHA-256 `ACE4EF8A52877D666DFA8A86F0A52FA426916DD88057FF5284F2E77FEEA5CA31`。
- `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --target-platform=android-arm,android-arm64`：通过。该包是内部 QA Release，不是商店签名验收；APK 69,323,518 字节，SHA-256 `84FB3F5D3CBF5EE9E42027189C705CC7D5ABA6FC9E7C370CDDEB5C9C0E1B464E`。`aapt` 回读包名 `cn.saydian.ring`、版本 `0.1.21 (1006)`、targetSdk 36。
- ADB 仅显示离线模拟器 `emulator-5554`，没有在线 Android 真机或目标戒指；因此本轮没有把 R7Ultra 的扫描、连接、设备信息握手、能力读取、同步、断线重连写成真机通过。
- Windows 无法执行 iOS Debug/Profile；iOS 与原生鸿蒙也没有 CoolWear/LuckRing SDK 接入，本轮未修改或构建这两端。要宣称三端支持，仍需供应商提供并授权对应平台 SDK 后分别实施、构建和实物验收。
