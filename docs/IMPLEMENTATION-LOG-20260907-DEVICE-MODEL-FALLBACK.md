# 2026-09-07 三端设备型号展示回退

## 目标与边界

设备详情没有返回型号时，从蓝牙名称最后一个 `-` 后取非空内容用于显示。例如 `SD-Watch-W9S` 显示为 `W9S`。

该值只属于 UI 回退。设备连接、厂商识别和能力判断继续使用 SDK 原始字段，不把名称后缀伪装成厂商真实型号。

## 修改

- Flutter `DeviceInfo.displayModel` 统一服务苹果、安卓的设备卡与“关于设备”。
- 鸿蒙 `wearableModelText` 同时用于设备卡和“关于设备”。
- SDK 型号非空时始终优先；无连字符或尾段为空时显示未知占位。
- Flutter build 提升为 `0.1.19+24`；鸿蒙 build 提升为 `0.1.4 (9)`。

## 验证

- 修改前已执行 `git fetch --prune origin`，本地与上游为 `0/0`，工作区干净。
- `flutter analyze`：零问题。
- Flutter 完整测试：UTC 525/525，中国时区 525/525。
- 鸿蒙完整测试：UTC 429/429，中国时区 429/429。
- Android Debug APK：构建通过。
- iOS Debug 无签名：构建通过。
- 鸿蒙 Debug HAP：ArkTS 编译、打包及签名通过。

## 真机边界

鸿蒙 nova 14 已覆盖安装 `0.1.4 (9)`，安装后账号与设备绑定保留，App 冷启动成功且进程保持存活。

W9S 自动恢复为 Vep 已连接状态；设备页真机确认 `SD-Watch-W9S` 在 SDK 型号为空时显示“型号 W9S”，同时真实 MAC、电量、固件和最近同步时间可见，手表 BLE 未断开。

电脑到手机的 HDC USB 通道期间出现间歇性 `Offline`／“communication channel is being established”，重新连接后可继续截图与查询；App 进程持续存在，日志未发现本应用崩溃、panic 或 fatal。该现象记录为 USB 调试通道不稳定，不误记为手表断连。
