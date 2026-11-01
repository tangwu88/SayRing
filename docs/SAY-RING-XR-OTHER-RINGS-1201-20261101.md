# iPhone XR 切换其他戒指真机调试（1201）

## 范围和数据保护

- 2026-11-01，XR 在线；iPhone 15 Pro Max 未在线。基线为原账号、原 R8、`cn.saydian.ring` 1.0.8（1201）Profile。用户先指定 R7 Pro／HR05 或 R7 Ultra，随后明确允许连接实际能连上的其他戒指。
- 开始前通过 `xcrun devicectl device copy from --domain-type appDataContainer` 将完整应用容器私有备份到 Git 外，共 103 个文件。所有测试包均以相同 Bundle ID 和开发团队原位覆盖；未卸载 App、解绑、重置戒指或清空记录。VM 地址、原生日志和设备标识保存在私有目录，不入库。

## 发现与真实连接

1. 新增只读扫描探针 `integration_test/ios_xr_other_ring_scan_test.dart`，经已验签 Profile 和 `tool/drive_ios_preserving_data.mjs` 在 XR 上运行，扫描到 R21、R12、HR05 和另一枚 CoolWear 广播；未发现 R7 Ultra。扫描后账号和 R8 目标未改变，测试退出码 0。
2. 现有页面走查脚本对 HR05 的四轮尝试均能筛出唯一候选，但连接未完成。补充状态轨迹后确认：`connecting` → `error`，实际错误曾为“戒指握手或能力读取超时，请靠近手机后重试”。广播 RSSI 约 -93 至 -95 dBm。最初脚本在选中新戒指前恢复旧 R8 自动连接，与真实添加页顺序不同；已将测试脚本改为 `stopDeviceScan(resumeRecovery: false)` 并复测，HR05 仍超时。因此不把首次失败全归因于脚本，也不在弱信号下声称 HR05 的 SDK 有确定缺陷。测试产生的失败记录没有删除。
3. 按用户后续授权，使用同一保数据测试流程选择扫描中唯一的 R21。真实 SDK 握手和能力确认成功，测试记录为 `connected=true`、`requestedModelMatched=true`、`connectedSdk=qring`、账号不变。页面走查共通过 24 个可达入口，另有 8 个入口按当前能力或配置门禁不可用；包含健康首页、各已开放指标详情、睡眠概览、设备、健康监测只读设置和账号页面。后台同步流程已结束，但没有以此证明新活动或睡眠样本已读到。连接当下未取得有时间戳的电量值，电量读取不计为通过。
4. 测试后重新安装、启动已验签的普通 `lib/main.dart` Profile 1201。XR 运行态再次读到 R21 为已连接且与保存目标一致，前台、无恢复操作、同步不在进行。接着前台静置约 300 秒，59/59 次有效采样均显示同一目标已连接，断开 0 次、VM 读取错误 0 次；结束后再次核对连接与保存目标均为 R21。测试前后原有 `Documents` 文件无缺失，唯一变化的是本次走查的私有 `proof.json`；其余变化属于缓存／状态文件。此检查不证明云端或戒指内部历史数据完整，也不证明更长时间或锁屏状态不会掉线。

## 构建和回归

- 两份真机测试源码 `dart format`、`flutter analyze --no-pub` 通过；Flutter 全量测试 UTC、Asia/Shanghai 各 1709/1709，原生连接相关测试 30/30。Android Debug 和 `SAIDIAN_ALLOW_QA_RELEASE=true` 的 QA Release 构建通过，QA 包未发布或安装。iOS Debug 与 Profile 在本机 Xcode 27 使用临时 `IPHONEOS_DEPLOYMENT_TARGET=15.0` 串行构建通过，仓库默认最低系统未改。最终普通 Profile 为 `cn.saydian.ring` 1.0.8（1201）、团队 `W7SXQ4A226`，签名验证通过。
- 本轮只修改了真机测试脚本和记录，没有修改产品连接实现。R21 通过不等于 HR05 或 R7 Ultra 通过，也不等于拍照手势、提醒振动或活动／睡眠有新样本。

## 待续测

- HR05 需贴近 XR、从充电座取下并确认未连接其他手机后重测；若仍在较强信号下握手超时，再抓原生回调和固件状态定位。R7 Ultra 本轮未被发现。
- 锁屏、自然断连后的自动恢复和跨机抢连尚未验证；本次 5 分钟观察没有发生自然断连。
