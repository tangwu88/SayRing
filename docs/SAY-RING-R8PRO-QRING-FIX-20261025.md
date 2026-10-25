# 2026-10-25 R8 Pro 改走 QRing

## 授权、基线与问题

用户明确纠正：R8 Pro一样要走QRing，立即修复。此要求取代10月22日的R8 Pro CoolWear例外，以及前一轮只读核查结论中的该例外；历史记录保留，不改写成此前已按新要求实现。

基线7d3a7c5cb6d3450cdc6bd0594dfeaed678e2ea09，当前开发分支codex/device-search-help-1141-20261024；开始工作树干净，origin为tangwu88/SayRing，fetch及pull --ff-only成功、Already up to date。已读AGENTS、最新核查/提交记录、国际交接、回归清单与复盘。未发现并发iOS构建。

P1：名称R8 Pro/r8PRO/R8-Pro/SD-RING-r8_pro-123被专门的正则例外从QRing标记中剔除，因而Flutter和双平台原生均选择CoolWear。按本次新要求应选择QRing，且不能被另一桥再次接纳。

## 修改与保护

- Flutter分类器、iOS QRingNamePolicy/CoolWearPolicy、Android共用RingNamePolicy同步删除R8 Pro例外，统一由不区分大小写的R8包含规则识别。
- 原生CoolWear不再返回R8Pro型号，扫码/连接/恢复沿用现有真实名称检查；不按名字假造SDK能力。
- 保留R1/R2/R7C优先、含跨通道冲突标记时拒绝错误选择、R7 Pro/R7 Ultra/HR05等其余通道及owner精确目标保护。不把旧CoolWear保存ID直接转成QRing绑定，仍需通过正确通道真实选择和握手。
- 更新Flutter分类、双桥扫描去重/连接分派和Android/iOS名称测试；覆盖R8 Pro、r8PRO、R8-Pro、R8_Pro、SD-RING-r8_pro-123、R8Pro-R21/R8Pro-R8的QRing路径，R8Pro-HR05/K80/R7冲突继续拒绝。
- AGENTS追加本次明确纠正，防止后续重新引入已废弃例外；不改既有历史审核回执。

## 验证记录

修改后的iOS实际头文件主机测试：QRing名称策略50例通过；CoolWear原生策略PASS，包括R8 Pro不进入该SDK与原能力/历史门禁。此为合成输入，不是R8 Pro实物握手或同步验收。

格式化两个Dart修改文件后diff --check通过。全量检查、跨端构建及Git同步结果随后追加；未执行前不记为通过。本轮不操作线上后台、数据清空、设备解绑、下载页、TestFlight或苹果审核，已提交1141不会因源码变化自动更新。

## 已完成的全量主机检查

私有build/r8pro-qring-fix-20261025/run-host.py沿用上一轮已验证的同等命令，输出独立目录，不覆盖历史日志：离线锁定pub get通过0.7秒；格式门禁通过1.0秒；analyze零问题13.2秒；UTC/Asia-Shanghai各1470项全量通过33.7/34.7秒。Node工具139项中138通过、1项Windows限定跳过；Harmony两时区各518通过；Python发布35项通过。Android Debug构建25.1秒成功。未扩大SDK/生理数据或服务端范围。

设备清单仅确认XR在线，未取得R8 Pro实物和本次握手；未安装覆盖原XR应用或用原R7 Pro冒充R8 Pro验收。旧通道绑定不自动迁移，用户实际升级后需在添加设备中通过QRing重新选择正确戒指；本轮不执行解绑、重置或清数据。

Android双ARM内部QA Release构建68.5秒成功，未当作正式下载包发布；`:app:testDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline`7.1秒成功，实际读取14份JUnit XML共60项，0失败/错误/跳过，包含更新后的双桥R8 Pro策略。APK/签名私有配置不入Git。

已串行启动普通lib/main.dart的iOS Debug/Profile配置及开发签名构建，版本参数沿用1141仅作本轮QA编译、不作为新发行包、不覆盖已提交二进制。无测试入口安装或真机覆盖；结果待追加。

## 最终iOS构建与交付边界

普通main的Debug配置26.9秒/开发签名构建13.6秒，Profile配置25.4秒/开发签名构建27.0秒，全部exit 0。Profile已strict/deep验签、cn.saydian.ring、团队W7SXQ4A226、开发签名核验通过；App.framework SHA256 851ecba0237a6d711157bf6e3254ef723eedc4be7f3f7765cd589475d929c246。编译产物沿用1.0.6(1141)只用于QA，未安装、未导出发行归档、未上传或冒充已提交1141的更新。已提交的1141仍是旧二进制，需要后续新构建才能让用户端获得此修复。

本轮无测试/编译失败；遗留Kotlin迁移及deprecated API提示未影响构建，Node的1项Windows限定测试按平台跳过。全部检查完成后仅提交当前开发分支，main不提升，R8 Pro实物连接与同步仍待新包安装后验收。
