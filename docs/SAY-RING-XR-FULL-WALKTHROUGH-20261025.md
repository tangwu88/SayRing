# 2026-10-25 XR修复版安装、任一戒指连接与页面巡检

## 授权与基线

用户要求将R8 Pro通道修复版安装到XR，连接任一设备并遍历各界面。基线5d9c86eb038c24c89746dad455140ed818b578fb，开发分支codex/device-search-help-1141-20261024；status干净、fetch/pull --ff-only成功、origin身份正确。已读AGENTS、国际交接、回归清单/复盘、R8 Pro修复及XR历史巡检记录。本次任一戒指授权只用于当前账号、正常扫描与显式连接，不突破真实SDK能力和owner保护，不自动清数据或迁移旧协议ID，不操作苹果审核/后台。

## 安装与保护

devicectl确认物理iPhone XR在线。先私有备份cn.saydian.ring的appDataContainer：25文件、3805353字节；证据与容器仅在忽略的build/xr-full-walkthrough-20261025，不入Git。

普通main使用刚通过完整主机检查与双平台编译的修复版Profile，严格深度验签、cn.saydian.ring、团队W7SXQ4A226、描述文件包含XR和开发签名核验通过。App.framework SHA256 851ecba0237a6d711157bf6e3254ef723eedc4be7f3f7765cd589475d929c246；版本沿用1.0.6(1141)仅为QA身份，不是苹果已提交的旧1141二进制。原位安装、启动均成功，无卸载。

## 测试脚本与实际准备

扩展既有ios_read_only_page_walkthrough_test.dart：真实已存在账号/绑定下优先恢复原目标，明确测试开关允许按用户本次授权从实际扫描的QRing/CoolWear候选中尝试连接，最多3个，仍通过正常connectDevice与真实能力包；没有记忆绑定时拒绝该QA选择，防止测试触发首次会员清理。未连接成功也先检查可用页面，最终不能把缺少握手记为通过。

页面使用有界帧推进代替全局pumpAndSettle空闲，避免持续BLE/同步动画阻塞巡检；保留各页面独立标记、异常/可点击检查。扩展模式逐页保存标签、状态JSON和私有截图，检查真实设备的手势/提醒/监测等设置页，不写设备设置、不发送OTP/支付/AI报告。截图和可能包含个人信息的数据仅保存在App私有Documents及忽略build目录，Git只记录结果摘要。

首轮analyze发现3个新脚本多余null-aware警告并退出1；移除对不可空sdkSource的多余?.后，analyze零问题11.9秒。测试Profile config25.8秒、原生签名构建成功；明确测试入口、包名1.0.6(1141)、团队和XR包含、get-task-allow均核验通过，测试App.framework SHA256 b69ef9cd9df53e025b8324e9a68f0f2b30343061782934cee8261a90a03817c3。

通过tool/drive_ios_preserving_data.mjs、显式已核验测试binary和强制keep-app-running执行，普通main独立保留，finally私有后备份并恢复普通版。安装启动21.7秒，已观测FlutterDriver Connected及测试正文启动；中途原生launch成功、日志有SIGCONT，不把启动/VM接入当作页面或连接通过。真实结果随后追加。

## 首轮实物巡检通过

实际扫描4枚兼容戒指，首个显式连接候选通过QRing真实握手；设备页私有截图读回R21（完整广播名仅私有截图）为已连接，ownerUnchanged=true。测试未改任何账号或设备设置、未解绑/重置；选择其他戒指是本轮用户明确授权的正常连接，不宣称R8 Pro实物已验证。

driver正文02:41 All tests passed、退出0；私有proof保存25个实际页面/流程标签，健康首页、心率/血氧/皮肤温度/HRV/压力/睡眠详情、睡眠概览、全部数据、远程关爱、健康百科、运动总览、消息、设备、真实健康监测只读回包、查找页、我的、资料、单位、账号、权限、帮助反馈、客服和关于页均有实际标记及截图。未知指标、当前R21未返回的手势/来电/消息/闹钟等能力按门禁隐藏，不把它们列为已测；搜索入口已有绑定时未出现，后续独立页面补查。

