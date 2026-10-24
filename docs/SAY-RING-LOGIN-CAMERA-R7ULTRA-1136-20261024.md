# 登录恢复、相机与R7 Ultra连接检查（1136）

2026-10-24用户要求恢复微信按钮原位置/样式和手机号/邮箱旧逻辑；优化遥控相机并确保相册保存；修复R7 Ultra手势无反应及选择场景后切首页/设备断联。只在Say Ring独立仓库实施，不改后台、旧手表项目、绑定和健康算法，不解绑/重置戒指、不发送真实OTP。保留此前隐藏创建账号要求；恢复手机验证码/邮箱密码及已启用时的邮箱验证码切换，微信回表单下方描边按钮。登录协议/14岁确认及渠道门禁保留。

起点62842830a8f3cb577ad64c6b24fe57bf1182fc56，status/remote/fetch成功、当前跟踪分支一致且干净。远端iOS审核独立分支更新至1aef18c，不擅自合并其归档/设备实验；本轮从已安装1134基线创建codex/login-camera-r7ultra-1136-20261024，保留其它分支/产物。已读AGENTS、国际交接、最近1133/1134记录、复盘和回归清单。

修改前P2登录：当前手机号单入口/顶部绿色微信与用户要恢复的旧版不同；拟改global_code_login_page及登录回归。P2相机：当前预览叠快门与通用大设备标题占空间，已有saveGalleryImage调用但未校验原生saved结果，保存失败没有重试本张照片入口；拟优化真实入口DeviceFeaturePage，不用未被R7调用的QRingCameraPage代替。原生Android/iOS已有相册实现，继续使用系统相册权限，不添加全相册读取。

P1连接/手势：用户复现选择场景后返回首页再进设备页断联。实际手机1134、已保存SD-RING-R7 Ultra，初查即断开；只对原绑定点重新连接。私下日志显示本App反复建立/发现服务后主动关闭GATT，不能直接判定距离原因或“页面退出一定发了disconnect”。正在逐层核对控制器详情轮询、SDK回调/自动恢复和系统HID配对，未把开启模式指令当实物动作成功。SDK只读javap和手机日志留Git外E:\SayRing-fixes-1136-20261024，不提交MAC/账号/健康数据。

实施、失败、测试与真机结果据实续记。Windows不具备Xcode/iOS真机；不把宿主用例替代实际拍照保存及物理手势。

## 用户追加认证要求（覆盖本轮早期恢复方案）

2026-10-24用户进一步要求：手机/邮箱注册均须密码和验证码，邮箱接阿里云邮件API；登录两个渠道默认密码，可切换验证码。因此恢复独立注册与找回入口，手机号/邮箱均默认密码；不再沿用本轮早期“隐藏创建账号/手机号默认验证码”。复用GlobalAuthPage的register-with-code、注册purpose challenge与密码确认、当前Say Ring协议/14岁确认；即使旧服务器返回verificationRequired=false，客户端注册也不走临时免验证码。既有无密码账号保留验证码登录/找回能力。邮箱API及后台变更在独立服务端仓库候选分支，不混入App仓库或自动修改生产配置。

认证追加前相机/登录/UI定向142项通过，analyze首轮5条lint（多余typed_data导入、缺少花括号）已修复，第二轮无问题。为连接诊断生成与原正式证书一致的私下Profile；它不是市场包，不会发布产物。追加需求后的源码需重新分析/回归，不能复用这些早期结果宣称新认证完成。

追加认证定向第一轮70通过/2失败，均为新增注册测试fixture滚动后未pump导致点击在屏幕外，没有触发年龄/同意勾选；保留失败日志，修正等待布局并显式断言勾选后两渠道注册测试通过。追加认证analyze无问题。服务端61项认证/邮件合成测试、全量typecheck/test/build已通过，部署工具首次缺jq、已从官方jq-1.8.2下载并核对SHA256后重跑；并未真实投递或部署。

R7当前已保存目标在OS配对列表中，Profile初版安装成功保留登录，但恢复仅扫描、未找到广播；发现Android CoolWear没有既有QRing使用的精确OS-bond lookup接口。补Android专用适配器及原生lookupBondedDevice，仅查询路由层当前环境/账号已保存的精确MAC、系统BOND_BONDED及真实原厂名称，不枚举展示其他配对项、不采用SDK全局目标、不改配对/绑定；之后仍走原连接和设备信息/能力握手。新增本机名字/MAC拒绝和Dart契约测试，真机效果待后续包复测。Profile结构日志无MAC/账号/健康值，正式版移除。

## 冻结源码后的完整检查

