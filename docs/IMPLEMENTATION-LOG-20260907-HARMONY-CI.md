# 鸿蒙主机侧回归接入 CI（2026-09-07）

## 范围与结论

在现有 Flutter、Android、iOS 检查之外，新增独立 `harmony-contracts` 任务。
它运行鸿蒙纯模型、契约和带平台替身的生产服务方法回归，不等同于 ArkTS/HAP 编译、签名验证或真机验收。

本机 UTC、Asia/Shanghai 各 380 项通过；远端运行尚受账单门禁阻断，不能标记为 CI green。

## 修改前保护

- 本批开始于 `32948ae`，修改前成功执行远端 `fetch --prune`。
- 保留主线程和其他协作者已有改动；只新增 CI 任务与本说明，不修改业务源码、签名或商店配置。
- 主线程可继续提交其他已验收改动，本批不单独提交或推送。

## 新增门禁

位置：`.github/workflows/ci.yml` 的 `harmony-contracts`。

- Node 主版本固定为 24；测试实际使用 `node:module` 的 `registerHooks` 与 `stripTypeScriptTypes`。
- 时区矩阵为 `UTC`、`Asia/Shanghai`，一组失败不会提前取消另一组。
- 在仓库根目录执行 `node --test harmony-native/tests/*.test.mjs`，每组超时 10 分钟。
- 任务仅有 `contents: read` 权限；检出不保留凭据；不启用依赖缓存。
- 不引用签名、推送、支付或商店 secrets；不依赖移动端构建任务，便于独立发现契约回归。
- 原有 Flutter、Android、iOS 任务未更改。

`actions/setup-node` 使用固定提交 `249970729cb0ef3589644e2896645e5dc5ba9c38`（v6.5.0）。
本轮通过官方仓库 API 核实 v6 标签指向该提交、提交签名验证通过，且该提交的 `action.yml` 使用 `node24` 并支持关闭 `package-manager-cache`。
核查来源：[官方固定提交](https://github.com/actions/setup-node/commit/249970729cb0ef3589644e2896645e5dc5ba9c38)。

## 本机验证

| 检查 | 结果 | 本机证据 |
| --- | --- | --- |
| Node 版本 | v24.18.0 | 本轮终端读取 |
| UTC 全量主机侧测试 | 380/380；失败、跳过均为 0 | `/tmp/saydian-harmony-ci-utc.log` |
| Asia/Shanghai 全量主机侧测试 | 380/380；失败、跳过均为 0 | `/tmp/saydian-harmony-ci-shanghai.log` |
| actionlint 1.7.12 | 通过 | 检查 `.github/workflows/ci.yml` |
| ShellCheck 0.11.0 | 通过 | 从新增任务提取实际 `run` 内容，按 Bash 检查 |
| `git diff --check` | 通过 | 本批最终差异检查 |

上述日志位于临时目录，仅作本机核验索引；不随源码发布，也不替代 GitHub Actions 执行记录。
本批未运行 Flutter、手机构建、HAP 构建或真机操作。

## 远端真实状态与后续门禁

核查运行：[34052917528](https://github.com/saydian88-cmyk/saydianapp/actions/runs/34052917528)。
该运行对应 `32948aed63a0b14436090adc50b0a3b48c863f47`，创建于 `2026-09-06T18:49:03Z`，整体结论为 failure。

- `quality` 没有启动任何步骤；检查注释明确指出账户支付失败或消费限额需提高。
- `android`、`ios` 被跳过；这不是编译或测试执行后的失败。
- 该运行发生在新增鸿蒙任务之前，不能作为鸿蒙任务已在云端执行的证据。

账单问题解决且本批合入后，需要在包含新任务的提交上重新运行，确认两个鸿蒙时区任务及其他必需任务全部通过。
只有本机通过或仅新增了工作流，都不能写为 CI 已绿、HAP 已验证或正式发行通过。
