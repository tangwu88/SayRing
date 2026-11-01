# iPhone 15 Pro Max 保数据安装与 Debug 1204

## 范围和源码

用户要求继续苹果开发签名、原位安装和真机调试，Android 暂停。当前干净分支为 `codex/integrate-latest-20261031`，源码 `53bdc461bfbdd9e70b30c4678a942faf866ae8af`；开始及记录前 fetch / ff-only 核对均无远端新增。没有修改产品源码、依赖、服务端开关、商店状态或其他 App。

实际目标是 USB 连接且已解锁的 iPhone 15 Pro Max，iOS 26.6，开发者模式 enabled。原装 Say Ring 1.0.8（1185），包名 `cn.saydian.ring`，团队 `W7SXQ4A226`。本轮没有卸载、注销、解绑、清空数据库或重置戒指。

## 串行签名构建

使用本机 Flutter 3.44.9 / Xcode 26.6，正常 `lib/main.dart`，开发团队保持不变，依次执行：

```sh
flutter build ios --profile --no-pub --target=lib/main.dart --build-name=1.0.8 --build-number=1204 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn
flutter build ios --debug --no-pub --target=lib/main.dart --build-name=1.0.8 --build-number=1204 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn
```

Profile Xcode 35.3 秒、Debug 45.4 秒成功。每种构建完成后独立冻结 App，再开始下一种构建。两者严格深度验签成功；实读 1.0.8（1204）、固定 Bundle ID、UIDeviceFamily=[1]、开发调试 entitlement、描述文件有效且包含当前设备。Profile 的 Runner / App dSYM UUID 匹配；Debug 确认 JIT kernel 存在。没有提高最低系统版本。

保留既有 sqflite_sqlcipher / YC 插件 SPM 警告、微信 SDK 新模拟器 arm64 警告；它们没有阻止本次 iphoneos 构建。Android 没有启动本机或云端构建。

## 覆盖安装与数据证据

1185 是苹果商店签名，安装前 `devicectl copy from` 返回 ContainerLookupErrorDomain 3，不能记为备份成功。按当前正常安装调试授权，用系统原位安装已核验的同包名、同团队开发 Debug 1204；没有使用 Flutter drive 或卸载参数。

安装成功后，iOS 实际迁移了数据容器路径，旧私有安装包装器的“路径必须相同”断言停止了后续启动。容器 UUID 相等不能替代文件保留证明，也不能据此直接断言丢失；保留失败记录后，先导出新可访问容器，再启动调试。

第一次导出仍用旧脚本 `--source .`，当前 CoreDevice 拒绝该路径（11007）。改为容器根 `--source /` 后导出成功，24 个文件；包含约 3.2 MB 的加密健康数据库，数据库及偏好文件修改时间早于安装。该目录没有 Documents，不能沿用旧手机“必须有 Documents”的断言。

这是**安装后、调试前**的私有快照，不是安装前商店版快照，不能声明完整安装前后字节一致。启动后的实际证据是原登录仍有效、读取到 88 条健康缓存记录、原绑定 R12 自动完成连接。没有把云端回读等同于所有本地旧数据已逐字节验收。

## 真机 Debug 和页面

使用核验后的固定 Debug App，`flutter run --debug --machine --no-pub --no-build --no-uninstall-first --device-connection=attached -d <已核验设备> --target=lib/main.dart --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --use-application-binary=<冻结的Debug App> --vmservice-out-file=<私有文件>`。

首次私有包装器误带 run 不支持的 `--build-name/--build-number`，退出 64，未启动应用；移除后成功。VM URL 文件为 ws 协议，首次只读检查错误地交给 HTTP fetch，随后在检查器转换为同一端点 HTTP 后成功；这些是本机检查脚本问题，不是 App 产品修复。

实际收到 `app.started`；非完整重启的 `app.restart` 热重载返回 code=0。原生目标进程与 VM PID 一致，main runnable=true、Resume；DevTools HTTP 200。最新回读仍是 1204、开发签名、同一原生/VM 进程，登录有效，无当时接口错误或未处理崩溃证据。

已有 WDA 开发 Runner 在本次设备授权后可用；仅接受了已核对属于 Flutter Debug 的本地网络提示。实际查看首页、设备页和“我的”；期间手机多次自行导航及切至其他前台应用，检测到非 Say Ring 前台即停止动作，没有读取其他应用内容。手势页仅有观察证据，不能记为本轮自动化完成整套功能验收。

本轮未改头像、账号、提醒、手势或监测设置，没有做固件写入、测量、相册保存、解绑或真实距离测试。

## R12 同步未通过项

原绑定 R12 自动连接成功，固件实读 `RT12_3.20.00_260730`，电量及实际设备功能入口返回；没有手动选另一枚戒指。当次 VM 为 connected=true，无活动测量，连接和 Debug 服务保持。

历史读取结束后状态为“已更新 64 条”，同时保留“戒指未返回完整同步确认”原因；本轮缓存读取仍为 88 条，不能将这两个不同口径混为一谈。同步不再持续忙，但不是完整历史通过。

核对原生实现：七天分项读取以真实回调记录完成状态，整体 150 秒保护结束时将未确认项保留为 partial；Dart 保存有效记录并保留部分失败原因。本轮证据尚不能判定是哪一类回包缺失、固件差异还是总时限触发；没有伪造完成、清戒指数据或删除提示。需补充逐项原生回调证据后再作针对性修改。自然断连三轮、完整历史、真实测量和全页走查仍待验。

## 检查与留存

本轮产品源码与已通过回归的 53bdc46 一致，没有为文档重复整套 Flutter 测试；此前静态检查、双时区各 1722 项 Flutter 与 42 项宿主协议测试见 [上一轮记录](SAY-RING-MAC-CACHED-UPDATE-20261101.md)。不能将该宿主结果写成此次 SDK 实物通过。

签名 App、符号、安装回执、备份、VM 端点、账号/设备原始日志和截图均仅保留于忽略的 `.build/ios-live-20261101-17Ay1l`，不进入 Git。当前继续保留 Debug 调试器；Debug 脱离 Flutter/Xcode 后不能作为桌面冷启动稳定性结果，独立使用可选已冻结的同源码 Profile，未将两者混称。

只提交和推送本记录及索引至当前开发分支，使用 `[skip ci]` 尊重 Android 暂停；不推进 main，不发布商店或下载包。

## 交接时的状态变化

09:27 后再次只读核对：1204 Debug/VM 仍在线、登录及 88 条缓存记录仍可读，但 connected=false。手机已进入“查找设备／未发现设备”页面；本任务没有点击解绑或搜索入口，不能推断是自然离线、其他手动操作或异常，也不能沿用此前 connected=true 宣称持续稳定。只读诊断补查 RPC 返回错误，未取得原因；没有尝试改变当前目标或清空数据。保留当前调试连接，恢复目标与同步完整性继续列为待验，未将本轮写成全功能完成。
