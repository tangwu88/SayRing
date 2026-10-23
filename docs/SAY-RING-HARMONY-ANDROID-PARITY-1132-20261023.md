# 鸿蒙按安卓版对齐（1132）

2026-10-23用户明确要求以当前安卓版为标准统一鸿蒙页面与功能并重新打包。基线b93f6b42d92fb75433cc41bf7c80cfb4f34273a3，工作树干净；已status/remote/fetch，开发分支仍1d2807b。创建codex/harmony-android-parity-1132-20261023保留原1131分支及产物，不改Android/iOS业务、后台、线上下载或商店。已读本项目AGENTS、交接/回归/复盘和最近1131记录。当前请求不是再次改版本号打包，必须记录真实适配范围。

P1差异：鸿蒙仍为旧邮箱密码默认登录，语言选择、注册入口、红色主题、旧健康双列和首页运动列表；Android是默认中国手机号验证码登录、独立微信绑定、统一暖白/蓝青主题、健康大卡片与可编辑布局、运动二级页。复现和期待见用户截图及两端源码。涉及Index.ets、GlobalAuth/AccountClient/NativeHttpTransport、主题/本地显示偏好及测试。现有账号/原始健康数据不清理、不伪造、不扩大设备能力。

API检查发现NativeHttpTransport只允许/api/开头，但AccountClient实际发送/global/api/saydian-app/v2路径，真实国际请求会在客户端被拒绝。修复必须仍固定国际域和路径，验证码沿用Android明确的两个共享认证端点，不允许旧国内路径、任意URL、携带其他会话或重定向。保留发布协议版本/产品校验、年龄确认、验证码目标绑定、过期与重发冷却、账号代次和安全持久化。

已异步询问用户是否有QRing/LuckRing原厂鸿蒙SDK；现仓库只有Android/iOS SDK及既有Vep/Yuc鸿蒙工程。缺原厂SDK不能用其它供应商代连或开放假测量/手势，不将视觉一致等同硬件功能一致。优先完成可实现的界面、登录与已有业务；厂商能力和真实设备/OTP/支付验收单列。未经授权不发真实验证码、付款、重置戒指、不卸载/清数据，不提交商店。正式构建沿用原证书，HAP和完整APP双签双验。

计划验证：新增真实契约测试、鸿蒙全量双时区、ArkTS Debug/Release编译、已验证原证书双签门禁和冻结包哈希；Android/iOS运行源码不动，已有1131回执只作不变基线，不能冒称新鸿蒙实测。所有失败、修正、实际结果和未验收项完成后续记。

## 用户确认及本轮完成范围

用户明确回复：**暂无鸿蒙 SDK，先对齐可实现部分**。本轮作为可实现部分的阶段交付，不宣称鸿蒙已具备安卓版全部业务或硬件能力。没有更换架构或删除旧账号、健康、运动数据；Android/iOS运行源码、原生SDK和后台代码不变。后续为核对跨端回归并保持交付构建号一致，使用原Android源码与原正式证书重新构建1132，不把版本号变化称为新增Android功能。

| 页面/能力 | 本轮结果 | 验收边界 |
| --- | --- | --- |
| 登录、语言、视觉 | 默认中文、默认大陆手机号验证码；移除可见的语言/区号选择及独立注册入口；黑色品牌标识、暖白/蓝青统一配色 | 邮箱验证码按后台能力关闭；保留原有邮箱密码入口，并明确说明渠道不可用 |
| 验证码认证 | 与Android同两个固定国际共享验证码端点，真实响应解析、CN规范化、已发布协议、年龄确认、目标绑定、到期与冷却、换号/退出后的迟到响应保护 | 合成传输契约测试通过；未向生产发送验证码或执行真实登录 |
| 健康首页 | 全宽大卡片、编辑入口、显示/隐藏、上下按钮排序、保存/取消、按稳定会员隔离偏好；离线实际历史仍可查看 | 不声称支持拖拽；不生成无设备能力的卡片；隐藏不删除记录；未做鸿蒙手机视觉验收 |
| 运动 | 首页入口进入二级页，默认首排最多4项，更多进入独立全部运动页；今日活动使用实际快照 | 依赖真实设备能力，未知数据不补零；原有本地轨迹/记录保留；Android高德静态底图尚未移植 |
| 设备、我的、二级页面 | 共用Android主题色，设备入口不再用手表图形；保留权限/不支持/未配置状态 | 不扩张实际SDK能力 |
| 客服 | 与Android相同企业微信客服链接、打开与复制；后台电话/公众号继续保留；其未配置不再把全部客服说成不可用 | 尚未在鸿蒙手机实际打开企业微信/浏览器 |
| 关爱分享项目 | 只列实际指标对应的项目，全选不修改已隐藏或未知的既有授权 | 仅前端选择逻辑已适配；旧关爱接口的国际V2迁移仍未完成，不能称真实分享已联通 |
| QRing/LuckRing戒指、手势 | 明确保留未接入状态，拒绝误路由到其他SDK | 缺厂商原生鸿蒙SDK，不支持用替代供应商或假数据验收 |
| 微信授权及其他旧业务 | 保持原生能力门禁和失败关闭 | 原生微信仍未接通；旧V1关爱、商城、通用AI、头像/反馈等尚需逐项适配国际V2；无损健康上传仍受已有安全门禁限制 |

