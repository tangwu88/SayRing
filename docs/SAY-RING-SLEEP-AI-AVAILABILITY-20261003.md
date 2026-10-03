# Say Ring 睡眠 AI 分析说明与授权修复

## 原因与范围

- 1025 真机“AI 睡眠分析报告”页显示服务或分析说明不可用。生产 AI 已有真实配置，后台未发布分析说明，所以生成前被保护性阻止。
- 客户端从 `db96c5cef2f7344b839ed84e6466e549ec247a42` 继续；fetch 发现远端 `c31d618` 仅新增更新文档。安全合并保留双方记录，索引冲突已逐项保留，没有覆盖源码或其他 App。
- 本轮只修改 Say Ring 睡眠授权 API 与相关文案：专属说明、专属授权与撤回，不再复用 Health App 的健康分析授权。用户仍须主动确认每次上传；游客、不完整说明、旧版本、换号及撤回继续拒绝。
- 预期：服务端说明发布后可加载并确认，不再显示含糊的不可用错误；真实 AI 成功后才显示实际评分和报告。保留现有账号、本机数据与 App Store 审核包。

## 检查与验收

- 格式化、静态检查、定向/全量测试、双端构建、1026 原位安装与真实报告回读逐次补记。模拟报告仅用于测试，不作为真实生成证据。

## 已执行

- `dart format` 四个运行时代码/测试文件通过；首轮 Analyzer 零问题。首轮定向 14 通过、1 失败，原因是撤回提示从“健康 AI”改为“睡眠 AI”后旧断言未更新；更新断言，第二轮 15/15 通过，保留首轮日志。
- 新增不可用原因不得触发同意/上传的 UI 测试后，最终 Analyzer 零问题（5.2 秒）；`TMPDIR=/private/tmp TZ=Asia/Shanghai flutter test --no-pub --concurrency=2` 与 `TZ=America/New_York` 全量各 1069/1069 通过。
- `devicectl list devices` 与 `xctrace list devices` 均显示 iPhone 15 Pro Max 离线，没有执行卸载、安装、清数据或真实第三方健康上传。构建产物与安装结果分开记录。
- Foundation 的 QRing 原生映射断言通过；它使用合成样本，不替代真实 SDK 睡眠或 AI 验收。
- 同源生产配置 `--dart-define-from-file=config/ios-app-store-no-push.json` 串行完成 `flutter build ios --debug/--profile --no-pub --build-name=1.0 --build-number=1026`。Profile 保存于忽略目录 `.build/SayRing-1.0-1026-Profile.app`；实际 plist 为 `cn.saydian.ring`、`1.0.0 (1026)`、`UIDeviceFamily=[1]`，Apple Development / `W7SXQ4A226`，`codesign --verify --deep --strict` 通过。Runner SHA-256 为 `27d45eac2404eadd764528c5bb6470865d3e2461d7301fdbb51f61084aedd3ce`。未将开发包作为 App Store 分发包上传。
- `JAVA_HOME=…/temurin-17.jdk/Contents/Home ./gradlew :app:testDebugUnitTest --rerun --max-workers=1` 首轮失败：QRing AAR 的 Gradle 9.1.0 immutable transform 单个缓存目录 `7d449599654a801d656c79251a8c1bc3` 校验不一致。确认没有文件句柄或活动构建后，将该 49 MB 缓存移至 `/private/tmp/sayring-gradle-quarantine-20261003.hweJRI/` 保留恢复，没有删除 SDK 或全局缓存。原命令重跑通过，JUnit 8 套件共 37/37，零失败、零跳过。
- Android `flutter build apk --debug/--release --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0 --build-number=1026 --dart-define-from-file=config/ios-app-store-no-push.json` 串行通过（29.4 秒 / 76.8 秒）；Release 使用显式 `SAIDIAN_ALLOW_QA_RELEASE=true`，仍是 Android Debug 证书，仅内部 QA，不是正式商店包。双包实际 ID 为 `cn.saydian.ring`、`1.0 (1026)`、ARM32/64，`apksigner verify` 和 `zipalign -c -P 16 4` 均通过。
- 已保留 `.build/SayRing-1.0-1026-Android-Debug.apk`（SHA-256 `4fd282ae4632abf7767def5a35866c84ba6567037a291d3950c999865f502fbf`）和 `.build/SayRing-1.0-1026-Android-QARelease.apk`（SHA-256 `fd6d5eafc4808d7f8831c1bef81c48f9caef6c12ab50c7ed9204fac8abc4aaa3`）。没有安装安卓手机或将 QA 签名写成正式签名。
- 日志保留于 `/private/tmp/sayring-sleep-consent-{analyze-final,full-shanghai,full-newyork,ios-debug,ios-profile,android-native,android-native-retry,android-debug,android-release}.log`；未关闭已有厂商插件 KGP/SPM 未来迁移警告，也没有改 SDK 或权限来绕过检查。
- `python3 -m unittest discover -s scripts/release -p 'test_release_gate.py'` 30/30 通过；均为合成发布门禁测试，不是对正式 App Store 分发包的验收。fixture 中打印的旧 Health 地址不代表本轮客户端请求或上线地址。
- 服务端专属授权修复 PR #17 首轮真实数据库/镜像 CI 已通过；安全合并同事后续主线改动后正重跑集成 CI，未在本条记录时上线或发布候选说明。客户端仍只推当前 Say Ring 分支；本轮没有真实 iPhone 报告回读，不先把它升级为已接受的 main 基线。

