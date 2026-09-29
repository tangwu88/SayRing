# 2026-09-29 Say Ring Android 真机覆盖安装

## 范围与基线

- 用户要求将最新版装到手机；本轮未修改应用源码、配置、接口或健康数据。
- 安装前工作树干净，当前分支 `codex/home-health-device-update-download`，本地 HEAD 与上次获取的 `origin/main`、`origin/codex/home-health-device-update-download` 均为 `403051a22f594586964dfd6680034582396af153`。
- 两次 `git fetch origin --prune` 均因 GitHub 连接被重置失败，故不能证明安装时远端没有新提交；“最新”仅指本机已构建的上述版本。

## 安装包检查

- 使用 `build/app/outputs/flutter-apk/app-release.apk`，其 SHA-256 为 `300C26D82E87AFDBD96D982AF5335239170D64F5E5D5FADA10D3D5C3D7A1BAD4`，与 [QRing 接入构建记录](SAY-RING-QRING-MULTI-SDK-20260929.md)一致。
- `aapt dump badging` 确认包名 `cn.saydian.ring`、版本 `0.1.21 (1004)`；`apksigner verify --print-certs` 返回 QA 证书 SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`。该证书不是应用市场正式签名。
- 已连接的华为 `JAD-AL00` 安装前已有同包名同版本应用，上次更新时间为 2026-09-28；本轮使用覆盖安装，不执行卸载或清除数据。

## 真机结果

- `adb install -r` 返回 `Success`；安装后系统显示 `versionName=0.1.21`、`versionCode=1004`、更新时间 2026-09-29 14:27:59（Asia/Shanghai）。
- 通过系统启动入口打开 App，前台为 `cn.saydian.ring/cc.saidian.saydian_app.MainActivity`；启动后约 13 秒进程仍存活。
- 检查当时最近 2000 行系统日志，未发现 Say Ring 的 `FATAL EXCEPTION` 或 ANR。仅确认安装、启动和短时存活，未执行登录、页面逐项检查、后台接口或真实戒指功能验收。
- 未执行 iOS、HarmonyOS 安装；QRing 实机扫描、连接、同步、健康和运动仍待真实设备测试。

## 失败与待验证

- GitHub fetch 两次失败：`Recv failure: Connection was reset`。网络恢复后需重新 fetch 核对远端，再决定是否有更新版本需要重装。
- 本轮安装记录已在本地 Git 提交；推送开发分支时再次无法连接 `github.com:443`，因此记录尚未同步到线上仓库。网络恢复后需要先 fetch，再以普通快进推送，禁止强推。
- 首次 APK 验签命令的 `JAVA_HOME` 指向工具链上层目录，报目录无效；改用真实 JDK 17 根目录后验签成功。
- 该包仅为 QA 签名安装包，不能当作已正式发布或生产验收通过。
