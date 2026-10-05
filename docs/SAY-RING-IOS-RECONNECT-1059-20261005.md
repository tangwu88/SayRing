# iOS 保留绑定重连修复：1059

## 基线与问题

- 2026-10-05，Say Ring，基线 f1c9d32，分支 codex/macos-update-20260930。工作树原先干净，fetch / ff-only pull 已更新。
- 用户实物反馈：点重新连接无反应，解绑、蓝牙断开并搜索后才连接。等级 P1；预期是保留原绑定重新握手，不依赖解绑或清库。
- 本轮手机已由用户重新搜索连上 QRing。旧 1058 的控制器重连、软件断开后的正常页面按钮均能握手，未在当前已恢复状态重现原故障；不能把原报告追认为已取得静默取消现场证据。
- 代码核对发现：原生取消屏障只等回调，未确认 CoreBluetooth 已关闭却缺回调的情况；已有 disconnecting 状态曾被当作已断开。手动准备目标仅检索缓存外设，缺少精确 UUID 的新搜索。按钮没有单飞操作的可见进度。

## 修改边界

- QCCentralManager / QRingWearableBridge：按原操作代次、同一外设对象及系统 disconnected 状态核对取消；20 秒等待结束后仍低频核对，绝不只因超时释放屏障。新连接开始、目标变化或实际回调结束使旧核对失效。
- 保留仍在 disconnecting 的屏障，拒绝外设已有新连接状态的迟到失败 / 断开回调。此为 CoreBluetooth 当前状态保护，不宣称 SDK 回调包含未提供的原始操作令牌。
- 手动重连：OS 已有实际连接可重新握手；其余情况重新搜索并只选择保存 UUID，目标出现即结束搜索。无目标返回空后走既有精确自动恢复，不选同名其他戒指，不删除绑定。
- AppController / 设备页：重连单飞期间显示正在重连并禁用重复点击；成功后仍隐藏重连按钮。失败和完成都释放 UI 操作状态。
- 包名 cn.saydian.ring、生产 /global、登录、健康算法与存储不变。不改审核、TestFlight、服务端、其他 App；未执行解绑、卸载、清库、系统蓝牙切换或 OTA。

## 检查记录

- 新增 Foundation 取消判定 16 组合及两个 Node 源码接线契约；合成输入和源码检查不是缺回调实物验收。
- 第一轮 Flutter 定向测试两项失败：Fake AppController 未实现新 getter isDeviceReconnecting；补齐测试替身并增加按钮忙碌 / 恢复验证。失败日志保留，不改生产逻辑掩盖错误。
- 最初 Python discover 在 tool 路径执行了 0 项，不能计为通过；改为 scripts/release 全套执行。
- 格式化和 `git diff --check` 通过；`flutter analyze` 无问题（47.4 秒）。修正替身后定向测试 47 项通过。
- `TZ=UTC flutter test --reporter compact`：1196 项通过（4 分 49 秒）；`TZ=Asia/Shanghai flutter test --reporter compact`：1196 项通过（3 分 18 秒）。
- `node --test tool/test_*.mjs`：117 项，116 通过、1 项 Windows ACL 平台跳过；无失败。两个新增源码接线契约通过。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py'`：33 项通过（83.974 秒）。
- Foundation 主机检查：`clang -fobjc-arc -framework Foundation` 编译并执行 QRing 连接策略（16 个布尔组合）、相机策略、记录映射及 CoolWear 策略四个测试程序，均通过。未执行 iPhone RunnerTests XCTest；不能把主机检查称为设备原生验收。
- Java 17 下 `./gradlew :app:testDebugUnitTest --rerun-tasks`：11 套 / 51 项，无失败、错误或跳过，构建 6 分 17 秒。最初按默认 `android/app/build` 查 XML 不存在；实际产物在 `build/app/test-results/testDebugUnitTest`，从该目录复核计数。
- Android Debug：163.7 秒；QA Release：563.5 秒、69.5 MB，均成功。QA 签名不是商店发行签名；本轮未安装 Android。
- iOS 串行 Profile（343.3 秒、60.1 MB）及 Debug（187.6 秒）成功。构建号 1059、版本 1.0.0，生产 API 与空 JPUSH key；独立保存 `.build/1059-profile/Runner.app` 和 `.build/1059-debug/Runner.app`，两者 strict codesign 通过，`UIDeviceFamily=[1]`、包名 `cn.saydian.ring`。开发描述文件包含目标 iPhone，有效期至 2027-09-30。
- 实际日志均在忽略目录 `.build/1059-*`，包含失败记录、签名信息、编译及测试输出，不提交设备标识、照片、凭据或健康记录。

## 覆盖安装与真机边界

