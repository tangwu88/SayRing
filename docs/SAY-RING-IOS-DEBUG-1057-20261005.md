# iPhone 真机 Debug：1057

## 本轮范围

- 2026-10-05（Asia/Shanghai），按用户要求开启 Say Ring 苹果真机调试。只启动当前代码，不更换当前审核、账号、包名或戒指绑定。
- 开始时工作树干净，当前分支 codex/macos-update-20260930，基线 ad26aa3。fetch 和当前分支 ff-only pull 成功，远端无新提交；没有覆盖其他改动。
- 实际设备为 iPhone 15 Pro Max / iOS 26.6，连接、开发模式和解锁状态可用；其他 iPhone unavailable，未使用它们安装。

## 安装前保护

- 手机已有 cn.saydian.ring / 1.0.0 (1057)。首先获取安装与进程清单，按实际 App 容器路径校验进程归属，而非匹配通用 Runner 名称。
- 首次备份是在运行状态下取得；随后仅停止 Say Ring，另存一份停止后的 Library/Documents 备份，两次 copy JSON 均为 success，停止后目录约 23 MiB。没有覆盖初次备份，不把它冒充完整系统/Keychain 备份。
- 备份目录权限 0700；手机截图、运行日志、设备清单及备份只在忽略的 .build 私有目录，不入 Git。另一款 App 的 Runner 进程未停止，未操作其账号或界面。
- 构建前磁盘约 1.4 GiB 可用；本轮未删除缓存、源码、原始 SDK、签名或旧归档。

## 构建、启动与验证

```sh
flutter build ios --debug --no-pub --build-name=1.0.0 --build-number=1057 \
  --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn \
  --dart-define=JPUSH_APP_KEY=
flutter run --debug --no-pub -d <已核实的 iPhone UDID> \
  --use-application-binary=<已验签的 build/ios/iphoneos/Runner.app> \
  --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn \
  --dart-define=JPUSH_APP_KEY= --pid-file=.build/ios-debug-20261005.pid
```

- 实际 Flutter 路径 /Users/saydian/development/flutter/bin/flutter；本轮读取本机 Flutter 实现确认支持预建 .app，安装失败没有卸载重试回退。
- 开始曾将 build-name/build-number 直接用于 flutter run，CLI 返回不支持该选项（exit 64），没有安装 App。改为先构建明确版本，再启动同一签名 Debug 二进制；失败日志保留。
- iOS Debug 构建成功，Xcode 34.1 秒；严格验签通过，cn.saydian.ring / 1057、UIDeviceFamily [1]、get-task-allow=true。插件 SPM 和模拟器 arm64 警告不是本轮 iPhone 编译失败。
- flutter run 安装及启动成功（18.7 秒），保持 LLDB/Flutter 附加。Dart VM Service 可访问，getVM 返回 VM 和一个非系统 isolate；DevTools 调试地址实际生成且可用。打开面板请求返回 queued，不宣称面板已完成显示。
- 输入 r 热重载成功：505 ms，0 libraries（本轮无源码变化）、compile 189 ms、reassemble 77 ms。没有用仅有应用进程代替调试附加证明。
- 设备安装清单回读确认 1.0.0 (1057)；原登录与健康首页可见。启动期间已观察到第一方 API HTTP 200，未显示具体健康数值或凭据到本记录。

## 边界与保持状态

- 保留运行中的 Debug 会话，未执行 q、detach、卸载或清数据。Debug 仅在调试器附加期间使用；后续要脱离 Mac 独立启动，应保数据覆盖已验签的普通 Profile，而不能据 Debug 独立启动评价闪退。
- 本轮没有修改运行时代码，也没有重新执行全量 Flutter、Android、Profile 或发布回归。此前 1057 的全量测试证据仍归此前记录，不冒充本轮新跑。
- 本轮只验证启动、附加、热重载、首页和启动接口，未完成逐页/真实戒指测量验收。R21 复测断连、相册权限与摇动拍照、可信固件及 OTA 的既有待验边界不因启动成功而解除。
- 未上传新 TestFlight 包、未修改 App Store 审核或销售资料。
