# 修改与测试记录索引

本文件是项目长期执行约定。每位同事开始修改前必须先同步 `origin/main`，再阅读最近记录；每组修改和每次验证都写入对应日期的实施记录，并随源码一同提交。

## 执行顺序

1. 检查分支、工作树、本地与远端提交号；工作树不干净时只做安全合并，不覆盖既有修改。
2. 阅读最近实施记录中的已完成项、失败方法、待验证项和真机边界。
3. 记录本次修改原因、文件、影响范围和预期结果后再实施。
4. 逐次记录格式化、静态检查、自动测试、构建、安装、真机流程和日志检查结果。
5. 失败记录保留，并补充根因与最终修复；交付时提交记录并核对远端提交号。

## 最近记录

- [2026-09-06 Android 连接、权限与发行安全细节检查](IMPLEMENTATION-LOG-20260906-ANDROID-DETAIL-QA.md) — 修复蓝牙权限竞态闪退风险，收紧厂商 SDK 权限、组件、明文网络与健康数据备份；双时区各 404 项、Android 原生 12 项和发行门禁 20 项通过，另一台 Android 手机未被 macOS/ADB 枚举，真机安装待设备通道恢复。
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
