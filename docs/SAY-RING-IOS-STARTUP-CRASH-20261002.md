# Say Ring iOS 启动闪退修复（2026-10-02）

## 诊断

- iPhone 15 Pro Max 的设备崩溃报告属于 `cn.saydian.ring / 0.1.21 (1006)`。
- 报告为 `EXC_BAD_ACCESS / SIGSEGV`，地址 `0x0`；崩溃线程在主线程，发生于 Flutter `VSyncClient initWithTaskRunner:callback:` → `FlutterViewController createTouchRateCorrectionVSyncClientIfNeeded` → `viewDidLoad`，Dart `main()` 尚未运行。
- 栈与 Flutter 上游记录的 iOS 26、ProMotion、隐式引擎初始化竞态一致：[Flutter #187565](https://github.com/flutter/flutter/issues/187565)、[Flutter #190030](https://github.com/flutter/flutter/issues/190030)。

## 修复

- `AppDelegate` 在 UIKit 创建场景窗口前显式启动并持有 `FlutterEngine`，随后为该引擎注册生成插件与 Say Ring 原有蓝牙、QRing、支付、StoreKit、认证通道。
- `SceneDelegate` 将 `FlutterViewController` 连接到已启动的引擎；保留原有 URL 与 Universal Link 回调，并继续由 `FlutterSceneDelegate` 转发场景生命周期。
- 未改 Dart 登录、健康数据、设备绑定或服务端配置；未卸载 App、清除容器或重置手机。

## 验证

- `flutter analyze`：通过；登录/注册/认证 API 定向 Widget 测试 48/48 通过。
- iOS Debug 与 Profile 均完成设备目标 Xcode 构建。Profile 包签名有效，Bundle ID `cn.saydian.ring`，版本 `1.0.0 (1023)`，设备族仅 iPhone，开发团队 `W7SXQ4A226`。
- 同 Bundle ID 原位覆盖安装成功；未卸载旧 App。随后不附加调试器冷启动成功，`devicectl` 返回 Launched，进程持续存在；`flutter attach --profile` 获得 VM Service，`getVM` 返回主 isolate `main`。
- 安装后崩溃日志列表没有新增 `Runner` 报告。验证为一次真实设备无调试器启动及一次 VM 附加；仍需在 iPhone 上手动点图标复验和做多次冷启动，不把构建或单次启动夸大为完整验收。
