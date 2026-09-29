# 2026-09-29 HR05 提醒、运动、关爱与客服

## 修改前检查

- 当前仓库：`E:\SayRing`，分支 `codex/home-health-device-update-download`，基线及 `origin` 分支均为 `2627a248774b970f85cfddcf1aa8f7fedfdd8573`；已完成 fetch 和快进检查。
- 工作树在本轮操作中发现 `docs/SAY-RING-YOUTHFUL-LUCKRING-UI-20260928.md` 的既有空行改动，保留且不纳入本轮提交。
- 已阅读 `AGENTS.md`、国际版交接、最新 HR05 / 双 SDK 记录、跨端复盘与回归清单。
- 手机 LuckRing 实测确认：状态提醒包含久坐、喝水、吃药、闹钟；消息/来电和自动健康检测有独立入口；SDK 文档确认消息/来电、久坐/饮水及自动检测间隔指令。未取得药物/闹钟完整协议前不猜测实现。
- 用户确认客服只参考页面样式，联系方式从后台配置；随后要求补地图后台配置并选择高德地图，Key 稍后录入。

## 原因、范围及预期

- HR05 原生提醒、频率指令未接 App 设置，导致入口不工作；补全 Android CoolWear 桥、通知监听与 Flutter 功能入口，仅已握手 HR05 生效。
- 关爱设置固定列出所有健康项目，可能展示戒指不支持的项目；按当前真实能力过滤，不在能力未知时开放编辑。
- 运动页只读本地今日记录，且运动详情缺少配速/心率时间记录；进入和下拉时同步，保存运动轨迹、心率样本，按实测距离与运动时长计算配速。地图仅在国际后台高德 Web 服务 Key 发布后通过第一方接口加载，失败时明确显示轨迹示意，不冒充地图。
- 国际版客服只显示不可用；读取 `/global/api/saydian-app/v2/support/config` 的公开已配置联系方式。无配置时继续安全地显示不可用，不沿用国内固定号码。
- 涉及：`android/app/src/main/java/.../CoolWearRingBridge.java`、通知监听、Flutter domain/services/UI、测试及本文。

## 验证记录

- 首次执行 `dart format`/`flutter analyze`/定向测试失败：Flutter 未在系统 PATH；改用项目工具链 `E:\saydian\.toolchains\flutter\bin\dart.bat` 与 `flutter.bat`，格式化成功，静态分析无问题，定向 34 个测试通过。
- `TZ=UTC flutter test --no-pub --reporter compact`：全量 897 个测试通过。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter compact`：全量 897 个测试通过。
- 最后调整运动地图预览的请求缓存后再次运行 `flutter analyze --no-pub`、定向测试，以及 UTC/Asia/Shanghai 两轮全量 `flutter test --no-pub --reporter compact`：均通过；两轮退出码均为 0。
- 关爱指标与国际后台契约交叉检查发现皮肤温度需映射为 `temperature`，压力不在关爱服务支持范围；已修正并增加专门测试，避免显示后保存报错。
- `android/gradlew.bat :app:testDebugUnitTest --no-daemon`：通过，300 项 Gradle 任务中 11 项执行；现有插件弃用警告未阻断。
- `flutter build apk --debug --no-pub`：通过，`build/app/outputs/flutter-apk/app-debug.apk`，186184705 字节。
- `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub`：通过，`app-release.apk`，70046318 字节、SHA-256 `E6710DB02811A01AC8B4822F6832F009518236B268B355D1AD4CC8E935DD4183`。`apksigner verify --print-certs` 确认为 Android Debug 签名，仅 QA 使用，不作为正式商店包。
- `git diff --check`：通过；既有行尾规范提示不影响差异检查。真机仅只读确认设备在线，当前用户在微信中，未覆盖安装/打断会话，HR05 真实提醒与运动联调仍未验收。
- iOS 源码只读检查未找到 HR05/CoolWear 对等桥；本轮仅 Android 原生提醒实现，iOS 未接通。iOS 构建需要 macOS/Xcode，本 Windows 环境无法执行，不能视为通过。
- 源码提交 `bbc8956` 后，常规 `git push` 两次因 GitHub 443 连接超时失败；先只读核对远端仍在原 SHA，再用单次命令 `git -c http.version=HTTP/1.1 push` 成功将功能提交快进推送到当前分支与 `main`，`git ls-remote` 核对两者均为 `bbc8956`。本日志的补记将另作仅文档提交，同样需要核对远端。

## 未验收边界

- 实际来电、短信/应用通知以及久坐/饮水提醒须在 HR05 真机并获得系统通知权限时逐项验证。
- 吃药/闹钟提醒尚未接通；高德底图代码已接入但 Key 未配置，真实地图联调未验收；iOS CoolWear/HR05 原生桥仍需另行实现并在 macOS 与 iPhone SDK 环境验收。
- 客服联系方式须由国际版后台发布 `global_support` 公开配置后才能在 App 显示。

## 2026-09-29 真机覆盖安装补记

- 用户要求继续安装到手机。本轮先核对仓库：`HEAD`、`origin/main` 和当前远端分支均为 `6a202e7dd6534c4bf281ec434ced2935d103295b`；保留既有界面文档空行改动，不纳入提交。
- 安装包：`build/app/outputs/flutter-apk/app-release.apk`，`cn.saydian.ring`，`0.1.21+1004`，SHA-256 `E6710DB02811A01AC8B4822F6832F009518236B268B355D1AD4CC8E935DD4183`；`apksigner verify --print-certs` 通过，属于 QA 调试签名包，不能作为正式分发包。
- 华为 Android 真机在安装前已存在 `cn.saydian.ring` 同版本包。执行 `adb install -r`，系统安装确认后返回 `Success`；未卸载、未清除用户数据。安装后 `dumpsys package` 显示 `versionCode=1004`、`lastUpdateTime=2026-09-29 18:48:09`，进程存在且前台窗口为 Say Ring 主页面。
- 本次仅验收覆盖安装与启动，不把已安装等同于 HR05 提醒、运动轨迹或高德真实 Key 联调通过。