首次连接检查时batteryRead=false，截图仍为未知电量，不能当电量读取成功；页面稍后出现真实同步22%进度，不能用早期backgroundSyncFinished快照宣称完整历史同步通过。当前测试是UI/实际能力读回，不是数据准确性或全部SDK历史完成证明。

finally后备份、普通main原位恢复及启动全部exit 0。原位恢复版本仍含R8 Pro路由修复。新增第二轮只读脚本补查活动日周月、睡眠日期、百科正文/特大字号及恢复、设备信息/说明、搜索帮助、登录邮箱切换，以及公开配置允许时的商城只读页面，不创建订单/不支付。首轮已通过页面不重复作为新验收。

## 截图发现的接口提示问题与修复

首轮截图目检发现消息、账号相关页面出现This action could not be completed英文通用提示，个人资料还在加载，百科截图为加载中。此前25个标记仅证明导航/渲染，不代表这些接口内容加载成功，不能据此扩大为全部功能正常。旧1139曾记录refresh 401及accessExpired，但不是本轮实时结论；新增现有仅状态码的profile API探针，在第二轮独立验证当前会话，不导出凭据。

P2根因：GlobalSaydianApiClient._decode对普通API错误统一硬编码英文。窄范围修复安全提示：按现有locale对中文/繁中返回对应安全文案；受保护资源或refresh的401明确重新登录；登录接口密码失败不误报会话过期；保留原status/code，不回显上游正文，不清会话或绑定、不改变鉴权策略。增加6项实际HTTP客户端回归，包含中文/繁中/英语、过期会话/错误密码区分、错误码保留和vault owner/token不变；该API测试文件41项通过。源码修改前已fetch、保存私有diff及新增文件快照，不覆盖已有巡检结果。

初次私有截图拼图脚本因系统Python无PIL而失败；改用系统AppKit生成私有联系表并目检25页，没有安装库或向外上传截图。截图中的真实健康/资料数据不写入Git。用户随后明确确认XR已解锁、戒指在旁且保持前台；继续第二轮。

## 当前会话问题的实物证据

第二轮资料探针实际返回profileLoaded=false、sessionOwnerUnchanged=true、accessExpired=true、errorStatus=401、errorCode=401；唯一请求为/global/api/saydian-app/v2/auth/refresh，HTTP401/业务401。没有读取成员资料正文、凭据或修改登录状态。因此资料等云端页面未通过是当前认证阻挡，不能假定服务器功能全部正常或靠UI文案修复会话。

第二轮已开始补充页面，活动目标与步数日周月实际标记已到达。探针失败将保留为整轮失败，不删除断言或把接口阻挡降成通过；恢复普通版后需要用户在XR重新登录同一账号，再核对云端页面。

API修复普通Profile配置26.6秒/签名27.5秒，第二轮测试配置26.8秒/签名24.9秒通过，双包严格验签/包名/团队/XR包含核验成功。普通App.framework SHA256 404a024764835f98786435d3dcec414434ee264122f624ff4d5db1f43040a515，专项f04efd6fb91782913a99805f4112ceb3d954d9dea50540964770b629a5367d30。全项目analyze首次误扫描私有快照before-api-fix-secondary.dart，触发文件名及测试专用API的3条提示；快照改扩展名为.dart.txt保留原文后重查43.6秒零问题，未改产品代码迎合提示。全部失败日志保留。

## 第二轮结果与普通版恢复

资料API探针因真实会话过期失败，正文01:37 +2 -1 Some tests failed、driver退出1；保留这项失败，不把teardown或导航成功抵作API成功。独立secondary UI测试已通过11个实际标记：活动目标、步数/距离/热量日周月、睡眠前后日期、百科文章详情、特大字号及原字号恢复、设备信息、连接说明、添加设备搜索帮助、邮箱密码/验证码切换。与首轮合计36个页面/流程检查，不代表36种传感器采集验收。

第二轮私有proof：healthLibraryVisible=true、commerceEnabled=false（商城按公开配置未开放，未强行进入或下单）、ownerUnchanged=true、targetUnchanged=true、connectedAtEnd=true、batteryRead=true、syncIdle=true。证实真实R21连接和后续电量读取，不能将syncIdle当完整历史传输回执。

finally后备份、原位恢复含API提示修复的普通main及启动全部exit 0。已请求用户在XR重新登录原账号后保持前台，继续云端资料/消息验证；不索取聊天密码或验证码，不清会话、伪造token或修改服务器授权。当前等待用户恢复认证，其他主机检查继续。

