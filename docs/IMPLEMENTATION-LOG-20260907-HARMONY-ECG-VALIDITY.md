# 鸿蒙实时心电无效值与佩戴状态整改

## 现场问题与证据

- 主线程在 r6、W9S 上观察到：刚启动手动心电即显示 HRV 255 ms，收到约 2500 个采样点；手动结束未保存，蓝牙连接和电量保持。用户尚未确认接触电极，不能把这次流标记为有效生理测量。
- [Veepoo 官方 Android API 文档](https://github.com/HBandSDK/Android_Ble_SDK/wiki/VeepooSDK-Android-API-Document#ecg-function)的 `EcgDetectState` 明确：HRV 255 是无效值，不应显示；`wear=0` 表示导联佩戴通过，`wear=1` 失败，应结束测量。这是协议有效性，不是医学阈值。
- 对当前锁定官方 HAR（SHA-256 `60cdffa08076d7167e90736cd8ea433b62dbf562d295c5275acfc4bfcdd40bd2`）执行只读 `ark_disasm`：`EcgService._decodePerSecond` 直接把字节 6 映射为 `hrv`、字节 11 映射为 `wearStatus`，未过滤 255；`_decodeInstruction` 只提供采样配置及开关，不证明电极接触有效。
- 原生产 `VepWearableService.onEcg` 只过滤非正数，未读取 `wearStatus`，配置到达即提示“电极已连接”。新增生产服务回调反例在修改前复现 4 项失败，日志 `/tmp/saydian-harmony-ecg-sentinel-before.log`。

## 修改范围

- 当前测量会话增加独立佩戴确认标记，每次开始重置；只有明确 `wearStatus=0` 才展示实时指标，未知状态等待，不判定疾病。
- `wearStatus=1` 沿用现有单次、串行取消流程，丢弃未完成波形和读数，不主动断开蓝牙。取消中的迟到结果直接忽略；结束提示受测量对象、账号及连接代次保护。
- 心电实时与最终结果中的 HRV 255 不展示、不作为健康指标保存；其他真实字段不因 HRV 缺失被删掉。
- 未确认有效佩戴就收到结束结果时，不保存本次测量；配置/波形提示改为简短用户指引，不展示采样率、原始点数等开发细节。
- 保留现有设备设置命令排空、账号切换、取消超时和旧回调保护，不修改厂商 SDK 或历史原始记录。

## 验证

- 直接执行生产 ArkTS 服务，仅替换平台及 SDK 外部依赖：17/17 通过，其中新增 5 项覆盖 HRV 255、有效 HRV、佩戴失败单次取消、迟到结果、未知佩戴、再次测量重置、换号迟到取消。
- Harmony 全量 UTC 344/344，Asia/Shanghai 344/344；日志 `/tmp/saydian-harmony-ecg-r8-utc.log`、`/tmp/saydian-harmony-ecg-r8-shanghai.log`。
- `git diff --check` 通过；复用两项小辅助方法，无新增依赖或无用导入。
- Debug/Release 整合及真实佩戴完成/未佩戴取消复测，交主线程后执行；上述自动化不是新包真机验收。

### r8 整合构建（02:22–02:23，追加）

- r7 单位安全修复两包先行独立导出，随后才同步锁定的 r8 心电源；没有覆盖原暂存工程的本地签名配置。
- Debug 构建成功（16.428 秒），Release 构建成功（14.498 秒）；两包官方 `verify-app` 均成功，证书链与手机原 r2/r7 开发签名逐字一致。
- Debug：`/tmp/saydian-harmony-session.5ERCEO/Debug-r8-ecg-safety-development-signed.hap`，SHA-256 `6a371155a26b4059483975a2e67dbc2bee7d3efdffd06c80deab41a1ab1408a3`。
- Release：`/tmp/saydian-harmony-session.5ERCEO/Release-r8-ecg-safety-development-signed.hap`，SHA-256 `f7b0891e8d9d9ea26c57d3ffaf1a57ec4e270e58c4027e3cd6b7b8f09ee1fe3d`。
- 构建与验签日志位于 `/tmp/saydian-harmony-session.5ERCEO/`，文件名含 `r8-ecg-safety` 或 `verify-*-r8`；全量 344/344 双时区日志已回读确认。构建后 `git diff --check` 通过。
- 此为开发证书及 debug profile 的同签名测试包，不是正式商店签名。没有操作手机、没有执行真实佩戴测量、没有提交或推送；真机安装、未佩戴取消及有效佩戴完成由主线程验证。

## 跨端与历史边界

- Flutter 共用 `health_record_validation.dart` 对 ECG HRV 使用 1–250 的既有传输门禁；同步、事件入库和本地加载都调用它。Android ECG 缓存及最终指标已有 1–250 限制，实时进度虽传原值，但 Flutter 当前不显示其 HRV 字段；iOS 原生只做正数判断，最终记录仍由共用门禁拦截。
- 今日独立 HRV 历史尚不能按本轮结论批量修改。Harmony `DfHealthDataParser._parseB7` 为带 `hrvTestType` 的字节数组；现有日历史聚合接受 1–1000，Android/iOS 日 HRV 同样未特判 255。厂商公开条目只明确 ECG 实时字段，未明确该历史字段，须取得对应协议定义或原始回调证据。
- iOS 多导联诊断头文件的 HRV 范围 0–210 仅适用其对应模型，不移植为所有 W9S/日历史指标的上限。不执行整库删除或将数值判为疾病异常。
