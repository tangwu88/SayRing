# Android CoolWear连接校时延后补做（1314，2026-11-19）

## 原因、范围和基线

- 用户要求修复R7P测量超时排查中复现的App校时缺陷，重新打正式APK。HR05也是用户确认的R7P设备名称，不将名称或手机品牌归因为故障根因。客户实际超时仍缺测量回包证据，不声称此代码缺陷解释所有客户。
- 问题/P1：真实时间格式在历史同步期间返回时，原synchronizeConnectionClock先消耗connectionEpoch、随后因繁忙返回；同步结束再调用也不发送。预期保留真实格式，空闲后只补做一次，断连/换目标/撤销账号即取消。此前独立提取原方法的本机对照：空闲发送1次，忙后空闲发送0次。
- App修改前工作区干净，fetch origin --prune成功；HEAD和原上游均d5940052b05f552c320466b6b634707f662fcd70，差异0/0。新分支codex/coolwear-deferred-clock-1314-20261119；新分支尚无upstream导致首次ff命令失败，改用显式origin/codex/registration-sdk-install-1313-20261119核对，Already up to date。未拉取或改动服务端脏工作区。
- 已阅读AGENTS、INTERNATIONAL-HANDOFF、CHANGE-TEST-LOG及1313记录、BUG-RETROSPECTIVE和REGRESSION-CHECKLIST。修改Android CoolWear桥接及有界校时调度，补原生与提取生产方法回归；不更换SDK、服务器、初始化、健康值/时间映射、首次诊断一次规则或iOS/其他通道。
- 实时测量的时间/有效性校验保留；不补造读数、不把历史改成今天，不以移除门禁掩盖超时。校时提交不等于戒指ACK，更不等于实际测量成功。

## 验证计划

- 执行提取生产方法的同步/测量繁忙、握手前时间回包、空闲补做、重复回包、无格式/非法格式、异常不重试、过期、断连/账号/目标/代次切换等测试；与真实SDK只读请求编码及既有协议测试同跑。
- 原生单测、静态分析、Flutter双时区全量、Debug/普通main正式Release，1.0.14（1314）；验签/包身份/运行库完整性/ABI/SDK副本/ZIP对齐/差异检查。不安装手机或发布下载页，当前用户只要求打包；Windows不可执行的iOS构建和客户实物测量明确留待验，不以本机模拟代替。
- APK与原始日志放Git外E:/SayRing-coolwear-clock-1314-20261119；签名参数不入Git。每步真实结果和失败修正随后追加。

## 实现与早期回归

- 新增连接级有界校时请求：只存本轮真实格式、账号授权代次、精确目标与连接代次；主线程空闲时执行一次独立时间命令。同步、手测、运动、初始化、配对/手势、提醒设置或提醒振动进行中均延期，最长5分钟；结束/撤销/换目标清理任务。握手前到达的时间格式在同目标屏障内保留，等待设备信息完成。即时手测前先补已就绪的校时，避免同步刚结束的调度竞态。
- void供应商发送API抛错时不自动重发，不把发送尝试或SDK接收当作设备ACK。SDK与测量/历史mapper均不改；没有移除10分钟实时有效性校验。
- 新的提取生产方法夹具首轮因Windows javac默认GBK无法编译原方法中的中文注释失败；改为显式UTF-8。第二轮28个执行场景通过，但Node包装的读取器只匹配private，误报public dispose缺失；扩展为读取真实public/private方法，没有跳过销毁检查。原失败由本轮工具输出保留，随后全套日志落盘。
- 协议整套首次运行因旧HRV/恢复目标夹具未提供新引入的时钟依赖而编译失败；保留node-initial-fixture-dependencies-failed.log。仅在原本无时钟任务的HRV夹具补空边界，在恢复夹具补取消计数并断言；真实时钟控制流由新增28场景直接提取生产方法执行，不删除旧HRV、清理ACK或目标隔离断言。
- 新时钟执行测试加入Android CI原有协议门禁。额外运行整个发布工具Python测试时，22项Xcode脚本用例在Windows因缺/bin/sh启动失败（非App失败），记录release-gate-tests.log；不修改/跳过其断言来制造通过，当前平台另执行APK/推送门禁子集，macOS结果由CI单独核验。

