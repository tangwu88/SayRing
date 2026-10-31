# 2026-10-31 XR / R8 近距离断连与恢复清理1198

用户明确确认R8始终在XR旁，没有连接其他手机，要求继续修复并保留数据。基线69905ca，fetch当前分支0/0；其他同事r22分支有更新但本轮未合入。继续原XR / SD_RING_R8，不替换目标、不解绑、不恢复出厂。

## P1故障与修复范围

1197复测后出现非主动断连，随后原目标恢复持续未完成。无线transport阶段多次出现，但未完成SDK注册/能力准备；手动正常重连等82.45秒亦未恢复。用户排除了距离及其它手机占用，不能再把这些当作已知根因。

确认了一条代码缺陷：SDK注册失败时先报告逻辑Disconnected，再回调didFailConnected。bridge在第一回调清除了recoveryConnecting，后面的失败回调不再进入failConnect；CoreBluetooth仍可能连接着。于是下一轮会复用失败的未关闭无线会话，不能确保一次干净的SDK注册。既有2秒冷却只限制频率，没有实际关闭该会话。

1198在清理前保存的handshakeInterrupted条件下，若该原目标无线尚未Disconnected，先调用保留绑定的disconnect并保持cancellingConnection屏障。只有实际CoreBluetooth关闭回调或原有严格状态校验的关闭核对完成后，才恢复原owner/UUID。真实已断开的普通掉线仍立即重新等待，不额外发送取消。

另一个关联问题：QCCentralManager状态setter会重复转发相同状态。失败清理又同步设置Disconnected时会重复清理/安排恢复；现在相同状态不再重复上报，避免重复SDK准备或恢复。没有调整全局失败回调顺序，没有用超时假装无线已关闭。

加入有界Debug诊断：无线真正关闭的CoreBluetooth错误代码、SDK注册失败分类、radioState及失败会话取消阶段。仅固定类别/数字，不记录账号、UUID、原始NSError内容或健康数据。Release不写诊断日志。首次非主动断开的具体底层原因仍需新诊断和实际复测，不能用恢复缺陷反推首个断开就是App造成。

## 真实方法回归

修改前先让夹具保持无线Connected而触发真实SDK注册失败，实际编译通过后跑红；旧代码没有请求实际取消。增强断开模拟后还揭示重复Disconnected上报导致重复安排，未把该失败删除。修复后恢复9场景通过，初轮完整原生组合28/28通过；后来补充owner撤销及SDK缓存缺失场景，最终保留组合30/30通过。

新增/增强用例覆盖：取消请求不等于无线关闭、冷却到期不能绕过取消、实际关闭后仅开始一次新恢复、旧SDK回调不能取消新尝试、原账号与绑定保留、已断开无线不再次取消、相同Connected/Disconnected不重复准备/恢复。分别移除新取消条件、状态去重或原失败冷却后，行为反例均再次失败；不是编译失败反例。

```text
DEVELOPER_DIR=<official Xcode27.1>/Contents/Developer node --test tool/qring_recovery_state.test.mjs tool/qring_capability_handshake.test.mjs tool/qring_camera_policy.test.mjs tool/test_qring_reconnect_integration.mjs tool/test_qring_camera_integration.mjs
flutter analyze --no-pub
TZ=UTC flutter test --no-pub --concurrency=4 --reporter=expanded
TZ=Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded
```

## 构建与数据保护

1198使用正常main、原开发团队W7SXQ4A226、cn.saydian.ring，构建前私有备份完整容器。原191条健康记录ID全部转为哈希私有保存，核验191个唯一ID，不将健康内容写入公开记录。Debug签名与XR描述文件、版本1198、arm64核验完成后，正常Flutter运行原位覆盖安装，不使用会卸载的默认drive，也不回退旧包。

实际安装、完整构建门禁、恢复/静置与功能复测及安装后数据核对在最终回执追加。完整日志和容器仅留在Git忽略的build/ios-recovery-1198-20261031。

## 1198实机未通过与1199连接参数对照

