# 2026-08-26 实施与测试记录

## 11:40 W9S 心电结果与波形质量回归

- Git 基线：修改前本地 `main` 与最后一次成功更新的 `origin/main` 均为 `72ba97ac26ee2236bbf8272702ecfb8c21331a87`。工作树的 3 个修改文件均属于本轮修复，没有覆盖用户改动；期间 GitHub 两次连接被重置，因工作树不干净没有执行 `pull`。
- 原生回调根因：W9S 的 `onEcgDetectResultChange` / `onEcgDetectDiagnosisChange` 偶尔会在 `isSuccess=false` 时仍带回可用的心率、HRV 和 QT。旧逻辑把整个回调丢弃，造成测量结果缺失或一直等待。现在保留合理的核心指标，但只在回调真正成功时写入设备风险和诊断字段。
- SDK 对照：官方 HBand Android Demo 实时心电使用 `onEcgADCChange` 和 `EcgUtil.convertToMvWithValue`；App 因此继续以实时 ADC 为主，`filterSignals` 只作无 ADC 时的兼容回退，不把 SDK 滤波数据冒充原始实时波形。对照文件：`HBandSDK/Android_Ble_SDK` 的 `EcgDetectActivity.java`。
- 波形问题：两条 W9S 真实记录包含转换器超量程、边沿常量填充、上下限削顶和内部长时间无信号。旧界面把这些数据画成三角形轨迹，容易被误认为真实心电图。
- 展示修复：心电展示层现在会去除边缘常量填充，拒绝超过 ±2.5 mV 的密集超量程值、转换器连续削顶和有效覆盖率低于 90% 的长时间掉线记录。不合格波形显示明确空状态，不改写原始样本，已有心率、HRV 和 QT 继续显示。
- 真机记录 1：`2026-08-26 09:53:35`，心率 86 bpm、HRV 26 ms、QT 缺失。原波形在稳定区间中有连续 10 秒完全无信号，占 41 秒可检区间的 24%。最终界面不再显示失真三角波，改为“本次未返回有效心电波形”，心率与 HRV 保留。
- 真机记录 2：`2026-08-26 10:15:23`，原生不完整回调中的心率 86 bpm、QT 345 ms、HRV 95 ms 已完整保留；由于波形包含轨道饱和和长时间无信号，同样显示可解释空状态，没有绘制假波形。
- 自动化：`flutter test --no-pub test/ecg_waveform_test.dart test/device_sdk_source_test.dart test/ui_shell_test.dart` 通过，47 项成功、0 失败；心电专项 17 项，包含正常重复心搏、超量程、削顶、10/41 秒掉线和内部长时间无信号。`dart analyze lib test` 为 `No issues found`，`git diff --check` 无错误，最终源码无临时心电诊断日志。
- Windows 构建：中文工程路径下 AGP/JNI 会误判 `libdartjni.so` 不存在；使用临时 ASCII `S:` 映射构建成功。期间发现并删除一份指向旧 `S:` 盘的可再生 `flutter_build.d`，没有删除源码或用户数据。
- APK：`build/app/outputs/flutter-apk/app-debug.apk`，包名 `cc.saidian.app`，版本 `0.1.19 (23)`，大小 218,064,035 字节，SHA-256 `65EBD9FB6877FF30523C252BB8D1502B4850BAFE8B6D36276767DC7636E7AB38`。已在华为 JAD-AL00（序列号 `L2E0222510006851`）同签名覆盖安装成功，设备记录的 `lastUpdateTime` 为 `2026-08-26 11:34:42`。
- 稳定性：最终安装后冷启动、健康首页、全部数据、心电列表和两条心电详情页无 `FATAL EXCEPTION`、Flutter 未处理异常或诊断日志残留。
- 验收边界：本轮证明了核心指标不再被不完整回调丢弃，且失真波形不再被展示。当前佩戴/电极接触没有产生一条符合质量条件的新波形，因此“真实有效 W9S 波形与手表轨迹一致”仍需下一次良好电极接触时现场验证，不使用伪造样本补齐结论。