## 实际文件与修复

- `model/RingParity.ts`：共享Android主题/客服目标；手机号、已发布渠道、挑战、会话的严格解析；卡片顺序/隐藏和能力过滤；关爱可见分组切换保留未知授权。
- `model/GlobalAuth.ts`、`model/GlobalConfiguration.ts`：读取公开login能力，固定两个国际验证码端点；不开放任意URL或国内回退。
- `services/SaydianApi.ets`、`services/LegacySafeHttp.ets`：修复国际V2请求被旧`/api/`前缀误拦的P1；API17–22与23+均走固定国际地址，共享验证码仅允许无旧会话的JSON POST，禁止重定向。旧V1业务仍拒绝，未通过批量替换路径伪装已迁移。
- `services/AccountClient.ts`：验证码请求与登录、当前能力/协议版本检查，复用安全会话持久化/登录代次；未改变原有其他认证兼容接口。
- `services/AppLocaleStore.ets`、`services/HomeCardPreferenceStore.ets`：中文默认和会员隔离显示偏好，不删除旧语言资源或健康数据。
- `pages/Index.ets`：上述登录、首页、运动、客服、关爱与页面主题；编辑保存失败保持草稿，取消不应用，会员变化不应用上一账号结果。
- `AppScope/app.json5`、`services/AppUpdateService.ets`：版本1.0.5/1132。
- `tests/android-parity.test.mjs`与`tests/layout-contract.test.mjs`：新增14项真实模型/AccountClient合成传输/来源契约；更新3处与用户新需求冲突的旧UI断言，不跳过数据/鉴权/SDK边界门禁。

## 实际验证、失败及校正

证据目录（Git外）：`E:\SayRing-harmony-parity-1132-20261023`。CLT26.0.0.821、JDK17、既有Node24与依赖，未升级SDK/插件。所有同项目构建串行，保留每轮日志。

1. 首次新增12项定向测试全部通过。随后增加关爱隐藏授权和退出登录迟到响应两项，14/14通过。
2. `node --test`显式列举`harmony-native/tests/*.test.mjs`，分别设置`TZ=UTC`和`TZ=Asia/Shanghai`。首轮各515项中512通过、3失败：旧快照仍要求注册按钮、红色旧主题和旧首页健康结构。保留`full-*.log`；只将这些断言改成用户本轮指定的新结构，同时保留原权限、隐私、能力和跳转约束。
3. 第二轮两个时区各515/515；增加最后两项后最终两个时区均**517/517、0失败、0跳过**，日志`final-full-UTC.log`及`final-full-Asia-Shanghai.log`，耗时约4.0和4.1秒。测试不含真实戒指回包和生产验证码发送。
4. 首轮Debug/Release编译成功；所有最终源码变更后重新编译：`hvigorw.bat --mode module -p product=default -p buildMode=debug assembleHap --no-daemon`通过，阶段17.9秒、Hvigor16.339秒；`hvigorw.bat --mode project -p product=default -p buildMode=release assembleApp --no-daemon`通过，阶段19.7秒、Hvigor17.873秒。最终日志`debug-build-final.log`、`release-build-final.log`。既有资源重复及弃用警告保留，构建阶段的unsigned产物只是签名前中间文件，不交付。
5. 只读GET国际`/global/api/saydian-app/v2/auth/capabilities?locale=zh-Hans&product=say-ring`：product=say-ring、realm=global、login.sms=true、login.email=false、CN已允许，协议版本`say-ring-cn-2026-10-05-v3`。随后只读获取`say_ring_user_agreement`及`say_ring_privacy_policy`，均该版本、zh-Hans、reviewed=true。没有生产认证POST、测试账号、真实健康数据或后台修改。
6. `hdc list targets`返回`[Empty]`，没有可用于本轮原生鸿蒙验收的手机。未做实际页面截图、物理戒指连接、登录、测量、微信授权、轨迹GPS、支付或通知到达验收。不把宿主测试或编译当真机通过。
7. `git diff --check`通过。辅助只读检查曾猜错文件名/路径、Windows rg字面通配符不匹配、一次补丁上下文不匹配；按实际目录/导入顺序更正，无删除或覆盖用户文件。一次额外检查错误使用服务端cwd读取App文档，立即改回实际App工作树；服务端无修改。

