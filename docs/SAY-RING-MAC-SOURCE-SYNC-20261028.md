# 2026-10-28 Mac同步最新开发代码

## 范围与基线

用户明确选择“同步Git最新代码”，本轮仅源码同步和验证记录。工作树起点干净，当前分支`codex/login-camera-r7ultra-1136-20261024`，原HEAD为`d52d5a435a82ee63d50b468aa1e1971c19831390`。已读AGENTS、国际交接、复盘/回归清单及最近三端模块、Android1155和鸿蒙1156记录。

`git fetch --prune origin`成功，当前分支ahead/behind为0/9；`git merge --ff-only origin/codex/login-camera-r7ultra-1136-20261024`成功，快进到`5cc02168cddc46b138a049b9a2f2947cb76df9a9`，无冲突、无重置或强推。共同步9个提交、33个文件；`HEAD..origin/main`独有提交为0，未提升含待验硬件功能的main。

## 同步内容

- 三端共用既有百科/商城显示配置，保留缺省关闭、产品/平台匹配、租约和撤销守卫；未扩展医疗、手动测量、AI或购买权限。
- 原生鸿蒙关爱、百科、商品读取对齐Android国际V2契约，保留UUID、分页、逐项共享及迟到响应隔离；既有SDK/支付缺口仍保留。
- 合入Windows侧Android1153/1154安装、1155正式构建、鸿蒙1156构建及三端线上核验的原始记录。那些设备和产物证据保持原归属，本轮不冒充在Mac重做。

## 本机检查

完整命令、退出码及各步时长保留于私有`build/mac-source-sync-20261028-5cc0216/results.json`及同目录日志，未覆盖上一轮验证。

- `git fsck --full`退出0；保留所有备份分支和对象，未做清理。
- `flutter pub get --offline --enforce-lockfile`成功；`flutter analyze --no-pub lib test integration_test`零问题。
- `TZ=UTC`与`TZ=Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded`各1556/1556通过。
- `TZ=UTC`与`TZ=Asia/Shanghai node --test harmony-native/tests/*.test.mjs`各540/540、0跳过。
- `node --test tool/*.test.mjs tool/test_*.mjs`140通过、1跳过（Windows ACL非本机平台）。`git diff --check`通过。
- 直接核验源码`5cc0216`的[mobile-ci40655983762](https://github.com/tangwu88/SayRing/actions/runs/40655983762)已completed/success；quality、Android、iOS、Harmony UTC/Asia-Shanghai五个任务均success。该回执与之前健康提醒兼容修复CI是不同运行。

本轮未自行修改运行代码、重新打包或发布下载/商店。原生构建和Windows签名包以各自原记录及上述云端结果为准，不把本轮宿主检查写成Mac新的原生包或实物通过。

## 手机只读发现与Git交付

只读`adb shell dumpsys package cn.saydian.ring`已显示这台Mac所连华为为1.0.7（1152），此前1144/待安装记录已过期。本轮未点击安装、登录、绑定、清数据或测试戒指；1152版本号读取不代表新功能实物验收。两台iPhone仍unavailable。Windows记录中的1154手机及1155 APK不能混用为这台手机的实际版本。

同步完成后运行源码与远端5cc0216一致；本轮只新增本记录和索引，使用既有GitHub连接提交文档回执，并保持运行文件blob不变。文档提交标记`[skip ci]`以免重复相同源码的整套构建，代码的五项CI与本机回归均已真实执行。本地原文档提交保留备份，远端更新须前置SHA匹配、非强制，并在fetch后再核对工作区与运行代码。
