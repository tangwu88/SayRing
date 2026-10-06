# Say Ring 协议产品隔离与正式 1014 包（2026-10-06）

## 用户范围、基线与现象

- 用户要求：隐私政策/用户协议读取后台所属 APP「Say Ring」，修复后重新打 Android 和鸿蒙正式包并安装手机，不需要调试。
- Git 专用工作树 `E:\SayRing-market-release-20261005`；修改前 status 干净、fetch 成功、HEAD/origin/main 为 `4e8bac0646da49e64df4e0c188e055f76079f51b`。主目录既有 UI 文档改动不触碰。
- 阅读根约定与最新正式重构建、QRing 修复记录；没有修改服务端、后台数据、生产配置或健康算法。
- 前一轮已按用户明确指令卸载 Android 1011 并全新安装 1013；ADB install 返回 Success，设备回读 1.0.0/1013 和 APK hash 一致。用户随后转入本轮修复，未启动/调试。

## 根因和改动

- 两端 `auth/capabilities` 没有带 product，后台默认 saydian-global；登录提交同样漏传 product，会把新版协议 consentVersion 用于错误产品校验。
- Flutter 法律页枚举仍要求 user_agreement/privacy_policy；鸿蒙也限制旧类型，且直接请求 canonical /api 路径，而原生 transport 只允许部署的 /global 路径。
- Flutter 能力请求显式 product=say-ring，校验响应产品及文档类型/版本；隐私/用户协议只允许 say_ring_privacy_policy/say_ring_user_agreement，无本地文本或其它 APP 文档回退。保留独立 health_ai_analysis 读取，避免影响报告授权页。
- 微信授权、发绑定验证码、绑定、手机号/邮箱验证码请求与登录、兼容注册提交均带同一 Say Ring 产品标识；本轮未发送真实验证码或真实登录。
- 鸿蒙能力请求和注册提交同样带 Say Ring 标识；逐项校验 ring 文档类型与版本、精确引用、响应 reviewed/version/locale/type，并将后台 canonical 内容引用安全映射至 /global。缺失或错误文档关闭，不降级到另一 APP。
- 线上后台对 Say Ring 新用户要求明确的 14 周岁确认；Flutter 验证码页现有协议勾选文案明确追加年龄确认，微信绑定页增加默认不勾选的确认项。鸿蒙原生注册协议勾选也追加明确年龄说明，再传递用户实际选择。ageConfirmed 通过可选参数显式传递，API 默认 false，未自行假定同意。
- 两端正式版本 1.0.0/1014，Android 使用构建参数，不覆盖 pubspec 的其它端版本；鸿蒙 AppScope 与更新检查版本一致。

## 在线只读核对

- 请求 `GET /global/api/saydian-app/v2/auth/capabilities?locale=zh-Hans&product=say-ring`，响应 product=say-ring、consentVersion=say-ring-cn-2026-10-02-v2。
- 两份引用均真实读取成功，documentType 分别 say_ring_user_agreement/say_ring_privacy_policy，title 为「Say Ring 用户协议（中国大陆）」/「Say Ring 隐私政策（中国大陆）」，locale=zh-Hans、reviewed=true、version 一致。
- 对比默认另一产品，仅作公开元数据读取，确认旧请求返回 saydian-global 文档。没有编辑法律正文、授权、发布状态或后台记录。

## 验证和失败记录

- 定向 Flutter 初次 61 项通过/2 项失败：旧注册测试按精确 JSON 断言漏了新 product；更新三处预期，不放宽生产校验。新增错产品/错文档拒绝测试及旧类型禁止读取测试。
- Harmony 定向 global-auth 17/17 通过，新增测试确认产品、部署路径以及拒绝另一 APP。夹具改为 Say Ring 类型，保持缺失协议 fail-closed。
- Windows rg 使用路径通配字符串失败；改为目录搜索加 --glob，未造成文件修改。只格式化本轮七个 Dart 文件；diff check 无空白错误。
- 本轮 Flutter analyze 通过；完整 UTC、Asia/Shanghai 各 947/947 通过，Android Debug 构建通过。
- Android 原生首轮因 QRing immutable transform workspace hash 校验失败，不是测试断言或 Java 错误；保留 first-failed 日志，停止 Gradle daemon，将精确 transforms/7d449599654a801d656c79251a8c1bc3 的非 lock 内容移动到本机 gradle-quarantine/qring-7d449599-native-1014，未删除、未关闭校验或改变 SDK。重建后原生 32/32 通过、无跳过，正式 APK 编译成功（309.4 秒）。
- 鸿蒙完整双时区各 502/502 通过。补齐原生年龄确认后再次完整运行并编译，Release 成功；最终使用官方工具和既有正式证书/Profile 签名，独立 HAP 与 APP 提取 HAP 的 code/permission/profile 验证均通过，二者 HAP hash 一致。厂商 SDK/resource 警告未移除。
- 发布 Python 可执行套件 19/19 通过，未执行 POSIX/Xcode 专用 helper。

