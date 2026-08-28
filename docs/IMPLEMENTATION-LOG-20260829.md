# 2026-08-29 实施与测试记录

## 00:00 关爱、跨端历史、运动、预警与 iOS 表盘修复

- Git 基线：修改前已执行 `git fetch --prune origin`；本地 `codex/ios-full-migration`、远程调试分支与 `origin/main` 均为 `5d203f231c9901f7cf682c5a35e7c34890a0c1a1`。本轮保留已有修改现场，没有覆盖原型、交付源码或用户数据。
- 原因：修复关爱邀请计数、远程心电、Android 高级历史同步、运动能力、预警历史和 iOS 在线表盘；同时完成跨模块复盘，避免后续修改重复引入同类问题。
- 文件/范围：Flutter 健康模型、控制器、远程关爱 API 与页面、运动页面、表盘服务；Android Veepoo/Yuc 桥接；iOS Veepoo 桥接和映射；自动化测试、README、实施记录与回归清单。
- 预期：数据来源明确、设备能力不猜测、厂商耗时命令串行、在线表盘使用真实设备参数和独立传输；全量测试、双端构建及可执行的真机步骤通过。
- 数据来源：健康记录新增 `watch_history`、`app_measurement`、`remote_member`、`manual_entry`、`imported` 和 `unknown` 来源。预警和页面保留来源标签，避免自己的手表历史、App 测量与远程成员数据互相污染。
- 关爱邀请：角标和待处理列表统一使用真实 pending 关系；已同意、已拒绝关系不再进入待处理数量。远程心电使用独立卡片展示心率、HRV、QT 和可用波形，不再把原始接口键值直接展示给用户。
- Android 历史同步：在睡眠和 Origin 数据完成后，串行读取半小时心率/血压、设备手动测量历史和手表心电历史。新增血压脉搏、血氧、体温、血糖、HRV、身体成分和血液成分映射；同秒记录改为字段合并并保留同一 `rawVersion` 的完整波形，避免把原始 ADC 误标为校准数据。
- iOS 心电：实时与历史 ADC 均通过 Veepoo SDK 换算为 mV；只有校准完成且存在可用信号时才保存波形。低质量历史仍保留设备明确返回的心率、HRV、QT，不生成无意义曲线。
- 运动与预警：恢复两端实际支持的运动入口，能力未握手或桥接未实现时不显示默认模式；活动中退出增加确认。最近手表历史可进入预警评估，并按记录 ID 去重；旧记录不补发实时预警，也不从普通数值推断疾病。
- iOS 表盘：在线表盘不再误用已安装表盘的 `switch` 参数，改为独立 `upload_network` 文件传输。传输前校验设备运行时协议、最大文件长度和表盘形状，完成后读取设备状态确认；运行时资料不完整时不展示在线商城。
- 自动化与构建：最终 `flutter analyze --no-pub` 零问题；`flutter test --no-pub` 共 232 项全部通过；Android 双架构 Debug/Release、iOS 无签名 Debug/Profile 均构建成功。Android 首次构建曾因 Java 缩写字段需显式 getter 失败，改用 SDK 实际 getter 后重新构建通过，没有把失败结果记为通过。
- Android 产物：Debug APK 为 `192966996` 字节，SHA-256 `57f9a3d6a67195a1a6b248102b9f8df049b19e547669709586136ded3895727c`；Release APK 为 `69206144` 字节，SHA-256 `3557ecfbbafc85506682e768951b1fade905ca300167c5d7c411b17d0005afc4`。两者均核对包含 `armeabi-v7a` 和 `arm64-v8a` 的 Flutter 引擎。
- Android 真机：阶段性 Debug 包保留数据覆盖安装到华为 Android 10，首页完成渲染并恢复 W9S 连接；日志未发现本应用 `FATAL EXCEPTION`。最终仅补强手动历史参数和去重契约，已完成双架构构建，但 Android USB 随后断开，最终 APK 未再次覆盖安装，不能虚报最终包第二轮真机通过。
- iOS Debug 真机：iPhone 15 Pro Max / iOS 26.6 完成签名、安装、Flutter 附加启动；关爱成员接口返回成功，Runner 持续运行。脱离 Flutter 后直接启动 Debug 会退出，这是 Flutter DebugEngine 的运行限制，不代表发布包崩溃。
- 构建并发失败：准备执行签名 Profile 冷启动时，发现另一会话正在同一仓库为 iPhone 12 构建。两个 Xcode 构建共用 DerivedData，导致本轮 Profile 出现 `.pcm/.scan` 临时文件缺失。未中断另一会话，也未删除源码；另一构建结束后串行重建成功，确认不是业务代码错误。
- iOS Profile 真机：iPhone 15 Pro Max 完成签名 Profile 安装，随后脱离 Flutter/Xcode 以系统方式连续冷启动 3 次。每次等待 12 至 15 秒后新 Runner 进程均持续存在，第三次进程在后续复核时仍存活，没有复现独立启动闪退。
- iOS 16.3 兼容：iPhone 12 的 Profile 构建、安装和启动命令退出码为 0，并完成 W9 的配对及能力握手。旧设备未在 30 秒内暴露 Dart VM 服务，CoreDevice 也不支持该系统的进程查询，因此只确认安装、启动和蓝牙握手，不把独立长期存活写成已通过。
- iOS 原生测试：`xcodebuild build-for-testing -only-testing:RunnerTests` 成功，RunnerTests 已编译和签名。直接执行 XCTest 时，测试宿主会因 Debug FlutterEngine 脱离 Flutter 工具而无法启动；这是测试宿主限制，未删除失败记录，也未伪报原生测试已运行通过。
- 复盘与防复发：新增 `BUG-RETROSPECTIVE-20260829.md` 和 `REGRESSION-CHECKLIST.md`，并从 README、AGENTS 和长期记录索引提供入口。后续每次修改按“Git 基线 → 影响面 → 定向测试 → 全量测试 → 双端构建 → 真机 → 提交”执行。

## 待补最终结果

- iOS 在线表盘真实传输、切换和读取回验结果。
- 有效电极接触下的 iOS 心电波形，以及非零运动记录对表结果。
- Android USB 恢复后，为最终 APK 补做第二轮冷启动、完整同步和无崩溃日志检查。