## 14:42 发布续检与阻断

- 更新后的服务端分支 `be9e07c7b5d66b81edeabcc64421b4e79bd67ba3` 在 Actions `37102416098` 完成集成 CI；真实 PostgreSQL、运行镜像及原始镜像离线传输演练通过。PR #17 于 2026-10-03 14:22:39（中国标准时间）合入主线 `d350538ac53cb7c7a188405b8fc8e3917112cb29`；与已测分支源码相同，同事的国际公开页面改动保留。
- 主线 Actions `37102848479` 的 `verify` 与不可变发布产物生成成功，自动发布失败：`Another release is running`。GitHub 中旧的 `c93eeb27a64f1f9c70ceba8aebcc1d564e2e43e5` 发布 `37101853848` 已取消，但服务器的发布锁仍未释放；不把 GitHub 任务取消当作服务器进程已退出。
- 为排除服务器拉取镜像网络问题，临时将现有 `PRODUCTION_IMAGE_TRANSPORT` 从 `ghcr` 改为 `ssh`，对同一通过检查的主线与原始镜像触发 `37103676639`。镜像导出及 SHA 校验成功，但预装仍因同一发布锁失败，实际应用更新步骤未执行。随后核对该变量没有被别人改变并恢复原值 `ghcr`，回读确认；没有新增凭据或放宽 SSH、证书、接收器权限。
- 两个线上 ready 路径仍显示 `50dd2abbbcad82323b7d6fef7310a4aa33a26713`、数据库正常，不能写成新版本已部署。管理后台仍没有新的睡眠分析说明类型，候选中英文说明尚未发布；没有将旧的 Health App 分析说明冒用为 Say Ring 说明。
- 现有腾讯云终端未登录，Mac 没有该主机的 SSH 身份。按用户此前获准的服务端配合范围，请“导入-app服务端”任务仅作只读检查；其确认没有可用的既有服务器会话，未能核实持锁 PID 或阶段。没有扫描或使用其他凭据，没有杀进程、删除锁文件、修改生产权限或重复并发部署。旧脚本的镜像拉取有 3600 秒期限，但未确认实际执行阶段，因此不承诺锁一定在某个时刻自动释放。
- `devicectl list devices` 与 `xctrace list devices` 再次显示 iPhone 15 Pro Max 离线。1026 Profile 验签及双 APK SHA 重核与前述一致，但没有覆盖安装、同意第三方健康传输、真实生成或重开回读；既有手机数据与审核中的 App Store 版本不变。
- 本次只补记录，不改运行时代码或已验证构建。后续必须先确认发布锁可用及最新主线，通过标准发布流程核对两条线上 revision，再在后台发布专属中英文说明并从公共接口回读。最后用 1026 在真实手机上由用户确认上传后生成、回读真实 AI 报告；完成这些前，本故障仍属于待上线、待真机验收。

## 15:10 真机续检与生产客户端遗漏

