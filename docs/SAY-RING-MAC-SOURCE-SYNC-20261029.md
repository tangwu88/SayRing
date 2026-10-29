# 2026-10-29 Mac同步最新开发代码

## 范围与基线

用户本轮明确选择“同步 Git 最新代码”，仅同步源码、执行本机回归并提交验证记录。开始时当前分支为`codex/login-camera-r7ultra-1136-20261024`、工作树干净，原HEAD为`2b1b611f04e835c9c2fe2c6f6542882f319d9789`。已核对AGENTS、国际交接、复盘/回归清单、变更索引及最新R22实施记录；这些规则文件没有本轮上游修改。

`git fetch --prune origin`成功；`git merge --ff-only origin/codex/login-camera-r7ultra-1136-20261024`快进5个提交至`04f18a55c649a0ec3ed3f482b2cd5fb75cbc8681`，源码树为`4eacfb8630a4a54b07b0919b3ddb3d69080f1789`。共同步12个文件，无冲突、覆盖、重置或强推。`origin/main`仍为已接受基线`0e350063d727678b2dab8d9e61abf8edec51fd11`，未将含待验设备项的开发分支提升为main。

## 同步内容与保护

- Android测量不再显示SDK没有提供的固定进度；同时检查响应状态及设备错误码，未佩戴等错误及时结束测量。操作序号、连接及账号上下文共同拒绝旧操作或迟到回调。
- 监测设置依据实际AAR响应类型编解码；保留真实开关和间隔，写入后ACK及回读核对，不给缺少能力的项目虚构频率，不把调频率当作开启开关。
- 相机注册SDK实际拍照命令回调，保留前台、账号、连接、会话及防重复保存守卫；界面提示改为适配不同型号的操作说明。
- 保留原`QRingHistoryReadState`的逐项读取、错误不误报完成及过期回调隔离。未修改供应商二进制、后台生产配置、iOS功能上限或鸿蒙SDK能力。R21手势读取和后续断连待验项仍保留，R22结论不代替R21验收。

## 本机回归

完整命令、退出码和耗时保存在私有`build/mac-source-sync-20261029-04f18a5/run_checks.py`、`source-proof.json`、`host-v1/host-results.json`及同目录日志，未覆盖前轮证据。以下11个步骤均退出0：

| 检查 | 实际结果 |
| --- | --- |
| `git fsck --full` | 退出0；存在既有dangling对象，未删除或清理对象/备份分支 |
| `flutter pub get --offline --enforce-lockfile` | 通过，锁文件未变 |
| `dart format --output=none --set-exit-if-changed lib test integration_test/ios_device_search_help_test.dart integration_test/ios_read_only_page_walkthrough_test.dart integration_test/ios_xr_secondary_pages_test.dart` | 279个文件，0修改 |
| `flutter analyze --no-pub lib test integration_test` | 零问题 |
| `TZ=UTC flutter test --no-pub --concurrency=4 --reporter=expanded` | 1557/1557通过 |
| `TZ=Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded` | 1557/1557通过 |
| `node --test tool/*.test.mjs tool/test_*.mjs` | 140通过、0失败、1跳过；Windows ACL测试在Mac不适用 |
| `TZ=UTC node --test harmony-native/tests/*.test.mjs` | 540/540通过、0跳过 |
| `TZ=Asia/Shanghai node --test harmony-native/tests/*.test.mjs` | 540/540通过、0跳过 |
| `python3 -m unittest discover -s scripts/release -p 'test_*.py'` | 35项通过；输出中的示例包/域名来自测试夹具，不是本轮发布产物 |
| Android目录下`JAVA_HOME=/Users/saydian/develop/jdk17 ANDROID_HOME=/Users/saydian/Library/Android/sdk ./gradlew :app:testDebugUnitTest -Ptarget-platform=android-arm,android-arm64 --offline` | BUILD SUCCESSFUL；17份JUnit XML合计73项、0失败、0错误、0跳过；保留Gradle弃用提示 |

Node命令由运行器展开为匹配文件的明确参数列表；Android运行器同时把JDK的bin目录加入PATH。没有另行生成交付APK/IPA，也没有运行手机测试。

记录读取时曾把R22文档路径误写成多含`ANDROID-`的名称，`git show`返回路径不存在；随后读取正确的`docs/SAY-RING-R22-MEASUREMENT-MONITOR-CAMERA-1162-20261029.md`全文。没有文件被覆盖，此工具路径错误不属于产品回归失败。测试进程正常结束后再次轮询旧进程号返回Unknown process；结果文件已完整落盘，11项退出码及日志已逐项核验。

## CI及设备证据边界

直接核验[mobile-ci 40852418971](https://github.com/tangwu88/SayRing/actions/runs/40852418971)：精确源码`5223379fb58dcfe5c2203351d312cf1cdb45df88`已completed/success，quality、android、ios、Harmony contracts (UTC)、Harmony contracts (Asia/Shanghai)五个任务全部success。

`git diff 5223379fb58dcfe5c2203351d312cf1cdb45df88..04f18a55c649a0ec3ed3f482b2cd5fb75cbc8681 -- AGENTS.md lib test integration_test android ios harmony-native tool scripts .github pubspec.yaml pubspec.lock`为空，后续两个上游提交只更新文档。上述CI用于对应运行源码的云端构建证明，本机宿主测试不扩写成实物或新发行包验收。

上游R22在Windows及另一台手机的1162/1163安装、用户拍照/摘下中断反馈、随后经该轮用户明确要求卸载1155及恢复1163的记录保持原归属；该次卸载已清除那台手机本地数据，不能写成全程保数据，也不能套用到Mac此前使用的华为1161。本轮没有查询或操作手机，没有安装、卸载、清数据、登录、连接戒指、改变监测设置、更新下载页或提交商店。当前手机连接、实际佩戴活动/睡眠新样本、R21手势及稳定性均没有新增实物结论。

## Git交付

本轮只新增本记录和索引条目，运行源码与`04f18a5`保持一致。验证记录以`[skip ci]`文档提交推送当前开发分支，沿用已实际通过的相同运行源码CI；提交树与本地候选逐项核对后，使用GitHub连接进行有前置SHA校验的非强制更新，再fetch核对远端、工作树和运行文件。保留本地候选提交的备份分支，不修改main。
