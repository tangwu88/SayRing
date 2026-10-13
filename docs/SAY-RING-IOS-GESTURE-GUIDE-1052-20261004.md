# iOS 手势使用说明与 1052 验证

## 范围与来源

- 基线 571f0e0，当前工作分支 fetch / pull --ff-only 后一致。仅 Say Ring，保留 cn.saydian.ring、数据、图标和现有 App Store 审核。
- 用户要求苹果版手势控制参考 LuckRing 增加指导。说明结构为配对准备、六种模式用途、操作方法、无反应排查；独立只读小组件，不增加依赖或图片，不新增 BLE / 网络 / 权限操作。
- 原厂 `CE_GestureCmd.h` 明确枚举 0–5：关闭、短视频、音乐、阅读、拍照、电话。SDK 无可靠当前模式读取，勾选仍只表示本次连接收到的指令 ACK。
- [LuckRing 原厂触控款说明书](https://p.globalsources.com/IMAGES/PDT/SPEC/499/K1228167499.pdf?ver=6101079381) 的控制开关 / 智能拍照段落已读取并检查图示：选择对应应用场景、退出后关闭以避免误操作和额外耗电。该文档标明 ColorRing 01，并不证明 HR01 等所有型号采用相同点击次数；未把单击 / 双击 / 三击映射套到当前戒指。
- SDK `CEProductK6.h` 区分 App 通信握手和系统配对；指导用户仅在出现并核对目标的系统配对提示时操作，不提供陌生设备配对或授权绕过。
- 拍照说明按本 App 实现：系统手势模式与“摇一摇拍照”分开；App 拍照须停留拍照页。电话模式不等于来电提醒，不扩大缺失能力。

## 修改与首轮验证

- `lib/ui/widgets/ios_ring_gesture_guide.dart` 新增折叠说明和模式短提示；`prototype_pages.dart` 仅 iOS 能力已就绪的手势页引用。Android 入口 / 原有能力门禁不变。
- 格式化仅四个修改 Dart 文件；首轮定向测试 94 通过 / 2 失败：两项新平台模拟测试在 addTearDown 之前触发 Flutter 全局变量不变量检查。改为 finally 即时恢复平台值，不改生产逻辑、不删除断言。
- 重跑 `flutter test --no-pub --concurrency=1 test/ios_ring_gesture_guide_test.dart test/ui_shell_test.dart`：96 项通过。覆盖 iOS 展开、Android 无说明、打开说明不写模式、不伪造勾选；320px / 2 倍字与 390px 页面可滚到最后一步，无异常。
- `flutter analyze --no-pub`：4.7 秒，零问题；`git diff --check` 通过。
- `node --test tool/client_package_contract.test.mjs tool/measure_ios_bundle.test.mjs tool/test_coolwear_ios_integration.mjs tool/test_native_log_privacy.mjs tool/drive_ios_preserving_data.test.mjs`：34 项通过。
- `python3 -m unittest discover -s scripts/release -p 'test_*.py'`：31 项通过。Foundation CoolWear / QRing 编译及执行均通过（合成输入，不当作实物手势通过）。

## 新连接手机

- 用户追加要求：安装到新连接的另一台 iPhone，安卓也已连接。读取实际设备：iPhone XR / iOS 18.7.9，华为 PPA_LX3 / 已装 1.0.0 (1043)。不切回已离线的 iPhone 15 Pro Max，不卸载或更换包名。
- XR 初次 CoreDevice 应用查询失败：未完成配对；Xcode 设备页随后显示 Developer Mode disabled，再查应用明确错误 10005。现有 1051 开发描述文件亦未包含 XR。只显示开发者模式入口，不能绕过手机确认或把旧包安装当通过。
- 原始 ZIP 已不在先前 Downloads 路径；使用仓库保留的 SDK 头文件和来源校验记录，未修改原始素材。网页手册和临时图示只存忽略目录，不打包到 App。

## 最终回归与交付

- `TZ=UTC flutter test --no-pub --concurrency=1`：1179 项 / 147 秒通过；`TZ=Asia/Shanghai flutter test --no-pub --concurrency=1`：同一源码 1179 项 / 110 秒通过。
- Android `JAVA_HOME=.../temurin-17.jdk/Contents/Home ./gradlew :app:testDebugUnitTest --max-workers=1`：14 秒成功，XML 合计 40 tests / 0 failures / 0 errors / 0 skipped。
- 所有构建暂停时，确认 `.dart_tool/flutter_build` 为本项目非链接生成目录后清理约 1.7 GiB 可重建编译缓存，空间由不足 1 GiB 恢复到约 2.5 GiB；未删除安装包、原生 SDK、签名、源码或备份。
- 安卓现有 APK 已只读拉取保留，签名 SHA-256 与本机 1051 Debug 一致。已通过 run-as 私有备份应用容器 tar（103 MiB，42 条目录 / 文件），备份与 APK 均在忽略目录，未上传或加入 Git。
- iOS 1052 unsigned Debug 构建 56.6 秒成功。指定 XR 的签名 Profile 构建 6.8 秒失败：Xcode 无开发者账号、旧描述文件不包含 XR。没有把旧 1051 或无签名产物装作新版已安装。
- iOS unsigned Profile 回归 122.9 秒成功，66.3 MB；产物 Info.plist 为 cn.saydian.ring / 1.0.0 / 1052 / UIDeviceFamily [1]。codesign 明确无签名；编译通过不等于可安装，不上传该产物或替换审核包。
- 写入额外真机 UI 测试文件时磁盘空间不足，文件未生成。确认无构建后，仅清理本项目 `merged_native_libs` / `stripped_native_libs` 约 502 MiB 生成缓存；原始素材、安装包、数据和签名均保留。
- 现有 Apple API key 的只读授权检查返回 401，未新建、撤销或公开凭据。Apple 网页后来恢复会话：按现有列表保留全部 40 台设备完成年度更新，再注册 XR；平台返回 Registration Complete，但该设备状态为 Processing，页面提示 24–72 小时后可能可用于开发与 Ad Hoc。尚不能为 XR 生成有效安装授权，不绕过苹果验证。
- Android 首次 Debug 构建因缺少锁定版本的 camera_android_camerax 缓存失败；`flutter pub get` 修复缓存后 lock 未变。重跑 Debug 21.9 秒成功；QA Release 66 秒成功，69.4 MB。两者核对 1.0.0 (1052)、cn.saydian.ring、arm64 / armv7、相同旧版签名；QA Release 16 KiB zipalign 通过，仅为 QA 签名，不用于应用市场发布。
- Android `adb install -r` 在手机出现安装风险免责提示时等待，未代接受新条款；手机确认后返回 Success。版本查验为 1052，firstInstallTime 与原版一致，正常 main 启动、进程存在、Flutter attach / Dart VM 服务连接成功。只读检查确认登录会话和原健康记录仍在；实际设备页发现 K80 / HR01 / R21，但当前无连接，不把发现设备等同握手或手势效果通过。
- Android 热重载成功，无 Lost connection 或 Unhandled Exception；保留正常 main 的调试连接，不切换测试入口、不清空记录。手机界面由用户操作时仅只读检查，未代替用户换绑戒指。
- XR 上此前无 Say Ring；没有把旧手机账号或健康数据复制到 XR。当前未安装、真实手势效果和物理充电 / 夜睡等旧待验项不宣称通过。原始截图、备份、VM 对象和签名材料均只留忽略目录，不写入 Git。后续构建结果按实际执行追加。
