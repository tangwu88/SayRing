# Say Ring 默认中文、隐藏 HRV 与全部运动子页

## 范围与基线

- 时间：2026-09-24（UTC+08:00）。
- 分支：`codex/rebuild-from-handoff`；修改前 HEAD：`97cfbab86249dcca6dcf973ee55d3fd5bfb39df1`。
- 修改前工作树干净；`git fetch origin --prune` 成功，远端 `origin/codex/rebuild-from-handoff` 为 `eefa533f13cbe38a6b8d562b47ed4c0a209f57f2`，本地领先 5、落后 0，未拉取、未覆盖、未强推。
- 用户目标：App 默认中文并隐藏语言选择；隐藏 HRV；运动首页只显示一排 4 项，“查看更多”进入子页面展示全部可用运动。
- 本轮不改 SDK 能力、健康历史、同步、运动协议、服务端接口或数据库；未知值继续保持未知。

## 实施内容

### 1. 默认简体中文并隐藏语言选择

- `GlobalLocaleController` 的无显式语言默认值由英文改为简体中文，仍不跟随系统语言。
- 登录页、验证码登录页和“我的”页移除语言选择入口；通用语言按钮返回空组件，避免后续旧页面误挂入口。
- 八种语言资源继续保留，供已有内部契约和内容本地化使用；本轮不删除翻译文件，也不改变服务端语言参数格式。

### 2. HRV 仅从用户健康入口隐藏

- `shouldShowHealthMetric` 对 HRV 返回不可见，因此健康首页和“全部健康数据”均不再显示独立 HRV 卡片，即使设备实报支持或本地已有 HRV 历史；戒指健康检测设置也不展示 HRV 自动检测开关。
- 身心准备度可用数据计数不再包含 HRV，避免隐藏指标继续影响可见状态提示。
- SDK 能力解析、历史落库、云端同步、ECG 原始客观字段和既有数据均保留，未删除或补零。

### 3. 首页固定 4 项与全部运动子页

- 运动首页不再按屏幕宽度显示 2/4/6 项，也不在原地展开；始终取戒指实报可用模式的前 4 项并排一行。
- 可用模式超过 4 项时显示“查看更多”，跳转到“全部运动”子页面；子页从同一个 `availableSportModes` 读取全部模式，并继续复用原运动会话页。
- 子页在手机、横屏和平板按 3/4/6 列响应式展示；首页仍固定 4 项，大字模式允许名称两行并省略过长文本。
- 新增八语“查看更多/全部运动”文案并重新生成本地化代码。

## 修改文件

- 语言：`lib/l10n/global_locale_controller.dart`、`lib/ui/global_auth_page.dart`、`lib/ui/global_code_login_page.dart`、9 份 ARB 与生成文件。
- 健康与运动：`lib/services/app_controller.dart`、`lib/ui/pages.dart`。
- 回归：`test/global_l10n_test.dart`、`test/ui_shell_test.dart`。
- 交接：`docs/INTERNATIONAL-HANDOFF.md`、`docs/CHANGE-TEST-LOG.md` 与本文。

## 验证流水

### 已完成

