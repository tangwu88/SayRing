# Say Ring 1326 分享与亲友互动入口

2026-11-25。App 从 `b583bdf` 接续，iOS 和 Android 内测构建为 1.0.15（1326）。

## 排查和修改

- 1325 的分享、邀请和问候入口依赖第一方能力接口。当时现网 `/global/health/ready` 显示后台版本 `62bf80e`。`/global/api/saydian-app/v2/ring/capabilities`、分享 H5 与邀请 H5 均返回 404。现网部署缺少后端候选 `4b85774`。
- Android 普通模式误受 iOS 健康发行条件限制。`lib/services/app_controller.dart`、`lib/services/app_controller_ring_experience.dart` 改为按 iOS／Android 手机平台与实际 API 客户端判断。分享和互动仍分别由服务器开关控制。
- `lib/ui/ring_share_page.dart` 按当前账号与读取权限响应晚到的服务器开关。睡眠、健康记录、运动及每周回顾共用。心血管趋势首张血压卡提供分享操作，按来源与日期选择实际读数。分享预览保留实际测量时间。
- `lib/ui/global_care_page.dart` 页收到能力更新后显示邀请入口，空列表有「亲友邀请」按钮，已建立关系可查看「问候与近况」。已有的会员号邀请继续走原流程。

## 验证

| 范围 | 结果 |
| --- | --- |
| App | 格式检查和 `flutter analyze` 通过。UTC、Asia/Shanghai 完整 Flutter 测试各 2,502 项，两端入口测试验证晚到开关可以更新已打开的页面。 |
| 安装包 | iOS Profile、Debug 和 Android Debug、QA Release 均构建成功。iOS 真机测试 IPA 与 Android QA APK 已验签。 |
| iPhone 15 Pro Max | 从 1325 原位覆盖至 1326，系统读回构建号并成功启动。已有远程关爱和会员号邀请入口可打开。公网能力接口仍返回 404 时，新邀请入口按预期隐藏。 |
| 后台候选 | 类型检查、构建、633 条接口目录及 48 项网关检查通过。全工作区 2,525 项通过，116 项按环境条件跳过。 |
| 隔离数据联调 | PostgreSQL 完整迁移成功，7 项实际 HTTP 与数据库测试通过。核对免登录打开快照、回应去重、撤回、一次性邀请、无默认共享指标、问候、语音和散步目标。 |

首次全量 App 回归发现旧的界面测试替身没有声明新功能可用状态，补齐后两时区均通过。Mac 自带 Node 24 拒绝加载 Rollup 的本地库，改用已核验的 Node 22。文件上传测试因系统临时目录解析到别名而失败，改用本轮独立真实路径后通过。数据库建立后重新应用 Prisma 迁移，所得联调用于实际后台 HTTP 测试。

安装包、双端回归、线上探查和真机日志保存在 `build/say-ring-sharing-recovery-20261125.ixUad5/`。实际社交平台打开、通知和公网可用性依据上线后测试确认。

## 当前发布状态

GitHub 设备授权已建立，仓库接口确认对 `tangwu88/saydianserver` 的 `push` 权限为 `false`。待发布候选仍为 `4b85774`。最后一次现网检查读回 `62bf80e`，能力接口仍为 HTTP 404。1326 的真机安装与候选后台的隔离联调结果见上表。
