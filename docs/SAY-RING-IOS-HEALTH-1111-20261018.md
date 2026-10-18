# iOS 只读健康上线联验与历史日期入口修复

## 基线与范围

2026-10-18，客户端基线 6e343225，当前验证分支与 origin 一致、工作树干净；fetch / ff-only 成功。已重读项目工作规则、交接、复盘、回归清单及 1110 记录。
仅 Say Ring，保留账号、绑定、数据、图标、cn.saydian.ring 和仅 iPhone；不改现有 App Store 审核，不操作 AI 生成/重试、授权或计费。

## 服务端已上线的独立证据

原部署遇到下载超时、143 和恢复下载 137；未将其归因为已证实的 OOM，也未修改共享服务端代码或另起发布。恢复 attempt2 校验原镜像成功后，现有 Deploy production 39099027213 成功。
已独立 GET `/health/ready` 和 `/global/health/ready`：均 ready / database ok / aeb9afcb8bbd8b4168c38e489c827790c448bf7a。

canonical 与 `/global` 的 app-display?product=say-ring&platform=ios 均严格匹配 schemaVersion=1 / validForSeconds=300：心率、HRV、血氧 true，皮肤温度、压力 false，原 hideAi=true / sleepAiEnabled=true 不变。
后台保存与重新打开持久回读、其他 App/Android 不受影响由服务端任务验收；本客户端没有重复写开关、改法律 DB 或触发真实 AI。美国站独立容量失败不等于同版本部署通过。

## 真机发现与修复计划

USB / InstallationProxy 再次确认 iPhone 15 Pro Max 仍安装 1.0.2（1110）；仅将原 Profile 切回前台，没有重装或退出账号。首页心率、HRV 卡片随公开开关出现，月历史可读取；没有用合成数据代替。
一次导航截图失败，重新取图成功；同一进程仍存活，崩溃清单未见本轮 Runner 报告，不据截图助手失败断言 App 闪退。仅返回已有 AI 报告页，没有点击其重试/授权按钮。

P2：有非今天历史值的首页卡片，进入趋势默认今天，显示空页；切换月份可见实际历史。预期入口应对齐卡片对应真实记录日期，不应补造今天数据。
修改仅限共享 Dashboard 卡片的 initialDate、三项合成回归和本文/索引；不改数值、时区语义、存储、接口、SDK 或权限，Android 同步回归。

先补心率/HRV/血氧历史日期测试，再修入口。计划候选 1.0.2（1111），必须重新完成静态/全量/双端构建，再保数据覆盖并重测，未完成前不记通过。
原始照片、健康值、账号、设备唯一标识、容器及截图仅在忽略的权限 0700 目录中保存，不进入 Git。

## 已完成检查与修正

三项合成历史日期测试先红：均为预期记录日期、实际 null；补上 `initialDate: record?.measuredAt` 后发布/UI 文件 11 项通过。仅增加入口参数，不推算或修改任何记录。
最终源码格式 235 文件零变化，静态分析零问题；完整 Flutter 测试 UTC、Asia/Shanghai 分别 1281/1281 通过。负向夹具输出的错误日志不代表真实服务被调用。

原生/包装/隐私/保数据门禁 43 项通过，含实际 Foundation 109 断言及 Swift 导入检查；主机契约 503 项通过，附加 80 项中 79 通过、Windows ACL 平台跳过 1；发布工具 Python 35 项通过。
iOS 串行签名 Profile 125.7 秒 / 60.2 MB、Debug 37.0 秒成功；独立核验签名、原团队、目标设备描述文件、1.0.2（1111）/cn.saydian.ring/仅 iPhone。两包均冻结，Profile 无 JIT、Debug 含 JIT。

## 1111 原位安装与真实界面

InstallationProxy 核对旧 1110 后停止精确目标进程；首次停止后出现新目标进程，早期副本不作停止态一致性证据。该次编排未据停止态检查失败阻断复制，后续明确弃用该副本，没有据此安装或声称一致。
再次停止并确认进程不存在，最终复制前后均核对停止态。只覆盖安装冻结 Profile 1111，不卸载、不改包名、不清库；启动前再次复制并对比：52 文件、内容变化 0、系统文件少 2 多 2，Documents / Preferences / 数据库既有文件哈希一致。

安装后精确回读 1.0.2（1111），正常独立启动成功。原账号、头像、绑定和睡眠记录保留；三项首页卡片均出现，日/周/月切换及记录详情可读，单位分别为 bpm、ms、%，来源为戒指历史数据；没有手动测量、医学判断或风险按钮。
1111 首次重开后读到原账号当天历史；这不单独证明本轮新采样或新的 SDK 完整同步。设备页两次显示原 R12 等待靠近，没有解绑、改绑或用其他设备替代，固件与本轮新生理同步尚未重新确认。

初次记录仅完成 Profile 独立启动与真机页面验收；1110 的 VM/Inspector/热重载不冒称为 1111 结果，1111 实际附加由下节续记。访客流程只由测试覆盖，未退出个人账号来做真机验证。

### 1111 原生 Debug 附加排查

