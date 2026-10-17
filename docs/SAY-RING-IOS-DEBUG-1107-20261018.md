# iPhone 真机 Debug 1107

## 范围和基线

用户要求开启苹果版检查调试。仅处理 Say Ring 与当前连接的 iPhone 15 Pro Max，不修改商店审核、服务器、Android 或其他 App。
工作树原为干净的 `4dee4e66d1afc362b9a5b8bf08ced603c91dde5a`；fetch、`git pull --ff-only origin main` 无新变化。
已阅读 AGENTS、交接、复盘、回归清单及最近安装/调试记录。本轮没有修改产品运行代码、依赖锁或原始 SDK。

## 真机及数据保护

CoreDevice 确认为真实 iPhone 15 Pro Max / iOS 26.6、wired / paired / connected，开发者模式与 DDI 可用，手机已解锁。
CoreDevice 的精确及完整 App 清单均异常返回空数组；不把空数组当作未安装。通过原已配对的 InstallationProxy 查到 `cn.saydian.ring / 1.0.2 / 1101`，并核对同一 Runner 进程路径。

先保存运行时副本，再正常停止已核对的旧 App，复制其私有容器并生成逐文件 SHA-256。安装前副本为 48 文件、32,833,843 字节。
只覆盖安装，不卸载、清库、退出个人账号或解绑。没有恢复演练，不将容器副本当作完整 Keychain 备份。

安装后再次复制容器：Documents 和 Preferences 既有文件哈希一致；数据库、JCore 缓存哈希有变化，系统启动快照被替换，并出现空 SDK 日志。
保留前后副本和差异，不宣称全容器逐字节相同，也未完成数据库逻辑全量比对。实际启动后原账号、资料、绑定和已有活动记录均可读。

## 构建及安装

开始时没有其他 iOS 构建。磁盘约余 3.7 GiB，未清理其他项目、原材料或旧归档；离线 pub get 成功，受版本控制文件没有因此变化。
使用仅含 `IPHONEOS_DEPLOYMENT_TARGET=15.0` 的私有 XCODE_XCCONFIG_FILE；正常生产入口 `lib/main.dart`，生产 API 与既有 no-push 配置。

实际命令为 `flutter build ios --debug --no-pub --target=lib/main.dart --build-name=1.0.2 --build-number=1107 --dart-define-from-file=config/ios-app-store-no-push.json`。
Xcode 构建成功，38.1 秒；SPM 插件兼容和微信模拟器 arm64 提醒仍存在，不影响本轮 iphoneos 构建，未修改闭源框架。

严格深验签通过。产物为 `cn.saydian.ring / 1.0.2 / 1107 / iPhone / iOS 15.0`，原团队 W7SXQ4A226、`get-task-allow=true`。
开发描述文件包含指定真机，有效至 2027-09-30。未更换包名、创建证书或将 App Store 分发 IPA 当作 Debug 包。

独立冻结的 Debug IPA 为 58,084,780 字节，SHA-256 `9d4a7de1557671dcb6c29bcbfda59fbcc5ac2f03d4cf9afa0160c6cdee53026b`。
devicectl 覆盖安装返回成功，InstallationProxy 回读 1.0.2（1107）。不使用旧二进制作为构建失败回退。

## 实际调试结果

通过 `flutter run --debug --no-pub --target=lib/main.dart --use-application-binary=<本轮独立 IPA>` 启动；安装/启动 19.8 秒，保持 Flutter / LLDB 附加。
VM / isolate 实际读取成功：一个 main isolate、runnable=true、Resume，根库为 `package:saydian_app/main.dart`，Inspector 可用。

实际发送 `r`，回执 `Reloaded 0 libraries in 363ms`；未改运行代码，0 libraries 符合预期。
读取当前 AppController，确认原登录、资料、绑定、健康记录存在，启动结束；QRing 处于连接状态且能力对象已返回，通用 AI 为 false。

CoreDevice 现场截图显示正常首页、头像昵称和已有活动卡片，无白屏或 Flutter 错误页。当前睡眠概览显示暂无记录，不补造数据或把它记为真实夜睡验收。
本轮日志检查未见 `Unhandled Exception`、`EXCEPTION CAUGHT BY` 或 `Lost connection to device`；不扩大为全页面、长期后台或全部戒指型号验收。

DevTools 面板首次通过应用工具打开只返回 queued；随后在当前浏览器实际打开并确认 Debug 连接，Memory 页与 main isolate 可见。
DevTools 的 CPU 标签为 simarm64，但物理设备身份独立由 CoreDevice、配对目标及其实际安装/进程确认，不以该标签冒充模拟器或其他真机。

交付前一次额外 HTTP 只读复核超时，同机另有 Health App 进程；不凭进程并存判断故障根因，也未结束其他 App。
仅将 Say Ring 切回前台后，VM、main isolate 和控制器只读检查再次通过，原账号/绑定、QRing 连接和活动记录仍可读。

## 辅助工具失败及边界

首次把包含 Date/Data 的完整描述文件转 JSON 失败，改为按字段提取；私有 Node 路径曾未解码中文 URL，改用 fileURLToPath 后核验通过。
VM URI 为 WebSocket，改为对应 HTTP 读取后 getVM/getIsolate 通过。表达式求值返回“无编译服务”，改用 getObject 只读已存在字段；这不是 App 运行异常。

本轮没有运行 flutter drive、修改设备设置、OTA、退出账号、拍照、生成或上传 AI 报告，也未重新采集真实睡眠。
没有产品代码修改，未重跑此前完整 Flutter/Android/Profile 发布矩阵；本轮实际验证限新 Debug 构建、签名、安装、VM、热重载、首页和只读状态检查。

调试会话保持运行，不发送 quit/detach。Debug 必须保持工具附加；脱离调试器的独立桌面启动，应使用 Profile、TestFlight 或 Release，不能据此判断 Debug 闪退。
所有容器、实际健康值、用户截图、设备唯一标识、签名材料和调试认证 URL 仅保存在权限 0700 的忽略目录 `.build/ios-check-debug-20261017-35NXIe/`，不提交到 Git。

本轮交付只提交本文及记录索引，正常推送当前 Say Ring 分支；不强推或覆盖主线。当前构建源码为上述 4dee4e6，文档提交不改变运行代码。
