# Say Ring 鸿蒙首次上架正式包（2026-10-05）

## 范围与基线

- 用户已准备鸿蒙正式证书，要求打包；本轮不安装手机、不修改后端、不提交应用市场。
- 专用发行工作树 `E:\SayRing-market-release-20261005`，分支 `codex/first-market-release-20261005`。
- 修改前及提交前重新 fetch，基线 HEAD/origin/main 为 `9bb725bcc45dc80f76f35cde04bf3e2a0281610d`。最后一次直连 fetch 遇 Connection reset，改用本机既有代理重新 fetch 成功，远端基线未变。
- 仅修改 `harmony-native/AppScope/app.json5` 与 `entry/src/main/ets/services/AppUpdateService.ets`：版本从 0.1.4/9 更新为 1.0.0/1012，应用包名仍是 `cn.saydian.ring.hm`。更新检查版本必须与安装包一致。业务与 SDK 代码未改变。
- 主工作树原有文档改动、后台草稿均保留；签名材料与产物都在 Git 外。

## 证书与构建验证

- 本机受保护签名目录 `E:\saydian-release-signing\SayRing\harmony`，沿用既有 EC P12，不新建或更换密钥。证书链叶证书公钥与私钥对应公开证书一致，profile 的 distribution-certificate 与该叶证书一致。
- 官方 `hap-sign-tool.jar verify-profile` 通过：release、app_gallery、bundle `cn.saydian.ring.hm`。证书有效期至 2029-10-05。
- 命令行工具链 26.0.0.821，JDK 17.0.20，SDK compatible 5.0.5(17)。`ohpm install --all` 成功。
- `TZ=UTC node --test tests/*.test.mjs` 和 `TZ=Asia/Shanghai node --test tests/*.test.mjs` 各 501/501 通过。
- `hvigorw.bat --mode project -p product=default -p buildMode=release assembleApp --no-daemon`：CompileArkTS 和 PackageHap 成功，SignHap 首次失败（见下）。输出 unsigned HAP 后，使用官方 `hap-sign-tool.jar sign-app -mode localSign -signAlg SHA256withECDSA -compatibleVersion 17 -signCode 1` 和已验证证书/profile/P12 完成正式签名；密码只在本机脚本内从 DPAPI 解密，未记录命令密钥值。
- `hap-sign-tool.jar verify-app` 对独立 HAP 和最终 APP 内提取的 HAP 均通过：摘要、code-sign、permission-sign、release profile。
- 官方 `app_packing_tool.jar --mode app --hap-path ...entry-default.hap --pack-info-path ...pack.info --force true --replace-pack-info false --deduplicate-so false` 完成 APP，内部 HAP 与独立签名 HAP SHA256 一致，模块文件名与 pack.info 的 entry-default 对应。
- 包内 module.json 实测：bundle `cn.saydian.ring.hm`，versionName `1.0.0`，versionCode `1012`，debug=false，compatible API 17，target API 26。
- 厂商 HAR 编译有类型、废弃接口、资源冲突及字节码 HAR 不支持混淆警告；编译成功不等于厂商 SDK 真机验收。

## 失败与修复（保留记录）

1. 首次 .NET 导入串联 PEM 只读取根证书，误判公钥无匹配；改为逐段解析三张证书后确认叶证书匹配。profile content 已是对象，再次 ConvertFrom-Json 导致解析失败，修复为按实际类型处理。
2. Hvigor 把明文 storePassword 当作 IDE 加密数据处理，在 `DecipherUtil.getKey` 查找私钥目录的 material 子目录时报 ENOENT。未伪造 material、未绕过签名、未修改工具链；改用官方独立签名工具。临时 build-profile 内容在 finally 恢复，密码未进入 Git。
3. 首次临时 ACL 恢复因 Set-Acl 涉及 SeSecurityPrivilege 失败；原文件内容已经恢复。后续脚本使用 Access-only descriptor，保留受限 ACL；签名改为独立脚本不再修改仓库 ACL/config。
4. app packing 默认重写 HAP 导致内嵌签名块丢失；最终显式关闭 replace-pack-info 与 deduplicate-so，再逐字节 hash 和官方 verify-app 复验。失败的 APP 不是交付物，最终路径已被验证后的 APP 替换。
5. `verify-app -h` 和 packing `--help` 不是该工具接受的调用方式，帮助查询失败不代表产物失败；改为签名工具根 `-h` 与官方参数/本机 Hvigor builder 定义。

## 交付与未验收

- 上架 APP：`E:\SayRing-market-artifacts-20261005\SayRing-HarmonyOS-1.0.0-1012-release.app`
- APP SHA256：`99F6D9C6B691BF3CE7BE42AC497E30A9DDB7F25182FE80F8255FE31922C1F6EA`
- 签名 HAP：`E:\SayRing-market-artifacts-20261005\SayRing-HarmonyOS-1.0.0-1012-release.hap`
- HAP SHA256：`F3C593BB9698B5D005DD01941A30D5F0AEA50430835D2F7D9665269CFFEFC863`
- 公开叶证书 SHA256：`C4F4B2AF305C338728D7172B845B4455D7CE1896EA0D40A28579FC1E56C28A3C`
- 输出日志、验证 profile 和本机签名脚本在仓库外，不提交私钥、密码、构建产物。
- 本轮没有鸿蒙真机安装/戒指功能/微信授权/推送联调，没有应用市场预审或上传；签名通过不保证应用市场审核通过。
- Flutter/Android/iOS 源码未改，本轮未重新运行 Flutter/Android 构建；同日 1011 Android 记录可查但不是 1012 鸿蒙真机证据。Windows 无 Xcode，iOS 构建未执行。
