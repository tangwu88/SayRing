# 2026-10-27 iPhone XR 1145 真机调试启动

## 授权、源码与设备

用户要求“开启苹果真机调试”。本轮只启动正常主入口Debug、保留调试连接，不上传TestFlight或修改商店/下载后台。开始工作区干净，当前分支codex/login-camera-r7ultra-1136-20261024，fetch成功、ff-only报已最新，HEAD/远端均99f6162dd888dbc027096c77d7854601c2010ce6。保留现场分支，没有切回前次开发分支或推进main。已读AGENTS、国际交接、最新Android1145巡检及修改索引。

devicectl和flutter devices确认iPhone XR通过USB连接，iOS18.7.10、已配对、Developer Mode开启；另一台15 Pro Max为配对可用状态。本轮选择明确有线在线XR，未操作另一台手机。唯一目标cn.saydian.ring，安装前1.0.6（1141）。设备唯一标识与完整回执仅存私有build/ios-debug-1145-20261027。

## 先备份，再构建

安装前通过devicectl device copy from，domain-type=appDataContainer、domain-identifier=cn.saydian.ring、source=.，取得完整可访问容器，命令退出0，68个文件/9752884字节。备份及日志在忽略目录，未上传Git。不卸载、不清数据、不解绑或重置戒指，不改账号资料/监测设置。

先检查没有其他Flutter/Xcode编译，串行执行：

```text
flutter build ios --debug --no-pub --config-only --no-codesign --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --dart-define=JPUSH_APP_KEY= --build-name=1.0.6 --build-number=1145 --target=lib/main.dart
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination generic/platform=iOS -derivedDataPath build/ios-1135-20261024/derived IPHONEOS_DEPLOYMENT_TARGET=15.0 SAIDIAN_DEVELOPMENT_TEAM=W7SXQ4A226 DEVELOPMENT_TEAM=W7SXQ4A226 CODE_SIGN_STYLE=Automatic 'CODE_SIGN_IDENTITY=Apple Development' build
```

Debug配置23.6秒、开发签名构建12.4秒，均退出0。保留现有插件Swift Package Manager/模拟器架构提示，没有升级依赖来消除提示。使用本机已有开发证书成功，没有发行导出或云端分发私钥步骤。空JPush配置沿用本机开发模式，不将本次启动当推送验收。

保存本轮新鲜Debug.app后，codesign --verify --deep --strict通过；Info.plist为cn.saydian.ring/1.0.6/1145，团队W7SXQ4A226、get-task-allow=true、描述文件包含XR。App.framework/App SHA256为7814aed978bb8f52defd761275cb4517e644c88e6608599bbbe865dd718e93bd；实际Debug kernel_blob.bin SHA256为d78104bdd43b35eaea19c76e15239e626a6b3cc549139c6dbf07b15f25d57206。Debug框架哈希不单独冒充Dart源码证明，内核及完整签名一并留证。构建失败不会使用旧包，本轮所有构建实际成功。

## 启动命令纠正与实际连接

首个flutter run误带仅build支持的--build-name/--build-number，工具报unknown option，未进入安装。首次tee包装未启用pipefail导致shell显示0，已依据实际错误输出判定失败，日志保留为flutter-run-unsupported-flags.log，未当调试成功。删除不支持参数，保留已核验预编译App的1145身份，并启用pipefail后重跑：

```text
flutter run --debug --no-pub -d <本轮已核验XR> --target=lib/main.dart --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --dart-define=JPUSH_APP_KEY= --use-application-binary=build/ios-debug-1145-20261027/SayRing-1.0.6-1145-debug.app
```

当前Flutter本机源码IOSApp.fromPrebuiltApp明确支持.app目录及IPA，未按过时简略帮助将正常App误判不支持。正常run用于保持实时Debug，不是integration_test入口，未使用默认drive卸载清理。安装并启动34.1秒，文件同步226ms；Flutter实际输出Hot reload/Hot restart命令、Dart VM Service及DevTools地址。公开第一方启动GET日志返回HTTP200，并加载既有会员关爱数据；没有输入账号凭据、接受新协议或改会话。

发送一次r，实际Reloaded 0 libraries in177ms（compile13ms/reassemble73ms），验证热重载与应用响应；没有更改产品源码。VM只读getVM/getIsolate确认mainRunnable=true、pauseEvent=Resume，DevTools页面HTTP200。调试URL/运行日志仅存私有目录，不把本地调试令牌写入Git。已向Codex请求打开DevTools，工具返回queued，故仅认定打开请求已排队及服务可达，不据此声称浏览器画面已检查。

安装后devicectl再次核验手机实际cn.saydian.ring/1.0.6/1145。Flutter会话保持运行供用户继续调试，不发送q、d或卸载；因为没有运行测试探针，无需恢复另一测试入口。Debug独立冷启动仍不作为验收，应保持Flutter/Xcode连接。

## 结果边界

已通过：原数据容器备份、最新源码Debug构建/开发签名、XR原位安装、真实Flutter/VM连接、热重载、DevTools HTTP可用。未执行本轮Profile/Release构建、源码全量测试、戒指连接或活动/睡眠/提醒/相机专项、商店上传送审；不把Android的既有R7 Ultra结论当iOS验收。只提交本记录及索引，不提交容器、App、原始日志或调试URL。
