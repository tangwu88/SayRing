# Say Ring 资料保存 / 头像地址兼容修复

## P1 复现与根因

- 用户在已登录 Android 1040 的资料页选取头像并编辑资料后反馈出错。保留已填写内容，不更改字段、不退出账号、不清数据；按当前表单复现保存。
- 真机日志显示头像 POST 返回 201，但资料 PUT 尚未发出；实际提示为照片无法上传。照片预览存在，失败发生在上传响应解析之后，而不是相册读取阶段。照片、真实资料、完整日志仅保留忽略目录。
- 只读核对 /global/health：生产 revision ee452e2b38d88a0601d61342e0140c2e24e9dcaf；该版本统一部署 PUBLIC_BASE_URL 为 https://app.saydian.cn，文件接口输出绝对 /api/saydian-app/v2/files/{UUID} 地址。客户端 GlobalEnvironment.media 原先只允许绝对 /global 地址，将同源统一文件 URL 变为空串，uploadImage 抛出与真机相同的错误，后续保存被中断。
- 使用服务端实际响应格式的合成用例，修复前两个正例失败：上传后不能保存/回读，合法文件 URL 被转为空串；非法地址负例正常。先保留失败日志，再修改实现，不伪造真实上传通过。

## 修改范围

- 修改 lib/services/global_environment.dart：同一配置 origin 下仅增加精确 UUID 文件资源路径，禁止 query、额外路径、其他 API、用户信息、片段、路径穿越及外部 origin。资源重定向仍拒绝。
- 鉴权请求继续 /global、会话/产品/存储命名空间不变；不更换账号系统、数据源或上传接口，不跨域兜底、不改服务器存储方式。
- test/global_api_test.dart 与 test/global_network_boundary_test.dart 覆盖 HTTP 201 上传→保存→回读、仅头像保存、图片读取、API 路由保留、非法地址和重定向。
- 修改前已 fetch，当前远端分支仍为 bc1225506c6241c0973a62bd6c9b9b519990d19c；保留 1041 完整 diff 与未跟踪记录副本，不在脏树 pull。

## 调试与验收边界

- 只读 VM 诊断可连接。尝试求值 URL 形状遇到 RPC 113 编译错误，已移除断点并恢复 Resume；没有输出真实 URL、照片或账号。后续准备读取时发现手机前台已是另一 Health App，立即移除第二个断点，确认 VM Resume，停止手机点击。
- 不安装覆盖正在编辑的表单，不接管另一 App；采用本机回归和明确指定 Say Ring VM 的状态保持调试。1042 新包和真实保存、重开回读以最终实际结果为准。
- 先前 1041 的双时区 1155 项及构建不代替 1042 新源码验收；本轮继续追加检查结果、失败与未完成项。

## 1042 检查与实际保存（追加）

- 定向接口/边界测试 63 项通过；flutter analyze --no-pub 无问题。全量测试分别以 TZ=UTC、TZ=Asia/Shanghai 执行，两次均 1159 项通过。Node 27 项通过；Python 发布门禁 31 项通过。源码及测试格式化通过。
- 原有 Say Ring 调试附加已核对 VM pid 与 cn.saydian.ring 进程一致；SIGUSR1 两次热重载成功，表单及照片保留。新 attach 错把现有 host DDS 端口当 device 端口，连接失败；仅移除该次新增 forward，保留原附加。VM evaluate 因没有编译服务返回 RPC 113，不代表上传失败；所有诊断断点均已移除，VM Resume。
- ADB 多次按钮点击未触发保存，未把这些点击标为成功。随后通过调试器调用当前资料页原有 _save 回调，未修改表单、绕过校验或鉴权：真实头像 POST 201 →资料 PUT 200 →资料 GET 200 →头像图片 GET 200，页面返回“我的”并显示新头像。再次正常点击资料入口，GET 200，头像与原填写字段回读一致；真实资料和照片不入 Git。正常保存按钮及新包重开继续验收。
- 清理前检查无本仓库构建正在运行，已将 1041 Debug/Profile/最终 iPhone app 与 Profile dSYM 压缩保存，gzip 校验通过，SHA256 6423cae773055f0d8315779a3ccaa1910e39db9766abc831a22c23f44cfeed07。flutter clean --scheme Runner 和离线 pub get 成功，释放可重建产物，不清手机数据或 SDK 原件。
- Android 1042 Debug 双 ABI 构建通过（36.6 秒），apksigner 验签通过，cn.saydian.ring / 1.0.0 (1042)，与已安装包证书相同。独立 APK SHA256 4909f8a91c05c5060529367215189d9605586fdbd3369831835b30b205be5e7e。QA Release、原生回归、iOS 构建、新包安装及正常按钮验收以接下来的追加结果为准，暂不冒称全部完成。

