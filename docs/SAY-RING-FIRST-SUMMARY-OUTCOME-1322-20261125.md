# 首次连接摘要误报修复1322

## 截图与可执行证据

- 用户反馈前端已连接，而新安装1321的后台首份摘要显示连接失败、尚未读取/上传；截图中功能读取和首次初始化已完成。原首次报告不改写、不删除，不为该旧账号补采。
- 当前华为JAD-AL00在18:41已完成1317→1.0.15（1321）的保留数据覆盖安装：ADB返回Success，系统包管理器读回versionCode=1321、versionName=1.0.15及更新时间。APK SHA256和原正式证书均重新核对通过。随后USB断开，未取得该次连接的可追溯原生日志，因此不将下面任一分支宣称为该账号唯一已确认原因。
- 在真实AppController的合成探针中复现两条路径：一是SDK连接及功能读取已成功，其他功能同时设置全局errorMessage，连接函数末尾据此把connect阶段改成failed并冻结报告，控制器本身仍ready；二是首次初始化ACK后的必需重连短暂失败，首份摘要立即冻结，随后同一流程自动恢复成功并读取数据，原摘要仍失败。
- 基线fa27ce3578167a7ea21644d00fdbd00fb0c50ecd，origin同分支一致，工作树干净，status/remote/fetch及交接/最近记录/回归清单/复盘已核对。原server和App其他工作区均未覆盖。探针及手机本地私有材料保存在Git外E:/SayRing-first-summary-777-20261125，不提交真实截图或手机日志。

## 修改与保护边界

- 连接失败只由本次连接调用实际进入的异常分支确定，不再把共享UI错误提示当作BLE连接结果。真实SDK错误仍报告失败，取消不伪造失败；不会清掉其他功能的错误来制造连接成功。
- 仅由控制器内部首次初始化恢复流程授予续接上下文，绑定当前账号、会话和精确设备。初始化必需的自动重连属于同一次首次窗口；其短暂失败保留在原草稿，待恢复与首次同步给出结果后冻结同一份摘要。
- 不重置原3分钟看门狗；到期仍如实记录未恢复的失败。外部显式重试、目标切换、账号变化、隐私撤回、已冻结/已拒绝/重启后的旧草稿均不借续接资格重新采集。没有放宽首绑授权或原生初始化校验，没有新增/重放重置、清空、SDK同步或测量指令。
- V1/V2/V3字段格式不变，续接标记只在客户端内部使用，不增加上报字段。后台无需重新发布；原不可变报告是历史采集结果，不等于设备此刻在线状态。旧报告即使升级也不会被改成成功。
- 仅修改AppController、SyncDiagnosticsService及相应回归测试；不改SDK、能力、健康值、云端上传、绑定、商城、权限或消费者页面。

## 验证与失败记录

- 初版初始化探针30秒超时：替身在没有已保存目标的初始化阶段也等待未完成恢复Future。修正替身无目标时返回null，两个基线探针均通过，准确复现上述现状；不把“探针通过”当成客户实体故障已复现或修复。
- 46项定向测试通过，新增覆盖无关错误与成功连接、真实失败后显式成功仍保留旧报告、取消、仅一次ACK初始化后的重连续接、外部新尝试冻结原失败、换目标隔离及原3分钟截止。原服务器资格、隐私、冻结重试和账号隔离测试保留。
- 第一轮候选已通过两时区各2507项、Debug/Release及发行门禁，但追加“初始化恢复之后的第二次自动失败”用例发现仍提前冻结；先保留失败日志following-automatic-retry-before.log，再让已确认的内部恢复失败标记持续至成功、显式新尝试或原3分钟截止。初轮候选未交付/安装，日志和候选散列保存在产物目录attempt-1，不以旧候选替代最终产物。
- 补齐上述边界后，targeted-final.log的46项全部通过，第二轮静态分析无问题，UTC/Asia-Shanghai全量各2507项通过；重新执行Debug、Release及实际APK门禁。所有Flutter阶段串行，未清理共享缓存。
- Dart格式化、静态分析通过。最终第二轮两时区全量Flutter各2507项、Android Debug/正式Release及包内容验证全部通过；没有以定向测试代替全量检查。
- 原生源码和依赖锁文件未变。本轮只生成当前releaseRuntimeClasspath报告供包内容门禁使用，不把依赖报告当作重新执行139项原生单测。Windows未执行iOS Debug/Profile，不宣称iOS实体SDK验收。
- 1322继续使用原正式证书与1.0.15版本名；签名、包号、构建号、非debuggable、双ABI和运行库在产物生成后核对。不先卸载、不解绑、不切换当前手机账号、不替客户触发新的首次初始化。

## 最终产物与命令

- 串行运行产物目录Invoke-Checks.ps1的analyze、utc、shanghai、debug、native、release、verify阶段。静态分析flutter analyze --no-pub无问题；全量flutter test --no-pub --concurrency=1 --reporter=expanded分别使用TZ=UTC和Asia/Shanghai，每轮2507项通过。
- Android Debug assembleDebug通过，最终耗时153.3秒；原生阶段仅运行:app:dependencies --configuration releaseRuntimeClasspath，成功。正式APK构建成功，最终Flutter阶段约130秒。验证使用apksigner verify --verbose --print-certs、aapt dump badging、zipalign -c -P 16 4、release_gate.py apk-manifest/apk-abis及Inspect-SayRingNative.ps1。
- 最终普通正式APK：E:/SayRing-first-summary-outcome-1322-20261125/SayRing-1.0.15-1322-release.apk，75944581字节；SHA256=d66f139592a2b861a5a46b2d441b7afc786bdfb213d8ebc9579825da97be72fd。cn.saydian.ring、1.0.15（1322）、非debuggable、ARMv7/ARM64及各自libapp.so/libflutter.so均实物核对。
- 正式证书SHA256=81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de。临时android/key.properties已清除，未提交签名材料和产物。最终两ABI的libapp.so散列均不同于已废弃的第一轮候选，避免把旧缓存APK当成最终修复。
- ZIP 16KB对齐验证通过；原有ARMv7 libDspConfig.so与libEcgAnaly.so仍为4KB ELF对齐，不宣称所有原生库或所有市场的16KB兼容验收已通过。
- 全部检查日志、失败探针及两轮候选证据均留在Git外专用目录。源码和日志只提交本轮显式范围；提交前再次fetch、比较HEAD/上游fa27ce3并运行git diff --check。

## 待验收

- 19:49最终产物生成后手机USB仍不在线，已请用户重连；1322未安装，最终安装与系统版本读回以实际结果补记。此前18:41实际安装并核对的是1321，不能用它作为1322安装回执。
- 不能用已经冻结的原账号报告验证修复后的首份结果。需要真正合资格的新账号，且实体首绑可能涉及戒指内历史初始化，未经另行明确授权不执行；本轮合成测试不代替该实机验收。
