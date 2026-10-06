# 2026-10-06 QRing 解除绑定与蓝牙断开修复

## 任务与成功标准

- 用户反馈：QRing 系列戒指在 App 中解除绑定后，手机仍未真正断开蓝牙，导致其他手机无法发现该戒指。
- 影响等级：P1。换机、换号或交给其他用户时会阻断重新连接。
- 成功标准：解除绑定必须调用厂商真正的解绑能力；原生确认传输层已断开后，Flutter 才能清除保存的设备；失败或超时不得伪报成功，也不得提前抹掉可重试的绑定状态。
- 产品边界：只修改独立 Say Ring 仓库；未修改 SAYDIAN Health、健康算法、健康值或服务端协议。

## 修改前基线与现场保护

- 仓库：`https://github.com/tangwu88/SayRing.git`，分支 `main`。
- 修改前提交：`ae6e73d2e899f3a78525cfdb75748bf873f95281`。
- 修改前执行 `git status --short --branch`、`git remote -v`、`git fetch --prune origin` 并核对 `HEAD...origin/main` 为 `0 0`；工作树干净。
- 修改前阅读 `AGENTS.md`、`docs/CHANGE-TEST-LOG.md`、`docs/BUG-RETROSPECTIVE-20260829.md` 和 `docs/REGRESSION-CHECKLIST.md`。

## 根因

1. Android QRing 桥接把 App 的“解除绑定”映射为 `BleOperateManager.disconnect()`，并在调用后立即向 Flutter 返回成功。
2. 对已集成的 `qring_sdk_1.0.0.76.aar` 反编译核对确认：
   - `disconnect()` 进入 `disconnectDeviceKeepBond(...)`，明确保留厂商绑定；
   - `unBindDevice()` 才会关闭重连、执行厂商解绑并清除保存的 MAC。
3. iOS QRing 桥接同样调用只保留绑定 UUID 的 `disconnect`；已有 `QCCentralManager.remove` 才会删除保存 UUID 并取消 CoreBluetooth 连接。
4. Flutter 路由和控制器使用 `finally` 清除本地绑定与当前设备。即使原生断开失败，界面也会显示已断开，掩盖真实蓝牙占用。

## 修改内容

### Android

- `QRingBridge` 的 Flutter `disconnect` 命令改走 `manager.unBindDevice()`。
- 连接中解绑会先结束待处理连接结果，再执行解绑，避免 Flutter Future 永久悬挂。
- 已连接设备等待原生断开广播；15 秒超时后再次检查 SDK 连接状态，仍连接则返回可重试错误。
- 只有确认断开后才清除设备详情、能力、电量、测量和运动状态并发送 `disconnected`。
- 重复解绑返回 busy；桥接销毁时结束待处理解绑结果。

### iOS

- Flutter `disconnect` 命令改走 `QCCentralManager.remove`，删除 App 保存 UUID 并取消 CoreBluetooth 连接。
- App 管理连接模式下，根据本地绑定是否仍存在区分 `Disconnected` 与 `Unbind`，不再把成功解绑误标为仍绑定断开。
- 发出 CoreBluetooth 取消请求后保留 peripheral 引用直到真实断开回调，超时重试仍能再次取消同一连接。
- 等待 `QCStateUnbind` 后才返回 Flutter 成功；15 秒仍未进入解绑态则返回可重试错误。
- 断开后同步清理连接 ID、名称、能力、电量、测量与运动状态。

### Flutter

- `RoutedWearableBridge` 仅在原生断开 Future 成功后清除 transport 与保存的绑定；异常时保留当前 owner 和绑定。
- `AppController` 的普通用户解绑失败时保留当前设备和 ready 状态，显示普通用户可理解的重试提示。
- 登录/退出账号切换仍使用强制本地隔离模式：即使原生断开失败，也清除账号页面的本地设备状态，但保留“下次连接前必须再次断开”的保护标记。
- 设备页捕获异步解绑错误，避免产生未处理 Future；错误文案由控制器展示。

## 测试与失败记录