- dart format仅本轮文件；flutter analyze --no-pub无问题。
- 第一轮完整UTC1429通过/2失败为旧源码审计仍查找原大页面中的相机设置Key/说明；修改审计跟随实际RingCameraPanel导入及openAppSettings回调，不删除断言，并保留屏幕外布局测试。第二轮1431通过/1失败是200%文字下新增指导语使重试按钮滚动后尚未布局，补pumpAndSettle；均保留失败日志。
- 最终UTC和Asia/Shanghai完整Flutter各1432/1432通过，包含手机号/邮箱注册必须密码和验证码、原无密码账号找回、旧服务端能力缺失不静默自动注册、合法协议/年龄、换号/健康/路由回归。
- Android Debug双ARM编译通过；原生JUnit13个suite、56项、0失败/错误，releaseRuntimeClasspath检查通过。正式Release及实物测试续记，不把Debug当最终发布。
- Node工具127通过/8项原生iOS运行需macOS而跳过；两项Windows无符号链接权限的独立fixture按既有精确模式排除。相机契约跟随真实新组件并检查权限设置接线。
- Harmony未修改，新认证本轮只适用于共享Flutter Android/iOS；既有原生鸿蒙兼容验证码单入口保留，未声称完成新界面或鸿蒙SDK。其既有宿主回归UTC/上海各518项通过；不构建或安装鸿蒙包。
- Python全discover首次35项含23个子用例错误，原因Windows进程缺Bash及POSIX/Xcode测试条件，不能作通过；可移植ReleaseGateTest与PushConfigTest单独23/23通过，POSIX/真实Xcode保留未验收。
- 第一份1136 Profile以原81f35c...正式证书重签后保留数据覆盖安装成功。第二份包含精确OS bond恢复和最新登录注册源码，analyze/双ARM Profile编译及同证书验签通过，目前在等待手机确认。正式包不保留Profile。
- Windows没有Xcode，iOS Debug/Profile/真机未执行；没有真实OTP或邮件投递，无账号解绑、健康清理、重置或新绑定。

## 后台协调

服务端候选f6e2dec完整检查及推送后，用户另明确授权“现在发布后台代码”。独立干净main运行Start/Publish全部门禁通过，仅本轮12文件，提交eca857da1755d8e115cafdb90634276f5889a888，CI https://github.com/tangwu88/saydianserver/actions/runs/40062660169 正在运行，尚未视为上线。部署前public capability短信true、邮箱false、旧verificationRequired=false；新流程通过显式authFlow及公开能力协同，不提前停用旧版验证码客户端，不修改实际邮件凭证。生产回查另续记。

## 最终可核对回执（2026-10-24）

- App功能提交74c5ec23102257977c290617435271f8536359f2已推送codex/login-camera-r7ultra-1136-20261024，ls-remote一致；未将尚未完成R7实物验收的候选擅自推广为main基线。
- 从该功能源码生成正式Android 1.0.6(1136)，原正式证书SHA256=81f35cc98e023821425fefaa0aa8dc998283baabc161b5f9f5ec1295ee8ce5de。APK路径E:\SayRing-market-artifacts-20261024\login-camera-recovery-1136-final2\android\SayRing-1.0.6-1136-release.apk，72,046,779字节，SHA256=F5B91308FA5245750B9859643CC62CE36A72DD31C6CFCF41FF4BCC1ABEC0649D。apksigner、zipalign -P16、正式包名/版本/JPush权限与双ARM门禁均通过；ARM64全16KB，保留已审JPush jutils单ABI及两项ARM32 4KB依赖边界。android/key.properties已由签名器finally清理。QRing构建副本30项不变，仅移除两条mapping输出规则。
- 原生SDK嵌套DEMO/SDK Guide只读核对：手势按官方sendGestureConfig及系统createBond接入；Gensor采集是另一项命令，未猜测追加或调用removeBond。没有对真实戒指发重置、清理、解绑命令。
- 主站CI verify和auto-deploy/deploy均success；root与/global readiness均eca857da1755d8e115cafdb90634276f5889a888。公开Say Ring能力sms=true、email=false、explicitRegistrationCodeLogin=true、verificationRequired=true；已发布后台/admin/及入口JS均200，主bundle实际包含aliyun_dm/accountName/fromAlias字段。首次只读静态验证脚本误假设懒加载IntegrationsView分包，后确认当前配置在主bundle，不是发布失败。
- 同一Actions run的独立auto-deploy-us/deploy在SSH receiver阶段exit2，因此整个run为failure，不能写全站/整个CI成功。未重试或修改美国环境、凭据、维护状态；本轮主站实际版本和成功任务单独验收。邮箱真实投递尚未验收，没有修改/启用生产邮件配置。
- 手机仍在锁屏及第二份Profile覆盖安装等待，已发解锁确认问题，尚未收到后续答复。当前不能声称已安装本次正式APK或R7 Ultra手势/连接稳定及照片相册实测通过；相机测试授权的一张真实照片尚未拍摄。完成手机确认后先在新Profile复测，再保留数据覆盖本段正式APK并核对安装包来源，不卸载/不清数据。
- 本轮广泛蓝牙logcat采集已停止，只保留Git外私有证据；Windows iOS原生/真机及原生鸿蒙新登录界面仍不计完成。本次Node发现135项中127通过、8项macOS执行条件跳过；命令保留旧Windows精确skip-pattern，不将未实际运行的额外fixture算作通过。
