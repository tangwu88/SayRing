# Veepoo Android SDK

官方来源：<https://github.com/HBandSDK/Android_Ble_SDK>

当前 Veepoo 锁定提交：`a3c02015aa9130ab1ae34c93ae0b04ecbcbfe408`（2026-08-07）。

W8 云创插件固定提交：`5ca3050d7170509d386f548fcae7d5f8b457febf`。

本项目已获得合作客户授权，并锁定下列官方文件：

- `vpprotocol-2.3.77.15.aar`
- `vpbluetooth-1.20.aar`
- `abpartool-release.aar`

Gradle 会自动检测完整文件集；只放入部分文件时会直接停止构建并列出缺失项。
这些合作方二进制随本私有 App 仓库锁定，禁止脱离本项目再分发。

当前官方文件校验值：

- `vpprotocol-2.3.77.15.aar` SHA-256：
  `2D2062E9E8EB89F571B3F1563569C20AA125D8EF404A9D8850B5AA9B4191A5E8`
- `vpbluetooth-1.20.aar` SHA-256：
  `26D7037238D18A28AC373A511B7A2ABDFAC2A405E01564F90A89C926B5B48BD8`

授权范围仅限赛电 App 调用。

## CoolWear 戒指 SDK

2026-11-19 将 `coolwear_bluesdk-release.aar` 更新为官方公开 Android SDK **1.4.1**，
来源：<https://github.com/Coolwear/androidSDK/commit/39b72153be987c0c788d4f7ffeb12c6ea842db1c>，
路径 `app/libs/coolwear_bluesdk-release.aar`。SHA-256：
`F9181033FC25C0EED3C5EFC42AEDE2726B4017B4F5758037B1BC0D1121DA13A1`。
原文件来自项目方 `Android&iOS_SDK20260910.zip` 中的 `Android_SDK_DEMO_1.4.0.zip`；
原SHA-256 `AD482D5D69B99941D906038794165C1D479E5E038713954D9CA22059083D0F5F`。
保留既有名称路由和真实能力握手，新版新增的左右手/计数器接口不自动开放产品入口。
现有一次初始化/真实ACK、历史逐包保存、手动测量、相机和手势边界不因升级放宽。
Gradle 缺少此锁定文件时停止构建；不得把调试 SDK、原始健康数据或供应商包公开分发。

## QRing Android SDK

2026-11-19 按项目方提供的 `QRing_Android_SDK_1.0.0.86.zip` 升级至
`qring_sdk_1.0.0.86.aar`，替换原 1.0.0.76。SHA-256：
`1c89c4ae657e61d646669651e03d7fce4aea1e2adaf70288f9e0ecdc907927fa`。
使用厂商原始 AAR；仅构建副本移除两个 `-printmapping map.txt` 输出指令。
新 SDK 控制台、文件、原始包及 UUID 日志在初始化前关闭；保留真实能力、
无默认测量值、账号隔离、一次初始化与恢复设置回读门禁。R7 Ultra/R7 Pro
仍使用原 CoolWear SDK。此升级不开放 WhatsApp、录音或其他新业务功能。

## 共享依赖选择

最终 App 只从云创插件目录解析共享杰理 AAR，Veepoo 的协议和蓝牙 AAR 保持不变。
原 `android/app/libs` 中的杰理文件只读保留，但不再进入 `veepooSdkFiles`，避免重复 dex。

- `JL_Watch_V1.13.1_11214-release.aar`：`7B63DE70139AE92AF67E74FEFFEDC044A383CDDA31914344EB3318BF41D5DE6E`
- `jl_rcsp_V0.7.2_527-release.aar`：`0CBB1D46BCFDA8F6D2B7A68D805C88DC4F543A4890FC2537E9AA76D0F93857B2`
- `jl_bt_ota_V1.10.0_10932-release.aar`：`7B0671E4F98B39537ED1A0701FCD0AECD16C17EEBC43468FA58F17AF0E84EE15`
- `BmpConvert_V1.6.0_10604-release.aar`：`8B5E6661B18EB39AC11F48CAAEE29C54FFF07213455E8C6B06A3B8BC903DCCA3`
- `ycbtsdk-release.aar`：`6F405B07E30F3D634FEEC0258F8A8A83DF5EF53803BF94D7C7C1E675AEF3FB1C`
