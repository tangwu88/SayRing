# 国际版生产域名直接切换

## 修改前

- 用户要求：国际版 App 直接切换到 `https://app.saydian.cn`，不考虑旧域名过渡。
- 基线：`main` / `c9faadae517ca40bd8c35b2e37de09ce2e54c345`；`git fetch origin --prune` 通过，`HEAD...origin/main` 为 `0 0`，工作树干净。
- 已阅读：`AGENTS.md`、国际版交接、最近真机扫描/注册/实施记录、回归清单和问题复盘。
- 现状：正式 `AppController` 已使用 `GlobalSaydianApiClient` 与新域名，但通用 API/更新默认值、真机契约和在线 QA 脚本仍残留 `app.saidian.cc`；当前 Android 调试会话显式使用本地 `127.0.0.1:8082`。
- P1 风险：遗漏构建参数或直接构造通用客户端时，仍可能请求旧域名；与国际版隔离边界冲突。
- 范围：仅 API/更新服务默认值、真机网络契约、在线 QA 默认目标及对应测试；不改路径、字段、账号隔离、健康算法、设备或支付逻辑。

## 验证记录

- 待执行：格式、静态分析、域名契约定向测试、双时区全量 Flutter 测试、Android Debug/QA Release，以及真机新域名启动。
- iOS/Harmony 真机与签名发布：未执行，不计为通过。
