# 最新 Git 同步、正式重打包与手机覆盖安装（2026-10-05）

## 用户范围

同步最新 Git、重新打包 Android 正式版并安装到已连接手机。只进行 Git 本地同步、App main 同步和 APK 构建/安装，不自动部署后台，不改微信/极光生产参数，不读写用户健康数据、不操作戒指。

## Git 同步与现场保留

- App 原目录 E:\SayRing 在旧分支 d8eb123，用户有一处文档空行删除。定向 git stash 保存后切 main，快进到远端 c31d618，再快进纳入已验证的 JCore 严格版本锁定提交 0b109dfb046dc181af57b063a1bf0421fb1034a2，push main 成功。文档改动已通过 stash apply 原样恢复，stash 作为恢复副本保留，没有提交用户改动。
- 正式构建目录 E:\SayRing-market-release-20261005 干净；HEAD 与 origin/main 均为 0b109df，构建基于该 SHA。没有远端新增业务提交，本次只将已验证的修复纳入 main，并通过构建参数递增到 1.0.0 (1011)，不改 pubspec 的其它平台版本。
- 后台 main 工作树 E:\saydian-support-publish-20260930 从 97eed39 快进至远端 6fe11493616fdf2db0e215e70d62a5942ea6ec8e；tools/Start-Change.ps1 核验 main 干净、HEAD 等于 origin/main，通过。
- E:\saydian h5 的未跟踪法律草稿/图标概念记录用定向 stash -u 保存，切新本地分支 codex/local-main-sync-20261005 到 origin/main 6fe1149 后 stash apply 恢复全部草稿。HEAD 与远端相同，仍保留原来的未跟踪文件；没有覆盖、提交草稿或推送后台。未运行 pnpm 或数据库迁移，不把 Git 快进写成后台已部署/运行验收。
- 网络使用本机已配置代理；fetch、push 和 ls-remote 实际成功，不依赖历史快照声称同步。

## 构建与检查

- 使用受保护永久 Android 证书，正式构建开关保持启用，JPush standard 通道参数按既有独立产品配置注入；后台 Master Secret 不进 App。
- 本机构建脚本调用 flutter build apk --release --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.0 --build-number=1011：成功（234.6 秒），key.properties 生成后清除。
- 先将已确认的 QRing immutable workspace hash 缓存移到工具链 qring-transform-20261005-release-1011 隔离目录，避免重复上轮已复现的缓存校验失败；没有删除源码、证书或用户数据。
- 产物 E:\SayRing-market-artifacts-20261005\SayRing-1.0.0-1011-release.apk，69,044,934 字节。
- APK SHA256：4a0adb25a584c682b4241725eda5bea1bf2b3ac218fe7af0abb9b9c94a9a36cc。
- apksigner verify --verbose --print-certs：通过，RSA4096/v2，正式证书 SHA256 81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de，与手机 1010 同证书。
- aapt dump badging：cn.saydian.ring / Say Ring / 1.0.0 (1011)，minSdk 26、targetSdk 36、双 ARM。
- zipalign -c -P 16 4、release_gate.py apk-manifest：通过。
- Gradle releaseRuntimeClasspath 报告成功（35 秒），JPush 6.2.0 / JCore strictly 5.5.2；基于本次新报告和新 APK 的 apk-abis：通过，精确保留 libjutils.so 例外，不放宽门禁。
- Windows 可执行发布 Python 套件 19/19 再运行通过。业务源码未变，复用此前同一 0b109df 源码的 analyze 零问题、Flutter 两时区各 940/940、Android 原生 32/32 和 Debug 构建证据；不把复用写成本轮重跑。
- 原生 ELF 静态检查仍为 43 个库：所有 arm64-v8a LOAD 对齐至少 16KB；32 位 libDspConfig.so/libEcgAnaly.so 仍为 4KB。只作静态检查，不是 16KB 设备运行验收。

## 手机安装结果

- 连接的华为 JAD-AL00 原版本 1.0.0 (1010)，首次安装时间 2026-10-05 16:20:44。
- adb install -r 新正式 APK：Success；手机息屏时唤醒/关闭锁屏遮罩后系统已显示安装成功，无卸载、无清数据、无权限或隐私同意操作。
- 手机回读版本 1.0.0 (1011)，首次安装时间仍为 16:20:44，最后更新为 16:50:03。
- 从手机安装目录拉回 base.apk，SHA256 与上述本次正式 APK 完全一致；启动 MainActivity 成功并检出进程，只证明安装和短时启动，不冒充登录、推送、戒指和健康验收。

## 待验收与发布边界

- 正式证书 MD5 09D14504FD119AE833B2AAAAEECC13FE 需微信开放平台登记并复测回跳；本轮未改平台参数。
- 极光标准通道真实注册/账户绑定/通知到达、厂商专用通道、戒指功能与 16KB 机型仍需单独现场验收。
- Windows 无 Xcode；本轮不编译 iOS/鸿蒙、不重打 AAB、不提交应用市场、不发布下载清单、不改线上数据库/维护状态。
- 本记录和索引是本轮唯一新源码文件变动（纯文档），不会改变刚构建的 APK 业务输入。手机升级保留应用容器，但没有读取并验证具体用户健康记录，不能声称逐条数据验收。
