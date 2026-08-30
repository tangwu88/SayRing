# 2026-08-30 iOS 心电手动测量崩溃修复与真机回归

## 结论

“点击心电手动测量后设备马上断连”的实际原因是 iOS App 崩溃，不是手表或 BLE 主动断开。

Veepoo SDK 在首个 `Testing` 回调中已返回 `VPECGTestDataModel`，但 `filterSignals` 和 `originalSignals` 均可为 `nil`。原代码强制遍历 `filterSignals`，触发 Swift runtime trap。

## 修复范围

- 心电波形转换接受缺失、空、单点、全零和非有限数据，无法解释时返回空波形。
- `Start` / `Testing` / `NotLead` 仅发送进度、佩戴状态和新增波形，不提前保存健康记录。
- `Complete` / `Over` 只在主指标与波形都完整时保存；忙、失败、不支持和未知状态显示真实错误。
- 新增测量代次。停止、断连、换表后的旧回调无法覆盖当前会话。
- 发起测量前校验会话就绪、历史同步、表盘传输和电量命令状态，避免抢占厂商单命令通道。
- Flutter 收到终态测量错误时同时清理测量代次、进度和临时波形，确保可立即重试。
- SDK 冷启动自动重连验证成功后完成回调和操作门犹初始化，避免表面已连接但手动测量仍处于未就绪状态。

## 验证证据

- LLDB 崩溃现场：`convertedEcgWaveform` 访问空的 `filterSignals`，触发“Unexpectedly found nil while implicitly unwrapping an Optional value”。
- iPhone 15 Pro Max / iOS 26.6 + ET488：Profile 包启动心电后，连续返回 `Testing` 和 `NotLead` 进度超过 60 秒，App 没有退出，BLE 会话保持。
- iPhone Profile RunnerTests：24/24 通过，包含空波形、不完整波形、合法增量、非有限换算和心电状态终态判定。
- 心电与主流程定向 Flutter 测试：81/81 通过。
- `TZ=UTC flutter test --no-pub`：341/341 通过。
- `TZ=Asia/Shanghai flutter test --no-pub`：341/341 通过。
- `flutter analyze --no-pub`：零问题。
- iOS Profile ARM 真机编译：通过。
- 最终普通 App 包 `0.1.19 (23)` 已安装到 iPhone；独立终止并冷启动 3 次均成功，每次等待 8 秒后进程仍存活。
- 三次冷启动后检查 iOS 系统崩溃目录，没有新增 `Runner` 崩溃日志。

## 验收边界

本轮无人持续接触手表心电电极，因此真机只确认“首回调、空波形和未佩戴状态不再崩溃”。

有效实时波形、完整终态保存和手表历史回读仍必须在正确佩戴并持续接触电极的现场下复测，未以模拟数据或旧记录替代。
