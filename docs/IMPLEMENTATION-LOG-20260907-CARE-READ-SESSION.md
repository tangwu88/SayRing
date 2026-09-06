# 关爱组合读取的账号归属保护（Flutter r5）

## 范围与证据

- 修改前已核对 Git 状态、远端并安全 fetch/prune；基线 `3d330b193ee2929159f60ae4889eb2a1ae87adbb`，保留并行改动。阅读实施索引、最新实施记录、复盘与回归清单；原始素材只读。
- 只读审查用生产 `SaydianApiClient` 配合本地合成响应证明：账号 A 读取成员概况及心率时切到 B，旧心率结果可能保留，后续指标又携带 B 的登录态。原反例日志 `/tmp/saydian-care-readonly-audit.SsMCBW/api-late-response.log`。
- 这是可执行的 API 组合请求归属缺陷，不是现网抓包，也没有证实正常操作路径下已经发生跨账号泄露。正常个人资料退出会返回首路由，关爱成员页面销毁后有 mounted 保护；仍需 API 与 Controller 防御迟到结果。
- 本批只改 `lib/services/api_client.dart` 的关爱读取路径、`lib/services/app_controller.dart` 的成员预览入口、新增 `test/care_read_session_test.dart` 与本记录，不改 Harmony、其他页面、全局重试器或服务端。

## 修改

- 组合入口捕获稳定账号标识；每次实际发出关爱请求、返回或失败时复核，账号变化/退出后抛出内部状态 `STALE_CARE_SESSION`，不继续后续指标。
- 旧账号迟到 401 在共享重试器刷新旧凭证前即被拒绝；同一账号正常 token 刷新仍可继续，不用 token 字符串变化误判换号。
- Controller 捕获已有登录代次。旧请求成功、网络错误或归属错误都不能更新新账号的结果、错误提示或监听通知；退出转换期间不发起新成员预览。
- 保留 r4 单项权威语义：不恢复无 type 总表、不合并未经授权确认的健康摘要，不把空结果推断为未授权。
- 清理检查没有新增无用导入、失效辅助方法或重复旧回退逻辑；本次辅助函数只服务关爱请求，未扩大全局改动范围。

## 可执行回归

- 新测试先于修复运行：14 项中 13 项明确失败，仅同账号正常 token 刷新正例通过。日志 `/tmp/saydian-care-session-before.log`。
- 首轮实现后 87/87 定向、UTC 完整 477/477 与静态分析通过；这是中间版本，不能替代最终结果。
- 最后补充 3 项迟到 401 反例，分别覆盖概况、首项、末项，发现旧请求仍会尝试刷新凭证；修前 3/3 失败，日志 `/tmp/saydian-care-session-401-before.log`，随后在关爱局部请求闭包补回调后归属检查。
- 最终新增 17 项：概况/首项/末项的迟到成功、500、离线、401 共 12 项；退出后迟到 1 项；同账号刷新正例 1 项；Controller 迟到成功/普通错误/归属错误 3 项。全部为合成账号与响应，不连接真实服务器。
- 最终定向、双时区全量、静态分析与锁源结果在下方追加。

## 必须保留的发布阻断

- 主线程实测：r4 iOS + r11 Harmony 在约 03:31 的 HRV 撤销复验仍失败，重新进入成员后仍显示 1 条记录；原授权随后由主线程恢复。当前没有该次单项请求的原始响应，不能声称服务器确实返回 200/403 或认定具体后台分支。
- r5 修复只保证组合读取不混账号，不修复服务器逐项授权。上述撤销验收仍为 P1 阻断，不因自动化通过而关闭；旧 Yii 后台只读核查受 Mac 锁屏阻断。
- 本子任务没有操作手机、修改共享状态、编译原生包、提交或推送。实际安装及 r5 真机验收由主线程完成；GitHub workflow 授权同样等待正常解锁，未改权限或付费额度。

## 最终锁源结果

- 定向 API/授权 UI/账号代次测试 **90/90** 通过，日志 `/tmp/saydian-care-session-final-targeted.log`。
- UTC 完整 **480/480**、Asia/Shanghai 完整 **480/480**，日志 `/tmp/saydian-care-session-final-utc.log`、`/tmp/saydian-care-session-final-shanghai.log`。
- `flutter analyze --no-pub` 零问题；日志 `/tmp/saydian-care-session-final-analyze.log`。本批三个 Dart 文件格式检查零修改、`git diff --check` 通过。
- r5 源码已锁定交主线程重编 iOS/Android。上述是本机自动化结果，不能替代撤销共享的服务端与真机验收；r4/r11 HRV 撤销失败仍保留。
