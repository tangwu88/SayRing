# 2026-10-31 iPhone XR 1188真机调试

用户要求“开启苹果版本真机调试”。仅启动正常lib/main.dart的Debug并保持附加，不运行集成测试或戒指业务探针，不改变商店提交、下载页、后台或设备绑定。

## 源码与目标

开始工作树干净，status/remote/fetch成功，开发分支从321296e快进到bf6587e9cfe7cf85458ba7578888fd359df1a70e；已读AGENTS、交接、最新1186/1187及XR调试记录、复盘和回归清单。新源码包含当前戒指实际能力过滤，历史不再授权健康功能。相对1185运行指纹仅lib/services/app_controller.dart改变；lib/ios/android/assets/pubspec/config与已通过完整CI41090998479的842dd9f实际diff为空，且本轮只读核实该run为completed/success。

当前唯一在线物理iPhone为XR，15 Pro Max不可用；XR已解锁，原Say Ring为cn.saydian.ring / 1.0.8（1185）。选定已配对XR，不操作另一部手机。完整设备标识、描述文件、容器及调试令牌仅保存在Git外。

## 保数据安装与调试前备份

现装1185为非开发签名，devicectl实际containerAccessible=false；最初导出容器返回ContainerLookupErrorDomain error 3，未将其记为成功备份，也不读取或绕过受保护存储。此次请求为正常Debug启动，不是更换入口的Flutter集成测试。按用户启动调试的授权，使用系统原位覆盖安装正确同Bundle/团队的开发包，没有请求卸载、删除、清空或重置。

新Debug安装后实际回读1.0.8（1188）、builtByDeveloper=true、containerAccessible=true。随后在Flutter启动/热重载核验之前导出完整可访问容器，copy from退出0、2.5秒，89个文件/13,663,850字节，包含原健康数据库。这个快照是原位安装后的调试前备份，不冒充安装前商店版容器备份；无法比较商店版安装前的完整字节基线。

正常调试启动后再次导出容器：仍89个文件，83个原文件哈希相同，3个原文件不再存在、3个原文件更新，另有3个新文件。健康数据库哈希与调试前快照完全一致。不读取、输出健康内容、凭据或偏好值，不把数据库字节相同当成原账号接口有效或戒指业务通过。

## 新鲜开发构建

冻结bf6587e，串行核对无其他iOS构建。使用现有官方Xcode27.1（27A9275）的独立DEVELOPER_DIR，默认Xcode/系统安全设置不改。正常生产第一方配置、商城开关保留、JPush开发密钥为空，无QA定义。

```text
flutter build ios --debug --no-pub --config-only --no-codesign --target=lib/main.dart --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --dart-define=JPUSH_APP_KEY= --build-name=1.0.8 --build-number=1188
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination generic/platform=iOS -derivedDataPath build/ios-xr-debug-20261031/derived IPHONEOS_DEPLOYMENT_TARGET=15.0 SAIDIAN_DEVELOPMENT_TEAM=W7SXQ4A226 DEVELOPMENT_TEAM=W7SXQ4A226 CODE_SIGN_STYLE=Automatic 'CODE_SIGN_IDENTITY=Apple Development' 'SAIDIAN_CODE_SIGN_IDENTITY=Apple Development' build
```

Debug配置30.8秒、开发签名构建30.9秒，严格深度codesign退出0。实际核实cn.saydian.ring / 1.0.8（1188）/ W7SXQ4A226、get-task-allow=true、描述文件包含目标XR、arm64、正常main与无QA定义。kernel_blob.bin SHA256 f10dadecc9b72551f9d84f96cd631415843feffa86b03f61de08135fa0847333。本机目标15仅为局部构建覆盖，与现装1185相同；仓库默认13不变，默认目标兼容性引用同运行源CI，未宣称本机13编译。

只在本轮成功后复制独立1188 App并安装，没有旧包回退。首次签名配置查询用了不存在的LocalSigning.xcconfig路径，随后按实际Local.xcconfig与project配置核对；没有修改签名文件。安装/备份命令及原始失败结果均存私有日志。

## 活跃调试连接

使用已核验的本次App运行：

```text
flutter run --debug --machine --no-pub --no-build --device-connection=attached -d <已核验XR> --target=lib/main.dart --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --dart-define=JPUSH_APP_KEY= --use-application-binary=build/ios-xr-debug-20261031/SayRing-1.0.8-1188-debug.app --vmservice-out-file=<私有文件>
```

使用本机Flutter实际源码核对正常run的安装/启动路径与机器协议，不用默认flutter drive或卸载参数。私有包装器只保留日志、记录真实进程/端点并发送一次非完整重启的app.restart热重载。实际收到app.started；热重载返回code=0、Reloaded 0 libraries。VM HTTP200、main isolate runnable=true、pauseEvent=Resume；DevTools HTTP200。

Codex打开DevTools的请求返回queued；两次读取内置浏览器均请求失败，因此只记录服务可达与已请求打开，不宣称面板已经目视核验，也不绕过连接失败另行控制浏览器。正常Debug会话继续驻留，不发送q/d、不停止进程或换回Release，供用户继续调试。Debug稳定性仅在附加工具时成立。

本轮无产品源码/权限/依赖变更，不为文档重跑已通过的整套矩阵。新增证据限定为最新源码Debug构建、签名、XR实际版本、调试前私有备份、健康数据库比较、附加及真实热重载/VM/DevTools可达；全页面、登录接口、蓝牙连接与活动/睡眠/健康提醒实物专项不在此次启动任务中冒称完成。仅提交本记录和索引至开发分支，不提升main，不公开App、容器、原始日志或临时调试URL。
