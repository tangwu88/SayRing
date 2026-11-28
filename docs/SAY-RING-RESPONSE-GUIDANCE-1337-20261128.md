# 回应好友署名条件与拒绝说明（1337）

## 原因与范围

- 用户在1336从微信报告进入“回应好友”成功，勾选昵称后收到笼统失败。经确认是别人的报告，双方尚未在远程关爱关联。用户同意保留关联要求，并明确说明匿名/署名选择。
- 修改前工作区干净；读取AGENTS、INTERNATIONAL-HANDOFF、最近1336记录、回归清单和复盘。`git status --short --branch`、`git remote -v`、带本机代理的`git fetch origin --prune`通过；当前分支codex/android-1320-install-20261124，本地与跟踪远端均为84300108ae27883ff8e475d823a2e48f1c1e55ed。`git merge --ff-only '@{u}'`返回Already up to date，不声称合并其他main改动。
- 只读核对服务端origin/main：署名需有效且未屏蔽的关爱关系，缺少时返回403“请选择匿名回应”。客户端requestRing经_decode保留ApiException.statusCode/message；原showRingError统一隐藏该原因。
- 本轮不改服务端、关系规则、健康/设备功能、微信分享或首连诊断范围。不为用户发送真实回应。

## 实现

- `lib/ui/ring_share_page.dart`：昵称选项新增常驻说明，未勾选仍匿名。仅在本页本账号、署名请求收到精确403及已知业务文本“请选择匿名回应”时显示持久的行内说明和无障碍播报，告知先关联或手动取消勾选。保留勾选及报告，不自动降级、不重发、不跳转。其他403不冒充未关联，429及未知错误沿用原处理。换账号后的旧错误不显示给新账号。
- `test/ring_named_response_test.dart`：使用合成报告/账号，覆盖默认匿名、显式提交、中文/英文未关联拒绝到手动改选再提交、允许署名、其他403/429/500、重复点击、换账号迟到错误，以及360x740/1x和2x字体滚动布局。没有实际网络写入。
- 目标正式包1.0.16（1337），Git外产物/日志目录E:/SayRing-response-guidance-1337-20261128。Windows不能执行iOS原生Debug/Profile，Flutter共享页面回归不等同iOS原生构建验收。

## 检查记录

- 首轮读取曾误用Windows通配路径向rg传参、读取不存在的BUG-RETROSPECTIVE.md，以及在服务端目录读取App文件失败；随后改为目录配合-g和实际文件路径，已读正确复盘与API实现。未因此改动其他项目。
- Dart format已执行；定向/静态分析/双时区全量及Android Debug/Release和签名门禁执行结果待后续追加，不预记成功。
- 服务端署名限制仅做当前源码契约核对；未向生产提交真实回应。用户本人验证匿名/有效关联署名仍待新包。

## 已执行命令及首轮结果

- `dart format lib/ui/ring_share_page.dart test/ring_named_response_test.dart`：两文件完成格式化。
- `flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn test/ring_named_response_test.dart test/ring_experience_test.dart`：44项通过，含本轮10项回归。日志targeted-initial.log。
- `flutter analyze --no-pub`：52.4秒，无问题。Git外Invoke-Checks.ps1串行运行analyze/utc/shanghai/debug/native/release/verify，各阶段保留单独日志，失败立即终止。
- 完整测试参数`flutter test --no-pub --concurrency=1 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`，分别使用TZ=UTC、TZ=Asia/Shanghai。Debug使用双ARM架构、--build-name=1.0.16、--build-number=1337、config/dev.json.example及SAY_RING_COMMERCE_ENABLED=true。Release通过原Git外签名脚本构建同版、同功能开关；不将密钥/构建产物入库。
- 本轮Android原生源代码/依赖锁没有变化。native阶段只生成当前releaseRuntimeClasspath依赖报告用于ABI检查，不冒称重新执行原生单测；沿用1335已通过的142项原生策略证据。
- UTC全量2567项通过（约5分7秒），未发现失败；其余阶段继续执行，最终结果后附。
- Asia/Shanghai全量2567项通过（约5分19秒）；Android Debug构建通过（assembleDebug约246.3秒），发布依赖报告通过（约2分7秒）。构建沿用已有camera/JPush插件KGP迁移与Java过时API警告，本轮不扩大范围升级插件；没有构建失败。正式Release继续执行。

## 最终构建与交付

- 正式Release通过，assembleRelease约538.3秒。`apksigner verify --verbose --print-certs`核实原正式证书SHA256=81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de；aapt核实cn.saydian.ring、1.0.16、1337且非debuggable。生产API/JPush manifest、ARMv7/ARM64 ABI与ZIP对齐门禁通过；原有ARMv7 DSP/ECG两项4KB ELF例外保留，不能称所有市场16KB验收。临时android/key.properties不存在。
- Git外APK：E:/SayRing-response-guidance-1337-20261128/SayRing-1.0.16-1337-release.apk，76453716字节，SHA256=5697c9f358e57b3528df0229734b759e4c7a33f15178c8290b33ab3bc063db8c。
- 最终`git diff --check`通过；提交前重新fetch成功，当前HEAD与跟踪分支仍均84300108ae27883ff8e475d823a2e48f1c1e55ed，没有远端分支冲突。显式提交本轮页面、定向测试、日志和索引四文件；不提交构建/签名材料，不改其他项目或强推。
- 当前USB手机只读系统核验仍为正式1336；本轮没有发起覆盖安装，也没有代用户提交真实回应。新包安装和用户本人匿名/有效关联署名回应属于待实测项；iOS原生构建未执行。服务端代码和部署未改动，APK生成/分支推送不等于线上更新清单已发布。

## 2026-11-28保留数据覆盖安装

- 用户要求安装到当前手机；重新通过`adb devices -l`核对唯一USB华为，原正式证书验签及APK SHA256重新核验通过，产物与上节一致。
- 执行`adb -s <已核实的目标手机> install -r <1337正式APK>`，未卸载/解绑/重置/清数据。手机锁屏遮住安装页，已请用户本人完成解锁及华为安全确认；随后安装进程返回Performing Streamed Install / Success。完整安装日志install-20261128.log保留在Git外产物目录。
- 系统`dumpsys package cn.saydian.ring`独立读回versionCode=1337、versionName=1.0.16、lastUpdateTime=2026-11-28 11:47:57；用户亦回复“已安装”。安装已确认，不再待安装。未代用户发送回应，真实匿名/已关联署名提交仍待本人验证。
- 本轮仅安装和记录，源码/APK未变，沿用上节完整测试和验签结果。修改前工作区干净、fetch成功、本地和跟踪分支均a6e69a90ecec4ef39124828fb26010f5d30c0d90；仅提交本记录，不重跑无变化的构建。
