# 手机号登录成功后返回页面1177

用户在15 Pro Max反馈：验证码能收到，首次点击登录没有跳转，第二次提示检查验证码；老/新手机号均有该现象。继续原有“修复验证码自动注册后更新/down2”任务，先修复并复验登录，不发布旧候选冒充最新。

## 基线与诊断

App分支codex/login-camera-r7ultra-1136-20261024干净，fetch/ff-only与origin均b705258dfba44d95ff47b769aa3bf0d1c8bedcc0，服务端main与线上root/global readiness均4da49f4468167fc139b096b5bc624d3b0acd0203，公开smsAutoRegistration=true、原配套v3仍有效。已读AGENTS、国际交接、最新1176记录、复盘与跨模块清单。

只读未知challenge负例返回400 verification_invalid，未发送短信/触碰真实验证码。既有授权测试账号密码登录返回201/code200，包含完整会话；该对照不替代短信成功。用户明确是在15 Pro Max测试，两台已连接iPhone原均开发签名1175。本轮未修改后台配置/协议/业务写入开关，也未撤回iOS1175审核。

## 保留数据与实机定位

15 Pro Max先私有导出完整App容器成功，88文件/52,436,354字节/1健康数据库，再使用已验证签名普通main Debug1176通过flutter run --use-application-binary原位覆盖并附加；没有uninstall、清数据、修改戒指或切换原账号。原Profile没有可发现调试服务，停止等待后才切Debug；不把其等待写成Debug失败。iOS DDS的HTTP getVM超时，改用实际公布的WebSocket后成功；手机进入后台会暂停服务，重新激活当前App后再读。只输出布尔状态，不记录号码/验证码/Token或健康数值。

新启后实际isAuthenticated=true、isLocalMode=false、phoneLinked=true、emailLinked=false，资料已正常加载，和首轮验证码已成功建立手机号会话相符。发现GlobalCodeLoginPage从iOS游客首页/设置压栈进入后，成功只等待根home重建，未退出上层登录route；该页仍能重复提交已经消费的challenge。

## 复现与修复

先仅补Navigator真实压栈回归：SMS和密码成功后应回到下层首页，两项在原实现均失败，仍找到global-code-login-page。保留pushed-login-before.log。修复后17项该页回归全通过，含失败密码继续留页、原root成功不误pop、年龄/协议/能力关闭、iOS游客入口和微信绑定；断言成功后表单消失且验证码只提交一次。

改动仅global_code_login_page.dart、对应测试及本记录/索引。成功后清除已消费challenge/敏感输入与倒计时，设置完成状态，只在服务成功返回时返回首页。若用户在登录等待时打开求助等另一页面，只移除下层已完成登录route，保留该页面；根登录页由原Listenable根切换，过渡期间仅显示登录成功、没有再次提交入口。密码与既有微信成功共用收尾；失败保持原错误/重试逻辑、一次性校验、账号/数据隔离和真实协议确认，不新增登录后门。

## 待闭环

已热更新到15 Pro Max，后续用同一手机号新OTP只提交一次，核对回首页、实际当前owner和资料，再完成1177全量、Android原签名正式/私有Debug与iOS Debug/Profile构建。1176正式包未发布，最终/down2候选改为包含本修复的1177。后台浏览器仍返回Codex app tool request failed；用户已确认前台但复查仍失败，open_in_codex仍queued，上传/保存尚未发生。最终源码/实机/产物/公开下载逐项续记。

## 最终检查和15 Pro Max实测通过

format/analyze通过，UTC及Asia/Shanghai全量各1612项通过；Node141通过/1平台跳过，Harmony两个时区各540项通过，Python发行35项通过。Android正式Release/原签名私有Debug、iOS普通Debug/Profile从固定f86c3af515c900344bf42bccc525511aae41e09f重新编译并验签。Android原生未改，74项沿用本轮1176原生验证。文档续写不改变这些产物的运行输入。

最终Android下载候选为1.0.7（1177），72,243,971字节，SHA256 **8a6a234fcc1777319c4c43297a5597f404de60f8eb3f18de901720e8429be257**，原发行证书81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de；非Debug、双ARM、ZIP16KB与22个arm64库16KB、Manifest/生产依赖门禁全部通过。私有Debug159,258,830字节、SHA256 c0dcf78389645d22dd5f2c56d0f2cf7ad0ac1811380c8ac50112881dd7de26b7，仅用于真机调试，不允许上传下载页。

首次预编译1176在热重载后出现ListenableBuilder构造不匹配的Widget异常（日志顺序确认发生在Performing hot reload之后），该轮真实页面未准备成功，不当作产品登录修复的实机通过。不修改Flutter框架或放宽产品断言来适配；按打开的专用日志文件与精确Flutter运行命令双重核对后停止旧调试进程，重新私有备份并完整安装新编译普通main Debug1177。早期两个进程匹配断言未通过时没有发送信号；最终识别实际dartvm后成功正常结束旧Flutter run，没有卸载。

最终设备安装清单核对cn.saydian.ring/1.0.7/1177、开发签名正确，正常冷启动firstFrameRasterized=true、AppLifecycleState.resumed、无Widget异常或掉调试连接。用户原手机号账号owner与安装前私有摘要相同；原1个健康数据库文件均仍在，启动/同步会合法写入，故只声称文件保留，不声称其字节不变。

用正常真实登录页面准备本次复测，没有代理发送验证码、填写号码/验证码或勾选法律/年龄确认。用户亲自在手机获取新码并确认“第一次点击已回到首页”。随即真实VM回执：authenticated=true、busy=false、phoneLinked=true、lastApiError=null、errorMessage=null、原owner相同、已挂载登录页0/首页1，passed=true。证明同一手机号验证码登录及返回首页通过；不冒称另一个全新号码本轮重新注册过，也不使用合成手机号作为真实通道验收。

后台浏览器在用户确认前台后仍持续Codex app tool request failed，直接恢复原标签页也失败，open_in_codex仍queued。已请求重启当前Mac聊天客户端以恢复操作连接；不是再次索取后台密码。下载页尚未上传/保存，当前公开Android仍标注1163，iPhone/Harmony字段保留，待真实发布回执后续记。Android1177覆盖安装已先私有备份当前容器，仍在核对华为系统安装确认，不把此等待写成安装通过。

Android1177原签名私有Debug也已完成-r覆盖及实际APK拉回核验；UID10140/初装时间保留，29个数据库/偏好/XML文件启动前SHA对比0丢失、0改变，实际安装APK与c0dcf783…产物相符。安装器风险页首次普通tap未切换；确认Awake、无锁屏后，使用正常指定display0的触屏点击完成两级实际“继续安装”，未绕过权限或安全设置。实际解析MainActivity启动成功，继续普通main调试；不是正式Release手机全功能验收。

用户随后确认已重启客户端并打开已登录后台；旧agent与同一受支持入口重新绑定的agent均仍返回Codex app tool request failed，未读到可操作DOM。未提取浏览器凭证、绕过后台认证或写入下载配置，不继续重复要求用户登录/重启。再次匿名读取公开清单，Android仍1163、iPhone1130、Harmony1128；1177包和元数据已就绪，下一步需在后台实际上传/保存后，再匿名重新下载核验。本轮CI40989162476的quality与两个Harmony任务已成功，Android/iOS任务仍运行，不称全CI完成。此段仅更新操作记录，运行输入仍与已编译f86c3af一致。