- iPhone 15 Pro Max 已恢复连接；1026 开发签名 Profile 原位覆盖安装成功，安装前后系统应用记录为同一 `cn.saydian.ring`，未卸载或清空数据。独立启动与随后冷启动均收到系统成功结果；真机截图可见原头像、昵称与已有健康/睡眠卡。这里只确认可见数据保留，不宣称全部历史库已验收；真实数值、头像、昵称及截图不入 Git。
- 首次启动命令把 `--console` 放在 Bundle ID 后，系统将其作为应用参数；该次不能记作连续调试控制台已附加。随后使用正确的 `--terminate-existing` 位置再次独立冷启动，保留原始命令结果，不将四行启动输出当作完整运行日志。
- 发现生产 `GlobalSaydianApiClient.getGlobalLegalDocument` 的精确白名单只包含用户协议和隐私政策，因此即使新说明部署发布，睡眠说明仍会被客户端阻止。原 UI 测试的控制器替身直接返回说明，没有覆盖此真实 API 客户端边界。
- 先增加 canonical/global 两种路径、中文/英文共四个真实客户端 HTTP 契约用例，修复前四项全部复现 `This document is not available.`。然后只新增精确 `say_ring_sleep_analysis` 类型，保持同源、路径穿越、版本、语言、查询参数和禁止重定向保护；新增十五个睡眠说明非法路径零请求用例。
- 新源码需使用 1027 构建并重跑完整回归，不能用 1026 的产物或测试替代。服务端发布、说明公共回读、1027 覆盖安装和真实 AI 生成的最终结果继续追加。
- 定向命令首轮误填不存在的 `test/sleep_report_service_test.dart`，已存在的两文件 63 项通过但整个命令因加载失败返回非零，不记成功。核对实际文件后重跑 `global_legal_page_test`、`sleep_ai_report_page_test`、`sleep_report_input_test`、`global_health_api_test` 共 89/89 通过；复现失败日志和两次定向结果均保留于本机。
- 1027 源码静态检查零问题（5.7 秒）；`TMPDIR=/private/tmp TZ=UTC/Asia/Shanghai flutter test --no-pub --concurrency=2 --reporter expanded` 两套全量各 1088/1088 通过（71 秒 / 63 秒）。新增十九项均是 HTTP 合成契约，不是实际 AI 报告。
- Android 原生 JUnit 8 套件共 37/37、零失败/跳过；Foundation 从当前 `test/native/qring_record_mapping_test.m` 重新编译执行通过，原生日志守卫 9/9、完整发布 Python 测试 31/31 通过。图标脚本 `--check` 核对 39 个已有资源通过，未重写图标或原始素材。
- 15:13 对同一服务端 `d350538` 与原始已校验镜像触发标准 SSH 传输发布 `37105618933`；未删锁或改变接收器权限。临时传输变量会在该次任务结束后按原值恢复，并单独记录线上核验结果。

## 1027 构建与真机检查

- 同一生产 API 配置的 iOS Debug / Profile 串行构建通过（72.7 秒 / 72.4 秒）。开发签名 Profile 已保存至 `.build/SayRing-1.0-1027-Profile.app`；`cn.saydian.ring`、`1.0.0 (1027)`、`UIDeviceFamily=[1]`、`W7SXQ4A226` 与严格验签正确，Runner SHA-256 为 `12677961f79262012ecef796fbe51ee1bd24620e57fa4609d04ba892e249a013`。未上传 App Store 或改变当前审核。
- 15:19:58 原位覆盖安装成功，系统应用列表确认 1027；未卸载、改包名、清数据或安装其他 App。15:20:30、15:21:15、15:22:03 三次独立冷启动，逐次超过 30 秒后系统进程查询仍返回对应启动进程。当前真机截图确认原头像、昵称和健康卡可见，首页睡眠概览与用户此前详情一致；所有私有截图及真实数值留在本机，不写入 Git。
- `xcodebuild ... -configuration Profile -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO ... build-for-testing` 成功，日志确认 `RunnerTests.swift` 已实际编译。未部署 XCTest Host 到用户 App 容器，未执行完整 XCTest / UI integration；不能把编译成功算作测试执行。已有厂商 dSYM 引用其原电脑 `.pcm` 的警告保留，未删除用户缓存或忽略真实构建错误。
- Android Debug / 显式内部 QA Release 串行构建通过（12.3 秒 / 66.0 秒），保存于 `.build/SayRing-1.0-1027-Android-{Debug,QARelease}.apk`。双包均为 `cn.saydian.ring`、`1.0 (1027)`、ARM32/64、Android Debug 签名，仅内部测试；没有安装安卓手机或发布为正式商店包。
- APK 检查首轮引用了不存在的 `36.1.0/aapt`，命令未执行，不计通过。按当前 Mac 实际工具清单改用 `36.0.0`，双包 `aapt` 身份与 ABI、`apksigner verify`、`zipalign -c -P 16 4` 全部通过。Debug SHA-256 `9578fbe30fa8a3c7e7aad2edad02ae00f89d98e537b8d1836dcddc79af81ab0a`；QA Release SHA-256 `fe3f72958b2342fc31a5565586e39dbd2b0c0bcad27baa45bc646858da4b8ea8`。
- 15:25 两条公共 ready 的新一轮核对仍为旧 `50dd2ab`，本次 `37105618933` 尚在原始镜像预装步骤。GitHub API 不提供未结束 job 的实时日志，匿名浏览器日志也需要登录；没有转移 CLI 凭据或操作其他账号。新说明尚未上线回读，未替用户确认向智谱 BigModel 发送真实健康数据，也未生成真实 AI 报告；该端到端故障仍未验收。
- 本次仅提交已测试的精确路径修复和脱敏记录到当前 Say Ring 分支，不将未上线、未获得真实报告的代码宣称为已接受的 main 基线。原协议、其他两款 App、现有 App Store 审核与原始素材均未修改。
