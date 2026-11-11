# 安卓 U19 血压结果读取修复 1298

2026-11-11，Asia/Shanghai。用户反馈另一台安卓手机的最新版 Say Ring 发起 U19 血压后没有返回结果。没有取得该手机的完整构建号、实时回包或现场结果；本记录只确认代码复现，不把 Mac 旁旧华为当作问题手机。

## 基线与范围

- 工作树开始干净；核对 `tangwu88/SayRing` 并 fetch。以最新安卓合并 `e8e29c1` 为基线，新建 `codex/u19-android-bp-result-20261111`。保留 Android 首绑 ACK、QRing 无 ACK 恢复、固定导入边界和原戒指路由。
- 当前 Mac 旁 PPA-LX3 实读为 1.0.11（1247），Say Ring 未运行且不可调试；只读核对版本，没有安装、启动、卸载、登录、改设置或新测量。用户确认问题发生在另一台安卓手机，并称其为最新版，但未给出具体数字。
- 只改 U19 传输/血压收集和等待，以及对应测试。既有账号、数据库、云接口、手表监测参数、戒指通道及 UI 保持。苹果 1296 TestFlight、正式审核、下载页均不操作。

## 可复现缺陷与修改

1. **测量中提前读历史使后续通道失效。** 原实现每 6 秒发一次 0x14。若固件测量期间不应答，该命令超时后在当前连接中隔离，随后 0x33 到达也无法取结果。根据原厂 EB1 1.0.12 的 0x73(2)/0x33 流程，改为收到数据变更或测完通知后再开始有界补读。没有通知仍在总时限结束，不自动再次充气。
2. **通用读取 ACK 被当作畸形血压。** 原厂通用应答章节允许“命令 + 全零载荷”表示执行确认，但旧收集器直接按血压解析并隔离命令，后续合法样本被丢掉。仅在 0x14 数据尚未开始时跳过该精确 ACK 形状，仍等待真实记录或 FFFFFFFF 结束包。ACK 不生成记录、不证明历史为空、不计为测量成功；其他畸形数据仍拒绝。
3. **读失败后继续空等。** 已经超时或损坏的读取无法在本会话安全重试，原代码仍等待后续计时。现在立即结束所属测量的界面等待，沿用现有失败提示；未收到物理完成仍保留防重复充气屏障。迟到事件不能复活旧测量。
4. **安卓回包快照补强。** 蓝牙通知和版本读取先复制字节，再投递主线程，保留实际 GATT 实例校验。此项是对可变缓冲区的保护，未取得问题手机的复用缓冲证据，不能单独断言是现场根因。[Android 官方回调说明](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback#onCharacteristicChanged(android.bluetooth.BluetoothGatt,android.bluetooth.BluetoothGattCharacteristic,byte[]))。

原厂文档只读核对：0x32 启动 ACK、0x33 完成通知均没有血压数值；真正结果来自 0x14，保留收缩压、舒张压、脉搏和设备时间。仍要求新指纹、唯一候选及当前测量时窗。旧历史、空历史、时间不符和多个新候选不能伪装成本次新结果。供应商原始文件不提交公共仓库。

## 已执行验证

- 三个新增失败用例先在未修改运行源码上运行，7 通过、3 失败，原日志 `build/u19-android-bp-20261111/before-fix-tests.log` 保留。分别复现提前读取、ACK 后丢样本、已失败却继续等待。
- 修复后三文件 42 项通过；补充 Android 实际顶层事件结构、拼包/分包、旧目标/旧代次隔离、ACK-only、坏记录、无完成防重复充气后，两协议文件 44 项通过。测试使用合成数据，没有发送真实充气指令。
- 已有测试继续覆盖设置只读、去重、错时钟、多候选、150 秒结束及 24 秒完成后等待。后续完整静态、双时区回归和构建结果在本记录追加；尚未执行的不计成功。

## 完整回归与 Android 构建

| 检查 | 实际结果 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | 349 文件，0 改动 |
| `flutter analyze --no-pub` | 零问题 |
| `TZ=UTC flutter test --no-pub` | 2331 项通过 |
| `TZ=Asia/Shanghai flutter test --no-pub` | 2331 项通过 |
| `python3 tool/test_urion_android_notifications.py` | 真实 Kotlin 通知方法的 JVM 执行通过；移除快照复制后预期失败，证明覆盖可变回包路径 |
| `node --test tool/test_native_log_privacy.mjs tool/test_urion_native_lifecycle.mjs` | 13 项通过 |
| Android CI 列出的戒指协议/断连/相机/HRV/只读设置夹具（单并发） | 35 项通过 |
| `python3 -m unittest discover -s scripts/release -p 'test_*.py'` | 35 项通过；其中发布/回退输出来自本机夹具，没有对生产执行发布 |
| `./gradlew --offline :app:testDebugUnitTest --no-daemon --max-workers=2` | 134 项，0 失败/错误/跳过 |
| 正常 `lib/main.dart` Android Debug / Release | 两者成功，版本覆盖参数为 `1.0.13` / `1298`，双 ARM |
| QRing SDK 不可变副本 | 30 项原内容一致，仅移除构建映射输出规则 |

- 新增 Kotlin 可执行回归并接入 Android CI；工作流通过 Ruby YAML 解析和差异空白检查。本机未安装 PyYAML、Go/actionlint，未声称 actionlint 已执行；远端 CI 状态需独立核对。
- 原生源码及 Dart 源码构建前后摘要一致。临时 `android/key.properties` 在构建结束清理，私密配置和原厂文档未纳入 Git。
- 对 Debug APK 做“原发行签名”断言时失败：检查 Gradle 后确认它沿用已有本地 Debug 签名，包本身验签正常，但不作保留数据覆盖交付。这个失败保留，未将 Debug 签名改为正式签名以迎合断言。
- **实际交付为 Release APK**，`cn.saydian.ring`／1.0.13（1298），不可调试。原证书 SHA-256 为 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`，发布清单、JPush、双 ABI 和 ZIP 16KB 对齐检查通过。继承的两个 armeabi-v7a 供应商库 `libDspConfig.so`、`libEcgAnaly.so` 仍为 4KB ELF 加载对齐，不把 ZIP 对齐或签名核验称为应用市场验收。
- APK 大小 74,437,409 字节，SHA-256：`19ef93754cbd1fb4653f24f333904f29f5763a44085cd8501952a9c7f2323272`。本机独立交付副本已再次核验同一 SHA-256；没有上传到下载页或任何应用市场。
- 完整日志和证明保留在忽略目录 `build/u19-android-bp-20261111`。APK 在本机 `Library/Application Support/SayRing/release-artifacts/android-1298-20261111`；二进制、签名材料、实际手机标识均不提交公共仓库。

## 共享代码的 iOS 构建核对

- 串行生成正常 `lib/main.dart` 的 Debug 和 Profile，均为 `cn.saydian.ring`／1.0.13（1298）、团队 W7SXQ4A226，Xcode 实际 `BUILD SUCCEEDED`，深度签名验证通过。Debug 包含调试内核，Profile 无调试内核或调试回包标记。
- 沿用本机已验证的 DerivedData 和 iOS 15 部署目标覆盖参数；没有改产品工程最低版本。Flutter 的可选扩展属性清理分别超过 30 秒时，仅终止本次子进程，保留文件属性；实际配置、编译及验签随后完成。原本的两份 Flutter iOS 本机配置逐字恢复。
- 构建前后运行源码摘要一致。未安装到 iPhone，未发起物理测量，未归档上传或修改 1296 的 TestFlight／正式审核状态；这些构建只是共享代码编译核对。

## 源码交付范围

- 本轮独立分支 `codex/u19-android-bp-result-20261111`，最终 fetch 后 Android 基线仍为 `e8e29c1`。仅提交 U19 源码、针对性测试、CI 检查和中文记录；不移动主线。
- 本机 HTTPS 推送缺少 GitHub 凭据而失败，原本地提交保留。已连接的 GitHub 接口可以创建该独立分支，改经此通道交付；以最终远端文件树和本地树完全相同为准，不将“已创建分支”当作修复已上传。
- 页面等待终态、传输和数据解析已在自动回归中验证；问题手机的界面、真正新测量值及云端读回仍待下面的现场验收，不能据此宣称实物故障已完全关闭。

## 现场验收待办

- 问题手机安装修复包后，确认具体构建号；用同一枚 U19、同账号和原设置，只发起一次本人准备好的血压测量。
- 分别核对启动、0x73/0x33 通知、新 0x14 结果、页面结束、本机保存及云端逐字段读回。若仍空，保留该次命令类别/终态的诊断，区分固件未返回、时间不符和 App 接收失败。
- 旧 XR U19S 的“手表有结果但返回空历史”仍未通过，本轮代码夹具不得覆盖该失败记录。不能因修好等待就宣称手表真实血压已回传。
