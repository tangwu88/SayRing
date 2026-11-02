# 首次绑定未决状态的恢复保护

2026-11-02，基线 `b3d678b`。本记录对应连接审查中的第二项：首次绑定决策响应丢失后，断连会清掉内存等待标记，而已保存的戒指会让下一次连接跳过首次决策，旧历史因此可能越过初始化保护。此前通过的是正常响应路径，不代表这一异常分支已经通过。

本次在客户端安全存储增加按环境、稳定账号和精确戒指标识隔离的阶段记录：尚未请求、请求结果未知、清理已尝试、仅清历史已获确认。密钥使用摘要，不将设备或账号明文写入键名。先持久化，再调用一次服务端或一次清理；显式连接、普通重连、自动恢复和新控制器启动均先读取记录。注销与连接终止只清除当前内存，不删除其他账号/戒指的未决记录；迟到回包和退役会话事件不能放行新连接。

安全解除条件保持区分：首次请求明确返回不清理，才可移除该决策记录；QRing 恢复出厂已尝试的记录只由同账号、同目标的原生完成回执解除；iOS CoolWear 仅清历史返回真正 ACK 后，仍等待下一次新的成功握手才允许同步。ACK 不会在当前初始化连接直接导入旧缓冲。已有绑定且没有未决记录的会员不新增清理、不改变原有正常同步。

服务端现有契约是一次性授权：首次事务才返回 `shouldClear=true`，响应丢失后的重复请求返回 `false`，没有可重放的决策凭据。因此客户端不能用重复返回的 `false` 推断原清理已完成，也不能再发恢复出厂。本修复保留未知状态，不部署或改动服务端协议。恢复这一罕见丢响应状态仍需要另行提供经过验证的服务端幂等凭据/核对流程。旧版本在升级前已经遗失且从未持久化的未决状态无法由本补丁凭空重建。Android CoolWear SDK 的仅发送清理请求没有 ACK，其结果仍为未确认，不把重连当作清理成功。

验证命令：

```text
flutter test --no-pub --reporter expanded test/first_ring_initialization_regression_test.dart test/device_connection_reporting_test.dart test/ring_initialization_vault_test.dart test/app_controller_exact_recovery_test.dart test/device_history_sync_test.dart
flutter analyze --no-pub lib/services/app_controller.dart lib/services/secure_vault.dart test/first_ring_initialization_regression_test.dart test/device_connection_reporting_test.dart test/ring_initialization_vault_test.dart
```

最终 72/72 通过，定向静态检查零问题。新增 11 个控制器边界用例及 2 个安全存储用例，覆盖响应丢失后重连/新控制器、自动恢复、未知决策与原生完成并发、账号/目标隔离、重复清理抑制、原生确认解锁、iOS 仅清历史 ACK、无 ACK 保持未知、存储不可读，以及断开后的迟到服务端授权。原有 1224 初始化回执保护和其他连接/历史用例一并通过。此处是宿主回归；完整回归、原生构建和实物结果由本轮主发布记录补充。

中间失败均保留在本地构建记录：首轮存在 Dart 接口交叉类型转换遗漏，修正后编译通过；既有恢复夹具只在 connect 早期发完成事件、没有模拟生产 getCapabilities 的持久回执重播，补齐重播后原断言通过；新用例初次误用未摘要账号键和非 SHA-256 环境命名，修正夹具后通过；两处单行 if 的格式提示已修正。没有降低测试断言、模拟真实射频结果、清除会员健康记录或在真戒指上执行恢复出厂。