## 已完成本机回归

- `node --test`执行原有CoolWear只读/协议/清理ACK/手势/HRV/恢复/相机/历史/日志隐私及新时钟门禁：49项中47通过、0失败、2项macOS专用跳过；新时钟单项内部实际运行28场景。旧夹具依赖失败已修正后完整重跑，非沿用旧版结果。
- `:app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --offline`：135项、0失败/错误，原生与Flutter Debug源码编译通过；依赖日志用于最终APK ABI检查。供应商弃用/flatDir提示不是测试失败。
- `flutter analyze --no-pub`无问题；`dart format --output=none --set-exit-if-changed lib test`检查361文件、0修改。
- `flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`在UTC和Asia/Shanghai均2452项全部通过。
- `python -m unittest test_release_gate.ReleaseGateTest test_release_gate.PushConfigTest`：当前平台24项通过（APK/推送/manifest等），与上面因平台缺/bin/sh未执行的22项Xcode脚本用例分开记录。
- Debug1314、普通main原证书Release1314及最终制品核验继续执行；未提前标为成功。

## 正式包核验

- 实际Debug1314与普通main生产Release1314均构建成功；原正式证书SHA-256为81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de。包名cn.saydian.ring，1.0.14（1314），non-debuggable；临时android/key.properties已删除。
- 产物E:/SayRing-coolwear-clock-1314-20261119/SayRing-1.0.14-1314-release.apk，74,634,353字节，SHA-256为24d14afe4d171c1544828f86db669c4da7806c54916c315a87bcb9e78878c8f6。普通main、生产manifest/JPush、ZIP16KB对齐、双ARM ABI及非空libapp.so/libflutter.so门禁全部通过；QRing86构建副本30项一致。
- 与1313比较classes.dex/classes2.dex及manifest均变化；从本次R8映射定位两个新增时钟类，并在实际APK DEX的class_def中确认存在。两种ABI的Flutter主程序库与1313相同符合本次仅改Java桥接的范围，未误用旧原生程序。检查脚本和结果在Git外native-package-proof.json。
- 原JPush ARM64-only受控例外及armeabi-v7a两项libDspConfig.so/libEcgAnaly.so的4KB ELF LOAD限制仍在，不宣称所有16KB ELF/市场审核通过。
- Release后Debug复建通过（112.9秒），原有不可变SDK构建/缓存门禁保留。提交前再次fetch成功，原交付上游仍为d5940052b05f552c320466b6b634707f662fcd70，没有覆盖其他远端改动。Git推送和云端CI状态随后追加；本轮未安装手机、变更服务器或线上下载页，客户vivo/R7P实物测量仍待验证。

## Git与云端检查

- 源码、CI门禁和本轮记录已提交80ede1bfad90b7df1aa5ac6942e72ef791beae84，推送origin/codex/coolwear-deferred-clock-1314-20261119；ls-remote核对同一SHA，工作区干净。未强推或覆盖其他分支。
- 匿名GitHub API返回403，当前Git凭据接口未提供可用HTTP认证；没有输出或另存凭据。改读GitHub公开Actions页面，确认对应源码的mobile-ci运行44526027176（https://github.com/tangwu88/SayRing/actions/runs/44526027176）已触发，最后检查为In progress，Harmony矩阵2项已完成；不把云端进行中写成全部通过。
- 此次交付以本机双时区完整回归、实际Debug/生产Release及制品检查为证；Windows无法完成本机iOS编译，客户634或其他R7P手机的物理测量结果没有被本机夹具替代。公开下载配置仍是原版本，本轮仅交付本地1314正式APK。