## 鸿蒙交付

- `E:\SayRing-market-artifacts-20261006\legal-1014\SayRing-HarmonyOS-1.0.0-1014-release.app`，SHA256 `B9EAB276B9FA72D291611EC05579CFE0084753635761642AF700698040B25AFD`。
- `E:\SayRing-market-artifacts-20261006\legal-1014\SayRing-HarmonyOS-1.0.0-1014-release.hap`，SHA256 `A1A80588FDA0B811725B3B673518A56C7C2C3711ED99B54694D57C873DECF5F6`。
- HDC targets 为空，当前没有原生鸿蒙设备；没有在 Android 手机上尝试安装 HAP。

## Android 交付与安装

- 正式 APK：`E:\SayRing-market-artifacts-20261006\legal-1014\SayRing-1.0.0-1014-release.apk`，69044934 字节，SHA256 `0AEC4CBB4E95147B99627E7B745E48320F9016C151A89EBE3920A541C50F4041`。
- `Verify-SayRingAndroid.ps1 -BuildNumber 1014` 完成 apksigner verify --verbose --print-certs、aapt、zipalign -c -P 16 4、manifest 发布门禁。cn.saydian.ring/1.0.0/1014，minSdk 26、targetSdk 36，正式 RSA 4096 证书未变化，非 Debug 签名；证书 SHA256 `81F35CC98E023821425FEFAA0AA8DC998283BAABC161B5F9F5EC1295EE8CE5DE`。
- `Verify-SayRing-20261006.ps1 -BuildNumber 1014 -OutputDirectory E:\SayRing-market-artifacts-20261006\legal-1014` 完成生产双 ARM ABI 和依赖门禁，保留已有受控 JPush libjutils arm64-only 例外，不新增放宽项。临时 key.properties 已清除。
- `adb -s <connected-device> install -r <formal-apk>` 返回 Success。手机锁屏导致系统安装等待，唤醒/滑动解锁后安装完成；没有卸载、清数据、执行 APP 启动命令或功能调试。
- 系统回读 versionCode=1014、versionName=1.0.0、lastUpdateTime=2026-10-06 15:01:11；`pm path` + `sha256sum base.apk` 与交付 APK hash 完全相同。安装后返回桌面，不进入功能页面。

## 本轮命令与文件

- 源码：`lib/services/global_api_client.dart`、`app_controller.dart`；`lib/ui/global_code_login_page.dart`、`global_legal_page.dart`；鸿蒙 `AccountClient.ts`、`Index.ets`、`AppUpdateService.ets`、`AppScope/app.json5`。
- 回归：`test/global_api_test.dart`、`global_code_login_page_test.dart`、`global_legal_page_test.dart` 和 `harmony-native/tests/global-auth.test.mjs`；记录与 `CHANGE-TEST-LOG.md` 同步提交。
- Git：`git status --short --branch`、`git remote -v`、`git -c http.proxy=http://127.0.0.1:7897 fetch origin --prune`、`git diff --check`；公开接口仅使用 GET。
- Dart 定向格式化/测试：`dart format` 本轮七个 Dart 文件；`flutter test test/global_api_test.dart test/global_legal_page_test.dart test/global_code_login_page_test.dart`。
- 本机外置脚本 `Rebuild-SayRing-20261006.ps1 -BuildNumber 1014 -OutputDirectory E:\SayRing-market-artifacts-20261006\legal-1014` 串行执行 analyze、UTC/Asia-Shanghai 全量 flutter test、Debug、`:app:testDebugUnitTest` 和正式构建；原生缓存恢复后使用相同脚本的 `-ResumeBuild -SkipDebug` 续跑。
- `Rebuild-SayRingHarmony-20261006.ps1 -BuildNumber 1014 -OutputDirectory E:\SayRing-market-artifacts-20261006\legal-1014` 完成双时区 `node --test tests/*.test.mjs`、Release、官方签名/验签/APP 打包；年龄确认补齐后完整重跑。`python -m unittest scripts.release.tests.test_release_gate` 完成可执行发布门禁。
- 脚本及签名材料在 Git 外本机受保护目录，不记录签名口令。构建日志和产物在上述交付目录，未加入 Git。

## 待验收和边界

- 按用户要求不进行手机调试、不启动 APP、不发送 OTP、不操作戒指、不读用户健康数据、不清除现有应用数据。
- 当前 Android 华为手机可安装 APK；HDC 是否存在可安装鸿蒙设备单独核对，不把 Android 安装称为鸿蒙安装。
- Windows 无 Xcode，iOS 编译/签名未执行。正式签名与单测不能代表市场审核、真实授权、推送或新用户注册验收。
