# Android 与鸿蒙正式包 1066

- 用户要求生成正式安卓和鸿蒙包。本轮不安装手机、不上传市场、不部署后台、不修改账号、供应商或健康数据。
- 修改前 status/remote/fetch 成功，干净构建工作树 HEAD/origin/main 为 6479dbf33c6f2fca054ae62195b19e7ae9def514；创建 codex/formal-android-harmony-20261015。阅读 AGENTS、交接、近期 Android/鸿蒙正式发行记录及复盘/回归约定。
- 运行时代码保持现有基线；Android 用命令参数 1.0.0/1066，鸿蒙仅将 AppScope/app.json5 与 AppUpdateService.ets 的构建号同步为 1066，版本名仍 1.0.0，不改变业务逻辑。原用户主目录文档、后台草稿不触碰。
- 正式签名沿用仓库外原永久 Android 证书和鸿蒙 P12/AGC release profile。签名密码只由受保护原脚本读取，证书/密码/产物/私有日志不进入 Git；不调用已标明弃用的 Hvigor 明文密码签名脚本。
- 构建输出计划为 E:\SayRing-market-artifacts-20261015\formal-1066；安卓 APK、鸿蒙上架 APP 及独立签名 HAP。正式签名和构建不等于市场审核通过或戒指功能验收。鸿蒙仍缺 QRing/LuckRing SDK，不因名称路由存在而宣称支持连接。
- 本机物理内存可用约 0.9 GB；两端串行，保留失败日志，不停止其它人的进程、不清理宽泛缓存。仅打包无 iOS 构建、安装、真实健康操作、短信或供应商调用。
- 测试、构建、签名和实际包身份/哈希结果完成后追加。

## 鸿蒙已完成验证

- `Rebuild-SayRingHarmony-20261006.ps1 -BuildNumber 1066 -OutputDirectory E:\SayRing-market-artifacts-20261015\formal-1066`：UTC/Asia/Shanghai 宿主测试各 503/503 通过；Release assembleApp 1m4.693s 成功，42 tasks（32 executed/10 up-to-date）。既有厂商 HAR/未内置签名配置警告保留；使用原独立官方签名工具完成签名，不把 unsigned 输出作为交付物。
- 官方 hap-sign-tool 验证独立 HAP 及从最终 APP 提取的 HAP 均成功，包含摘要、代码和权限签名。APP 的 entry-default.hap 与独立 HAP SHA256 完全相同；真实 module.json 为 cn.saydian.ring.hm / 1.0.0 / 1066 / debug=false。
- 复核签名 profile：release / app_gallery / cn.saydian.ring.hm。叶证书 SHA256 `C4F4B2AF305C338728D7172B845B4455D7CE1896EA0D40A28579FC1E56C28A3C`，有效至 2029-10-05，与既有正式签名一致。只检查公开证书/profile，不输出私钥或密码。
- APP 9,433,251 bytes，SHA256 `11E0647B6143ED2E03B753F6093179041341138782864FCDD3039C74C1A9010F`；独立 HAP 18,711,837 bytes，SHA256 `37088D7CD6FDF2FE69E2982D61AD33EBE6E24558A402568E6084FAF5DB35597F`。二者大小不同来自 APP 压缩封装，不是 HAP 被重写。
- Android `pub get` 和 analyze 已通过（零问题），UTC Flutter 1245/1245 通过；其余 Android 门禁仍在执行。

## Android 与最终交付

- `Rebuild-SayRing-20261006.ps1 -BuildNumber 1066 -OutputDirectory E:\SayRing-market-artifacts-20261015\formal-1066` 全部成功。Flutter UTC/Asia-Shanghai 各 1245/1245；Debug 双 ARM 117.6 秒；原生命令 1m43s 成功，XML 51 项零失败/错误/跳过；正式 Release 330.9 秒成功。
- `Verify-SayRingAndroid.ps1 -BuildNumber 1066`：生产 v2 签名、cn.saydian.ring / 1.0.0 / 1066 / minSdk26 / targetSdk36、双 ARM、zipalign 16KB 和生产极光 manifest 均通过。原永久证书 SHA256 `81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de`、MD5 `09d14504fd119ae833b2aaaaeecc13fe` 未变。
- 串行生成真实 releaseRuntimeClasspath 报告后，`release_gate.py apk-abis` 通过；严格 JPush6.2.0/JCore5.5.2/flutter3.5.1 的 libjutils.so arm64-only 原受控例外未放宽；临时 android/key.properties 已清理。
- `Inspect-SayRingNative.ps1 -Apk <1066 APK>` 成功，检查 43 库，所有 arm64-v8a LOAD/RELRO 16KB 通过。两项 armv7 既有 4KB 库 libDspConfig.so/libEcgAnaly.so 在本机报告中明确保留，未篡改厂商二进制或把它们写成通过。
- APK 69,816,719 bytes，SHA256 `BAE37667D09ADA688B88F6F89D2264D127FD7B854E5B9A29BA72F8B63BFF0A70`。路径 `E:\SayRing-market-artifacts-20261015\formal-1066\SayRing-1.0.0-1066-release.apk`。鸿蒙 APP/HAP 位于同目录；原受保护鸿蒙签名脚本的日志名称保留 1012 后缀，不代表实际包版本，实际签名包和 module.json 已独立确认为 1066。
- `git diff --check` 无错误；仅本轮两个鸿蒙版本字段及日志/索引提交。生成物、私有签名材料、原始机器日志与用户其它改动不进 Git。发布前再次 fetch 校验 origin/main，普通推送当前分支与 main，不强推；实际提交以 Git 回读为准。
- 本轮无安装、真机页面/戒指测试、后台配置/数据库变更、线上下载替换或市场提交；iOS 未构建。正式签名不等于市场已批准，也不补足鸿蒙缺失 QRing/LuckRing SDK 的产品功能。受保护脚本和签名配置原样恢复，没有新签名身份。
