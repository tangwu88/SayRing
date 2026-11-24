# Android 1320 正式签名构建与手机安装

## 代码同步

- 用户要求同步最新代码并安装到手机。2026-11-24 开始时，原分支工作区干净，HEAD 为 72c77761f6b7c4ee183e5b06a1b4af5697992bcf，status、remote、fetch 已执行。远端功能分支由 e518579 更新至 14724c6dfc9bc315b921bd58197d7eb741fa860b，包含远程关爱刷新和安卓心血管入口补充；本轮固定该运行源码作为候选。
- 已读取 AGENTS、交接、最近变更、功能记录、复盘和回归清单。保留 codex/before-android-sync-20261124 检查点，新建 codex/android-1320-install-20261124，合入远端功能分支。双方仅在 CHANGE-TEST-LOG 索引冲突，保留线上排查和新功能的全部条目，未选择丢弃任一侧。合并提交 6864979；未改业务源码或 SDK。
- 保留校时修复、双 SDK、初始化保护及终生一次首连摘要规则。本轮不修改服务器、线上下载配置、商店或客户数据。

## Windows 构建与验证

- 构建/私有日志在 Git 外 E:/SayRing-android-1320-20261124。沿用已保护的正式签名辅助脚本，临时指定 1.0.15（1320）、正常 main、生产 JPush 配置和既有商城构建参数；临时 key.properties 在构建后清除，不提交签名材料。
- 首次离线 pub get 因新增 audioplayers 不在缓存中失败。保留 prepare.log，改正常联网获取依赖后 prepare-online.log 成功，锁文件没有变化。新增原生依赖也在本轮首次下载/编译，未通过换依赖或跳过测试制造成功。
- flutter analyze --no-pub 无问题；完整 Flutter 回归在 UTC 和 Asia/Shanghai 各 2481 项全部通过。Android 原生 testDebugUnitTest 共 135 项，失败/错误均为零；同时保存 releaseRuntimeClasspath 供 ABI 校验。
- Android Debug 和普通 main 的正式 Release 均成功。Debug 期间出现 File modified during build 的构建输出，最终 assembleDebug 正常完成；未把旧 APK 当作新包安装。Windows 未运行 iOS 构建或新功能实体戒指验收，远端已有记录不冒充本轮重跑。
- apksigner 验证正式证书 SHA256 为 81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de；aapt、生产 manifest、推送资源、双 ARM ABI 与 zipalign 检查通过，非 debuggable。既有 SDK 的部分 ELF 4KB 加载对齐限制仍保留，不能称为所有市场已验收。
- 实际新 APK DEX 核对包含 CoolWearClockSync 及 Request 类，新 native DEX 与旧包不同；两种 ABI 均有非空 libapp.so 和 libflutter.so，未重用缺主程序的错误产物。
- 正式 APK：E:/SayRing-android-1320-20261124/SayRing-1.0.15-1320-release.apk，75,928,197 字节，SHA256 为 773207e8509eadfc440dae4d10cb00be41b4e72a6e56277f6c549e014ff20160。

## 手机交付

- 当前唯一已授权 USB 手机为华为 LIO-AL00，安装前实读 1.0.14（1314），首次安装时间 2026-10-30 14:36:15。对精确 USB 目标执行 adb install -r，不卸载、不解绑、不清数据或重置戒指。
- 已发起安装；首次核对时手机锁屏，版本仍为 1314。已请求机主本人完成解锁与安全验证，尚不能把安装请求等同安装成功。最终结果另行追加。

## 安装完成核对

- 用户确认已安装后，重新确认同一部 LIO-AL00。安装日志为 Performing Streamed Install / Success；PackageManager 实读 versionName=1.0.15、versionCode=1320，lastUpdateTime=2026-11-24 18:08:42，firstInstallTime 仍为 2026-10-30 14:36:15，符合保留数据覆盖安装。
- 显式启动正常 MainActivity，初次立即查询尚无 PID；随后独立复核进程存在、前台为 cn.saydian.ring 的 MainActivity，未锁屏。未执行新的戒指测量、解绑或重置，不能用成功启动代替所有新功能或异常客户实物验收。
- 含 APK 拉取及摘要比较的组合命令在执行前被工具策略拒绝，没有完成手机 APK 文件读回；改为独立的包管理器版本、安装成功日志和前台启动核对，不声称已验证手机 APK 读回哈希。本地已验签交付包摘要再次核对一致。
- 追加记录前工作区干净，fetch 成功，本地与当前上游均 2cfd5fa661b691f0806902749b2fe2bfd0fd5258。本次仅追加实际安装结果，未修改已构建源码或重新打包。
