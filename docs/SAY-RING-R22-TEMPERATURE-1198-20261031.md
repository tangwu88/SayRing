# R22手动皮肤温度换算修复1198

- 用户报告皮肤温度一直失败，并确认R22已佩戴、贴合且静止；不解绑、不重置、不清记录，保留1196重连与快速同步优化。
- 修改前已检查状态/远端并fetch；当前隔离分支 `codex/r22-controls-1188-20261031`，HEAD与上游均 `d7f45ae381db1eb7d97cc28fde303d60d9c3bd16`、工作区干净。读取AGENTS、国际版交接、回顾、回归清单及最近日志。
- 实际SDK1.0.0.76字节码：`manualTemperature`→内部193回调→`createManualTemperatureResponse`，返回整数十分之一摄氏度。构造函数不做除法，公开文档与可选默认值365对应36.5℃相符；本App默认值开关仍为false，绝不启用任何示例默认值。
- 原桥把所有大于100的结果除100，真实十分位值因低于20℃被丢弃，最后等Flutter75秒看门狗提示失败。修正为明确除10，仅接受原有20～45℃范围；无效值不补零，不将未测得数据替换为历史/默认值。历史SDK返回的摄氏度float不作变换。
- SDK真实`supportNoSingleTemperature`表示禁止单次体温；手动能力同时尊重该禁止位，保留已确认的皮温历史与自动监测能力，不按名称虚构功能。厂商Sample在单次体温入口也检查该位，文件类单次历史同步不冒充当前手动测量。
- 涉及QRingBridge、QRingRecordMapper及原生回归测试；不改iOS原生、其他SDK、阈值、算法、上传或后台配置。
- 验证/构建/真机结果待逐项补记。私有采样目录 `E:\SayRing-R22-temperature-20261031`，不将真实健康数据或产物提交Git。

## 实际验证结果

- 原1196真机佩戴静止复测：重试后77.8秒出现长时间未检测有效结果的超时提示，未声称捕获了该轮原始数值。SDK单位错误是确定代码缺陷，但不能单凭此声称当前固件必然支持手动测温。
- `flutter analyze --no-pub`零问题（29.2秒）；完整Flutter回归UTC1685项（3分02秒）、Asia/Shanghai1685项（3分04秒）全部通过。Node相机/重连/历史/日志隐私18通过、3项Objective-C环境fixture跳过、0失败，未把跳过计为通过。
- 双ARM Debug编译184.1秒通过；`:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1 --offline -Ptarget-platform=android-arm,android-arm64`实际2分34秒成功。原生XML汇总81项、0失败/错误/跳过，新增覆盖十分位值、上下边界、无数据/错误倍率拒绝，以及真实SDK能力对象的禁止单次位/无传感器/无App测量能力。
- Release实际编译266.3秒成功。原正式证书、cn.saydian.ring、1.0.7(1198)、非Debug、生产JPush/Manifest、双ARM和ZIP16KB门禁通过；厂商原有2项32位ELF对齐限制及受控JPush单ABI例外未改变，未把它们写为完全通过。临时key.properties已移除。Windows不能运行iOS Debug/Profile；本轮未改iOS原生或扩大其能力。
- 交付 `E:\SayRing-market-artifacts-20261031\r22-temperature-1198\SayRing-1.0.7-1198-release.apk`，72,617,793字节；SHA256 `272949d501ad7ce3c2b11b72c60e647e828d1ab6164ab26512a958e851d2a47d`；证书SHA256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de` 不变。
- `adb install -r`保留数据覆盖，用户本人完成华为安装身份验证后ADB真实Success；包管理器确认1198，拉取已安装base.apk与正式产物哈希一致。未卸载、解绑、重置、开启手势或变更健康监测开关。
- 新包重新读取实际能力后，R22_C493保持已连接；皮温趋势可查看已保存记录，手动测温入口未开放。进入设备→健康监测，等实际SDK设置读取结束，皮肤温度自动检测返回已开启；只读核对，未写设置。此结论是自动设置/现有记录的验收，不能写成该R22当前手动测温成功，也不能把记录当新采样。
- 已询问用户原厂QRing是否有成功的手动皮温入口，暂未获得对比回执；不据此扩大当前设备手动能力，若后续提供相反实物结果需继续核对协议语义/固件。当前修复按SDK文档与本机能力门禁处理。
- 界面核对首轮因连接后首页大活动卡令入口滚出屏幕而未找到唯一“全部数据”，未盲点；滚动后按实际节点进入并核实。其后仅做读取和导航，没有反复开启不支持的测量。
- 临时USB常亮0→3已恢复0，读取蓝牙仍为1。真实截图/XML/SDK字节码证据仅保存在Git外私有目录，不提交用户健康值、账户或安装包。
