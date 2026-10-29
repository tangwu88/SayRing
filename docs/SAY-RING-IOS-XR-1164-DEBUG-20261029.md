# 2026-10-29 iPhone XR 1164真机调试启动

## 范围、源码与设备

用户要求“开启苹果真机调试”。本轮启动正常`lib/main.dart`的Debug并保持Flutter附加，不运行集成测试探针，不发布商店或下载页。开始工作树干净，分支`codex/login-camera-r7ultra-1136-20261024`；`git fetch --prune origin`成功，`git merge --ff-only origin/codex/login-camera-r7ultra-1136-20261024`返回Already up to date，源码HEAD为`931f9df75feb49036ab084c7cbfa1e882dc0a1e5`。

已读AGENTS、国际交接、最新修改/验证记录、XR上次调试记录及复盘/回归清单相关门禁。设备发现和实际details分别确认XR及15 Pro Max均为有线、已配对、开发者模式开启；选择延续最近的XR调试目标，不操作另一台iPhone。XR为iOS18.7.10，`passcodeRequired=false`、`unlockedSinceBoot=true`，安装前Say Ring为`cn.saydian.ring`/1.0.6（1145）。完整设备标识、容器、日志和调试令牌仅存私有忽略目录`build/ios-debug-1164-20261029`。

## 备份与保数据覆盖

安装前执行`xcrun devicectl device copy from --device <本轮XR> --domain-type appDataContainer --domain-identifier cn.saydian.ring --source . --destination <私有备份目录> --json-output <私有回执> --timeout 60`，退出0，2.6秒，70个文件/9,992,928字节。未卸载、清数据、修改账号或解绑/重置戒指。

安装后`devicectl device info apps --bundle-id cn.saydian.ring --include-container-paths`实际回读1.0.7（1164）。第一次核对错误地假定覆盖前后容器UUID路径必须相同，断言失败；没有执行回滚或再次安装。随后重新导出安装后容器并比较实际文件内容：仍70个文件，64个文件哈希相同，3个旧系统状态/启动快照文件被替换，3个既有文件更新，3个新快照/日志文件出现。原健康数据库SHA256完全一致；原偏好设置2个键均保留且值相同，仅新增1个键。没有读取或输出数据库健康内容、凭据或偏好值，也不据此宣称登录会话有效或戒指业务已验收。

## 新鲜构建与签名

确认没有并行的Flutter/Xcode构建；磁盘可用约59GiB，存在有效Apple Development身份。首轮进程检查因本机其他进程名包含无效UTF-8，Python解码失败；发生在任何构建/安装之前。改为以`errors=replace`读取进程列表后继续，失败说明保留在`preflight-attempt-1.log`，未改产品源码。

串行命令如下：

```text
flutter build ios --debug --no-pub --config-only --no-codesign --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --dart-define=JPUSH_APP_KEY= --build-name=1.0.7 --build-number=1164 --target=lib/main.dart
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination generic/platform=iOS -derivedDataPath build/ios-1135-20261024/derived IPHONEOS_DEPLOYMENT_TARGET=15.0 SAIDIAN_DEVELOPMENT_TEAM=W7SXQ4A226 DEVELOPMENT_TEAM=W7SXQ4A226 CODE_SIGN_STYLE=Automatic 'CODE_SIGN_IDENTITY=Apple Development' build
```

Debug配置26.2秒、开发签名构建14.3秒，均退出0；保留插件弃用、架构及既有构建脚本提示，没有为消除提示升级依赖或改变项目最低系统。15.0仅为本机这次构建覆盖值，仓库默认13.0不变；相同运行源码的默认目标CI见本日源码同步记录。开发JPush配置为空，本次不验收推送。

仅在本轮构建成功后复制新鲜`Runner.app`为`SayRing-1.0.7-1164-debug.app`。`codesign --verify --deep --strict`退出0；Info.plist为`cn.saydian.ring`/1.0.7/1164，描述文件团队`W7SXQ4A226`并包含目标XR，`get-task-allow=true`、application-identifier匹配。

- App.framework/App SHA256：`998fbef9542f4c8df8b7e21a739a825f1e6b40a651519fb63410e471fe6c68fd`。
- Debug kernel_blob.bin SHA256：`8b7454e39c4cc40911762fa81c0db3eccff03e9cbcbdef0b5b22ee12b50b9742`。

生成配置及App仅位于忽略目录；构建后Git跟踪的运行文件没有改动。不在构建失败时回用旧App。

## 实际启动与调试核验

使用已经核验的本轮App：

```text
flutter run --debug --no-pub -d <本轮XR> --target=lib/main.dart --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --dart-define=JPUSH_APP_KEY= --use-application-binary=build/ios-debug-1164-20261029/SayRing-1.0.7-1164-debug.app
```

命令以`pipefail`保留失败状态，完整运行输出写入私有日志，控制台仅显示调试状态。正常run未使用默认`flutter drive`卸载清理，也没有测试入口需要换回。安装并启动35.7秒，文件同步63ms，实际输出Dart VM及DevTools地址；设备进程列表确认正常Runner进程。

发送一次`r`完成真实热重载：`Reloaded 0 libraries in 213ms (compile: 21 ms, reload: 0 ms, reassemble: 82 ms)`。只读VM接口HTTP200，main isolate的`runnable=true`、pauseEvent为Resume；DevTools HTTP200。向Codex请求打开DevTools返回queued，因此记录为已请求打开及服务可达，不宣称浏览器面板已目视检查。

保留Flutter会话运行供用户继续调试，不发送q或d。Debug稳定性只在附加工具时成立，不用于发布版独立冷启动判断。

## 回归与交付边界

本轮没有产品运行代码改动，沿用同日`SAY-RING-MAC-SOURCE-SYNC-20261029.md`对相同运行源码的完整双时区1557/540项、Android原生73项及[五任务CI](https://github.com/tangwu88/SayRing/actions/runs/40852418971)证据，不为文档重复整套构建。此次新增证据为XR容器备份、最新源码开发签名构建、实际覆盖版本、健康数据库保留、Flutter附加、热重载及VM/DevTools可达。

未执行本轮Profile/Release打包、全页面走查、戒指连接或活动/睡眠/健康提醒实物专项、推送送达、商店上传或送审。R21/R22及其他平台的原始待验结论仍分别保留。只将本记录和索引提交推送当前分支，不提交容器、App、原始日志、完整设备标识或调试URL，不提升main。
