# 2026-09-30 R22 手动恢复与真机复查

## 修改前检查与原因

- 仓库 `E:\SayRing`；开发分支 `codex/home-health-device-update-download`，修改前本地与远端开发分支均为 `a84404ed647012e6eeb58018d5bc291f02be1236`。执行 `git fetch origin --prune` 后确认 ahead/behind 为 `0/0`。既有 `docs/SAY-RING-YOUTHFUL-LUCKRING-UI-20260928.md` 单行空行改动属于其他工作，保留且不纳入本次提交。
- 用户反馈 R22 再次搜索不到。真机先关闭 QRing 后台进程但不解绑、不清数据；Say Ring 的普通扫描实际发现过 `R22_C493`，说明名称路由和 QRing 扫描回调可以工作。选择后戒指停止广播；随后 Android 系统配对列表也没有该戒指，原先仅枚举系统已配对设备的入口无法恢复。
- 对照用户提供的 QRing Android SDK 1.0.0.76 示例：示例会保存上次设备地址，并直接调用 `BleOperateManager.connectDirectly(deviceMac)`；只有设备能力 `supportBlePair` 为真时才建立系统 Bond。因此“成功连接后不再广播”不等于该戒指一定仍在 Android Bond 列表。
- 本轮不允许任意地址连接，也不放宽后台自动恢复。只增加用户主动点击后，使用当前 App 环境中上次成功握手保存的精确 QRing 标识重新尝试，并继续要求 SDK 基础握手、扩展能力读取成功。

## 本轮改动

- Android QRing 桥新增两类明确分开的手动候选：系统 Bond 列表中的受支持 QRing；以及本 App 上次成功连接后保存的精确蓝牙地址。后者要求完整蓝牙地址格式，只由显式页面操作准备，不能被自动恢复调用。
- 原生连接仍调用 QRing SDK `connectDirectly`，并继续以 `SetTimeReq`、`DeviceSupportReq`、资料写入和能力表为成功边界；Bond 候选在连接前重新核对系统 Bond，地址或能力校验失败时不保存。
- Flutter 路由记录“本轮用户主动选择的精确恢复目标”，仅该目标允许以通用恢复名称进入 QRing SDK；其他未知名称仍失败关闭。正常扫描会清除此临时授权。
- 成功连接后保存设备厂商、精确原生标识和经名称规则验证的设备名；旧版只保存厂商和标识的数据仍可读取。可选详情读取失败不改变 SDK 已完成的连接结果。
- 添加设备页入口“显示可恢复的戒指”，说明其范围为手机系统已配对或曾由 Say Ring 成功连接的戒指；八语文案同步更新。App 版本由 `0.1.21+1004` 调整为 `0.1.21+1006`，避免覆盖安装到已有 1005 时发生降级。
- 增加 Flutter MethodChannel、路由精确标识、错误标识拒绝、环境隔离保存设备名和 Android 蓝牙地址格式单测；更新 QRing 恢复安全约定。

## 验证与失败修复

- `dart format`、`flutter gen-l10n` 通过。首次使用未配置 PATH 的 `flutter`/`dart` 命令失败，改用受控工具链绝对路径后通过。
- 定向 Flutter 测试最终 34/34 通过。首轮编译暴露 Dart 接口类型提升不足，改为显式接口调用后通过。
- `flutter analyze --no-pub` 最终无问题。中间两次分别发现 null-aware collection 写法建议和错误位置，按当前 Dart 语法改为值侧 null-aware entry 后通过。
- 完整 Flutter 测试在 `TZ=UTC` 与 `TZ=Asia/Shanghai` 下各 920/920 通过。
- Android `:app:testDebugUnitTest` 首次因 `JAVA_HOME` 指向 JDK 父目录失败；修正为实际 JDK 子目录后，又分别发现缺少 `ANDROID_HOME` 和本机 QRing AAR 单个 Gradle immutable transform 缓存损坏。停止 Gradle daemon，将报错精确目录移动到 `C:\Users\admin\.gradle\quarantine` 后自动重建，最终 `BUILD SUCCESSFUL`。未删除项目、账户或设备数据。
- Android Debug 与 QA Release 均构建成功。最终 QA APK：`build/app/outputs/flutter-apk/app-release.apk`，包名 `cn.saydian.ring`，版本 `0.1.21 (1006)`，minSdk 26、targetSdk 36；70,144,686 字节，SHA-256 `B76353D9949E500D3A1CD8489DD91C49C4A17006B7064D3880F488CB1C241707`。签名证书 SHA-256 为 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，属于 Android Debug/QA 证书，不是应用市场正式签名。

## 真机状态

- 修改前包在华为手机上确认：普通搜索能出现 `R22_C493`，但连接后停止广播；系统 Bond 枚举为空，说明原恢复入口覆盖不足。未解绑、未清 App 数据、未重置戒指。
- 最终 1006 包准备覆盖安装时，手机从 ADB 列表断开；重启 ADB 服务后仍无设备。因此最终包覆盖安装、“显示可恢复的戒指”读取旧精确绑定、SDK 重连和冷启动后的再次手动恢复仍待 USB 恢复后现场验收，不能把自动化通过写成真机通过。

## Git 与线上状态

- 源码与首版记录提交为 `1abc334cdfa46fd94a887314dfdc969eb3891dc0`。提交前重新 `git fetch origin --prune`，确认远端开发分支与 `main` 均未偏离基线 `a84404ed647012e6eeb58018d5bc291f02be1236`；随后普通快进推送两条远端分支，`git ls-remote` 核对均为 `1abc334`，未强推。既有 UI 文档空行改动继续排除。
- 本机没有 `gh` 命令，无法从终端读取私有仓库 Actions 结果；Git 分支已同步不等于 CI 已通过。
- 本轮只修改 Android/Flutter App，不修改服务端、生产数据库、旧后台或线上配置。推送 Git 不等于应用已发布或生产已部署。

## 待验收

- 手机重新连接 ADB 后，覆盖安装最终 1006 QA 包；验证旧 App 数据保留，点击“显示可恢复的戒指”出现 R22 或通用的上次连接 QRing 条目，选择后完成 SDK 握手并在设备页显示已连接。
- 强制停止并重启 Say Ring，再确认自动恢复仍严格要求系统 Bond；无 Bond 时只允许用户再次点击手动恢复，不做后台自动认领。
- iOS 没有本轮手动恢复实现和真机证据；Android QA Debug 签名也不能用于应用市场正式发布。
