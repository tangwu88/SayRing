# R8 恢复同步回执时序修复 — 2026-11-09

## 范围与基线

- 用户要求处理已连接/电量正常但恢复同步提示“设备状态暂未确认”的问题；保留账号、绑定、历史及首次初始化门禁，不重复重置/清空戒指。
- 修改前工作区干净，HEAD 90170f9；检查status/remotes，fetch origin成功。独立分支codex/r8-sync-receipt-recovery-20261109承接当前1273来源；未混入另一个1275跨平台分支的未验收改动，也未推进main。
- 当前只证明一处会产生该提示的消息时序缺陷，尚未用截图客户的R8复现，不把它写成该设备的唯一原因。遵守用户先前停止真机测试的要求，本轮未操作手机、配对或戒指。

## 原因与修改

- Android QRingBridge.getCapabilities调用emitFactoryInitialization后返回能力结果；emit用main.post异步发送EventChannel，与MethodChannel结果有独立的交付顺序。原AppController立即比较receiptRevision，合法回执晚于能力结果到达时会误判缺失。
- 新增回执等待，仅在之前已有原生初始化待确认且能力读取成功时使用，最多2秒；只由既有当前账号、设备、会话校验通过的ringInitialization事件唤醒。回执到达后继续等待原有持久化完成，再走原有门禁。
- 断连、退出、账号切换和dispose经invalidateDeviceSync立即释放等待；旧操作finally不会清除新操作的等待。能力读取失败、回执始终缺失、未知清空结果仍保持保护；没有发出任何新的重置/清空指令。
- 改动仅lib/services/app_controller.dart、合成数据测试和实施记录；未改SDK、原生能力位、后台或数据库。

## 验证记录

- 首先添加“回执比能力返回晚20ms”的真实异步回归：原代码Expected true/Actual false复现失败；失败路径旧测试Timer在tearDown后触发已关闭流，补充关闭检查避免干扰根因。
- 修复后初始化、回执恢复与绑定上报3个测试文件共83项通过，包含缺失回执不放行、保存失败保留保护、退出取消等待并拒绝旧账号回执；无真实健康数据或凭证进入测试。
- 完整分析、UTC/Shanghai全量、Android Debug/Release及发布包验证结果待下方追加。Windows无法运行iOS Debug/Profile；遵照停止真机测试要求未重新安装/测量，不能用主机测试替代设备验收。

## 最终检查与交付

- `flutter analyze --no-pub`通过；UTC与Asia/Shanghai完整Flutter测试各2117项通过。Android Debug构建通过（241秒）；原生JUnit117项通过，依赖报告已生成；Android Release构建通过。
- 首次verify因本轮漏跑native阶段、缺少native.log依赖报告而失败，未把签名/Manifest局部成功当全部通过。保留verify-missing-report.log，补跑原生测试与依赖报告后重新verify，签名、产品配置、推送配置、ABI、zipalign及既有ELF门禁全部通过。
- 正常正式签名包1.0.11（1276），未开启debuggable，沿用原证书SHA-256 81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de。APK SHA-256 358C3BE41EA6E86327B0209FA2650EBCF2557FB2511C9FB41054FDB2CDD84548。签名临时key.properties已清除；APK、凭证、完整测试输出不提交Git。
- 本轮未运行iOS Debug/Profile（Windows不可执行）、未进行客户R8真机验收、未安装手机、未发布后台或应用市场。对真实完全缺失回执的设备仍保留初始化保护，不能声称截图设备的全部潜在原因已经排除。