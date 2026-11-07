# 鸿蒙同步 Android/iOS 最新改动（2026-11-07）

## 基线与范围

用户要求按 Android/iOS 最新改动调整鸿蒙。原工作目录 E:\saydian h5 为服务端仓库，分支 codex/local-customer-image-fix-20261028 且存在他人改动；Start-Change.ps1 因不是 main 按规则停止。E:\SayRing 同样有未提交文档，保留两处现场。在 E:\saydian h5\SayRing-harmony 建立独立工作树 codex/harmony-sync-20261107，先读取 origin/main 0e350063d727678b2dab8d9e61abf8edec51fd11，再干净快进到 fetch 后的最新 Android 开发分支 c4ab520（2026-11-07）。main 不是最新开发基线，不推进 main、不改服务端。

已读 AGENTS、INTERNATIONAL-HANDOFF、CHANGE-TEST-LOG、复盘/回归清单及 1187 鸿蒙、1254 睡眠、1259 首页/运动/验证码记录。

对齐范围：今日活动分字段保留最新有效值（部分快照不抹掉其它指标）；所有首页指标按当前目标隔离；最近睡眠明确日期；移除首页提醒入口并保留我的/设备入口；验证码六位数字归一化；运动手动同步迟到结果限本页/本目标。现有运动页已只读本地、设备搜索已每次进入扫描，无需重复改写。保留数值、原始记录、单位、健康权限与 SDK 门禁。

QRing/LuckRing 无原生鸿蒙 SDK，不能同步 Android/iOS 的厂商连接/手势/采集命令，也不能按名字伪造能力。生理周期完整页面不在本轮补建，列为功能差距。无生产密钥、设备数据或产物进入 Git。

## 验证过程

- 修改前 `node --test --test-reporter=dot harmony-native/tests/*.test.mjs`：547 项通过。
- `ohpm install --all`：执行中，后续补结果。
- 本轮源码、定向/全量测试、真实 ArkTS 构建和未验收项在完成后追加。

## 最终结果

- 服务端仓库独立 fetch 成功：本地 44054d5302c966646f3b4801f84f042af370c187，origin/main a6257b1fe641546be470b11da727a2f73f05afb3；非 main 且有未提交改动，没有 merge 或改服务端源码。
- `ohpm install --all` 成功，未改变已跟踪依赖锁文件。
- 源码编辑最初误用系统 Python 商店入口，未应用修改；取消该轮前置构建，改用 Node 编辑，再完整重建。取消的构建不作为通过证据。
- 新增 6 项逻辑/生产方法回归：部分活动快照、日期/设备/未来隔离、睡眠隔离、验证码、首页入口及运动迟到结果。定向首轮5/6，发现鸿蒙旧实现没有我的提醒入口，补齐实际入口后通过。
- 全量首轮 552/553；旧运动测试直接在首页调用同步，与新增页归属约束冲突。夹具改为真实运动记录页和确定目标，保留原断连/不支持/测量中门禁断言。最终 `TZ=UTC node --test --test-reporter=spec harmony-native/tests/*.test.mjs` 和 `TZ=Asia/Shanghai ...` 各553/553，通过，无跳过。
- `hvigorw --mode project -p product=default -p buildMode=release assembleApp --no-daemon`：真实成功（34s398ms）。最终 `hvigorw --mode module -p product=default -p buildMode=debug assembleHap --no-daemon`：真实成功（17s218ms）。未配置签名，只有 unsigned APP/HAP，不作为可安装发行包或新版本发布。既有第三方资源冲突、弃用API、厂商HAR未混淆、sourceMapsPath警告保留。
- `git diff --check` 通过；`hdc list targets` 返回 Empty，未安装/卸载、未访问真实健康数据、未发送验证码或改变设备设置。
- 本轮仅更改鸿蒙 ArkTS/契约与记录，没有修改 Dart/Android/iOS/服务端，因此未重跑 Flutter、Android/iOS 构建或服务端 pnpm/接口/部署脚本检查；不将它们记为通过。

## 尚未验收与差距

鸿蒙真机332dp/两倍字体、声音、登录验证码送达和真实数据刷新均待设备验证；QRing/LuckRing SDK、这些戒指的采集/运动/手势原生联调仍阻断，不能用其他厂商SDK冒充。周期日记及其CSV导出尚无鸿蒙完整模块，本轮不宣称平台功能全量一致。SDK/周期功能差距与本轮已同步的页面/数据保护分别交付。签名安装、下载页和市场发布未执行；版本号保持现有1187避免伪造发行状态。

源码与本日志提交至独立鸿蒙分支；不推进 main，不触发服务端发布。交付提交和远端回执见聊天最终结果，可由分支日志复核。

- 提交前再次 fetch：Android 对照分支仍为 c4ab520；另发现 Google Play 分发分支新提交698dee0并只读核对，其 iOS1263 恢复与 Play 分发/支付更新不适用于原生鸿蒙SDK；该分支的鸿蒙仍含旧热量展示，本轮保留更新的1267/1268隐藏热量行为，不以提交时间覆盖已验收功能。未整分支合并，避免把平台专用发行改动混入鸿蒙交付。

