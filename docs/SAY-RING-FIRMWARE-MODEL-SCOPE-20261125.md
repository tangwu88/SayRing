# Say Ring 固件升级范围与 QRing 附件核对

2026-11-25。从 App `df8d91c` 和后台 `057f824` 开始。本轮按用户确认的型号与原厂固件一一匹配。

| 设备型号 | 原厂通道 | 原厂固件包 |
| --- | --- | --- |
| R8、R21 | QRing | R21 |
| R7 Pro、R7 Ultra（R7u） | CoolWear | HR05 |
| R7、R7y | CoolWear | HR01 |

App 查包和验证签名都检查包型号，同时核对设备型号、硬件、当前版本及目标版本。同一包可对应两个商品型号，两个型号仍各自登记和核对。iOS QRing 原生发送只接受 R8、R21 和 R21 包，原生重读硬件、固件及电量。R8 Pro、R22、R7C、U19 和不能确认商品型号的 HR05／HR01 广播不进入该升级范围。设备连接与固件版本查看沿用原路径。Android QRing 和双端 CoolWear 仍待完成原生刷写与恢复验证。

## 本轮收到的 QRing 附件

- `QRing_Android_SDK_1.0.0.86.zip` 包含两个开发指南、AAR 和含 `OtaActivity.kt` 的嵌套示例。按 ZIP 中央目录逐层检查 SDKSample 和 AAR，未发现 R21 固件文件。其中 AAR 的摘要与项目已集成的 1.0.0.86 一致。
- `QRing_iOS_SDK_V1.0.0_20261102.zip` 内仅发现三个固件二进制文件：`HM01_1.00.08_261028.bin`、`R02A_2.06.06_240302.bin`、`R02A_2.06.11_240327.bin`。文件可读标识分别是 HM01 或 R02A，随包文档和示例没有给出这三个文件与 R21 的适配关系。
- 同时核对了本机找到的同名 R21 产品资料 ZIP，里面为规格、包装及美术资料。R21 实物联测还需要原厂发布的 R21 二进制文件、适用的 R8／R21 硬件修订和源／目标版本，以及中断后的恢复步骤。

## 验证

- Dart 格式和 `flutter analyze --no-pub` 通过。首轮静态分析指出新字段可用空值感知语法，修正后通过。
- 定向 Flutter 用例 18 项通过，包括签名有效但包型错误、缺少包型、同包不同设备，以及固件页现有入口。UTC 和 Asia/Shanghai 分别通过 2,498 项 Flutter 回归。
- 使用 macOS Foundation 编译执行 `test/native/qring_name_policy_test.m`，64 项通过，覆盖原有连接规则和 OTA 精确型号分离。
- iOS Debug／Profile 及 Android Debug／QA Release 构建通过。两端读回测试包为 `cn.saydian.ring` 1.0.15（1324），iOS 真机 IPA 与两份 Android APK 验签通过。
- 本机测试证据位于 `build/say-ring-firmware-scope-20261125.CBBezt/`。三个示例固件未用于刷写。真实升级完成仍以同一枚设备重启后读回目标版本为准。