## 鸿蒙正式包签名与991回归（收尾前候选）

目录：`E:\SayRing-market-artifacts-20261023\harmony-parity-1132`。复用已验证1128流程，仅在内存替换输出目录和构建号1132；不修改受保护签名脚本、不轮换密钥、不打印密码、不把凭据提交Git。

先使用原发布P12/官方证书/Profile签HAP；再用项目级`build/outputs/default/pack.info`、`pac.json`与签名HAP经官方`app_packing_tool.jar --mode app`打完整APP；最后用官方`hap-sign-tool.jar sign-app`签完整外层APP。`scripts/release/Verify-SayRingHarmony.ps1 -ExpectedVersion 1.0.5 -ExpectedBuild 1132`通过，外APP及内部HAP均官方验签，bundle=`cn.saydian.ring.hm`、debug=false、版本、release/app_gallery Profile有效、内HAP字节未变化。

官方叶证书SHA256：`C4F4B2AF305C338728D7172B845B4455D7CE1896EA0D40A28579FC1E56C28A3C`。负向测试用同门禁校验未签外层APP，明确拒绝：`signature not found / No Hap Signing Block before ZIP Central Directory`。正反回执保留`final-gate`/`negative-outer-gate`，不把证书、Profile、未签包或原始签名日志放delivery。

| 收尾前候选（不作为最终交付） | 字节数 | SHA256 |
| --- | ---: | --- |
| SayRing-HarmonyOS-1.0.5-1132-release-signed.app | 9468640 | 1CB4F519CF85EAE6A27EFB9976D3D4073563EF644DE7217EB395DDAC218C13CA |
| SayRing-HarmonyOS-1.0.5-1132-release.hap | 18751502 | 649765A44467807EB48E6B733944D8E57E7FBB3329307B0E8C832ADD5B41C9F3 |

完整双签APP用于后续市场提交验证，不解压重压、不改扩展名。HAP用于受控安装验证，app_gallery Profile实际侧载是否接受须以手机为准。本轮未上传AGC，不能声称991已在华为后台复验通过或审核通过。鉴于上述SDK、业务及真机缺口，此包为**正式签名的阶段对齐包**，不是全功能上架验收完成证明。

Android跨端回归、正式重建和Git提交/推送回执完成后续记；iOS源码不变，本机Windows不能执行Xcode Debug/Profile或8项macOS原生夹具，不计通过。不部署后台、不更新公开下载、不安装手机、不提交应用市场。

## 消费端引导收尾（正式冻结前）

源码巡检发现P2：连接引导仍要求“手表保持亮屏”“手表弹出确认”，设备设置又提示去手表操作，且旧注册页渐变/关爱文字/运动边框还含粉红色。对无屏戒指不适用，与本轮页面统一需求不一致。未用真机复现，仅按实际ArkTS文案定位。修正搜索、唤醒、手机系统配对引导和查找/运动/读数文案；设置明确只调整设备实际返回项目；去除上述残留配色。未全局替换供应商SDK标识或放开旧表盘/屏幕等受实际能力控制的兼容页面。

新增第15项契约防止无屏设备引导回归，最后两次双时区全量均518/518，0失败/跳过。最后冻结回执为`frozen-full-UTC.log`和`frozen-full-Asia-Shanghai.log`；先前517项记录及首次签名候选包保留，不将收尾前候选作为最终交付。最终鸿蒙需重编译并重签至新目录`E:\SayRing-market-artifacts-20261023\harmony-parity-1132-final`，冻结哈希以下方最终回执为准。

附加发布工具验证：Node24显式列举`tool/*.test.mjs`与`tool/test_*.mjs`，明确排除前轮已证实受Windows符号链接权限阻断的2项，125通过、8项macOS原生夹具跳过、0失败，`tool-tests-corrected.log`。一次误在`scripts/release`相对寻找`tool`，运行选中0项，不计通过；保留`tool-tests.log`并改用绝对路径/零项断言后重跑。Python在`scripts/release`执行`-m unittest test_release_gate.ReleaseGateTest test_release_gate.PushConfigTest`，23项通过，0.483秒。此为合成发布契约测试，不是线上配置或真实厂商调用。

## 最终跨端回归和冻结交付

Android回归使用Git外`Run-Android-Regression.ps1`，将已验证1126 runner只在内存替换为本轮独立输出目录、1132和测试并发4，PowerShell7关闭native错误偏好、按实际退出码判定。按analyze→UTC→上海→Debug→native→正式Release→verify串行完成，不与最终ArkTS编译并发。Android/iOS运行源码及锁文件未变化。