## 后续检查更新（2026-11-07）

- `git status --short --branch`：鸿蒙工作树干净，本地与 origin/codex/harmony-sync-20261107 均为9d59a2483a5c86a7efb3b01f69fe93f2cc452432；`git remote -v`和`git fetch origin --prune`成功。
- 最新Android开发更新952819c（运动恢复1269～1273）：相对c4ab520共15文件，涉及Android CoolWear、Flutter控制器/运动页、测试及记录，没有原生Harmony文件。只读核对实施记录，新增15秒恢复租约、真实握手恢复和离线结束依赖现有Android原生SDK；鸿蒙缺该SDK，不移植厂商命令或虚构恢复能力。Android实物运动仍待验收。
- Google Play分支已到534bffb，为1268分发提交回执；鸿蒙差异仍为旧热量UI，保持当前更新后的隐藏热量实现，不回退。origin/main仍为0e35006旧基线，不能以main覆盖鸿蒙已同步内容。
- 本次无需修改鸿蒙源码；未重复上轮已通过的553项双时区测试和Debug/Release构建，本次也不将这些历史结果记为重新执行。仅提交本检查记录；签名、真机、QRing/LuckRing SDK及周期日记差距不变。

## 真机安装尝试（2026-11-07）

- 用户要求安装，重新连接后 HDC 成功识别 JAL-AL90 鸿蒙手机，ADB无Android设备。只读查询 cn.saydian.ring.hm 未安装。
- 从当前已验收源码重新运行 Release assembleApp，58s227ms成功。使用仓库外 Say Ring 原生产P12/证书/Profile及DPAPI密码完成官方sign-app和verify-app，密码未输出或提交。包身份 cn.saydian.ring.hm / 1.0.7（1187）/ debug=false。独立HAP SHA256 D5C1FC962BA33FC1B6094535E46C3E048D4FA6F3D890D01E6EEE96147CAAA043，私下产物 E:\SayRing-harmony-install-20261107。
- `hdc install <本轮签名HAP>`实际失败：9568322，signature verification failed due to not trusted app source。HDC进程退出0不代表安装成功；安装后bm dump再次确认应用不存在，未声称已安装/启动。
- 检查本机 .ohos/config 两份开发profile，均仅适用旧产品 cc.saidian.app.hm，不能用于 cn.saydian.ring.hm。未改包名、未借用旧产品身份、未卸载应用、未绕过来源校验。
- 安装仍待适用于 cn.saydian.ring.hm 且包含本机设备的有效开发profile/配套签名，或官方市场分发。需在DevEco登录所属华为开发者账号生成对应开发签名；本机现有正式包验签成功不等于系统允许HDC侧载。无应用数据/签名密钥/Profile或设备标识提交Git。

## 开发签名安装成功（2026-11-07，续接）

- 用户明确授权直接操作后，发现本机已有 @deveco/deveco-cli 1.3.0-stable，无需安装完整IDE。auth status初始未登录；auth login成功，复用官方登录流程，没有输出会话Token/密码或接受新协议。
- 登录CLI需要Enter交互；首轮普通管道stdin关闭、第二轮PTY交互未完成、Node管道初轮换行转义错误，改为延迟发送真实LF后成功。失败仅涉及登录交互，不绕过认证。
- 在原生鸿蒙目录执行 `devecocli signature generate`成功，为当前包和连接设备申请开发签名；先备份build-profile，临时生成的含本机签名配置仅留仓库外，构建finally恢复原文件，Git源码/配置干净。证书/Profile/密钥/设备标识不提交。
- `hvigorw --mode module -p product=default -p buildMode=debug assembleHap --no-daemon`真实成功（16s684ms），SignHap成功；官方hap-sign-tool verify-app通过。HAP私下保存于 E:\SayRing-harmony-install-20261107\SayRing-1187-9d59a24-device-signed.hap，SHA256 06B4893CB9A4FD78B943EC7737D278A5BD13206E9A80270154D73FD62D1527FB。
- `hdc install <本轮开发签名HAP>`返回 install bundle successfully；无卸载、无包名替换。`bm dump -n cn.saydian.ring.hm`确认1.0.7（1187）。首次PowerShell解析遇metadata/metaData大小写键冲突，改-AsHashtable后正确读取，不把占位versionCode=0误当实际版本。
- `hdc shell aa start -a EntryAbility -b cn.saydian.ring.hm`返回start ability successfully，后续pidof确认进程存在；截图实核Say Ring手机号/邮箱密码登录首屏正常。snapshot_display要求.jpeg，首次.png被拒后更正成功，截图仅私下留本机。未自动勾选同意/年龄、登录账号、发送验证码或操作设备设置。
- 本轮交付为开发签名安装版，源码仍为本轮已验收鸿蒙更新；并非应用市场发布或正式包侧载成功。戒指SDK、登录与健康数据业务验收边界不变。本轮无运行源码改动，不重复上轮已通过的双时区553项测试。