## 修复后的完整主机检查

最终生产API提示修复后重新完成离线锁定pub get、格式门禁、analyze（14.3秒零问题）；UTC/上海Flutter全量各1476项通过（38.1/35.5秒），包含新增6项安全错误回归。Node139中138通过/1Windows限定跳过，Harmony两时区各518通过，Python发布35通过。Android Debug7.9秒、内部QA Release23.2秒及原生JUnit4.7秒成功。iOS Debug配置24.6秒/开发签名9.2秒通过，Profile同源普通/专项已通过，均未当作正式发布包。

用户已明确回复重新登录原账号并保持前台。已再次私有备份，新增仅复验资料API与消息页的实际账号测试，不重复首轮已通过的36项；检查真实资料加载、字段与真实API映射、消息成功/真实空态、owner/target不变，不读消息详情或标记已读。首个新增脚本analyze仅报重复notifications导入1项info；移除后必须新鲜重编译测试Profile，不回退旧测试包。真实复验结果继续追加。

## 用户重新登录后仍失效：继续定位

用户两次确认已在XR的Say Ring重新登录成功。第三轮实际probe仍为accessExpired=true/refresh HTTP401/profileLoaded=false；资料页复验也因memberProfile为空失败，driver退出1。finally后备份、恢复普通修复版、启动均成功。不能把用户的登录成功描述当作服务器已接受凭据，也不能无证据断言用户操作了其他App。

已只读核对生产factory与探针都使用SecureSessionVault.global，同一生产origin/product派生namespace；正常/测试的application-identifier均W7SXQ4A226.cn.saydian.ring、团队一致、无另设keychain-access-groups。服务端公共HEAD Date与Mac UTC当下相符；尚未取得手机时钟与新签发凭据的相对过期证据，未以猜测修复令牌或重置存储。

新增实物登录保存观察器：直接显示原公开登录页，用户亲自在手机输入并完成协议/年龄确认；脚本只比较会话是否变化、过期布尔、相对时长、新vault读回是否一致和真实profile状态，不读取输入框、导出凭据或自动接受协议。登录后复验资料和消息UI。初轮新脚本两处多余!的analyze警告已移除，继续以新编译Profile执行；原API探针失败及用户回复均保留。

## 本次获准的测试账号登录

手工观察器等待窗口未观测到任何新会话写入，04:10超时断言失败；普通版与后备份仍恢复成功。该结果只说明观察窗口内没有新凭证，不证明Keychain写入损坏。

用户随后明确提供测试账号凭据并要求自行登录。又在实际操作前明确确认已阅读并同意当前协议、年满14岁，允许本次勾选登录。复用观察器增加仅测试入口的显式批准模式：从App私有临时输入文件一次性读取获准凭据，读后立即删除；正常公开邮箱登录表单、协议/年龄控件及提交按钮均照常操作，没有API/审核专用认证绕过。源码、命令回执、Git及App编译常量不包含凭据，临时文件不随备份/交付保留。最终普通main不读测试模式或临时输入文件。后续仅记录会话变化/有效期相对值/新vault一致性/API状态及页面结果。

## 自动输入首轮的测试框架问题

获准自动登录首轮已正常转入邮箱模式，年龄/协议控件均true、consentVersion为既有v3，但会话未变化且未产生API错误。只读VM检查仅输出非敏感状态与字段长度/是否匹配布尔，确认form本地invalidEmail、两输入框长度均0；不是服务器拒绝了已填写的密码。未输出输入框内容、令牌或成员资料。

Flutter IntegrationTest默认registerTestTextInput=false，Profile关闭assert，使原tester.enterText没有建立模拟输入客户端。已中止精确preserving驱动进程组（driver -15），保留失败/恢复日志；finally后备份、普通main恢复和启动成功。修复仅测试脚本：显式注册测试输入客户端、teardown注销，逐字段填写后用布尔断言校验输入已生效，失败断言不打印账号/密码。必须新鲜编译并重新验签测试Profile再执行，不改生产登录验证或制造有效会话。临时凭据输入在手机/主机均已清除，后续重试仍只用本次获准的测试账号和协议确认。

## 测试账号实际登录及云端页面复验通过

