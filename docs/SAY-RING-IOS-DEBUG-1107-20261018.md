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

## 同日续检：恢复有线附加与睡眠缓存核对

用户继续要求 iOS 检查。起点为干净的 `312d0a6`，fetch、当前分支 fast-forward 检查均无新变化；两次后续提交仅为上文记录，运行源码仍为 `4dee4e6`。
InstallationProxy 回读现有 App 为 1.0.2（1107）。本次没有重新构建、安装、卸载、清库、登录、解绑、替换 SDK 或改动商店审核。

此前 Flutter / LLDB 会话已结束，先保存本次运行中容器副本。该副本不是停止后的一致性快照，也不包含完整 Keychain 恢复保证。
正常启动现有 App，附加原厂 Flutter LLDB helper；保持独立的 LLDB、USB 转发和 Flutter attach 会话。

### 附加失败与恢复

首次 LLDB 命令文件在异步 attach 尚未结束时执行 continue，返回 `Process must be launched`。重试改为等到真实 SIGSTOP 后再继续，未修改 App 代码。
本地网络地址连接 VM 超时；通过已配对设备的 usbmuxd，仅向 127.0.0.1 转发实际广告中的目标端口后，getVM 实际返回成功。

直接手工调用 SDK 的 iproxy 未携带 Flutter 提供的 DYLD_LIBRARY_PATH，先后报缺少 libusbmuxd / libimobiledevice-glue。
这不证明 Flutter SDK 本身损坏；未修改系统库、Flutter 缓存、VPN 或全局环境，最终使用既有 pymobiledevice3 的 USB 转发。

核对本机 Flutter 源码后确认：显式指定 host-vmservice-port 时不会自动创建转发，须让该端口确实存在，再以正确的目标端口和认证路径附加。
attach 不支持 vmservice-out-file；相关尝试均保留日志，没有把失败参数或短暂 HTTP 200 记为稳定调试。

重试中此前 Runner 曾以状态 0 退出，无对应故障栈；随后只重新启动现有安装，并重新读取该进程的 mDNS 端口与认证信息。
最终 Flutter 实际完成文件同步并显示交互命令，VM / main isolate / Inspector 多次读取成功。发送 r 后回执 `Reloaded 8 of 2233 libraries in 1,132ms`。

最终复查未见 Lost connection、Flutter 未捕获异常、原生 EXC_BAD_ACCESS / SIGABRT / SIGSEGV 或目标进程退出。
仅清理本任务已不用的两个旧 USB 转发，不结束其他 App 或其他调试会话。DevTools 打开请求返回 queued，不能据此宣称本次浏览器面板已可见。

### 真实只读结果

真实首页截图正常，无白屏或错误页；原登录、资料和已有健康记录可读。当前挂载的睡眠概览不处于加载或失败状态，且引用了已保存的 SleepTimeline。
通过 VM 只读字段核对真实分段：起止有效、没有重叠，浅睡 / 深睡 / REM 合计与首页使用的汇总值一致；清醒、未知和未佩戴未计入。

这是当前已保存样本的结构一致性检查，不等同于重新佩戴采集、原厂 App 对照、小睡或睡眠详情页的完整真机验收。
当前控制器只有一个实例；已同意隐私、未切换账号、恢复未暂停，但 rememberedDevice、connectedDevice 和 capabilities 均为空。

手机随后显示设备页“添加智能设备”，与控制器状态一致。没有可用于当前账号自动恢复的精确目标，不擅自绑定附近其他戒指或重置账号数据。
与续检前 Preferences 对比，仅少了 SDK 的 QCLastConnectedIdentifier；不能把此历史 SDK 缓存当作账号隔离的绑定，也不能凭此认定全部绑定数据已保留或丢失。

本次只被动核对首页及设备页，不将 IndexedStack 中页面存在或自动测试通过算作逐页真机通过。
未执行查找振动、遥控拍照、手势写入、监测设置、充电插拔、真实距离重连、OTA 或 AI 上传；其他型号与上述硬件效果仍待验。

### 本次自动检查

- `flutter analyze --no-pub`：零问题。
- 睡眠、iOS 展示、设备能力及恢复等 8 个文件的定向测试：84 项通过。
- `flutter test --no-pub`：1259 项全部通过。授权文档版本变更用例打印的预期拒绝栈不是用例失败。
- 7 个 Node 桥接 / 隐私 / 数据保护测试文件：37 项通过，无跳过；包含 macOS Foundation 实际编译执行的 91 条活动 / 睡眠策略断言及 Swift 导入类型检查。

上述原生策略为主机执行，不冒充 iOS 真机 RunnerTests 或闭源 SDK 硬件验收；未重复执行 iOS / Android 发布构建。
本次没有产品代码修改，只补充验收记录。私有容器、截图、健康值和调试认证信息均留在权限 0700 的忽略目录，不进入 Git。
