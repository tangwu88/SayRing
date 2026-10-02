# Say Ring iOS 启动与个人页面修复（2026-10-03）

## 基线与问题

- 基线：`3e1aa1dc7dc7a93936a91fb80b37e57287bfb276`；工作树干净，`git fetch --prune origin` 和 `git pull --ff-only` 后已同步当前功能分支。
- 用户反馈：iOS 启动白屏、头像修改失败、“关于 Say Ring”文字重复、权限管理与实际功能不符、远程关爱标题重复。原始 `/Users/saydian/Downloads/logo_en.jpg` 只读保留。
- 启动页当前 `LaunchImage` 三张均为 1×1 像素。远程关爱全球页自带 `Scaffold/AppBar`，两个入口又各加一层标题栏。权限页固定展示通知、相机等，未按实际开放的功能筛选。
- 头像表单要求所有资料字段完整才可保存照片；后端资料接口允许仅提交 `avatarUrl`。UI 允许身高到 300 cm，生产接口只接受到 250 cm。

## 本轮修改范围与预期

- iOS 原生启动屏显示用户提供的赛电 LOGO；Flutter 启动过渡与登录首页保持原有功能。
- Say Ring 全球账号支持仅修改头像，使用现有专用上传和资料 PUT 接口，回读确认后才报告保存成功；完整资料编辑仍走原路径并对齐服务端校验范围。
- 关于页去掉重复品牌标题，远程关爱只保留一层标题栏；权限页只展示当前可用功能涉及的权限及准确状态。共享页面变更需回归 Android。
- 本轮不改健康数据、戒指 SDK、包名、用户账号或当前 App Store 审核包。真正头像上传与页面效果以本轮新包和真机结果单独记录。

## 验证记录

- `flutter pub get --offline` 首次失败（exit 69）：本机缓存缺 `sqflite_common_ffi`。随后在线 `flutter pub get` 成功恢复锁文件所需依赖；未升级约束或改动锁文件。
- `dart format` 完成；`flutter analyze --no-pub` 首次发现 `lib/app.dart` 未使用导入，移除后重跑无问题。
- `plutil -lint LaunchScreen.storyboard` 因其不是 plist 而报“unknown tag document”；改用 `xmllint --noout` 与 `xcrun ibtool --compile` 均成功。原始 LOGO 与两份打包副本 SHA-256 同为 `740306ca468a308b0d12a3fb01b4646fb3f63be8d8ce8415dca54eb1d1d62cf9`。
- 首次定向测试中，新增 iOS 权限用例的测试平台覆盖变量在测试结束前未复位，引发框架不变式失败；改为 `try/finally` 后，`flutter test --no-pub test/global_api_test.dart test/ui_shell_test.dart` 105 项通过。
- 资料接口服务端实现已只读核对：`MembersService.saveProfile` 支持仅提交 `avatarUrl`，身高边界 50–250 cm。头像选图使用的 iOS `image_picker_ios` 会把 HEIC 数据转换为 JPEG 后写入临时文件；上传仍严格限制 JPG/PNG/WebP，不放宽服务端图片校验。
- 权限源码只读核对：iOS 相册选图不调用广泛相册授权；只在户外路线、戒指相机及已配置的通知功能中显示相关系统权限，不再将“未能读到状态”冒充“未允许”。
- `TZ=Asia/Shanghai flutter test --no-pub --reporter compact`、`TZ=UTC flutter test --no-pub --reporter compact` 各 1052 项通过；最新 `flutter analyze --no-pub` 无问题。`git diff --check` 通过。
- `TMPDIR=/private/tmp flutter build ios --profile --no-pub --build-name=1.0 --build-number=1024 --dart-define-from-file=config/ios-app-store-no-push.json` 成功（87.3 秒，65.3 MB）。实际 `Info.plist` 为 `cn.saydian.ring`、`1.0.0 (1024)`、`UIDeviceFamily=[1]`、`LaunchScreen`。`assetutil` 确认 `SaydianLaunchLogo/logo_en.jpg` 已进入 `Assets.car`；`codesign --verify --deep --strict` 成功，Apple Development / Team `W7SXQ4A226`。签名包另存 `.build/SayRing-1.0-1024-Profile.app`。
- iPhone 15 Pro Max 原装 1023；`xcrun devicectl device install app` 未卸载即覆盖安装 1024 成功。`devicectl device process launch --terminate-existing cn.saydian.ring` 成功，之后安装清单为 1024，进程 `Runner` 仍在运行。未读取用户数据容器，故“旧数据完整保留”还需 UI 回读核实。
- 同一源码 `TMPDIR=/private/tmp flutter build ios --debug --no-pub --build-name=1.0 --build-number=1024 --dart-define-from-file=config/ios-app-store-no-push.json` 串行成功（35.8 秒），签名及 Bundle ID/版本复核通过。为保持手机可独立启动，未用 Debug 包覆盖已装的 Profile 包；本轮 Debug 附加/VM 未验。
- iPhone 镜像提示“iPhone 使用中，镜像已结束”，QuickTime UI 预览未能建立；改用 Xcode「Devices and Simulators → Take Screenshot」成功取得 1024 真机当前健康首页截图，留在桌面而不进 Git。画面可见原账号昵称和已有睡眠/健康卡片，证明这部分会话与本机状态在覆盖后仍可见；不推断全部历史数据均已核验。启动瞬间、关于/权限/关爱页面以及真实头像上传与重开回读仍缺真机可见证据，不误报通过。
- Android Debug `GRADLE_OPTS=-Dorg.gradle.workers.max=1 flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0 --build-number=1024 --dart-define-from-file=config/ios-app-store-no-push.json` 停在 Gradle 插件依赖下载约 3 分钟；线程转储显示 `DownloadAction` 正等待 SSL socket 读包，未生成本轮 APK，主动取消。随后 `./gradlew :app:assembleDebug --offline --max-workers=1` 立即失败，明确缺 `gradle-kotlin-dsl-plugins-6.2.0.jar`、Kotlin 2.2.20 插件及多项依赖缓存；不是本次 Dart 业务编译错误。Android QA Release 因相同前置依赖未执行，不标通过。
- 待补：Android 依赖网络恢复后的 Debug/QA Release、真机逐页目视和真实头像上传。
