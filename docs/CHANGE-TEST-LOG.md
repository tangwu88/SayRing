# 修改与测试记录索引

本文件是项目长期执行约定。每位同事开始修改前必须先同步 `origin/main`，再阅读最近记录；每组修改和每次验证都写入对应日期的实施记录，并随源码一同提交。

## 执行顺序

1. 检查分支、工作树、本地与远端提交号；工作树不干净时只做安全合并，不覆盖既有修改。
2. 阅读最近实施记录中的已完成项、失败方法、待验证项和真机边界。
3. 记录本次修改原因、文件、影响范围和预期结果后再实施。
4. 逐次记录格式化、静态检查、自动测试、构建、安装、真机流程和日志检查结果。
5. 失败记录保留，并补充根因与最终修复；交付时提交记录并核对远端提交号。

## 最近记录

- [2026-09-08 Android 微信授权登录真机联调](QA-20260908-ANDROID-WECHAT-LOGIN.md) — 已补 Android 微信入口、原生授权回调和 App 登录接口契约；真机可到达微信授权成功回调，但当前服务端接口要求客户端直接提交 `openid`，与 Android SDK 实际仅返回一次性 `code` 不兼容，完整登录待服务端按 `code` 换取身份后复验。
- [2026-09-07 三端设备型号展示回退](IMPLEMENTATION-LOG-20260907-DEVICE-MODEL-FALLBACK.md) — SDK 型号为空时仅在展示层取蓝牙名最后一个 `-` 后的非空内容；Flutter 双时区各 525、鸿蒙双时区各 429，Android/iOS/鸿蒙 Debug 编译通过。
- [2026-09-07 鸿蒙运动与记录完整闭环](IMPLEMENTATION-LOG-20260907-HARMONY-SPORT-PARITY.md) — W9S 真实能力限制为跑步/步行/骑行，跑步启停、51 秒加密记录和详情真机通过；双时区各 428 项、Debug/Release 构建与验签通过。
- [2026-09-07 三端包 GitHub 上传确认](release/QA-UPLOAD-20260907-R6.md) — `qa-20260907-r6` 私有预发布，5 个安装包加说明/校验共 7 附件，远端 SHA 和大小一致；标签 `1110a5f`，不等于商店或 CI 验收通过。
- [2026-09-07 最新三端 QA 安装与发布说明](release/QA-RELEASE-20260907-R6.md) — Android r6 两包、iOS r6 Profile、Harmony r12 两包及安装/签名边界；仅 GitHub 私有预发布，不能作为正式上线结论。
- [2026-09-07 Android r6 真机安装预检](QA-20260907-ANDROID-R6-LIVE.md) — 重连后确认现装 r5 与新包同签；随后 USB 三次断续，未执行安装或清绑定，不启动未知保存目标抢占手表。
- [2026-09-07 三端续测、授权恢复与 r6 构建](IMPLEMENTATION-LOG-20260907-CARE-PUSH-RESUME.md) — workflow 已推送但 CI 计费仍阻断；P40 r5 已装而 USB 未授权，r6 / 鸿蒙 r12 独立记录最终构建与验证边界。
- [2026-09-07 共享保存回读与账号隔离](IMPLEMENTATION-LOG-20260907-CARE-SHARE-READBACK.md) — POST 后原账号回读一致才成功、换号拒绝迟到响应、保留未知键；新增 44 项、完整双时区各 524 项通过，不替代服务端撤销授权修复。
- [2026-09-07 Android r6 安装包门禁](QA-20260907-ANDROID-R6-ARTIFACTS.md) — 首轮原生推送配置漏注入拒收，重建后按实际 APK 复核签名、原生参数、ABI 与 16 KB。
- [2026-09-07 鸿蒙 r12 构建与签名](BUILD-20260907-HARMONY-R12.md) — 同源重新生成 Debug/Release，双时区各 423、官方验签；开发 Profile 不等于商店发行。
- [2026-09-07 三端整改阶段总结](QA-SUMMARY-20260907.md) — 已完成、真机失败、开发验证包、服务器与系统限制分开；优先从此进入本轮最终结果。
- [2026-09-07 关爱组合读取账号归属](IMPLEMENTATION-LOG-20260907-CARE-READ-SESSION.md) — r5 拒绝换号后的迟到成功/错误与旧 401 刷新，同账号刷新保留；定向 90、完整双时区各 480 项，现网 HRV 撤销仍须后台修复与复验。
- [2026-09-07 关爱单项结果权威性](IMPLEMENTATION-LOG-20260907-CARE-METRIC-AUTHORITY.md) — r3 真机撤销 HRV 仍显示摘要失败后，Flutter r4 删除无类型总表预读/回填，完整双时区各 463 项通过；旧后台单项失败不再伪装成功。
- [2026-09-07 鸿蒙关爱单项权限边界](IMPLEMENTATION-LOG-20260907-HARMONY-CARE-AUTHORITY.md) — r11 同步删除总表补偿，403/空/不可用分开，完整双时区各 423 项；服务器单项授权与后台推送仍须现场闭环。
- [2026-09-07 鸿蒙离线运动与资料保存回读](IMPLEMENTATION-LOG-20260907-HARMONY-OFFLINE-SPORT-PROFILE.md) — 按账号查询本机运动而非依赖连接及全局快照；实际提交字段逐项回读，保存不完整不报成功。
- [2026-09-07 CI 鸿蒙双时区契约检查](IMPLEMENTATION-LOG-20260907-HARMONY-CI.md) — 新增独立 Node 测试矩阵，非 HAP 编译；工作流授权及远端计费门禁仍阻断。
- [2026-09-07 鸿蒙命令排空与迟到回调隔离](IMPLEMENTATION-LOG-20260907-HARMONY-COMMAND-DRAIN.md) — 8 类旧操作补真实 Promise 排空及断开确认；生产服务 53 项、完整双时区各 380 项通过，最终 r9 构建和验签通过。
- [2026-09-07 鸿蒙单位设置非目标字段保护](IMPLEMENTATION-LOG-20260907-HARMONY-UNIT-SAFETY.md) — 避免官方单字段接口随手机覆写手表时制；保存前后逐一核对 32 字段，真机恢复原 24 小时并完成距离/温度切换回归。
- [2026-09-07 三端关爱授权撤销核查](IMPLEMENTATION-LOG-20260907-CARE-AUTHORIZATION.md) — 修复 Flutter 单项 403 被总表回退吞掉及未授权旧值显示；若现网只返回 200 空表，仍需服务端明确授权状态，不能据此声称撤销联调通过。
- [2026-09-07 鸿蒙心电无效值与佩戴状态](IMPLEMENTATION-LOG-20260907-HARMONY-ECG-VALIDITY.md) — 厂商明确 ECG HRV 255 为无效值；补真实佩戴回调、单次安全取消和迟到结果隔离，双时区各 344 项通过，独立日历史 255 未做推断性删除。
- [2026-09-07 关爱红点、前台横幅与通知点击复核](IMPLEMENTATION-LOG-20260907-CARE-NOTIFICATION-UNREAD.md) — 远端0不抹本地邀请未读；完整双时区439项通过；旧安卓包系统通知点击异常仍待新包现场复验，不能标完整通过。
- [2026-09-07 现网旧后台关爱推送](QA-20260907-CARE-PUSH-LIVE-BACKEND.md) — 已用Chrome核实旧Yii与有效极光配置；P40单设备通道约1秒到达，实际业务自动触发仍缺旧控制器/主机证据。
- [2026-09-07 鸿蒙前台关爱邀请提醒](IMPLEMENTATION-LOG-20260907-HARMONY-CARE-POLLING.md) — 补前台定时兜底、按账号本地收件箱、通用系统通知、稳定邀请去重和迟到请求隔离；后台即时投递及跨通道系统去重仍待服务端与真机验收。
- [2026-09-07 三端统一、账号隔离与真机回归](IMPLEMENTATION-LOG-20260906-THREE-PLATFORM-QA.md) — 本轮持续实施记录；Flutter账号/连接代次、通知契约、iOS原生表盘路由与响应式布局已补定向及全量回归，三端真机与后台通知仍在联调，不能作为整体上线通过。
- [2026-09-07 账号与手表会话防串写](IMPLEMENTATION-LOG-20260907-ACCOUNT-WEARABLE-SESSION.md) — 登录切换排空旧测量/连接，拒绝迟到回调和未绑定记录；保留手动取消与自动完成边界。
- [2026-09-06 Android 连接、权限与发行安全细节检查](IMPLEMENTATION-LOG-20260906-ANDROID-DETAIL-QA.md) — 修复蓝牙权限竞态闪退风险并收紧发行权限；华为 P40 已完成覆盖安装、ET488 自动重连、同步、趋势、表盘读取、查找手表和前后台恢复回归，404 项测试通过；当前账号 401 阻断远程关爱、消息与推送验收。
- [2026-09-06 鸿蒙 Vep 设备全功能真机验收](IMPLEMENTATION-LOG-20260906-HARMONY-ET488-FULL-QA.md) — ET488 历史问题与 W9S 现场回归已归档；已修复距离单位、血氧结束卡住和末帧覆盖有效读数，W9S 连接/同步/设备控制/测量/重连通过，完整心电终态及非零运动数据仍待后续真实样本。
- [2026-09-06 鸿蒙资料、关爱与设备发现整改](IMPLEMENTATION-LOG-20260906-HARMONY-PROFILE-CARE-DISCOVERY.md) — 资料编辑/头像选择、关爱指标状态与成员人数一致性已修复并真机验证；扫描链路正常但目标表未广播，非空成员健康数据与正式发行签名仍有外部阻断。
- [2026-09-06 鸿蒙内页逐页对照、功能补齐与手表发现复查](IMPLEMENTATION-LOG-20260906-HARMONY-INNER-PAGES.md) — 商城详情/规格/购物车/确认订单/订单详情/物流/售后续补；鸿蒙双时区各 198 项、Flutter 各 403 项、Debug/Release 编译及真机覆盖安装。交易写入、部分内页和目标表待验；GitHub CI 计费/额度阻断，非整体验收通过。
- [2026-09-06 鸿蒙设备发现与蓝牙广播排查](IMPLEMENTATION-LOG-20260906-HARMONY-DISCOVERY.md)
- [2026-09-06 鸿蒙版全面对齐 iOS 界面](IMPLEMENTATION-LOG-20260906-HARMONY-IOS-UI.md)
- [2026-09-05 iOS 微信登录与界面文案精简](IMPLEMENTATION-LOG-20260905-IOS-LOGIN-COPY.md)
- [2026-09-05 鸿蒙推送、支付与发布检查](../harmony-native/docs/PUSH-PAYMENT-IMPLEMENTATION-20260905.md)
- [2026-09-04 iPhone 与 W9S 真机测试](IMPLEMENTATION-LOG-20260904-IOS-W9S-DEVICE.md)
- [2026-09-04 合入 main 并保留 iOS 支付修复](IMPLEMENTATION-LOG-20260904-MAIN-MERGE.md)
- [2026-09-02 新服务端平滑迁移联调](IMPLEMENTATION-LOG-20260902-SERVER-MIGRATION.md)
- [2026-08-30 华为 P40 鸿蒙真机回归与窄屏溢出修复](IMPLEMENTATION-LOG-20260830-HARMONY-P40.md)
- [2026-08-30 iOS 心电手动测量崩溃修复与真机回归](IMPLEMENTATION-LOG-20260830-IOS-ECG.md)
- [2026-08-29 通知、表盘、电量、在线升级与多设备真机整改](IMPLEMENTATION-LOG-20260829-ONLINE-READINESS.md)
- [2026-08-29 关爱、跨端历史、运动、预警与 iOS 表盘修复](IMPLEMENTATION-LOG-20260829.md)
- [2026-08-28 远程关爱、小程序参数、双支付与健康链路回归](IMPLEMENTATION-LOG-20260828.md)
- [2026-08-27 心电、AI、关爱、监测间隔与连接恢复](IMPLEMENTATION-LOG-20260827.md)
- [2026-08-25 全界面体验与型号能力收口](IMPLEMENTATION-LOG-20260825.md)
- [2026-08-24 远程关爱、商城、头像与心电真机回归](IMPLEMENTATION-LOG-20260824.md)

## 固定防复发资料

- [2026-08-29 跨端问题修复复盘](BUG-RETROSPECTIVE-20260829.md)
- [赛电 App 修改与回归检查清单](REGRESSION-CHECKLIST.md)

## 记录模板

```text
### HH:mm 修改/验证名称

- 原因：
- 文件/范围：
- 预期：
- 结果：通过 / 失败 / 未执行
- 失败原因：
- 修复结论：
- 后续待验：
```