修正后的自动登录Profile严格验签、团队/包名/XR包含再次通过，App.framework SHA256 33770d31292f58b36559a104770fe757fbe99969fbae3441120c9590278be5bb。真实表单输入布尔检查通过后提交：sessionChanged=true、newExpired=false（当次剩余约899秒）、freshVaultMatches=true、profileLoaded=true。随后资料页真实字段与API映射一致、inboxLoaded=true，正文00:39 All tests passed、driver退出0。数据来自真实生产账号服务，不是mock、演示数据、API认证旁路或篡改旧令牌。

该指定测试账号与先前缓存账号不同（ownerUnchanged=false），这是用户明确要求使用所提供账号后的正常账号切换；不能宣称本轮所有回合是同一账号，也没有合并/移交原会员的本地健康记录或自动继承其戒指绑定。原账号的数据继续按owner隔离。先前401和手工观察失败保留；目前没有证据说明Keychain无法保存新登录，更不能把此次成功归因于修改了凭据存储逻辑。

临时输入在手机读取后已删除，主机传送文件也已删除；只保留状态证明，不在Git、编译常量、测试日志正文或交付文件中保存账号密码。所有截图和容器仍只在忽略目录。finally后备份、恢复普通main（SHA256仍404a024764835f98786435d3dcec414434ee264122f624ff4d5db1f43040a515）和启动均成功。另给未通过的account复验脚本补齐非空目标条件，避免未来将null==null误写为已连接；该失败回合本来在资料断言处终止，不覆盖任何已有实物成功结果。

已开始只读附加普通Profile，核验进程重启后状态，不安装测试入口、不更改会话/绑定或UI；结束将detach保留App运行。后续读回与Git结果追加。

## 普通版附加尝试与证据范围

普通版恢复后尝试flutter attach --profile --machine --app-id cn.saydian.ring只读观察新进程。该窗口内未取得app.debugPort，日志出现device.removed；按daemon的app.detach退出，未通过q/stop结束App，没有安装/卸载。此尝试不计普通版进程内状态或冷启动API成功。已验证的新登录保存、fresh vault读回、profile真实接口及资料/消息页证据来自获准自动登录实物回合，普通main安装/launch成功另有独立回执；不把两类证据混同。

## 新进程保存复验及最终交付

普通版调试服务未发现后，改用全新只读API Profile进程独立验证存储：明确既有ios_profile_api_diagnostic_test.dart目标、无凭据输入/写入，config23.8秒/签名15.9秒与严格验签成功，App.framework SHA256 ec2ea45fae93bcdaf8ac8d0152d5ca6fce565932621fb6d9b2dfbbe6fc8b1d9b。新进程实际profileLoaded=true、accessExpired=false、sessionOwnerUnchanged=true，唯一members/me请求HTTP200/业务200，正文00:04 All tests passed、driver退出0。证明新凭据在进程替换后仍可读取与访问真实账户；不是把先前未成功的普通版VM附加算成通过。

最终私有后备份、普通main原位恢复、launch全0；没有卸载、清本地/戒指数据、解绑或恢复出厂。设备清单仍为物理XR在线，安装清单独立保存包名/版本证明。正常使用版包含R8 Pro的QRing修复与本次安全中文错误提示；仍为内部QA 1.0.6(1141)，没有把它冒充苹果已提交的旧1141或改变审核构建/下载页。

最终格式六文件0改动、全项目analyze零问题（交付日志另存），git diff --check通过；最终Android原生JUnit仍60项/0失败错误跳过。新增差异与未跟踪交付源码的凭据字面量扫描为false；修改文件中原有单元测试的通用数字密码夹具保持原样，没有新增提供的测试账号凭据。状态、失败、纠正与恢复记录保留，私有容器/日志/截图/本机签名均不入Git。

实际覆盖合计36个页面/流程检查，后续又完成真实测试账号登录、资料与消息以及跨进程会话复验。商城公开配置未开放；本枚R21没有返回的手势/来电/消息/闹钟等硬件能力不强行开放，不宣称已测；没有执行真实支付、外部消息/电话触发、AI健康汇总上传或医疗准确性验证。原账号数据与用户指定测试账号保持隔离。当前分支记录及代码同批同步，不提升仍有其他实物待验项的main。
