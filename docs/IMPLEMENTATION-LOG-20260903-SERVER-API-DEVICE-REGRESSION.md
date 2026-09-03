# 2026-09-03 服务端接口真机联调记录

## 范围

- Android 真机：华为 JAD-AL00，Android 12。
- 客户端基线：`5d7a86f7416720f774e6489b2cc5c9e3755d45fe`。
- GitHub 当日首次检查曾两次连接 443 端口超时；提交前重试 `git fetch --prune` 成功，确认本地 `HEAD` 与 `origin/main` 均为上述提交，远端没有遗漏的新提交。
- 用户已有未跟踪目录 `docs/legal/` 全程保留，未纳入本次修改。
- 使用授权测试账号和历史测试订单；未确认或完成任何真实付款。

## 客户端修正

### 订单支付契约

当前接口文档与交付小程序源码均使用：

- `POST /api/v1/pay`
- `pay_type=1`：微信
- `pay_type=2`：支付宝
- `trade_type=app`
- `order_group=order`
- `data`：包含字符串形式 `order_id`、`money` 的 JSON 字符串

App 原实现发送 JSON Body，并使用旧兼容值 `100/101`，导致两种支付方式都拿不到可用的 APP 支付参数。本次改为 `multipart/form-data`，使用 `1/2`，并按文档传递订单编号和金额。服务端仍必须使用订单记录校验最终应付金额，不能信任客户端金额。

修改文件：

- `lib/services/api_client.dart`
- `test/api_client_test.dart`

## 真机与接口结果

### 通知

- 已登录打开消息列表：正常显示订单通知。
- 打开通知详情：正常显示，未出现旧路由 404 或页面异常。
- `GET /api/v1/member/notify/statistics`（已登录）：HTTP 200、业务 200，返回 `announce_count`、`remind_count`。
- 未登录访问 `/api/v1/member/notify` 和 `/api/v1/member/notify/{id}`：仍为 HTTP 200、业务 500，且响应含服务端内部诊断路径。
- 未登录访问 `/api/v1/member/notify/statistics`：业务 401，但响应仍含内部诊断信息。

结论：已登录业务可用；未登录鉴权和生产错误屏蔽仍需服务端修复。

### 远程关爱每日明细

- 成员列表正常显示昵称和手机号。
- 成员当日页正常展示活动、血压、血糖、血氧、体温、心电、心率、HRV、身体成分、睡眠、血液成分入口。
- 对有历史数据的 2026-08-26 实测：血压 11 条、血糖 6 条、体温 184 条、心率 191 条、HRV 174 条、血液成分 34 条。
- 血压逐条详情正常；血液成分详情正常显示尿酸、总胆固醇、甘油三酯、高密度脂蛋白、低密度脂蛋白，无乱码。

结论：本轮远程关爱聚合和详情接口通过。

### 推送设备登记与解绑

- `POST /api/v1/member/push-devices`：HTTP 200、业务 200，登记成功。
- `DELETE /api/v1/member/push-devices/{installation_id}`：HTTP 200、业务 404“页面未找到”。

结论：登记可用，解绑路由仍未部署或未匹配，闭环未通过。服务端需清理测试账号下 `codex-contract-` 前缀的不可投递探测记录。

### APP 支付

- 修正前：微信和支付宝均提示后台未返回 APP 支付参数。
- 修正后支付宝：服务端返回签名订单串，真机成功拉起支付宝；已立即返回赛电 App，未登录支付宝、未确认付款。
- 修正后微信：服务端返回的 `config` 仅含 `return_code`、`return_msg`。下游结果为 `FAIL`，明确提示微信请求缺少必填 `appid`，客户端因此正确拦截并显示“后台返回的微信 APP 支付参数不完整”。

结论：支付宝已打通到客户端拉起阶段；微信仍需服务端配置 APP 支付 `appid`，并返回 `appid`、`partnerid/mch_id`、`prepayid`、`noncestr`、`timestamp`、`sign` 等完整字段后再验收。

## 自动化与构建

- `flutter analyze`：通过，`No issues found`。
- 支付契约定向测试：1/1 通过。
- 全量 `flutter test`：372/372 通过。
- 真机 QA 并存包：`E:\saydian\测试包\赛电APP-QA支付接口修正版-v0.1.19-build23-20260903-1023.apk`
  - 包名：`cc.saidian.app.qa`
  - SHA-256：`9AD800DEFA4D84C07CDA2294B3DDE3AC381F27CC0AEC782FA0930182F6F13929`
  - 已覆盖安装并用于本轮真机联调。
- 正式包名测试 APK：`E:\saydian\测试包\赛电APP-接口联调修正版-v0.1.19-build23-20260903-1041.apk`
  - 包名：`cc.saidian.app`
  - SHA-256：`0666D9299EBFA9C2398EAAEB6D2E435D6196AF3D34DA9C1740B661A44E7C6873`
  - ABI：`arm64-v8a`、`armeabi-v7a`
  - minSdk 26，targetSdk 36
  - QA Release 使用测试签名，不是生产发布证书。

## 待服务端处理

1. P1：补齐微信 APP 支付配置，至少先解决缺失 `appid`，并返回微信 Android SDK 所需完整签名字段。
2. P1：无 Token 的消息列表/详情统一返回 401/403，关闭生产调试堆栈和内部路径输出。
3. P2：部署并验证推送解绑路由，保证刚登记的 `installation_id` 可立即解绑。
4. 清理测试账号下 `codex-contract-` 前缀的不可投递推送探测记录。