1198真实安装/附加成功，先经历一次CBErrorDomain/code6（本机CoreBluetooth头文件定义为CBErrorConnectionTimeout）后自动完成原R8能力握手，当前时点恢复过。但随后真实测试继续出现code6，多个连接在准备或同步期间再次掉线，五轮脚本因设备始终未稳定空闲而退出Not idle；不能把这轮或恢复过一次写成修复完成。该阶段没有捕获新recovery-cancel-failed-transport分支，实际SDK注册失败取消路径仍以真实生产方法夹具验证；无线超时与逻辑失败清理分开看待。

安装后191条原历史记录ID哈希逐项核对全部存在（缺失0），没有清空数据。静态分析、双时区各1702项及iOS Debug/Profile、Android Debug/显式QA Release均通过，但构建/宿主通过不覆盖本轮实机失败。

继续检查发现connectCurrentPeripheral把EnableTransportBridging始终设YES，这是从手表路径继承的配置。苹果官方文档说明该选项会在LE GATT连接时额外拉起经典蓝牙non-GATT profiles，并非BLE数据恢复开关：[Apple说明](https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionenabletransportbridgingkey)。本轮进行单项对照：1199只对ring显式关闭该请求，watch/band保持原经典桥接和ANCS配置。保留1198完整私有源码快照、构件及失败日志，没有覆盖失败证据。

新增真实connectCurrentPeripheral方法夹具，验证ring不请求经典桥接/ANCS、watch仍保留、准确目标/空目标不变；旧配置行为跑红，新配置及恢复/相机组合31/31通过。增加Debug标准服务提示（BLE HID/电量服务存在与服务数量），只做诊断，不据其开放任何功能。经典桥接与本次超时是否有因果关系仍待实际对照，不能在测试前宣布已定位首个断连根因。1199继续使用正常main保数据安装，不以UI强制显示或缓存功能冒充握手。

用户已确认在近处且未连接其它手机。为排除戒指无线状态卡住，另请求一次普通充电唤醒并取下，明确不是解绑或恢复出厂；尚未收到该操作完成回复时不计作已执行。

## 对照候选撤回与保留版本

1199仍在SDK准备阶段发生系统code6超时，未完成稳定连接；服务提示仅记录3个服务，没有确认BLE HID。不能以此确认桥接是超时根因，也不能在没有实物音乐手势回归的情况下保留可能影响原控制通道的改变。因此撤回经典桥接参数改动与该候选服务提示，完整源码/测试/构件/失败日志移留私有对照目录。原连接参数恢复，保留1198的失败会话清理、状态去重与无线错误诊断。

恢复前再次私有备份容器，运行源码822项指纹逐项确认与已验签1198完全一致，再使用该对应构件正常main原位恢复。这是实机候选未通过后的明确恢复，不是构建失败回退、旧包冒充新构建或卸载安装；1199未作为稳定修复交付。恢复操作使用独立1198-restored私有目录，不覆盖1198初轮证据。

最终保留源码的原生组合30/30通过（新增原账号撤销期间取消/关闭后不重连及无SDK缓存但有已确认App绑定的恢复场景），静态分析零问题，UTC/上海各1702项、iOS Debug/Profile及Android Debug/显式QA Release的1198构建均通过；这些不覆盖系统无线超时尚存的真机失败。

191条原健康记录ID在1198安装后逐项存在、缺失0。恢复后至Profile安装前的14张相机照片路径与SHA256逐项一致、缺失/变化0。用户普通充电唤醒回执仍等待，不能当作已执行；稳定性问题仍未解决完整，不送商店/下载发布、不将该轮判为全部通过。

## 正常Profile低开销对照

1198恢复Debug后，停止频繁Inspector/字段轮询，约101.7秒的低轮询窗口仍捕获一次code6，之后处于原目标等待恢复。它说明本轮减少读取没有立即消除故障，不能归因于用户离开或其它手机抢连。

