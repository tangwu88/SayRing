# Say Ring 固件升级：原厂 SDK 续核

## 范围

- 基线 ec54546，当前分支 codex/macos-update-20260930；fetch / ff-only 确认已与 origin 当前分支同步。仅核对 Say Ring 固件接入，不改 App Store 审核、账号、绑定、健康数据或其他 App。
- 本轮只新增实施记录，不修改运行时代码、SDK、接口或能力开关。1053 是既有验证包，本轮没有制作新包，也不把此前构建结果当作本轮重新构建。
- 原厂依赖只读。Android AAR 的 classes.jar 提取到忽略目录，用 Java 17 javap 核对公开签名和字节码；iOS 对照导出头文件与 framework 二进制中的选择子。

## 已确认的接口

| SDK / 平台 | 原厂接口 | 已确认边界 |
| --- | --- | --- |
| QRing / iOS | QCSDKCmdCreator.syncOtaBinData:start:percentage:success:failed: | 头文件有正式 bin 发送、开始、进度、成功和失败回调；framework 内有同名选择子。不是只有底层 DFU 枚举，但 App 尚未接入。 |
| QRing / Android | DfuHandle.switchToOta、checkFile、start、check、endAndRelease | AAR 公开方法可见；并不能据此确定某一枚戒指的升级流程、文件兼容性和复位恢复方式。 |
| CoolWear / iOS | CE_RequestOTAStatusCmd；CE_SendOtaDataCmd.initWithData:otaStatusInfo:deviceInfo:complteProgress: | 头文件及二进制选择子一致。发送依赖 OTA 状态和设备信息；原厂定义包含长度、CRC、介质和条目错误，不能只靠进度 100% 认定升级成功。 |
| CoolWear / Android | OtaK6Control.startOta、startOtaFromFile；DealOtaFile；K6_OTAStateInfo | 公开接口和参数传递已核对：入口参数顺序为目标版本、当前版本、URL 或文件路径。未调用、未下载、未写入设备。 |

- QRing iOS 接口位于 Vendor/QCBandSDK.framework/Headers/QCSDKCmdCreator.h 的 OTA 段；CoolWear 位于 Vendor/BluetoothLibrary.framework/Headers/CE_SendOtaDataCmd.h。不改这些原厂文件。
- CoolWear Android getBinFromServer 接收调用方提供的 URL，不是“查找最新固件”服务。所核对方法按 Content-Length 分配缓冲、仅设置连接超时；没有业务型号适配、可信发布目录或同源下载校验。后续不得直接将任意 URL 交给该方法代替 App 的安全下载。
- 两套 SDK 的传输格式不通用。CoolWear 示例下载文件名是 .img，QRing iOS 接口接受 bin；扩展名、蓝牙名或一个版本字符串均不能证明硬件兼容。

## 资源与阻断

- 用户此前提供的 /Users/saydian/Downloads/Android&amp;amp;iOS_SDK20260910.zip 当前路径不存在。本轮在 Downloads、Documents 和项目可读文件清单中未找到该原包或已验证的戒指固件；保留的集成 SDK 仍可读取。这是本次检索范围内的结果，不声称原包在整台电脑永久丢失。
- 服务端本地 apps/api/src 的 controller 与 update 文件未找到戒指固件发布、适配或下载接口；devices 服务的 firmware 是连接记录字段，support 的 App 更新也不是戒指固件发布。此结论仅代表所检本地源码，不等同线上所有服务的完整审计。
- 启用刷写仍需：原厂认可的固件及完整性信息、目标硬件/产品/协议与允许升级版本、可信发布来源、升级失败恢复说明。之后再按当前账号和精确设备锁定、蓝牙命令互斥、断连与迟到回调、升级后新握手和真实版本回读实现并验收。
- 没有上述资源前保持 supportsOta=false，页面明确暂未开放；不声称“已是最新”，不开放任意文件选择，不调用进入 bootloader、发送固件或清空数据命令。

## 现场与验证

- devicectl 本次仍识别连接的 iPhone XR；Apple Developer 设备页刷新后仍为 Processing，明确提示可能在 24–72 小时后可用于开发及 Ad Hoc 分发。没有再次尝试不包含该手机的旧描述文件，也没有安装无签名包。
- ADB 本次识别连接的安卓手机；本轮未强停、重装、换绑或切换手势模式。原登录和健康数据没有由本轮操作改动。
- 原厂头文件读取、framework 选择子检查、AAR javap 检查完成；均属本机接口检查，不是 OTA 实物验收。
- 首次服务端检索使用不存在的 src/updates 路径，随后以 rg --files 确认实际 update 文件并检查 controller；首次固件测试文件名猜错，随后在 ui_shell_test.dart 定位已有用例。另一次文件名检索范围过宽，遇系统隐私目录拒绝后停止自己发起的检索；不扩展权限，不读受保护内容。
- TZ=Asia/Shanghai flutter test --no-pub test/ui_shell_test.dart --plain-name firmware --reporter expanded：3/3 通过，覆盖入口、不虚报可升级、未知/断开/读取失败、刷新版本及窄屏大字。git diff --check 通过。运行时代码未变，全量测试与双端构建本轮不重复执行；1053 的已有证据及仍待验项保留在前份记录。

## 未验收

- 本轮没有固件查询、下载、传输、重启恢复或升级后版本回读的真实证据。固件完整功能仍受上述发布资源阻断，不能标记完成。
- iPhone XR 开发签名安装仍受 Apple Processing 阻断；不改变包名、不绕过签名、不撤回现有 App Store 审核。