- Android 原生 8 个测试套件共 39 项，失败/错误/跳过均 0；releaseRuntimeClasspath 解析通过。原厂 AAR 构建副本检查 30 个条目不变，仅移除两条 mapping 输出配置。CoolWear 与 QRing Foundation 合成测试通过，不能代替真戒指数据验收。
- 204 个 Dart 文件格式检查 0 修改；bash -n、shellcheck 两个 release 脚本及 actionlint 通过。首次 bash -n 使用不存在的 tool/android_qa_regression_gate.sh 路径失败，改用仓库实际脚本后通过，不删除失败记录。
- 独立 1042 Debug APK ZIP 和 16 KB zipalign 校验通过。adb install -r 成功，华为两次“继续安装”确认后版本为 1042，firstInstallTime 仍为 2026-10-03 12:55:15；未卸载、清数据或退出账号。新包启动读到已保存头像，首页和“我的”一致，资料 GET 200、头像 GET 200；旧睡眠记录仍可见。新进程与 --app-id cn.saydian.ring 附加 VM pid 一致，正常附加成功。
- 新包重新进入资料页后，未改字段，实际点击“保存资料”产生 PUT 200，正常按钮路径已验证；热重载阶段的调试器调用不替代此项。随后手机转入用户自行操作的远程关爱页，停止 UI 点击，保留调试器运行。新包再次选择照片上传未另做，已验证前阶段真实上传 + 新包重新回读；iPhone 头像保存仍待真机复验。

- Android 1042 内部 QA Release 构建成功（127.8 秒，69.4 MB），SHA256 655eafb0d71bbdfbba40aab973656d8c3f31000cec7f94257d37957ed7eba61d；包名、构建号、双 ABI、相同 Debug 证书、ZIP 与 16 KB zipalign 均核对通过。ABI 门禁通过，保留既有锁定 JPush/JCore libjutils ARM64 例外；此包不是正式签名分发包，不上传应用市场。
- 1042 Debug 原生测试/SDK 副本及 Release 映射、原生符号和 SDK 副本分别压缩保存，gzip 校验通过；两个独立 APK 已保留后执行 :app:clean，正常释放可重建输出，不删除原 SDK、签名、源码或设备数据。
- iOS Debug 首轮 pod install 1.239 秒、Xcode 31.9 秒成功。首次在异步构建结束前检查 Info.plist/Runner 文件失败，未把缺少产物认定为源码编译失败；Profile 请求启动时 Debug 工具尚未回收，随后进程核对仅剩本仓库 Profile xcodebuild。最终门禁将等待当前 Profile 完成后重新串行执行 Debug、Profile，避免以请求时序代替串行证据。

## 复核命令与交付边界

工作目录为 SayRing-update-20260930；Flutter 使用本机 /Users/saydian/development/flutter/bin/flutter，Android 使用 JDK 17 和 /Users/saydian/Library/Android/sdk。所有日志、包、映射、真实截图及 VM 调试信息只保留 .build 忽略目录。

```sh
flutter analyze --no-pub
TZ=UTC flutter test --no-pub
TZ=Asia/Shanghai flutter test --no-pub
dart format --output=none --set-exit-if-changed lib test
node --test tool/measure_ios_bundle.test.mjs tool/client_package_contract.test.mjs tool/test_coolwear_ios_integration.mjs tool/test_native_log_privacy.mjs
python3 -m unittest discover -s scripts/release -p 'test_*.py'
./android/gradlew :app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath -p android --max-workers=1
node tool/verify_qring_sdk_copy.mjs android/app/libs/qring_sdk_1.0.0.76.aar build/app/generated/qring-sdk/qring_sdk_1.0.0.76-build.aar
```

- Android Debug / QA Release 使用 --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.0 --build-number=1042 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=；仅 QA Release 设置 SAIDIAN_ALLOW_QA_RELEASE=true，不将 QA 签名冒充生产签名。
- iOS Debug / Profile 使用 --no-codesign --no-pub 和相同构建号、API、空 JPush 定义；实际产物核对 cn.saydian.ring、1042、UIDeviceFamily=[1]、arm64。无签名编译不代表 iPhone 安装或 App Store 分发验证。
- 验收仅处理当前资料错误与前段百科日期问题，不更改其他 App、登录开关、存储部署或现有 App Store 审核；AI 终态、充电插拔、三轮距离重连、CoolWear 实物、两账号撤权等前段待验项继续保留，不伪报已完成。

## 最终门禁与状态

- 首轮 Profile 60.2 秒成功后，等待会话明确 exit=0，再通过 shell && 串行重跑 Debug 和 Profile；两者分别 Xcode 24.1 / 46.2 秒成功。复核阶段再次提前探测正在重建的 Profile 文件返回不存在，保留该诊断失败；明确退出后实际 Debug 与 Profile 均 cn.saydian.ring、1042、UIDeviceFamily=[1]，Profile 为 arm64，最终 app 66.2 MB。没有使用未完成产物作验收。
- 编译仍提示闭源微信 SDK 缺少新 arm64 模拟器支持，以及部分插件尚未使用 Swift Package Manager、Android Built-in Kotlin 的未来迁移警告；本轮 physical iPhone 编译目标通过，不谎称这些供应商警告已解决。
- 当前 Android 包 1042、进程存活，首次安装时间未变；专用 Say Ring Flutter Debug 附加保持运行。当前进程日志匹配数：FATAL EXCEPTION、E/flutter、Unhandled Exception、RenderFlex overflow 均 0。该观察不等同长期零崩溃。
- 本轮完成 Android 真实上传、资料保存和回读，以及 1042 原位覆盖后首页/资料头像回读、普通保存按钮；iOS 为共享源码编译回归，未安装新 iPhone 包或修改审核。新包另选照片、iPhone 真机和前段硬件专项仍按上述边界待验。
- 最终 git diff --check 通过；真实 logcat、照片与 APK 的 .build 路径经 git check-ignore 确认被忽略。交付只提交本轮源码、合成测试和两份记录及索引，常规推送当前 Say Ring 分支，不改其他仓库、主分支历史或审核。