随后在当前822项运行源码指纹全部与1198一致的条件下，再次备份完整容器，串行构建正常main的Profile 1.0.8（1198），沿用本机Xcode27.1、最低系统15的构建覆盖参数，仓库默认13未修改也未据此声称通过。新构件原位安装前核验cn.saydian.ring、W7SXQ4A226、开发签名、XR描述文件和无QA定义。没有默认drive、卸载、账号切换或戒指解绑/恢复出厂。Profile对照有独立构件/源码/容器/日志目录，不覆盖Debug失败证据。

Profile实际启动并取得VM，初次完成同一R8能力握手。约185秒的首轮低频观察37个采样点均连接、App均在前台，能力对象确认ready，同时保留相机/手势能力。只读191条原记录ID哈希逐项核对仍全在、缺失0。但是随后再次断连，五轮脚本在初始ready条件处退出，未执行五轮动作；不能将首轮短时成功记作整体通过。

另用Flutter自带idevicesyslog和其既有动态库，只过滤原XR的Runner进程中QRing transport连接行，保存到权限受限的Git忽略目录。364.7秒采集中实际记录6次transport连接、6次code6关闭；这个低开销Profile对照仍未通过，不能认定Debug运行开销就是根因。没有修改系统蓝牙、清配对或更换SDK。

### 自动化回执判定纠正

首轮Profile脚本在约60秒时请求普通重连，但未检查VM返回对象的type。后续有界广播扫描也没有得到结果；复核发现两个公开Dart方法在AOT的服务调用中返回NoSuchMethodError（@Error），没有真正触发原生动作。该回执只说明Profile自动调用方式不成立，不能解释成App页面功能缺失、已手动重连、未搜到R8或戒指信号差。首轮手动请求以及两轮扫描均改计为未执行，保留失败记录，私有RPC助手补充拒绝@Error。Profile静置超时由独立真实系统日志确认，不依赖这些未执行动作。此前进度回执中误将首次手动重连记为成功，已向用户明确更正。

Profile结束后原191条记录ID哈希缺失0、14张原相机照片路径及SHA256变化0；再次保存完整私有容器。用同一822项源码和已验签的1198 Debug正常main构件恢复可控调试，以独立final目录继续核验，不把Profile失败覆盖为成功，不重新选择其它目标。

## 最终Debug广播核对与待办

正常Debug恢复后仍为原R8自动等待恢复状态。第一次直接调用QRing Dart adapter扫描方法得到真实Future，但在自动恢复同时发生的诊断用法中最终是TimeoutException；脚本起初只识别_AsyncError类名，没有识别当前Dart的AsyncError，因而先计作未确认。随后读取真实Future并明确记录超时。它不是“扫描没有发现R8”的证据，也没有据此修改正常添加设备流程。

明确清理该扫描后，改为每轮扫描3秒并主动stopScan，实际取得列表回执，三轮均发现同一已绑定UUID的R8（不是按名称换选目标），RSSI依次-93、-90、-92 dBm。每轮都显式结束扫描，不取消原owner授权、不修改配对、不恢复出厂。用户已确认戒指就在XR旁，不能把此弱信号观测改写成用户离得太远；它是后续普通充电唤醒及位置/方向对照的线索，不能单独诊断戒指或手机硬件故障。

最后保持正常1198 Debug附加，逐条再次核验原191条健康记录ID哈希及14张照片路径/SHA256，完整容器仅私有保存。当前近距离系统无线超时与持续连接问题仍未完整解决；不能把两处已修复的代码缺陷或短时成功当作本轮全部通过。待用户完成已请求的普通充电唤醒并取下后，再对同一XR/R8复测；尚未收到回执时不计作已执行。不开启下载页/商店发布，不把这轮当作稳定主线基线。

提交前再次fetch当前Say Ring分支仍0/0；只读查看同事R22分支近期变化（恢复/同步和温度解码），不合并或覆盖。提交本轮已通过宿主/构建验证的恢复清理、状态去重、有界诊断、对应真实方法夹具及上述失败/待验证记录到当前分支；保持整体真机稳定性未通过的状态。
