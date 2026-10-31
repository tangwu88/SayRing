# 2026-10-31 XR 手势重连循环修复 1195

用户反馈1190重连后仍持续显示“需要重新连接”。本轮从干净的30cc82d开始，fetch origin成功且没有远端新增；保留账号、资料和原绑定，继续当前XR与实际SD_RING_R8，不借用其他戒指结果。已阅读AGENTS、1190记录、交接及复盘/回归要求。

## 复现与定位，包括未通过轮次

1. 1190进入手势约1.15秒即返回requiresReconnect，原R8连接仍有效。上一版保留了失败提示，但未解决读取失败根因。
2. 1191为正常main开发签名诊断版，临时NSLog已编译入包，但Flutter未转发这些系统日志，不宣称取得诊断回包；再次进入约1.85秒失败。
3. 独立审计本机SDK二进制发现普通touch读取不填充预留strength、返回0；普通touch写入只发mode和duration。1192先兼容ordinary touch0：静态分析零问题，UTC/上海各1688项、原生契约和iOS Debug/Profile、Android双ARM Debug/QA Release均通过，但XR真实读取仍失败。这项修复没有命中本轮R8的gesture路径，不能记为问题已解决。
4. 1193将不含身份/健康数据的控制元数据写到私有Caches，取得真实证据：gesture=true、touch=false、screenTouch=false；相机探测进入/退出成功；读取手势时pendingSync/pendingConnect/pendingCamera/readingDetails与poison均为false。约0.605秒后SDK返回mode0、strength0、duration0、NSError=nil，旧校验拒绝。此证据排除了本轮相机探测失败和SDK仍忙的候选。
5. 1194兼容非screen成功零值后，首次约0.69秒读到真实“关闭”，显示实际支持的关闭、短视频、音乐、阅读。写音乐后固件连续三次返回rawMode1、strength1、duration0；旧“强度必须与关闭时0完全相同”规则再次误报未确认。重连后独立读取证实音乐实际已保存。随后正常UI恢复关闭并额外刷新，两次均rawMode0、strength1、duration0。固件首次开启会将未初始化强度0设为1，关闭后保留1；没有为复现而恢复出厂或把它强制写回0。

## 最终1195修复

- 原生快照明确区分screen路径；非screen保留成功返回的零强度，不伪造默认灵敏度。mode、duration、负值/上界和SDK错误过滤保留；screen SDK没有等同字段证据，继续严格校验。
- 新QRingGestureReadbackMatches继续要求实际模式等于所选模式、类型与时长相同，已有正强度完全保留。只对已证实的“非触控、原关闭且强度0 → 开启后实际强度1”接受固件初始化；原始输入仍原样发送，实际回读仍原样显示。
- SDK setter的成功回调仅是发送完成，不冒充戒指确认。最终要求两次连续相同的独立回读；最多3次只读尝试，写入不自动重试，仍保留expectedMode、连接代次及控制通道隔离保护。
- DEBUG控制诊断仅写本机Caches，限64KB，不记录账号、设备标识、健康值；Release不写日志。临时NSLog已移除，对外页面没有诊断内容。

## 原生与宿主回归

原生测试编译真实生产header，旧30cc82d头通过兼容调用成功编译但因实际行为失败：ordinary轮1/4通过、closed-gesture轮1/5通过；不是签名变化导致的编译假失败。新策略最终6/6通过，共389断言，覆盖真实关闭零值、模式映射、未知模式不冒充关闭、字段边界、screen拒绝，以及59项首次初始化和严格回读检查。首次默认PATH没有node，编译尚未开始；改用本机实际Node绝对路径重跑，失败记录保留。

主要验证命令：

```text
flutter analyze --no-pub
TZ=UTC flutter test --no-pub --concurrency=4 --reporter=expanded
TZ=Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded
node --test tool/test_qring_camera_integration.mjs
DEVELOPER_DIR=<official Xcode27.1>/Contents/Developer node --test tool/qring_camera_policy.test.mjs
flutter build ios --debug/--profile --no-pub --config-only --no-codesign --target=lib/main.dart --build-name=1.0.8 --build-number=1195 --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn --dart-define=SAY_RING_COMMERCE_ENABLED=true --dart-define=JPUSH_APP_KEY=
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug/Profile -sdk iphoneos -destination generic/platform=iOS -derivedDataPath <isolated cache> IPHONEOS_DEPLOYMENT_TARGET=15.0 SAIDIAN_DEVELOPMENT_TEAM=W7SXQ4A226 DEVELOPMENT_TEAM=W7SXQ4A226 CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY=Apple Development SAIDIAN_CODE_SIGN_IDENTITY=Apple Development build
flutter build apk --debug --no-pub --target=lib/main.dart --target-platform=android-arm,android-arm64 --build-name=1.0.8 --build-number=1195 --dart-define=SAY_RING_COMMERCE_ENABLED=true
SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release <same target/version/architectures>
```

本机官方Xcode27.1，最低系统本地覆盖15，仓库默认13未变；不将本机构建冒充默认13验证。Android仅回归构件，不安装或公开发布。每轮的完整实际命令、耗时、哈希与失败结果保存在Git忽略的各build目录。

## 数据保护与真机验收

每轮安装前devicectl copy from私有备份完整可访问App容器。最终1195安装前99文件，正常Flutter run使用已验签的main Debug，没有使用默认flutter drive或卸载，没有换号、清数据、解绑或重置。原始照片、数据库、端点和设备标识不提交Git。

最终1195安装、真实读取、模式切换/额外刷新/恢复、重连与数据比对结果按设备回执追加。不能将模式读写确认当成实际音乐/翻页动作已由人操作验证。本轮不发布商店或下载页。

## 最终1195回执

1195开发签名与XR描述文件、正常main、无QA定义均核验；手机系统实际回读cn.saydian.ring / 1.0.8 / 1195。Debug附加与热重载成功，静态分析零问题、UTC/上海全量各1688项通过，原生相机契约及389条策略断言通过。最终iOS Debug/Profile和Android双ARM Debug/显式QA Release全部成功。

XR/同一SD_RING_R8真实读取原关闭状态成功，音乐模式约3.54秒保存并完成两次独立相同回读；额外刷新仍是音乐模式，strength1/duration0保持不变。随后正常界面恢复关闭、额外刷新、再次连接原戒指并自动读取，均为readbackVerified=true、confirmedMode0、strength1/duration0。页面不再循环要求重连。1193/1194首次未初始化0及固件初始化1的实物回包，结合1195 helper回归验证该特殊路径；没有为了重现初始化而重置戒指。用户本轮表示现在不方便操作音乐播放器，实际播放/暂停/切歌动作保留待验证。

最终私有容器99→100文件，12个原相机文件哈希均不变，唯一健康数据库字节哈希相同。恢复的是原来的关闭模式；固件在首次开启时初始化后的强度1保留，不声称仍与最初未初始化0完全相同。保持正常1195调试会话，后续用户追加的连接稳定性/速度检查另立验证记录，不把本轮一次重连成功当成长期不断连保证。
