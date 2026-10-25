# 2026-10-25 蓝牙名称通道核查

用户要求检查含R21、R22、R8、R7C是否走QRing。本轮只核查现有规则与执行既有/宿主测试，不修改生产路由、后台、设备绑定、安装包或苹果审核。

基线d7b9abb7ce43cea413e6a5cb88fb17f0a2e4ef77，分支codex/device-search-help-1141-20261024；status干净，origin为tangwu88/SayRing，fetch及pull --ff-only成功、Already up to date。已阅读AGENTS、国际交接、最新修改记录、回归清单与复盘。核查Flutter分类器、iOS QRingNamePolicy/CoolWearPolicy及实际桥调用、Android RingNamePolicy及双桥调用，规则一致。

## 现行结果

- 名称先trim并转大写，不区分大小写。
- R1或R2开头、任意位置含R7C优先QRing；因此R21/R22开头及SD-RING-R7C等都为QRing。
- 普通名称任意位置含R21、R22、R8，且不与另一协议型号冲突时为QRing，例如R21_D47C、YC-R21-123、V-R22-123、device-r8-123。
- 保留用户10月22日指定的震动款R8 Pro例外：R8 pro、r8PRO、R8-Pro、SD-RING-r8_pro-123仍为CoolWear/LUCKRING，不因为含R8改走QRing。
- 未命中明确优先规则的双通道冲突名不选任意SDK，例如R8-R7、YC-R21-K80、R8Pro-R21；R21-K80因R2开头优先QRing。R7C即使包含R7也先选QRing。
- 名称只选候选SDK，设备能力和连接成功仍必须由真实握手证明。本轮未进行实物连接或同步验收。

## 本轮实际验证

1. `flutter test --no-pub test/wearable_routing_test.dart --reporter compact`：35项通过，包含各型号分类、冲突拒绝、选定SDK连接及绑定恢复保护。日志私有留在/tmp/sayring-routing-check-20261025.log。
2. `xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation test/native/qring_name_policy_test.m`编译并执行实际iOS头文件策略：46例通过。
3. 同样编译并执行`test/native_coolwear_policy_test.m`：PASS，包含R8 Pro归属及排除QRing名称的现有断言；为合成输入，不是硬件验收。
4. javac编译项目实际`RingNamePolicy.java`，用现有iOS名称用例加R8 Pro型号例外作跨平台宿主核对：50例通过。临时harness和可执行文件仅在忽略的build/name-routing-audit-20261025，不入Git。

初次路径搜索中旧ohos/harmony和CoolWearBridge.m路径不存在，已改为实际CoolWearWearableBridge.m和仓库真实路径；没有因搜索路径错误推断平台能力缺失。纯核查没有生产源码变化，因此不重跑全量构建、不上传新版本；本记录单独提交当前分支，不推广main。
