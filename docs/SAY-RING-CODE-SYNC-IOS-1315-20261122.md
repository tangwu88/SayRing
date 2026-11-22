# Say Ring 代码同步与 iOS 1315 内测

## 2026-11-22 源码合并

- 用户要求更新，随后要求完成后构建新的 iOS 版本并提交 TestFlight。当前分支 `codex/say-ring-support-sleep-20261114`，合并前为 `94dc286ec4aca2c87d13a658f7effcd7fa24284b`，工作区干净，fetch 已完成。保留检查点 `codex/before-update-20261122`，合入远端最新 `codex/coolwear-deferred-clock-1314-20261119` 的 21 个独立提交，保留双方历史。
- 纳入邮箱验证码登录与注册恢复、Android QRing 1.0.0.86 和 CoolWear 1.4.1、连接级延后校时及首次连接摘要。保留本分支在线客服、FAQ、睡眠报告、诊断手机信息和已隐藏的消费者诊断入口。
- 两条分支在日志索引、诊断 API、控制器、诊断服务及测试、页面导入共 7 处发生冲突。逐项处理，会员使用服务端一次性首次资格，按原摘要补传；保留 V1/V2 能力协商和有界手机信息，较旧接口只发送 V1。游客摘要仅在其客服会话明确请求时生成，切换账号后拒绝返回旧摘要。手机自定义名称等额外字段过滤掉，不在连接握手中等待网络。

## 自动验证

- 格式检查 368 个 Dart 文件通过，静态分析无问题。首次定向命令误含不存在的测试文件，改为现有 `online_support_page_test.dart` 后，认证、诊断 API/服务、首次控制器、设备页和客服共 105 项通过。
- 合并回归增加针对 V1/V2 首次摘要、后续连接不重复采集、游客上下文按需提供及账号切换拒绝旧摘要的检查。`TZ=UTC` 和 `TZ=Asia/Shanghai flutter test --no-pub --reporter expanded --concurrency=3` 各 2,464 项通过。
- 原生及协议 Node 检查首次 256 通过、1 失败、1 跳过，失败为扫描测试仍匹配旧版手势配对的一行写法。与已有配对回归核对后，更新为当前带异常处理的调用结构。完整重跑 257 通过、0 失败、1 跳过。发布门禁 Python 测试 35 项通过，QRing SDK 30 个原始条目校验通过。
- Android Debug/Release 本机 QA 构建 1.0.15（1315）均通过并验签、核对 ZIP 对齐，Gradle 原生单测成功。首次额外校验误要求 Debug 包包含 Release 的 `libapp.so`，按实际运行方式分别核对 Debug 的 kernel、Release 的 AOT 和双方的双 ARM 引擎后通过。Android 制品仅供本机回归，Release 使用 QA 签名。
- 同一工作区串行完成 iOS Debug 和 Profile 1.0.15（1315），严格验签通过。后续发行归档使用正常 `lib/main.dart` 和既有第一方生产配置，独立记录苹果接收与分组结果。

## XR 界面检查

- XR 测试前私下备份原应用数据容器。使用 `tool/drive_ios_preserving_data.mjs`、明确验签的 Profile 包和保留应用参数执行，结束后原位恢复普通 1315 并成功启动。
- 使用隔离内存模拟已连接和未连接，检查中文/英文、正常/两倍字号，8 种组合均可打开和退出「连接说明」，消费者诊断入口缺席且没有界面异常。本轮为真机界面验收，不包含新的实体戒指测量或同步验收。
- 自动检查、原生构建和真机原始证据保存在 Git 外 `/private/tmp/sayring-code-update-20261122.SupxrewA`。