为完成当前版本的实际调试，保留私有容器后覆盖同源 Debug 1111、start-stopped 并附加精确目标。第一次 LLDB 提前 continue 报 Process must be launched，待 attach 完成后再继续。
随后两次 DartWorker 在 JIT 页 EXC_BAD_ACCESS code=50 暂停；不能把旧 Profile 成功当作 Debug 无异常。查阅 [Flutter 官方 JIT 修复说明](https://github.com/flutter/flutter/pull/184690) 及本机 Flutter lldb.dart，发现 attach 后 GetAsync 仍为 True；把设置置于 attach 完成后并实读 False，不修改原厂/生成助手、App 或 Flutter SDK。

直接调用 Flutter 自带 iproxy 缺少 dylib 搜索路径退出 134；不据此判断 App 故障。使用独立 Python USB 转发，首次误将已转发主机端口作为 Flutter 的设备 debug-url，导致双重转发失败，保留该日志；改为新 mDNS 的实际设备端口，不使用缓存的首条广播。
只读 GET getVM 已核对为当前新启动目标 PID、main isolate 存在；Flutter 正在同步文件时，不提前将该结果当作已附加/热重载完成。最终调试与 Profile 恢复结果续记下节。

## Android 构建回归与磁盘

同生产 API / 1.0.2（1111）QA Release 130.3 秒、69.9 MB 成功并冻结；显式内部 QA / Debug 签名，不是正式分发包，未安装或发布。
Release 前后原 QRing SDK 副本校验通过。随后 Debug 在 D8 写 classes4.dex 时磁盘满；该次退出 1，不记通过，也未用旧 APK 替代。

停止本次构建后核对无本项目编译/LLDB 和无目录句柄，再逐文件确认 iPhoneOS 与 Debug 配置的 Runner.app 各 223 文件和冻结包一致。只清理本项目失败 Android intermediates、Flutter 编译缓存及无 dSYM 的 Debug 输出和重复生成 App；原始 SDK、源码、所有签名冻结包、Profile dSYM、映射及真机私有证据保留，可重建恢复缓存。
Debug 重跑 38.0 秒成功；后续离线双 ARM 原生单测 13 秒成功，12 suite / 53 项，失败/错误/跳过均 0。完整 APK 构建先通过，单测命令仅跳过重复 Flutter 编译，不冒充另一次完整 APK 构建。
QA Release / Debug 均验签，aapt2 确认为 cn.saydian.ring / 1.0.2 / 1111 / arm64-v8a + armeabi-v7a；Debug 后 SDK 副本仍通过 30 项校验，只移除原有两条映射输出指令。未安装 Android、未上传发布。

## 重开与只读联验

Profile 1111 三次独立启动均返回不同的新目标进程，非 start-stopped；原账号资料和首页三项重开可读。“全部健康数据”也仅包含已发布三项加活动/睡眠，没有皮肤温度、压力或医疗项目入口。
原 R12 手动精确重连进入“正在重新连接”，未取得握手成功证据；不更换目标、不解除绑定。新 SDK 采样、当前固件、CoolWear 实物及离线满五分钟的真机撤回仍标待验；自动化租约/迟到回包测试不冒充这些实物结果。

## 1111 实时 Debug 最终结果

确认 attach 完成、目标 SIGSTOP 后才设置同步模式，再 GET GetAsync=False；前两次将设置放在 attach 前会被后续流程改回 True。第三次未再出现 DartWorker 异常暂停，未修改任何生成文件、Flutter SDK 或厂商 SDK。
使用新 mDNS 最后一条广播、USB 只读 getVM 验证 PID 精确匹配，再将真实设备端口交给 Flutter 做自己的转发；不是把主机已转发端口再次当设备端口。

Flutter attach 文件同步 6.5 秒完成，实际 VM/DevTools 可连接。main runnable / Resume、根库 main.dart、AppController 唯一、Inspector 可用；热重载实际返回 Reloaded 8 of 2235 libraries in 1,148ms，随后再次核对 VM 正常。
第一版只读检查助手未展开 UnmodifiableSetView，曾误报 grantedMetrics 空；仅改私有助手展开 _source 后实读 heartRate / hrv / bloodOxygen。真实设备/能力为空，与等待原 R12 靠近一致，不虚报握手。

结束 Flutter attach 后目标仍被 LLDB 持有，普通 SIGTERM 两次未使其消失；均据新进程清单阻断后续容器复制。核对私有日志句柄仅属于本任务 LLDB 后结束该进程，再对精确 Debug 目标 SIGKILL，确认进程数 0 才复制最终容器；没有结束其他 App 或任务。
随后恢复同源冻结 Profile 1111，不卸载、不清库。恢复前后容器 51→47 文件，原内容变化 0，少 6 / 多 2 均为系统 SplashBoard 快照；Documents / Preferences / 数据库原文件哈希一致，非 Keychain 备份或恢复演练。
InstallationProxy 再次精确回读 cn.saydian.ring / 1.0.2（1111），正常独立启动和首页截图再次通过。最终留在可直接启动的 Profile，不留依赖调试器的 JIT 包，也不宣称当前仍有 VM 附加。

所有构建/LLDB 结束且确认目录无句柄后，收尾只移除约 1.3 GiB 本项目 Android intermediates 可重建缓存；原 APK、测试 XML、SDK 副本、R8 mapping、iOS dSYM、冻结包和私有证据均保留。
本轮结果先提交当前验证分支供远端 CI 复核；原 R12 新同步等硬件边界尚未全验，暂不提升为主线已验收基线，不动现有 App Store/TestFlight。
