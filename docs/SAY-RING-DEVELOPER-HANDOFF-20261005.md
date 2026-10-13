# Say Ring 开发交接（2026-10-05）

## 1. 导入与边界

交接 ZIP 内的 `source.bundle` 包含当前分支及其可达 Git 历史、已跟踪源码和必要原厂 SDK。
不是安装包，不包含服务器项目、签名密钥、本机配置、设备备份或健康数据库。SDK 仅供授权开发使用，不公开再分发。

先解压到新目录，再运行（路径换成自己的绝对路径）：

```sh
sh /path/to/handoff/IMPORT.sh /path/to/new/SayRing
cd /path/to/new/SayRing
git status --short --branch
```

导入先校验所有文件 SHA-256，再离线克隆并核对提交和 Git 对象。
已有目标目录一律拒绝覆盖；失败时保留现场，不自动删除用户文件。
`COMMIT.txt` / `BRANCH.txt` / `MANIFEST.json` 是这份包的准确源码版本，以它们为准。

## 2. 固定约束

- 本轮仅 Say Ring；Android/iOS 包名 `cn.saydian.ring`，仅支持 iPhone，不启用 iPad。
- 第一方 API 为 `https://app.saydian.cn/global`，更新产品标识为 `say-ring`。
- 登录页仍为主入口，保留无需登录的本机模式；本机与账号云端健康数据隔离。
- 不清空绑定、健康记录或戒指数据，不为了签名更换 Bundle ID。
- 原素材及厂商 SDK 不改写；能力只能由真实握手与已实现链路开放，未知数据不补造。
- 新导入项目不能运行旧的健康 App 发布工作流；现有审核和 TestFlight 不自动修改。

## 3. 结构导航

| 位置 | 负责内容 |
| --- | --- |
| `lib/domain/` | 健康、设备、睡眠等模型及解释边界 |
| `lib/services/` | 控制器、SDK 路由、API、加密存储与同步 |
| `lib/services/app_controller*.dart` | 控制器及关联分部；先读入口再找对应职责 |
| `lib/ui/pages.dart`、`lib/ui/pages/` | 当前页面入口与按功能拆分的页面 |
| `lib/ui/prototype_pages.dart`、`lib/ui/prototype/` | 兼容入口及原型页面分部，保留库私有成员关系 |
| `lib/ui/widgets/` | 共享图片、提示、手势说明等组件 |
| `lib/ui/html_text.dart` | 统一 HTML 转纯文本，不重复实现 |
| `ios/Runner/*WearableBridge*`、`ios/Runner/Vendor/` | iOS 桥接及已跟踪原厂 SDK |
| `android/app/src/`、`android/libs/` | Android 桥接、原生测试及厂商包 |
| `test/`、`integration_test/`、`tool/` | 模型/页面/源码契约、实机用例及检查工具 |
| `docs/CHANGE-TEST-LOG.md` | 最新实施、失败记录和未完成验收的入口 |

新功能写到对应模块，不回填两个页面入口文件。
`part` 拆分不等于独立业务层迁移；`DeviceFeaturePage` 仍较大，下一轮按功能测试逐步整理，不一次改写状态机。

## 4. 环境与启动

本轮环境为 Flutter 3.44.9 / Dart 3.12.2、Node.js 24、JDK 17；另需 Git、Android SDK，iOS 需 macOS、Xcode 和 CocoaPods。
版本锁定以 `pubspec.lock`、Gradle wrapper 和 `ios/Podfile.lock` 为准。
Git 导入可离线完成，首次 `flutter pub get`、Pod/Gradle 依赖下载仍需网络；不承诺离线编译。

```sh
flutter pub get
flutter analyze --no-pub
TZ=UTC flutter test --no-pub --reporter compact
TZ=Asia/Shanghai flutter test --no-pub --reporter compact
flutter run --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=
```

不得用真实账号、Token 或照片替换测试夹具并提交。`config/dev.json.example` 可参考，个人配置留在忽略文件。
`pubspec.yaml` 的历史默认版本号不代表当前发布；构建必须显式指定版本及新的构建号。

## 5. 构建、签名与原生回归

本轮本地验证号为 1.0.0 (1060)，不代表已上传市场。示例（之后应再递增）：

```sh
flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.0 --build-number=1060 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=
SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.0 --build-number=1060 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=
flutter build ios --profile --no-pub --build-name=1.0.0 --build-number=1060 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=
flutter build ios --debug --no-pub --build-name=1.0.0 --build-number=1060 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=JPUSH_APP_KEY=
```

iOS 构建必须串行，签名资料需由开发者另行授权。交接包不会复制钥匙串或本机描述文件。
QA Release 仅供内部测试，不是正式 Android 商店签名。正式发行遵循 `docs/release/ANDROID-PRODUCTION-RELEASE.md`。

当前插件还有 Swift Package Manager 兼容警告；微信 SDK 不支持当前 Apple Silicon iOS 26+ 模拟器所需的 arm64 切片。
本轮 iPhone 设备构建与模拟器支持分开，升级 Flutter/Xcode 前需复核厂商兼容性，不改原厂包掩盖警告。
Android 的 camera_android_camerax / jpush_flutter_android 仍有 KGP 未来兼容警告，升级工具链前一并核对；本轮未盲目升级依赖。

```sh
node --test tool/test_*.mjs tool/*.test.mjs
python3 -m unittest discover -s scripts/release -p 'test_*.py'
cd android
./gradlew :app:testDebugUnitTest
```

原生 Foundation 主机用例位于 `test/native/` 及 `test/native_coolwear_policy_test.m`。
主机策略与源码契约通过不等于戒指实物、iPhone XCTest 或 AI 供应商验收。

## 6. 实机与已有待验

保数据 iPhone 测试只能用 `tool/drive_ios_preserving_data.mjs`、已验签 Profile 二进制和保运行参数。
先私有备份 App 容器；禁止默认 `flutter drive` 卸载清理；测试结束原位恢复生产入口。
Debug 独立桌面启动不能作为稳定性证据，独立启动使用 Profile/TestFlight/Release。

待验清单仍包括：真实距离三轮自动重连、锁屏/蓝牙开关、原静默取消现场、CoolWear 各实物数据及睡眠样本。
QRing 实物快门、原厂可信固件和 OTA 安全适配亦未完成；入口存在不代表刷写已开放。
其他型号没有实物不能标为通过。具体看 1059 重连记录和各 SDK 实施记录。

本轮整理不改变健康算法、API 协议或后台配置，没有执行新的手机操作或供应商线上调用。

## 7. 发布与继续开发

此前 TestFlight 公开版为 1.0.0 (1059)，记录见 `docs/SAY-RING-TESTFLIGHT-PUBLIC-1059-20261005.md`。
公开入口：https://testflight.apple.com/join/k9Uye5C6 。服务状态可能变化，应实时回查，不等于 App Store 已上架。
1060 是本轮源码验证号；交接源码晚于 1059，不把旧包冒充新的整理版本。

修改前遵循 `AGENTS.md`，阅读回归清单和最新实施记录，fetch 后只做安全 fast-forward。
保留他人改动，禁止 force-push；当前验证分支先验收，再决定是否提升 main。

重新打交接包：先提交到 Git，保持工作树干净，再运行以下命令；输出目录必须不存在。

```sh
node tool/handoff/create_source_handoff.mjs /path/to/SayRing /path/to/new-handoff
```

最终必须从 ZIP 重新解压、验证 SHA-256、导入新目录、核对 HEAD 与完整已跟踪源码。
打包后修改说明或源码，就必须重新打包并重复验证，不能沿用旧 ZIP 的结果。
