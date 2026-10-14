# 最新代码 Android 正式构建与保数据安装

- 用户要求更新最新 Git 后安装到手机。修改前读取 AGENTS、国际交接、最新 1064/下载记录与回归约定；fetch 成功，从 5463cf1 快进到 6c18ff541d84a999377ca7e46a2338a29f573e61。仅记录和打包，不改运行时代码、平台范围、供应商参数或后台配置。
- App 主目录的原有文档改动先以 Git stash e05b793f90c81b23e31c56165fc87703c7f4655c 做可恢复检查点，快进后恢复，原文件 SHA-256 未变。构建目录创建 codex/android-release-install-20261014。
- 后台仅同步本地代码到 a5198b8692cb1355ab60b4c10e34af79f0242dd9，新分支 codex/local-git-sync-20261014；五个原未跟踪草稿以检查点 b98407757a7b4f26fd3bf343707b75cbdc6a708a 保留并逐文件哈希确认恢复。未触发后台部署。
- 起初 ADB 未发现手机，用户连接后确认华为 JAD-AL00 在线，当前 Say Ring 1.0.0/1016，firstInstallTime 2026-10-06 14:32:30。计划使用原正式证书覆盖升级 1.0.0/1065，不卸载、清库、解绑或修改真实健康数据；安装并不代表全部设备功能验收。
- 使用原受保护脚本 `E:\saydian-release-signing\Rebuild-SayRing-20261006.ps1 -BuildNumber 1065 -OutputDirectory E:\SayRing-market-artifacts-20261014\release-1065`，串行执行分析、双时区全量测试、Debug、原生单测和生产签名 Release/包信息验证。极光保持现有配置；签名材料和构建产物不进入 Git。最新 iOS 活动/睡眠边界原样保留，本轮不构建或安装 iOS/鸿蒙。
- 初次读取快进日志混合输出过长，后续按文件分段读取；没有据截断输出省略产品/账号/签名边界。构建、验证与安装结果待完成后追加，不把历史 Mac/QA 结果当作本轮正式验证。

## 本轮验证

- pub get 成功，analyze 零问题；UTC 和 Asia/Shanghai 全量 Flutter 测试各 1245/1245 通过。Android 双 ARM Debug 构建通过，147.8 秒；原生单测命令 2m33s 成功，XML 复核 51/51 无失败、错误或跳过。
- 原生产证书 Release 构建通过（419.6 秒）。Verify-SayRingAndroid 验证 v2 签名、包名 cn.saydian.ring、1.0.0/1065、targetSdk 36、双 ARM、16KB zipalign 及生产极光 manifest 成功。证书 SHA-256 81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de，MD5 09d14504fd119ae833b2aaaaeecc13fe，与旧正式包一致。
- APK `E:\SayRing-market-artifacts-20261014\release-1065\SayRing-1.0.0-1065-release.apk`，69,816,719 字节，SHA-256 5C5F495520EEBAD897ECA7423958DFA95A9F65E2AA728C9FD0FF8FEB10F65863。包与所有原始日志仅保留仓库外。
- 补充实际 releaseRuntimeClasspath 报告第一次被 Gradle stop 命令中断，未运行到 ABI gate；保留 android-release-dependencies-initial-failure.txt，没有改变源码或关闭校验，按相同报告/ABI 命令重跑。没有为了重试清缓存、终止其他构建或重置数据。
- 安装前再次 fetch 确认 origin/main 仍为 6c18ff5，源码未发生漂移。ABI 最终复核、同签覆盖安装及启动状态后续追加；本輪没有执行 iOS/鸿蒙构建、市场上传、后台部署或健康/运动实物测试。

- 依赖报告重跑成功（1m7s），实际 APK 双 ARM ABI gate 通过，只使用既有锁定 JPush 受控例外；临时 key.properties 已清理，APK 哈希再次相同。
- `adb -s <已确认手机> install -r <1065正式APK>` 正在等待华为系统确认；只读窗口状态显示 AOD 息屏和 InstallStaging，包回读仍为 1016，不宣称安装完成。仅发送 KEYCODE_WAKEUP 唤醒屏幕，并请用户解锁/确认；不读取密码、卸载、清数据或操作戒指。最终安装/启动与首次安装时间待确认后补记。
