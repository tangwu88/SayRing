# iOS 六项问题修复与验证（1259）

日期：2026-11-06。用户要求核查并修复健康页热量残留、运动实时心率、手势说明、连接自动同步及搜索页刷新；保留现有账号、健康记录、戒指设置。本轮不操作正在审核的 1257。

## 基线与范围

初始工作树干净，`215309b5c6aab5384f2747bb6cdee850214c94ad`。先 fetch，建立 `codex/checkpoint-before-ios-1259-20261106`，再从包含最新共享改动的 `origin/codex/android-latest-1258-20261106`（`a19542c`）建立 `codex/ios-six-fixes-1259-20261106`，避免覆盖 Windows 同事已完成的 Android 修复。

应用仍为 `cn.saydian.ring`，签名团队 `W7SXQ4A226`。未修改 SDK 二进制、云端接口、账号同意版本、绑定清空规则或提醒参数。

## 六项原因及改动

1. 今日活动已去热量，但 iOS 健康目录和显示排序仍包含 calories。移除这两处展示项；原始热量记录、上传和历史存储继续保留。
2. 运动页的心率被旧的 iOS activity/sleep 显示条件隐藏；运动实时回调也未接入。改按当前有效心率读取权限展示，接入厂商 `currentSportInfo`，只接收当前连接/当前运动的真实回包。无值或超过 30 秒不沿用旧心率。移除当前运动的热量块，保留已有运动记录；不以历史测量代替实时心率，不额外开启传感器或提高监测频率。
3. iPhone 短视频配置卡原本限于 tapControl 且有设置回读的设备，因此另一类支持短视频的戒指缺说明。统一按真实支持的短视频模式及已确认开启状态显示；未连接、忙碌、状态未知仍不声称已就绪。
4. 设置路径改为「设置 → 无障碍 → 触控 → 辅助触控」，保留旧版「辅助功能」别名。添加「晃动手指」「双击戒指」两个图示，具体动作按戒指实际支持尝试，不承诺任一动作在任意 App 都有效。[Apple 当前 iPhone 使用手册](https://support.apple.com/zh-cn/guide/iphone/iph96b21954/27/ios/27)。
5. AppController 的 iOS CoolWear 连接和自动恢复分支明确跳过初始同步；原生同步仅校时后等待推送，没有主动读各历史类型。恢复连接后自动同步，维持账号、绑定初始化、手动测量和运动互斥；原生改为 SDK 公共 CE_Cmd 的 REQUEST，只读 9/4 及活动、睡眠和实际能力允许的历史。不夹带校时、提醒、监测或清空写入。旧 hrvSupport 位不能证明新版 61 协议，未知状态单列，不影响已确认范围，也不伪造空值或全量成功。
6. 搜索页发现系统缓存候选就不继续扫描。改为每次进入先读取本轮缓存，再保留候选并自动扫描附近设备；换号、离开或开始连接后，过期查询不重启扫描。

## 历史批次证据与防回归

原厂文档示例采用 remainItemCount=1、curItemCount=1。核对当前未修改 SDK（SHA-256 `f56c39605abded5f57b7ab28f245d67218b9df9e8edbb7fe037755b8cd3ca624`）的 `CE_K6Protocol parseWithHead:body:`：0xe8dc 直接读前两字节，0xe8ec 读第三字节，0xec00 / 0xec40 分别赋给 remaining / current，没有扣减转换。与原始协议及已验证 Android 计数一致：remaining 包含本包，末包应为 1/1，不是 0/1。原 iOS 多加当前包并只等待 remaining=0，会误报未完成。

计数改为 expected=max(remaining)，terminal=(remaining==current)，完成必须去重后条数与 expected 相等。仍保留有界接收窗口，不能用 ACK、信封 9、当日活动 4 或短暂静默冒充完整历史；缺包、格式错误、未收到仍如实返回。未佩戴导致无睡眠样本与同步失败分别判定。

## 验证过程（持续追加）

- 原始工具日志/截图/包：忽略目录 `build/ios-six-fixes-1259-20261106`，业务备份在本机私有 Application Support，未纳入 Git。
- 格式化首次发现运动列表字符串拼接语法错误，已修复。
- 第一次 analyze 发现新增 scanDevices 参数影响一处 Fake 覆写及两处括号风格，已修复；第二次静态分析通过。
- 首轮专项 127 通过、1 失败：旧运动测试直接赋值，无实际事件时间；改为注入真实事件路径并等待 UI 帧，单测通过。未放宽实时心率条件。
- 原生 22 项通过，含 Foundation 实际数据过滤、批次重复/乱序/缺包/非法剩余计数以及只读命令防回归；不代表实物已同步。
- 首次、第二次全量均有 2 项旧手势文案断言失败（2058 通过）；根据实际新版展开说明修正断言，专项双平台通过，最终全量 2060/2060 通过。没有放宽业务门禁。
- XR 在线，初始应用停在生理周期设置底部，首次只找底栏的导航脚本失败；重启普通 App 后可进入设备页，看到原 R21 目标。已建立私有容器备份（119 文件）。未解绑或清数据，已请用户准备 R7 Pro／HR05 或 R7 Ultra 复测。
- 最终 `flutter analyze --no-pub` 无问题，`flutter test --no-pub` 2060/2060 通过；原生 `node --test tool/test_coolwear_ios_integration.mjs tool/test_ios_activity_sleep_policy.mjs` 22/22 通过。原始日志 `analyze-2.log`、`full-tests-final.log`、`native-final.log`。
- 构建均显式使用 `--target=lib/main.dart --build-name=1.0.11 --build-number=1259`，生产配置来自本机私有配置（不提交）。iOS `flutter build ios --debug/--profile --config-only --no-pub` 后串行 `xcodebuild`；Debug/Profile 均成功，核验 bundle、版本、团队、XR provisioning 和深层签名。
- Android `flutter build apk --debug/--release --no-pub --target-platform=android-arm,android-arm64` 均成功；`./gradlew --offline :app:testDebugUnitTest --no-daemon --max-workers=2` 108/108 通过（21 suites）。Release 原发行证书一致、Debug 调试证书一致，双 ARM、版本及包名通过，Release `zipalign -c -P 16 4` 通过。仅用于跨平台回归，本轮未安装或发布 Android 包。
- XR 原位覆盖普通 Profile 1259，未使用集成测试入口、未卸载。安装前后 71 个业务文件逐一 SHA 核对一致，0 缺失、0 改变；119 文件初始私有备份保留。
- XR 普通启动后原 R21 自动连接并进入活动／睡眠同步。后续页面按钮恢复可用；这里只证明连接及同步启动，不凭按钮恢复声称整轮历史完成。
- 第一次六项页面自动核对在“使用说明”失败：XCTest 将整个 Flutter 容器误当作点击目标，且截图处于路由动画。改为精确文字／可见小元素定位并等待动画，不修改 App；第二次 `testSixFixesPages` 通过。实际截图已核对：首页健康数据无热量／单位待确认，设备已连接有同步入口，手势原关闭模式读回正常，说明包含两种动作和新 iPhone 路径。没有切换模式或发送手势设置。
- 320 宽两倍字页面渲染通过；专用手势截图首轮因截图前仍需重绘失败，补等渲染帧后四组通过。补载系统字体仅用于私有截图，未加入 App；合成截图存在字体回退偏差，不作为真实字体效果验收，真机文字以 XR 截图为准。宽度 320／390、字体 2／1、两种控制类型的可读及只读断言均通过。
- 本轮未上传、未送审、未改线上下载。XR 留在普通 1259；现有账号、健康数据和戒指设置保留。

## 仍需实物完成的核验

XR 当前连接 R21，已请求用户准备 R7 Pro／HR05（或 R7 Ultra），截至本轮记录未取得新目标准备确认。以下不能写为已通过：

- R7 自动连接后是否收到完整活动／睡眠批次，手动重试是否仍有真实缺包；未佩戴导致无睡眠样本不能冒充同步完整。
- 运动期间真实心率持续回传。当前仅确认 SDK 回调接入、当前连接隔离、鲜度与 UI 条件回归；没有用静态或历史心率证明实物实时测量。
- R7 两种动作控制第三方短视频 App 的物理效果。本轮不改手势模式，仅核对说明页面与能力门禁。
- 设备搜索的新扫描调用已通过缓存非空、失败重试及离页保护回归；XR 保留现有 R21 绑定，未为测试搜索而解绑。

## 产物对应

iOS 运行时源文件摘要（构建后重新核对一致）：`b8ec69707e3651187b86401d6a018d42bdc8dae5253248f0dddf0bfe33fc07e5`。
Android 源文件摘要（包含 Android 构建配置，范围与 iOS 不同）：`021689bdc79f6a181d31aa1cd7c833f6b00db3bb3f3f0c7b3144ca33bd9e1da6`。
iOS 普通 Profile 主可执行文件 SHA-256：`b477dd3315dd9a8e933e68f7714eb2b2ca80f3196c1ad0d69143301f613d86ae`。
Android Release APK SHA-256：`7a1e28e2fdf3496bf969a082efc7ec5816595b9a3e3b34b930ea829787c5485e`。
完整包和私有验收材料位于本机忽略目录，不把健康截图、设备身份、签名配置或账号文件提交到 Git。

## Git 交付过程

本地实现提交 `eef362d` 后，命令行 push 因 `could not read Username` 失败；改用已连接 GitHub 工具传送同一份已验证文件树，并核对远端 tree 与本地 tree 相等。保留本地原提交检查点，不覆盖 main，R7 实物项继续待验证。
