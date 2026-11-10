# XR 1278 保留数据安装与持续调试

2026-11-09，Asia/Shanghai。用户在最新共享代码与运动栏修复完成后要求“苹果真机调试”。本轮采用刚完成验证的正常主程序 **1.0.12（1278）**，保留现有账号、健康数据、绑定和戒指设置。

## 来源与目标

- 当前分支 `codex/latest-sport-entry-20261109`，起始本地/远端为 `97754cdcdc158e5d93d1a161839f71d508066663`，工作树干净。读取 AGENTS、交接及最新实施记录，执行 fetch/prune 成功。
- XR 和 15 Pro Max 均在线，按最近实际调试目标选择 XR，已向用户说明；本轮只更新 XR 的 `cn.saydian.ring`，未更新另一部手机或手机中的其他 App。
- 正常 Profile 构件来自 [本轮双端验证](SAY-RING-LATEST-SPORT-ENTRY-20261109.md)，团队 `W7SXQ4A226`，**1.0.12（1278）**。重新核对实际运行源码指纹 `8cb3c50badeae5a8fd311c882df3370b531945d3e85eb6f0b75415754ac13835`、原生及 Dart AOT 哈希、深度签名、XR 授权和正常 main 入口；没有重用诊断构件或把编译失败回退成旧 App。
- fetch 另见独立 Android 分支继续推进到 `a9ea5f8`，本轮沿用已完成双端验证的 1278，不在安装阶段临时合入另一套未重新验过的代码。此处不宣称所有实验分支均已合并。

## 实际安装与调试

1. 先核对 XR 当前 Say Ring 的实际安装路径，只终止该路径下的 Runner。完整容器复制到用户私有 Library 备份目录，不卸载、不改账号、不清空任何数据。
2. 原位覆盖正常 1278，再读系统安装清单，明确为 `cn.saydian.ring` / **1.0.12（1278）**。安装前后 **72/72 业务文件完全一致，0 缺失、0 改写**，包括原账号、绑定、加密库和设置相关文件。
3. 通过标准 `flutter run --machine --no-pub --profile --use-application-binary=<已验签正常构件>` 启动，收到当前构件的 app.debugPort、app.devTools、app.started。保留持续 Flutter 主机，不按固定数分钟自动 detach/结束；未使用默认会卸载应用的 flutter drive。
4. 内置浏览器枚举及新标签页请求实际失败，未声称已打开。改用现有 Chrome 的独立标签页，实际画面显示 Flutter DevTools **Connected app / arm64 iOS / Flutter native (profile build)**，连接为本轮真实 VM 服务。未修改旧商店审核页面或其他标签页。
5. 只读 getVM/getIsolate/getObject/getInstances 核对 VM PID 对应 XR 系统安装路径，主 isolate Resume，isBooting=false。原登录会话、本机存储 owner 与健康 owner 一致。

## 启动后的记录完整性

- 重新复制运行后的私有加密库，使用只读 SQLCipher 对比：升级前 **453 条**、运行后 **453 条**；原 **453/453 全保留**，0 缺失、0 payload 变化、0 指标或原测量日期变化。读取前后加密副本哈希不变。
- 数据库密钥仅在本机内存中使用，不打印或保存；账号、目标标识、会话、原始健康载荷、备份及本地调试授权 URL 不进入公开 Git。
- 当前仍记住 SD-RING-R7 Ultra，实读 connectedDevice 为空，恢复未挂起。本轮没有替用户选择另一枚戒指，也未执行手动同步、测量、设置写入、解绑、重置或系统忽略设备。
- 上述是安装、启动、数据保留和调试连接证明，不是 R7y/R8/HR05 等型号的无线连接、运动或睡眠同步验收。

## 过程中的未完成检查及纠正

- 初次只读账户核对发生在尚无 live session 时，辅助脚本返回 `MissingLiveSession`，未能进行逐行记录检查；没有据此重登或更换账号。稍后实际 isBooting=false、session 存在，重新核对归属正常。
- 第二次已完成进程和账号归属核对，但旧辅助脚本读取备份路径时未去除行末换行，复制前发生 FileNotFoundError；没有改写或删除原备份。只修正忽略目录内脚本的 `.strip()`，第三次完成全部记录比较。没有修改产品源代码或把辅助脚本失败记成 App/戒指故障。
- 安装与三次检查的结果分别保留在 `build/xr-1278-debug-20261109-n46_h81w/`。持续调试、原始容器、密钥及日志仍仅在本机；本轮不提交应用市场或更改已送审 1275。
