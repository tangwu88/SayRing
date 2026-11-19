# CoolWear Android SDK 1.4.1 升级（2026-11-19）

## 来源和边界

- 用户在核对官方开发者入口后要求升级最新SDK。本轮基线 `535f94c7f1e2aadf62fc089000d45c11779b7da2`，工作区干净，fetch成功；从已交付QRing1.0.0.86的分支创建 `codex/coolwear-sdk-141-20261119`，保留该轮全部接入与日志关闭措施，不混入独立客服/iOS分支。
- 官方入口 `https://luckringmax.coolwear.fit/sdk/developer.html` 指向 `Coolwear/androidSDK`。本轮 `git ls-remote ... refs/heads/main` 再次确认最新为 `39b72153be987c0c788d4f7ffeb12c6ea842db1c`，2026-11-04提交说明“SDK 1.4.1 增加左右手设置、计数器接口”。使用该固定提交下原始 `app/libs/coolwear_bluesdk-release.aar`，不修改供应商字节码。
- 新AAR 669,194字节，SHA-256 `F9181033FC25C0EED3C5EFC42AEDE2726B4017B4F5758037B1BC0D1121DA13A1`，Git blob SHA-1 `b67a981717e3ed5dfde37b9f035bacd3a2b47b95` 与官方tree一致；原AAR 664,450字节，SHA-256 `AD482D5D69B99941D906038794165C1D479E5E038713954D9CA22059083D0F5F`。原包为9月10日供应商提供；本轮进一步读取AAR自身清单，确认实际SDK versionName从1.4.0变为1.4.1，两版供应商versionCode均为12，不用供应商versionCode替代App构建号。
- 本轮只升级安卓CoolWear SDK，覆盖实际选择此通道的R7Pro/R7Ultra等型号；不更换iOS二进制，不开放新增计数器/左右手UI、不更改已有监测间隔、手势场景或能力授权，不绑定、清空或重置任何实物戒指。
- 最新说明没有宣称修复R7P无数据。本次库升级不得等同于客户首绑无数据根因已经解决；实际新数据读取、手测与持续连接仍需实物验收。

## 接口和验证计划

- 对项目实际导入的35个供应商类，比较新旧 `javap -p -constants` 输出：无删除/签名或原有常量变化，仅新增 `requestCounterSync()`、`clearCounter()`、`setLRDisplay(int)`。两项扫描中不在AAR的类是项目自己的 `SayRingClearResultTap` / `SayRingHistoryObserver`，并非新版漏提供类。
- 保留一次初始化/真实清理ACK及原派发器恢复、精确账号和目标回调隔离、设置回读、历史逐包保存及真实完成、手动无默认值、相机与手势确认等既有保护。用原有实际SDK字节码/JVM夹具和原生回归核验，不使用假成功或移除校验来通过升级。
- 修改AAR、来源文档和客户端SDK指纹锁定测试。原ZIP/PDF、下载缓存、API差异、编译日志与APK都留Git外；本轮审计目录 `E:/SayRing-coolwear-sdk-141-20261119`。
- 将依次执行协议/初始化/同步/HRV/手势/相机定向检查、原生单测和依赖、分析、Flutter双时区全量、Debug/Release及正式签名/包身份/ABI/SDK副本检查。实际结果随后追加。

## 执行过程与环境修复

- 首轮Node检查有两项因父进程缺少ANDROID_HOME失败；只为本轮进程指向已有Android SDK后重跑，48项中46通过、0失败、2项macOS专属跳过，不把跳过算作iOS验收。真实供应商字节码/JVM回归覆盖清理ACK、初始化目标恢复、同步历史、HRV、相机、手势及只读请求编码；没有放宽断言或改写SDK。
- 原生编译首轮因E盘仅剩约0.11GB失败，出现磁盘空间不足及伴随的Gradle插件加载错误。手动复制后清理构建目录的方案被自动审批拒绝、未执行；改为受路径核验保护的原生Move-Item完整迁移构建缓存到 `D:/SayRing-build-cache/SayRing-market-release-20261005-20261119`，迁移前后26,990个文件的全部相对路径和长度一致，原E盘build路径建立junction后继续使用。保留了缓存、源码、账号、签名与已交付APK，未递归清理原缓存。迁移后本机测得E盘可用约9.77GB；这是时点读数。
- 对比新旧Logger、Lg、FileLogPrint的实际字节码，去除常量池索引差异后完全一致，没有新增或放宽日志通道。AAR资源与元数据一致，变化为classes.jar和清单中的versionName；原minSDK21、targetSDK33、权限与服务声明不变。最初清单未解码前的“一致”措辞已纠正，不能将SDK版号变化忽略或声称无文件差异。

## 已完成主机检查

- E盘空间恢复后，重新执行原生单测与releaseRuntimeClasspath依赖报告，135项通过，0失败/错误/跳过；没有跳过厂商SDK单测。`flutter analyze --no-pub` 无问题。前述失败日志保留在本机审计目录。
- Flutter两个时区全量、Debug/Release、原正式签名和Git/CI状态待完成后追加；新包构建号预留为1.0.14（1312）。这不是客户手机故障已恢复的验收结论。
- UTC完整Flutter回归2437项通过。此时上海时区回归和打包仍进行中；先推送本次已完成接口/SDK协议/原生/分析/UTC验证的独立SDK升级分支，继续本机剩余检查并核对云端CI，不将后续检查提前记为成功。
