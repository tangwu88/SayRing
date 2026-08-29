# Android/iOS Release 发布门禁实施记录

## 结构

- 基线：`637358514247`
- 范围：Android Gradle Release 门禁、iOS Xcode Release 校验阶段、GitHub Actions、发布脚本、发布配置模板和说明文档
- 非范围：Dart、iOS、Android 业务功能；本轮未提交、未推送

## 已实现

- Android 与 iOS 的普通 Release 默认失败，禁止无意中生成配置不完整的发布包。
- Android Gradle Wrapper 脚本与 JAR 纳入版本库，并使用官方 SHA-256 锁定 Gradle 9.1.0 分发包，确保干净 CI 可直接执行 `./gradlew`。
- 本地或 CI 无签名编译验证只能显式设置 `SAIDIAN_ALLOW_QA_RELEASE=true`；QA 模式不具备生产发布资格。
- 正式发布必须显式设置 `SAIDIAN_PRODUCTION_RELEASE=true` 且 `SAIDIAN_ALLOW_QA_RELEASE=false`，两个模式同时开启或同时关闭都会失败。
- Android 门禁挂接到所有 `pre*ReleaseBuild` 任务；iOS 门禁由 Xcode 的 `Validate Release Configuration` 构建阶段执行。
- 正式签名证书、APK 签名指纹和 APK v2 签名三重校验。
- JPush AppKey、正式 channel 和明确启用的厂商凭据一次性注入。
- annotated tag、versionName、versionCode、历史标签和最低支持 build 门禁。
- 公网清单地址、APK 地址、允许主机及 APK SHA-256 校验。
- 先发布不可变 APK，再公网回读校验，最后在远端锁和旧清单 SHA-256 比对通过后原子替换更新清单。
- 清单公网校验失败时恢复上一份清单，并从公网再次核对恢复结果。
- 拒绝低于线上清单的 Android versionName 或 versionCode，避免标签缺失时发生回滚。
- GitHub Actions 使用固定 commit SHA；签名、厂商配置和 SSH 私钥均在外部 Action 执行前清理。
- 私有 GitHub Release 仅在公网发布成功后作为内部归档创建。

## 本地验证

```text
python3 -m unittest discover -s scripts/release -p 'test_*.py' -v
Ran 14 tests - OK

actionlint .github/workflows/*.yml
shellcheck scripts/release/*.sh
python3 -m py_compile scripts/release/*.py
bash -n scripts/release/*.sh
cd android && ./gradlew --version
git diff --check -- <本轮文件>
均通过
```

本地 QA Release 验证命令：

```bash
SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release
SAIDIAN_ALLOW_QA_RELEASE=true flutter build ios --release --no-codesign
```

不设置模式变量的普通 Release 会按设计失败。正式发布只允许由已配置生产变量、凭据和签名的工作流执行。

测试覆盖 Release 默认拒绝、QA 显式放行、完整生产模式放行、模式冲突和非法布尔值拒绝，以及版本双递增、线上清单防回滚、iOS 条目保留、App Store 产品页约束、APK 版本和 JPush 元数据、Huawei 包名、不可变 APK、同字节重试、远端清单 CAS 及失败回滚后公网复核。

## 未执行

未执行真实正式签名构建和公网发布，生产推送 10 秒到达目标及线上更新链路也无法在缺少外部资源时验收。

截至 2026-08-29 的 GitHub CLI 只读审计：仓库为私有仓库，当前为 `0 Environments / 0 Variables / 0 Secrets`。既没有受保护的 `production`、`ios-adhoc` Environment，也没有已确认的公网 APK/清单服务器。具体解除条件见 `PRODUCTION-RELEASE-BLOCKERS.md`。
