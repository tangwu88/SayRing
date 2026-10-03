# Say Ring CoolWear/LuckRing 型号发现

## 原因与修复范围

- 用户报告 HR01、HR05、K80、R7、R7Y、R7Pro 找不到，并明确这些型号使用 CoolWear/LuckRing 方案。基线为 536be938d328a37bbca904c5806b822b54edaac1，工作树干净；只修改 Say Ring，不改其他 App、账号、绑定或健康数据。
- Flutter 和 Android 原生名单仅包含 HR01、HR01- 与精确 HR05，K80/R7 系列在两个层级都会被过滤。现同步接收六个确认型号，忽略大小写/首尾空格，并接受数字或十六进制技术后缀；相邻未知型号、其他 SDK 名称继续拒绝。
- 型号只用于候选 SDK 路由。选中后仍要求 CoolWear 真实连接、设备信息及功能位回调；没有放宽能力、伪造已连接或把未知数据补零。R2 系列继续 QRing，不能串用 SDK。

## iOS 事实与边界

- createProductionWearableBridge 仅在 Android 注册 CoolWear，iOS 当前没有对应原生实现。因此 iOS 找不到上述系列不是单纯名单问题，不能以 Android 补丁声称苹果端连接成功。
- 现有 AAR 的来源记录为 Android&iOS_SDK20260910.zip，但当前 Mac 的相关工程、Downloads 及文件名索引未找到原始压缩包或 CoolWear iOS SDK；旧 SDK 调试记录来自 Windows。旧 QRing 微信临时路径当前也已不存在，不修改或重建原始素材。
- 未复制或安装第三方逆向 App，不假装 QRing/Yucheng 是 CoolWear。厂商 iOS SDK、Demo、真机服务与握手证据取得后，才可实现和验收对应苹果端桥。

## 验证记录

- 首次新增路由测试编译失败：误用了夹具不存在的 devices 参数和 _bridge 帮助函数。改为现有 scanned 夹具及 RoutedWearableBridge 后，定向 33/33 通过，包含六型号、大小写、技术后缀、相邻型号拒绝与 SDK 隔离。
- analyze 0 issue；全仓库 Dart 格式检查 180 个文件、0 改动。Android 原生重新执行通过，名称用例从 1 增至 3，全套计 39 项，失败/错误/跳过均为 0。
- 两时区全量测试与 1029 双端构建结果后补，不沿用 1028 包冒充本轮型号修复包。名称测试均使用合成标识，未实际扫描或切换用户绑定。
- iPhone 在已安装 1028 的三次进程检查后变为 unavailable，第四次启动未执行成功；未改用别的手机、卸载或清数据。当前不能补真机 UI/型号连接验收。
- 文档首次补丁因交接标题上下文不匹配而失败，未改写旧交接内容；核对原文件后按新增段落补记。

## 1029 构建回归结果

- UTC 与 Asia/Shanghai 全量 Flutter 各 1098/1098 通过，0 失败或跳过；包含此前睡眠 AI 刷新修复。Android 原生 39/39 已核对本轮 JUnit XML，不沿用旧计数。
- Android Debug 与内部 QA Release 均为 1.0 (1029)、cn.saydian.ring、armeabi-v7a/arm64-v8a。两包验签及 16 KB 对齐通过；SHA-256 分别为 a45718ccbcb1b4dad7bb6c14fd21375862df5cabeaaffe01e5a9bcb2537b8b93 与 8469618136ad973216ee465b8ce0822ce70533da61530eab97ffc04d266bd092。内部 QA 不是正式市场签名。
- iOS Debug 与开发 Profile 串行构建成功，Profile 为 1029、cn.saydian.ring、UIDeviceFamily=1，签名验证通过。验证包留在 .build/SayRing-1.0-1029-Profile.app，不覆盖 1028 产物，不上传审核。
- 可重建的本轮临时 RunnerTests DerivedData 已清理，1028/1029 安装包和验证日志保留。没有清理用户健康数据、其他工作区或原始 SDK。
- 当前 devicectl 显示目标 iPhone unavailable，adb 没有连接设备。因此 1029 尚未安装，六型号均未做本轮真实广播/握手验收；iOS 原生 CoolWear SDK 仍缺失，这一结果不得写成苹果端已支持。

## 补充核对

- d89f28eb819a8dd7e637ae07eb3d047d42c456d3 已推送至当前 Say Ring 分支。远端 CI 37116337692 全部成功：双时区质量/Harmony 检查、Android Debug/Release 与原生测试、串行 iOS Debug/Profile/Release 和 RunnerTests 编译。CI iOS 包未签名，RunnerTests 编译不是完整 XCTest 执行。
- Profile 1029 Runner SHA-256 为 e34d6eaaf6d0e0678cc3e67672e5064d05e3ee9a919896ab5ae3f5cdbf3762ea。构建号、仅 iPhone 与签名已验证，但手机未在线，不能用构建成功代替安装或真实连接验收。
- 只读检查原 AAR 的 BluetoothHelper、Bluetooth_5SDK_Processor 与 CEScanDev_4_Android5：当前无参数 startScan 没有 HR01 名称白名单；SDK 仍要求可解析的厂商广播信息和设备名称。因此本轮未绕过厂商广播/握手验证，也未声称所有固件广播已兼容。
- Documents/Desktop/微信文件目录的补充文件名搜索耗时较长，已取消，不能写成全部目录搜索完成。此前相关工程、Downloads 与索引未找到 iOS SDK 的结论保留，仍不能从 Android AAR 推导 iOS 支持。
- 首次直接调用 adb 因当前 shell PATH 没有该命令而失败，改用 android/local.properties 指向的现有 SDK /Users/saydian/Library/Android/sdk/platform-tools/adb 后正常执行，设备列表为空；没有重复安装工具或改动系统权限。
- 补充使用 rg --files --hidden --no-ignore --maxdepth 12 查询相关工程、Downloads、Documents、Desktop 的 SDK 压缩包/CEBLE 文件名（排除 node_modules/build/.git/.gradle），未找到 CoolWear iOS 原包。微信文件目录 maxdepth 8 查询找到 QRing 原 ZIP 及重复副本，均只读保留；另一个收藏子目录返回 Interrupted system call，命令 exit 2。因此不能写成完整扫描或证明所有目录均不存在 CoolWear SDK，QRing 原包也不能替代它。