- `flutter analyze --no-pub`零问题，阶段42.9秒，内部39.4秒。
- `TZ=UTC/Asia/Shanghai flutter test --no-pub --concurrency=4 --reporter=expanded --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn`：两个时区各1411项通过，分别66.3/68.2秒。
- `flutter build apk --debug --no-pub --target-platform=android-arm,android-arm64 --build-name=1.0.5 --build-number=1132 --dart-define-from-file=config/dev.json.example --dart-define=SAY_RING_COMMERCE_ENABLED=true`通过，阶段220.7秒，内部217.6秒。
- `gradlew.bat :app:testDebugUnitTest :app:dependencies --configuration releaseRuntimeClasspath --no-daemon --max-workers=1`通过，162.7秒，302任务（10执行/292缓存）。实际`build/app/test-results/testDebugUnitTest/TEST-*.xml`统计12个suite、54项、失败/错误/跳过0。首次寻找旧`android/app/build`路径得到0项，不计通过；改正为项目实际输出目录并做零项断言。
- 原正式Android构建脚本、普通main、生产API/JPush、commerce既有编译配置、QA/emulator=false，构建1.0.5/1132成功，278.6秒，内部269.0秒。依赖提示74项有新版、KGP和Gradle弃用警告保留，不通过升级依赖掩盖。签名配置在finally清理，`android/key.properties`结束时不存在。
- 实际apksigner v2验签、原证书SHA256 `81F35CC98E023821425FEFAA0AA8DC998283BAABC161B5F9F5EC1295EE8CE5DE`、包名`cn.saydian.ring`、版本、非debuggable、zipalign 16KB、Manifest/生产JPush及依赖ABI门禁通过，阶段7.5秒。43个ELF中ARM64满足16KB；既有两个ARM32库libDspConfig.so/libEcgAnaly.so为4KB，不宣称全部原生库16KB。原精确JPush libjutils ABI例外不扩张。
- Debug及正式Release后均重新执行`node tool/verify_qring_sdk_copy.mjs android/app/libs/qring_sdk_1.0.0.76.aar build/app/generated/qring-sdk/qring_sdk_1.0.0.76-build.aar`：30个成员字节一致，仅移除原允许的两条mapping输出规则。没有改厂商二进制。

最终鸿蒙完成无屏引导和配色修正后，Debug重新编译通过，阶段72.3秒、Hvigor59.688秒；Release阶段22.9秒、Hvigor21.367秒。原证书双层签名、`Verify-SayRingHarmony.ps1`正向门禁及未签外层APP负向门禁再次通过。回执为`*-build-frozen.log`和最终输出目录`final-gate`/`negative-outer-gate`，不是前述候选签名结果。

统一最终交付目录：`E:\SayRing-market-artifacts-20261023\harmony-parity-1132-final\delivery`。仅放以下最终包、交付说明和SHA256SUMS，不放前候选、debug、未签中间包、凭据、证书/Profile或原始日志。

| 最终产物 | 字节数 | SHA256 |
| --- | ---: | --- |
| SayRing-1.0.5-1132-release.apk | 72030451 | 267F629016367740A12F3FEE001413CA734E0B91F425D4F90ACC37B6906EE987 |
| SayRing-HarmonyOS-1.0.5-1132-release-signed.app | 9468672 | 5018DF31B0CB601B27B98A1E9FAB6C042B5C17E73623076B0870F8A9C0C8805B |
| SayRing-HarmonyOS-1.0.5-1132-release.hap | 18751207 | D1E840A876982B8B90994934A21F1FE4DF6CD5E6AB45166CEDC8402E77E64144 |

最后源码检查仅Harmony15个显式源码/测试/文档文件，无Android/iOS/服务端业务修改。提交前再次通过单次代理参数fetch origin/prune成功，开发分支仍`1d2807b5b8f12645e99bb11ae554d871fd0e1b5a`，未覆盖同事工作。推送独立`codex/harmony-android-parity-1132-20261023`，不提升main、不启动部署；结束以实际HEAD/ls-remote相同及工作树状态为准。无本轮设备安装、真实OTP、SDK回包、支付、推送、公开下载或市场审核验收。

最终运行源码、测试和实施记录提交`675ec0f1867bd4a3fca9de3e4b9ffbebf93d460d`已实际推送到上述独立origin分支。随后`git ls-remote --heads`读回同一SHA，ahead/behind为0/0、工作树干净。最终delivery三包重新按SHA256SUMS逐项读取校验全部一致。本段仅为文档回执续记，不改变已构建源码或包；未核验GitHub Actions，不宣称CI或部署通过。