- iPhone 15 Pro Max / iOS 26.6。停止本次 Say Ring 进程后，先私有备份 Library 和 Documents（25 MiB，目录权限 0700）。不是整机或 Keychain 备份，也不等于健康记录逐条核验。
- 原 1058 控制器仅在私有文件保存绑定 UUID 和健康 owner 的 SHA-256，用于后续核对；未导出实际值到版本库。
- 首次 Profile 安装约 5 分钟无完成，应用列表仍为 1058；只中止该安装命令，未卸载。旧 LLDB 会话完全关闭后，Debug 覆盖安装 16.220 秒成功，应用列表确认 1059；不能仅凭先后关系断言第一次失败原因。
- Debug 启动经 LLDB 和 Flutter attach 曾发现实际 VM / DevTools，并观察 QRing transport connected；后续 VM 请求超时、原进程丢失调试连接。不能把启动工具成功当成稳定 Debug 验收，也不能据此归因于蓝牙修复。随后结束本次调试会话。
- 重试同源码已签名 Profile 覆盖安装成功；不卸载、不清库、不改包名。独立启动后原生检查：QCStateConnected、SDK isResolved、真实 battery 和非空 firmware 均成立；原恢复目标和账号上下文存在。
- 第一轮软件断开：只调用本机原生 central.disconnect，保留绑定与恢复上下文；继续运行后无点击重连，完成新代次 SDK 握手，电量确认时间更新，connectedID 等于原 recoveryTargetID、取消屏障释放。此为真实戒指的软件断开测试，不是距离、锁屏、蓝牙开关或静默缺回调实物测试。
- 第二轮取证时 LLDB expression 等待远程事件无返回；只终止本次 Mac LLDB，重启本 App。该轮不计成功，不能把调试器等待等同于 App 自身死锁。Profile VM 直接连接也超时，未据此宣称 Dart 状态核验通过。
- 后续使用 CoreDevice 隧道地址而非手机 Bonjour 地址连到 Profile VM：唯一 AppController 的原登录 session、绑定、非本机模式均确认；通过对象只读字段重新计算 SHA-256，与安装前比较，`sameBinding=true`、`sameHealthOwner=true`。只报告布尔结果，不提交标识或健康数据；这不等于健康记录逐条完整性验收。
- 调试日志另发现 VM 服务接收连接时 socket setOption 报 errno 22；未确认根因，不修改 Flutter SDK 或用户网络配置。该服务异常与 App 主 isolate / BLE 功能验收分别记录。
- 新增 `integration_test/ios_qring_reconnect_test.dart`，仅使用既有真实登录与绑定，三轮软件断开后实际点击设备页按钮，检查新电量确认时间、能力 ready、原目标 / owner 不变及成功后按钮隐藏；不接入虚构设备或数据。最初漏导入 DeviceCapabilityState，静态检查发现后补导入，复查无问题。
- 集成测试前再次停止仅本 App 进程并备份 Library / Documents（25 MiB，0700）。同源码 Profile 测试入口串行构建 59.1 秒、60.6 MB，strict codesign、包名、1059、仅 iPhone 均核对；独立保留生产 Profile，测试后须覆盖恢复生产入口。
- 按 `tool/drive_ios_preserving_data.mjs --profile --use-application-binary=… --use-existing-app=… --no-dds --driver=test_driver/integration_test.dart --target=integration_test/ios_qring_reconnect_test.dart` 保数据连接已安装的验签二进制；私有 URL / auth 不写入 Git。Driver 实际连接到运行中的 Flutter isolate，三轮真实页面按钮均完成新握手和电量确认，原生日志对应 4 次连接、3 次断开，无本轮 VM 错误。最终同步、测试退出和恢复生产入口结果下附，不将中间轮次打印当作整套最终成功。
- 加入集成测试后再跑整库 `flutter analyze --no-pub`：无问题（5.0 秒）；最终源码接线契约和 diff 空白检查重跑。
- 最终保数据 Profile Driver 退出码 0，实际日志 `01:11 +2: All tests passed!`（一个业务测试加 tearDownAll），三轮按钮断开 / 重连全部通过，末轮同步结束后才完成；`Leaving the application running`，没有卸载清理。只停止已通过应用路径核对的本 App 测试进程，再覆盖恢复 `.build/1059-profile/Runner.app` 生产入口。
- 恢复生产 Profile 安装成功，正常入口启动。首次只读脚本太早读取仍在启动的空 session / binding 而失败；补等 boot 完成后重读，`sameBinding=true`、`sameHealthOwner=true`、`productionReady=true`、`batteryPresent=true`、`firmwarePresent=true`、`sameConnectedTarget=true`，同步已结束。属于验证脚本时序修正，不改产品登录。安装列表再次核对 1059 及实际本 App 进程，未触碰同时运行的其他 App。

## 尚未通过的验收

- 原始“必须解绑才能连上”的已卡住现场、缺取消回调以及三轮真实远离 / 靠近仍待复测；不以软件断开或合成输入代替。
- 1059 正常页面“重新连接”按钮三轮已实物执行；既有健康记录逐条完整性及稳定 hot reload 尚待核对。登录 / 健康 owner 与绑定哈希已确认一致。
- CoolWear 实物未在本轮连接；不能将 QRing 结果推广为 HR01 或其他型号已通过。
- 当前分支修复可提交为验证候选；不升级 main 为已接受基线，不上传 / 撤回 / 替换当前审核包。