- `flutter gen-l10n`：通过；八种声明语言键集合保持一致。
- Dart formatter：本轮 Dart 源码与测试格式化通过。
- 首轮定向测试失败：新增 HRV 保留性夹具缺少必填 `rawVersion`，编译器准确阻止；补 `rawVersion: 1` 后 `test/ui_shell_test.dart` 54/54 通过。
- 语言、登录和 UI 首轮组合测试：语言 11 项、登录相关 9 项通过；UI 首轮失败仅为上述夹具编译错误。
- `test/ui_shell_test.dart`：54/54 通过，覆盖 HRV 已保存但不可见、430 像素首页 4 项、跳转全部运动子页、320 像素首页仍为 4 项。
- 首轮 `flutter analyze --no-pub`：发现移除语言按钮后两处未使用 import；删除后复跑通过，`No issues found`。
- 更新门禁、品牌与原型定向回归：33/33 通过。
- `TZ=UTC flutter test --no-pub`：873/873 通过。
- `TZ=Asia/Shanghai flutter test --no-pub`：873/873 通过。
- Android App 原生 `:app:testDebugUnitTest`：通过；5 份 XML、23 项，失败/错误/跳过均为 0。Gradle 仅报告既有插件的 Kotlin/AGP 迁移警告。
- 隔离账号/只读冒烟工具：78/78 通过；原生日志隐私：9/9 通过。本轮未调用真实短信、注册或生产写入。
- Android Debug：最终源码重建成功，`app-debug.apk`，186,124,921 字节，SHA-256 `510F7FC880348D9189AB4A7716B3725B9C3945681D3B6950FBEF12379C333012`。
- Android QA Release：最终源码以 `SAIDIAN_ALLOW_QA_RELEASE=true` 重建成功，`app-release.apk`，69,332,256 字节，SHA-256 `0928598D89F5A7F2B05457EA83FA1BF7B7AFDC761EA67536746028C015E34117`。
- 两包均为 `cn.saydian.ring`、`0.1.21 (1004)`、minSdk 26、targetSdk 36；`apksigner verify --print-certs` 通过。两包仍使用 Android Debug 证书，证书 SHA-256 `3ae71cff9ad924e28e4e4a5086a8b3dedf4332d9c574b5b564ed08bce2617eae`，QA Release 不是生产上架包。
- 提交前 `git diff --check` 通过；`git fetch origin --prune` 与 `git ls-remote` 均因 `Recv failure: Connection was reset` 失败。只能确认修改前成功 fetch 的远端 SHA `eefa533f13cbe38a6b8d562b47ed4c0a209f57f2` 和当前本地缓存，不声称提交前已复核远端最新状态；未执行推送。

### 华为真机

- 设备：`JAD-AL00`，ADB 序列号 `L2E0222510006851`。安装前只停止 LuckRing 进程以避免 BLE 争用，不解绑、不清数据。
- 最终 Debug APK 以 `adb install -r -d` 覆盖安装成功；包信息回读为 `cn.saydian.ring`、`0.1.21 (1004)`，首次安装时间保持 2026-09-19 13:41:28，更新时间为 2026-09-24 15:13:19。
- 冷启动后进程存活，首页为简体中文；身心准备度显示 1/3 项而不再计 HRV；“我的”页语义树无语言/Language/English/简体中文选择入口。
- 健康首页可见心率、血氧等实存数据，不见 HRV；“全部健康数据”页列出心率、血氧、皮肤温度、压力、睡眠，语义树确认无 HRV/心率变异性。
- 运动首页真机固定一排 `跑步、室内跑、步行、骑行`，显示“查看更多”；点击后进入“全部运动”子页，13 个设备实报模式均可见，最后一项为“登山”。
- 当前进程无本应用 `FATAL EXCEPTION` 或 ANR。未启动/停止真实运动，未写入健康数据，未执行 OTA、联系人或不可逆设备操作。

## 接口与平台边界

- 本轮未修改 API 地址、参数、Token、登录、健康上传、数据库或运动 SDK 调用。
- “隐藏 HRV”是 UI 门禁，不等于删除或停采历史健康数据。
- Windows 无 Xcode/CocoaPods/codesign，iOS Debug/Profile 构建与 iPhone 真机未执行；不能用 Android 或 Flutter 测试代替。
- 未推送 Git、未部署线上、未发布 APK。

## 待验收

- 在真实户外/室内样本中分别启动一种运动，核对戒指 SDK 回调、停止和运动记录；本轮只验收入口、模式数量与页面跳转。
- 使用 macOS/Xcode 串行执行 iOS Debug/Profile 构建，并在真实 iPhone 复核中文默认、隐藏入口与运动子页布局。
- 正式分发前配置生产签名并提升版本号；本轮 QA Release 为 Debug 证书，不得提交商店。