| 项目 | 命令或检查 | 结果 |
| --- | --- | --- |
| SDK 行为核对 | `javap` 检查 `BleOperateManager.disconnect/unBindDevice` | 通过；确认旧调用保留绑定，解绑必须使用 `unBindDevice()` |
| SDK 审计失误 | 首次在仓库根目录执行 `jar xf`，生成未跟踪的 AAR 内容 | 已将精确未跟踪路径移到 `D:\Temp\User\qring-sdk-audit-20261006\repo-root-extract`；随后 `git status` 恢复干净，未删除或覆盖源码；该失败保留供复盘 |
| Dart 格式化 | 仅格式化本轮修改的 Dart 文件 | 通过 |
| 定向 Flutter | `flutter test test/wearable_routing_test.dart test/app_controller_account_wearable_test.dart test/product_identity_test.dart` | 40/40 通过 |
| Android 原生 | `gradlew.bat :app:testDebugUnitTest` | 32/32 通过，0 failure/error/skip；QRing Java 编译通过 |
| 静态检查首轮 | `flutter analyze` | 失败 1 项：诊断测试替身仍覆写旧 `disconnectDevice()` 签名 |
| 静态检查修复 | 同步测试替身的可选参数后再次 `flutter analyze` | 通过，0 问题 |
| 全量 Flutter（Asia/Shanghai） | `flutter test` | 944/944 通过 |
| 全量 Flutter（UTC） | `TZ=UTC flutter test --no-pub` | 944/944 通过 |
| Android Debug | `flutter build apk --debug` | 通过 |
| Android Release 首轮 | 未声明发布模式的 `flutter build apk --release` | 按既有安全门禁失败：必须明确生产或 QA；未放宽门禁 |
| Android QA Release | `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub --target-platform=android-arm,android-arm64` | 通过；该包为 QA Debug 证书，不是商店正式包 |
| ADB 现场 | `adb devices -l` | 仅 `emulator-5554 offline`，没有在线安卓真机；未安装、未执行真实解绑 |
| iOS | Windows 主机 | 只完成源码契约测试；未执行 Xcode 编译、iPhone 或真实 QRing 验收 |

## 本地产物核对

构建产物位于 `build/`，不提交 Git。

| 产物 | 大小 | SHA-256 |
| --- | ---: | --- |
| `app-debug.apk` | 158,790,668 bytes | `5C7C5B5BE975F9B086F15A85C5652EAB28057CF9872B532932811270CD2C07EA` |
| `app-release.apk`（内部 QA） | 69,044,922 bytes | `E799D2DD41F68400B4F7E8A6088581DB3D809F23F635507B42B68A7CE1627092` |

- 两包身份：`cn.saydian.ring`，`0.1.21 (1006)`，`minSdk 26`，`targetSdk 36`。
- QA Release v2 签名证书：Android Debug，SHA-256 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`；不得作为正式商店签名包。

## 待真机验收

以下项目没有硬件证据，不能写为已通过：

1. 安卓连接一枚 QRing，点击解除绑定，确认 App 在原生回调前保持等待状态。
2. 确认原手机系统蓝牙已断开且厂商绑定已移除，App 不会后台自动抢回连接。
3. 使用另一台手机扫描并重新连接同一枚戒指，连续执行至少三轮“连接—解绑—另一机发现”。
4. 超时或蓝牙异常时确认 App 保留当前设备并允许重试，不显示虚假成功。
5. 在 Mac/Xcode 与 iPhone 上重复同样流程，确认保存 UUID 删除及 CoreBluetooth 断开。

## 复盘约束

- “断开连接”和“解除绑定”不是同一 SDK 语义；清除 App 保存绑定的操作必须调用厂商解绑/remove，而不是 keep-bond disconnect。
- 原生耗时操作只能在明确终态后完成 Flutter Future；不能发命令后立即返回成功。
- 本地绑定、当前设备和能力状态只能在原生成功后清除；失败路径必须保留可重试上下文。
- 自动化通过、APK 构建通过均不等于真实戒指已释放蓝牙占用；另一台手机重新发现才是本问题的最终验收证据。
