# Android r6 安装包只读门禁（2026-09-07）

## 范围

- 主线程完成构建后，独立核验正常 `lib/main.dart` Debug / QA Release 安装包；本执行者不编译、不安装、不操作手机、不读取签名私钥、不发布。
- 修改本记录前已执行 `fetch --prune`。基线为 `d18542d` 加本轮共享设置回读等锁定工作树；保留其他执行者改动，不在脏工作树拉取覆盖。
- 所有 r1–r5 产物保留。r6 任一门禁失败都不能记录为最终推送 QA 包通过，更不能称正式发行签名。

## Debug 首次产物：原生推送配置失败

| 检查 | 实际结果 |
| --- | --- |
| 首轮文件 | 原名 `Saydian-Android-QA-Debug-JPush-0.1.19-build23-20260907-r6.apk`；核验结束后由主线程移至 `artifacts/three-platform-20260907/android/rejected-r6-native-disabled/Debug-attempt1.apk`，与之后同名重建包区分 |
| 大小 / SHA-256 | 153904240 字节；`1fb8b8ea5485d8db92b035cefafa9353d92da3502778c1722596fbda4879e9da` |
| 官方 APK 验签 | `apksigner verify --verbose --print-certs` 通过，V2=true |
| 证书 SHA-256 | `1350168096373439fbb4fb80c0acd145f209e06310ddb658ce318d765525cb97`，仍为原 QA Debug 证书，非正式签名 |
| 官方 Manifest 元信息 | `cc.saidian.app`、0.1.19(23)、minSdk 26、targetSdk 36、debuggable=true |
| 原生推送配置 | **失败**：最终 Manifest 的 AppKey 和 channel 均是工程禁用推送的默认占位值；与受保护配置不匹配 |
| Dart 推送配置 | Debug kernel 与本机受保护 AppKey 匹配=true；与原生未配置状态不一致 |
| ZIP 16KB | 官方 `zipalign -c -P 16 -v 4` 只读检查通过 |
| 双 ARM | armv7 15 库、arm64 17 库，均有 Flutter 运行库；arm64 独有固定 JPush `libjutils.so` 及 Debug Vulkan 验证层，没有其他不对称库 |
| ARM64 ELF | 官方 NDK `llvm-readelf` 逐库检查 17/17 通过：ELF64/AArch64；每个 LOAD 的 align≥16384，offset 与 vaddr 满足 16384 同余 |
| 最终结论 | **不通过推送配置门禁，不安装、不发布，等待主线程重建**；静态对齐不代表真实 16KB 系统运行通过 |

Manifest 使用本 APK 的官方 `apkanalyzer manifest print` 结果，资源表来自同 APK 的 `aapt2 dump resources`，再执行仓库 `release_gate.py apk-manifest`。没有更改或放松门禁。

失败已经通知主线程。确认证据仅输出 `nativeAppKeyIsDisabledDefault=true`、`nativeChannelIsDisabledDefault=true`、`dartKeyMatchesProtectedConfiguration=true`，不记录 AppKey 值、登记标识或 Token。

### 诊断工具与失败过程

- 工具为 Android SDK build-tools 36.0.0、cmdline-tools/latest 的 apkanalyzer、NDK 28.2.13676358 的 LLVM 19.0.1。`zipalign -h` 不支持并返回用法，随后按官方用法使用只读 `-c -P 16 -v 4`；未执行对 APK 写入的对齐命令。
- 首次包门禁在原生推送配置比对失败后停止；读取准确失败原因为 `JPUSH_APPKEY` 不匹配。随后继续独立 ZIP/ELF 项目，但总结果仍为 failed，没有用其他通过项覆盖失败。
- 第一次附加 Dart kernel 检查的进程缓冲上限 50MiB 不足，未以失败输出判断配置不存在；改为 256MiB 后读取成功，并取得配置匹配布尔。
- 原始 Manifest、资源表、官方验签/ELF报告仅保存在权限受限 `/tmp/saydian-android-r6-check.buonXR`（目录0700，报告0600），不进入 Git 或交付包；受保护配置仅在进程环境中用于比对。

