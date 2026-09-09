# 鸿蒙 r12 最新签名重建记录

## 范围

按用户“完成后生成各端最新包并上传 GitHub”要求，重建鸿蒙 Debug / Release HAP，提供主线程统一上传到预发布附件。
本批不上传、不提交、不安装、不操作账号或手表；生产鸿蒙源码未变化，最新仍为 `790c2de`。

包版本保持 `0.1.3(7)`，不猜测或提升构建号。r12 是本次重建标签，不是 App 内版本升级。
沿用现有赛电开发签名；Release 只代表优化构建方式，不代表 AppGallery 正式发行签名或业务验收通过。

## 基线与保护

- 起始 HEAD：`d18542d5f43060f72449e31eda8d459698d4cde8`；已检查分支、远端并 fetch，无覆盖他人正在进行的 Flutter 关爱修复。
- 已读取 AGENTS、修改索引、复盘、回归清单及鸿蒙 r11 准确构建记录。
- 初始可用空间约 19 GiB；主线程确认 20.31 GB 可用后授权开始。无缓存清理、源码删除或旧产物覆盖。
- 英文签名暂存工程 `/tmp/saydian_harmony_build_20260906_0952`；不覆盖根 `build-profile.json5`，不复制私钥到仓库。
- 源码与暂存的 `entry/src`、`AppScope` 共 56 个文件逐字节一致，故无需重复同步；依赖声明/锁文件及模块构建配置一致，未改 HAR/JL 依赖。
- 源文件集合指纹：`a72c85928ad69b820f5cfe0caf329bf6fa4708675a066c5f24f08a94c0200e32`；仅用于本地重建追溯，不包含任何凭据。

## 可复用命令

测试从仓库根运行：`TZ=UTC node --test harmony-native/tests/*.test.mjs`，以及 `TZ=Asia/Shanghai` 同命令。
编译必须从上面的英文暂存运行，不在中文仓库路径执行 Hvigor。

```sh
env DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node \
  JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p product=default -p module=entry@default \
  -p buildMode=debug assembleHap --no-daemon
```

Release 仅将 `buildMode=debug` 改为 `buildMode=release`，串行运行；每次完成立即复制不同名字的产物，避免第二次编译覆盖第一份。
验签使用 DevEco 自带 `hap-sign-tool.jar verify-app` 与 `verify-profile`，只输出公开元数据和通过状态，原始 Profile 留在私有临时目录。

## 结果

| 检查 | 结果 |
| --- | --- |
| UTC 鸿蒙完整测试 | 423/423，失败及跳过均 0 |
| Asia/Shanghai 鸿蒙完整测试 | 423/423，失败及跳过均 0 |
| Debug 构建 | 33.294 秒，33 tasks；成功，0 ERROR；保留 104 条 WARN 级输出，不称零警告 |
| Release 构建 | 21.913 秒，33 tasks；成功，0 ERROR；保留 95 条 WARN 级输出，不称零警告 |
| 官方签名 / Profile | 两包 `verify-app` 与 `verify-profile` 均成功；代码、权限签名验证通过 |
| ZIP / 复制 | 两包 ZIP 完整性通过，复制源与导出 SHA-256 一致；旧 r9–r11 保留 |
| 真机安装与新增业务验收 | 本批未执行；不沿用先前 r11 安装冒充 r12 已安装 |

本地日志目录 `/tmp/saydian-harmony-r12.LpJwcl`；原始签名资料和构建日志不上传 GitHub。

## r12 产物实核

- Debug：`artifacts/three-platform-20260907/harmony/Saydian-Harmony-0.1.3-build7-r12-Debug-development-signed.hap`，13,072,920 字节；SHA-256 `470f12c4b3caac8c9b87c466968c5a127dce924b1ccb5e543dd1096e1e9548ce`。
- Release：同目录 `Saydian-Harmony-0.1.3-build7-r12-Release-development-signed.hap`，9,339,550 字节；SHA-256 `2102b7d3f15b936ef4b0bcb00df333a6c81575dcd81ec69a454f6e5510e20ae8`。
- 两包 `module.json` 实核：`cc.saidian.app.hm`、`0.1.3(7)`、min API `50000012`、target API `260000026`、compile SDK `26.0.0.105`、phone/tablet。Debug 的 `app.buildMode=debug/debug=true`；Release 为 `release/false`。
- 两包签名链与 r11 逐字一致，Profile 与 r11 逐字一致；根签名配置构建前后哈希一致。未修改私钥、签名路径、证书密码或设备登记。
- Profile：`type=debug`、APL `normal`、登记设备数 2；有效期 2026-09-06 10:03:29 至 2027-09-06 10:03:29（中国时间）。不输出设备清单或原始 Profile。
- 非 CA 开发证书指纹：`B8:3E:67:55:0F:43:77:81:AF:8D:BD:E2:99:47:5C:CB:D3:59:17:49:10:B1:C6:2D:D3:11:F3:DE:A9:20:C7:B9`，有效期与上述一致。不是证书链第一张根 CA 的有效期。
- README 和 SHA256SUMS 已更新为 r12 最新、r9/r10/r11 历史保留；GitHub 预发布上传及最终提交由主线程执行。
- 最终 `shasum -a 256 -c SHA256SUMS`：r9–r12 共 8 包全部通过；`git check-ignore` 确认新 HAP 仍为 ignored 产物，`git diff --check` 通过。

## 保留的工具检查失败

- 准备阶段 shell 的未匹配通配符使两次只读搜索未执行；改成准确目录后成功，没有修改文件。
- 误查 `harmony-native/package.json` 不存在；实际工程用 `oh-package.json5`，测试由 Node 直接执行。
- 首次 `openssl x509` 只显示证书链首张根 CA，不能作为应用证书期限；随后解析全部证书并选择 `ca=false` 的开发证书核对，未误将根 CA 的 2049 到期写成应用期限。
- 不从早期 README 的旧测试数或“正式候选”字样推断本次结果；最终以 r12 HAP 内真实签名与本轮测试为准。

## 三端边界文档同步

主线程确认新状态后，独立更新 `COMPATIBILITY-AND-SIGNING-20260907.md`：iOS r6 已覆盖独立启动但新共享 UI 待验；Android 首轮 r6 原生推送未注入被拒收，正确重建门禁待验，P40 当前 r5 已装且 USB unauthorized；Harmony r12 未安装、手机仍 r11 同源。
同时更新 Flutter 双时区各 524/524、鸿蒙各 423/423；较早 iOS 原生 32/32 不写为本轮重跑。workflow 已推送但 Actions 付款/额度 0 步骤失败，与本机测试分开。

更新前再次安全 fetch，保留并行 Flutter 改动；核对实际 iOS r6 IPA SHA 与主线程记录一致，`git diff --check` 通过。本段只同步文档，不构建、不操作设备。
