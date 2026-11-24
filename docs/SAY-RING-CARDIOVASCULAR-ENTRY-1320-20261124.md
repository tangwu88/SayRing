# Say Ring 1320 心血管趋势入口

2026-11-24。基线 `d287bda8d0bf6b448c24d478269cadea0da8452e`，分支 `codex/say-ring-connected-experience-20261123`。

- 华为 PPA-LX3 上读取到 1.0.15（1319）及实际安装包，核对同签名覆盖，首次安装时间与应用 UID 一致。打开「健康」确认页面有睡眠概览，首屏没有「心血管趋势」。源码将入口及本机读写绑定到 `ringExperience`，该开关依赖生产工厂只在 iOS 启用的健康发行策略。
- `app_controller_ring_experience.dart` 为心血管趋势提供 iOS 与 Android 共用的入口和本机读写条件。各指标继续按发行策略读取，U19 仍按实测型号固件、双数值和本机云端读回条件核对。
- `dashboard.dart` 把「心血管趋势」放在「健康」页上方，紧跟用户信息，可独立于睡眠和设备连接状态进入。
- `ring_experience_test.dart` 从「健康」页实际点击。在 320 dp、两倍字号下覆盖 iOS／Android 的中文与英文、空字段、本机保存及单条记录图。改动前两项 Android 用例因入口缺失失败。格式化、diff 检查及改动后定向八项通过。
- Flutter 静态分析无问题。UTC 和 Asia/Shanghai 的全量测试各 2,481 项通过。Android Debug、QA Release 与 iOS Debug、Profile 均编译通过，包名为 `cn.saydian.ring`，构建号 1320。
- Android Debug 沿用华为现装版本的证书，签名后检查安装包内容及双 ARM ABI。首次摘要脚本遇到 Python 3.9 缺少 `hashlib.file_digest`，用分块摘要重跑后完成校验。机主确认安装后覆盖成功，从手机读回的 APK 与本地已验签 APK 一致，首次安装时间及应用 UID 一致。
- 首次冷启动的界面抓取早于健康首页渲染。等页面就绪后在华为首屏点进趋势页，实测近 7 天默认选中、切换近 30 天、打开参考值的两个输入框、取消并切回近 7 天。验收只查看现有记录，真机未写入测试血压。
- 覆盖前后取样的持久文件路径除 Flutter 资源时间戳外一致。华为正常入口已重新附加 Flutter 调试器，第一次附加时移除了当前命令不支持的 `--no-pub` 参数。iOS 验证范围为两种构建和自动回归。
