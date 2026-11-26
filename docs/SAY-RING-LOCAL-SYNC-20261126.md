# 2026-11-26 本地代码同步

## 范围与基线

- 用户仅要求同步本地，本轮不打包、不安装、不推送远端，不改变服务器、客户数据和设备设置。侧聊不接管主聊的安装、测试或发布任务。
- 工作区E:/SayRing-market-release-20261005，当前分支codex/android-1320-install-20261124；同步前HEAD及同名远端均为b2c307275b9f25ea742061bba012fbfbeb694628，工作区干净。
- 执行git status --short --branch、git remote -v、git worktree list、git fetch origin --prune，阅读AGENTS、交接、最近记录、回归清单及问题复盘。远端功能分支codex/say-ring-connected-experience-20261123为f9c0604f036c84b88737996403f0005c8238f891，双方分别9/25个独有提交，不能快进覆盖本地修复。
- 先创建本地恢复分支codex/checkpoint/android-1322-before-sync-20261126，再执行git merge --no-ff --no-commit origin/codex/say-ring-connected-experience-20261123，保留双方完整提交历史。

## 合并与边界

- 唯一文本冲突是docs/CHANGE-TEST-LOG.md，两边新增索引全部保留。app_controller.dart和global_api_client.dart自动合并，未以整文件选择任一侧覆盖。
- 导入健康首页、心血管趋势、分享与关爱、通知跳转、英文文案、U19读取恢复及固件范围调整和对应测试/记录。远端iOS送审记录只作为其历史凭据，不能代表当前本地安卓已经打包或安装。
- 比较b2c3072，sync_diagnostics_service.dart、first_connection_diagnostic_outcome_test.dart和sync_diagnostics_service_test.dart无变化；控制器仍有本次连接异常独立判断和账号/会话/目标隔离的首次初始化续接参数。
- 首次报告仅限合资格新账号一次，不补采旧账号、不改写原报告；不改变初始化授权、清理次数或健康记录。未修改pubspec版本号，也未沿用iOS1332构建号伪称安卓版本已更新。

## 验证记录

- git diff --check与git diff --cached --check通过，冲突标记和未合并文件清单为空。
- 使用现有工具链串行执行flutter analyze --no-pub及UTC、Asia/Shanghai的flutter test --no-pub --concurrency=1 --reporter=expanded；沿用原first-party API测试定义。静态分析无问题（84.4秒）；UTC全量2539项通过（5分11秒）、Asia/Shanghai全量2539项通过（5分03秒）。新增首连结果测试、原首次摘要规则及远端功能回归均在全量范围内。日志保存在Git外E:/SayRing-local-sync-20261126，stage.txt=complete，无failed.txt。
- 本轮没有测试失败；唯一合并冲突及保留双方索引的处理已如上记录。完成后重新fetch核对当前分支及源分支未变，显式加入合并结果、索引与本记录，创建本地合并提交。远端同名分支和main保持不动。
- 本轮按用户范围不执行Android/iOS构建、手机安装、戒指实测、云端CI或部署，不把远端已执行的检查算作当前合并后的验证。Windows不能执行iOS构建，原生设备稳定性仍需后续实机验收。