## Release 与重建后核验

主线程确认首轮只传入 Dart define、遗漏原生进程的 `JPUSH_APP_KEY` / `JPUSH_CHANNEL`。首轮 Release 同样不作为候选，并移至 `rejected-r6-native-disabled/Release-attempt1.apk`；本执行者未把未核验的首轮 Release 写成通过。

主线程从已有受保护 dotenv 仅解析允许的两键，注入构建子进程（不 source、不输出值），随后分别重建两包。正确 QA Release 构建耗时 47.4 秒由主线程提供；独立核验不重新 assemble，不修改签名。

### 重建后的最终静态结果

| 产物 | 大小（字节） | SHA-256 |
| --- | ---: | --- |
| `Saydian-Android-QA-Debug-JPush-0.1.19-build23-20260907-r6.apk` | 153910223 | `9f97a5f46e02b227edb274aed4c8754d781d2530accd600f449ad361db77efe5` |
| `Saydian-Android-QA-Release-JPush-0.1.19-build23-20260907-r6.apk` | 64661988 | `b419c738d219c940544392a0013aa8c3d703b075c2a12fce19b38386eaf025aa` |

- 两包官方 V2 验签通过，证书 SHA-256 与前述 QA 证书相同。官方 Manifest 均为 `cc.saidian.app / 0.1.19(23) / minSdk26 / targetSdk36`，Debuggable 分别 true / false；不是正式发行签名。
- 两包原生推送 Manifest 与同 APK 资源表门禁通过；Debug kernel、Release arm64/armv7 AOT 与受保护推送配置均匹配，只输出布尔。Release 模式本身不能代替此配置核验。
- 编译锁释放后，分别运行当前 `:app:dependencies --configuration releaseRuntimeClasspath` / `debugRuntimeClasspath`，均成功；未执行 assemble。按实际报告与 `pubspec.lock` 验证 `jpush_flutter 3.5.1 / JPush 6.2.0 / JCore 5.5.2` 的唯一 `libjutils.so` 例外。Debug/Release 的该 arm64 库字节完全一致；不拿 r5 旧报告充当本次结果。
- Release ABI 门禁通过，armv7 15 库 / arm64 16 库，只有 `libjutils.so` arm64 独有；两架构均有 Flutter 和 AOT。Debug 为 15/17，另有仅 Debug 使用的 Vulkan 验证层，没有其他不对称库。
- 两包官方 ZIP 16KB 检查通过；官方 `llvm-readelf` 检查 Debug 17/17、Release 16/16 个 ARM64 库均符合 LOAD 对齐与同余要求。没有执行 16KB 系统真机测试。
- 最终源码完整 Flutter analyze 零问题、UTC 与 Asia/Shanghai 各 **524/524**、定向 **158/158**，发布 Python **22/22**、actionlint、shell 静态检查通过，均由主线程统一运行；本任务没有重复执行这些测试。
- 原始成功报告位于 `/tmp/saydian-android-r6-check.buonXR/debug-rebuilt-*`、`release-rebuilt-*`；失败的 `debug-attempt1-*` / `debug-attempt2-*` 原位保留。依赖报告同在受限临时目录，未提交包含配置的原始资料。

Android README 已改为 r6 最新候选，保留 r1–r5 全部记录；`SHA256SUMS` 仅追加两个成功重建包，`rejected-r6-native-disabled/` 不纳入候选清单。r5 后续已覆盖的直接证据和 07:29 USB 信任阻断已同步纠正，不再把历史等待密码状态写成当前状态。

全部 12 个候选/历史文件执行 `shasum -a 256 -c SHA256SUMS` 均通过。失败目录另附禁止安装/发布说明，Git 忽略规则实核仍覆盖全部 APK、README 和 SHA 清单；本记录 `git diff --check` 通过。

最终结论只限静态包门禁通过。r6 两包未安装、未发送推送、未上传；共享设置回读和通知点击仍待真机，服务端 HRV 撤销 P1 不因此关闭。
