# Say Ring 1.0.4（1120）App Store 更新

## 授权与基线

用户要求提交新的苹果构建并送审。现网 1.0.3 已发布，原审核均已结束，因此创建独立 1.0.4，不撤回或改写现网版本。仅 Say Ring，不改其它 App、后台业务开关、Android 下载或手机数据。

起点工作树干净，`codex/macos-update-20260930` / `0d84ae72705e28e613eb4dffc3b34a87986a1034`；修改前 fetch、ff-only 已核对。`origin/main` 是本分支祖先，当前分支领先19个提交，无遗漏的 main 提交，不重置或强推。

运行源码为 `c82b027d176018cbd5ea6daabfdfdae9ac053dbe`。本轮没有改业务源码、依赖、数据库或原始 SDK；仅通过构建参数增加商店版本与构建号，并编写对应商店资料和回执。

## 回归依据与实际边界

同一运行源码的 [完整 CI 39146680592](https://github.com/tangwu88/SayRing/actions/runs/39146680592) 本轮再次实读 completed / success，SHA 为 c82b027；quality、Android、iOS、Harmony UTC / Asia/Shanghai 均成功。

上一轮 Analyzer 零问题、Flutter 双时区各1336项、原生/发布契约与双端构建见 [商城名称回归](SAY-RING-MALL-NAME-20261019.md)。本轮没有为文档重复执行全量本机测试，不把旧结果描述成本轮重跑。

[1119 保数据真机记录](SAY-RING-IOS-1119-INSTALL-20261019.md) 包含同源码的登录/资料、旧睡眠、R12启动恢复及三次独立启动。此为开发签名 Profile，不是1120分发包的实际安装验收。物理距离重连、新血氧样本、其它型号及后台模块正向联验仍待验。

## 串行正式构建

Flutter 3.44.9 / Xcode26.6；构建前检查互斥，仅单个 iOS 构建。依赖不更新，使用正常 `lib/main.dart`，正式生产API，无测试入口或QA账号参数。

1. `flutter build ios --release --config-only --no-pub --build-name=1.0.4 --build-number=1120 --dart-define-from-file=config/ios-app-store-no-push.json`：退出0。
2. `xcrun xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination 'generic/platform=iOS' -archivePath <private>/SayRing-1.0.4-1120.xcarchive IPHONEOS_DEPLOYMENT_TARGET=15.0 archive`：ARCHIVE SUCCEEDED。
3. 同一archive使用现有App Store本机导出配置：EXPORT SUCCEEDED；解包后严格深度验签通过，Apple Distribution / Xuewu Tang / W7SXQ4A226，`cn.saydian.ring` / 1.0.4 /1120 / iOS15 / UIDeviceFamily=[1]。
4. 描述文件有效至2027-09-24，无ProvisionedDevices、非企业全设备分发，`get-task-allow=false`、`beta-reports-active=true`；关联域名保持原值。
5. Runner和App.framework的实际UUID分别与归档dSYM一致。已知厂商模拟器/SPM警告保留，本轮为iphoneos归档，不宣称模拟器验收。

本机导出IPA：38,364,526 bytes，SHA-256 `8c9b85d305e5bfc1c143627f873ddfec8464b208f464bf697fceb28336769e4a`。上传由同一archive再次导出，不宣称两次重签IPA逐字节相同。

上传命令使用现有destination=upload配置及已授权ASC密钥，密钥内容和JWT从不输出。07:36:53 CST明确返回 Upload succeeded / Uploaded Runner / EXPORT SUCCEEDED，退出0；没有重复上传。15个闭源厂商框架缺少dSYM的警告不阻止上传，但会限制其崩溃符号化，未伪报零警告或补造厂商符号。

07:41:27 CST，苹果构建实际回读VALID；build ID `45299ae1-6f3a-4380-8e1e-10a638e828df`，版本归属1.0.4、构建1120。Build Upload同时回读COMPLETE、errors=[]，保留一条90683定位purpose string警告：闭源依赖引用相关API，Runner缺NSLocationAlwaysAndWhenInUseUsageDescription；上版1107也有同一条警告。本轮没有新增定位采集或权限请求，未将非阻断警告写成已修复；后续需核对实际持续定位用途或删除不必要的依赖引用，不能填造用途来消除警告。

## 商店资料与配置核验

ASC app `6816549943`；创建1.0.4草稿 `edc87d1b-6172-448d-9002-e471566a3c15`，沿用AFTER_APPROVAL及既有审核凭据/联系信息。通过正式授权ASC API操作，不读取浏览器登录会话。

[描述](APP-STORE-DESCRIPTION-1120.txt)、[更新内容](APP-STORE-WHATS-NEW-1120.txt)、[审核说明](APP-REVIEW-NOTES-1120.txt) 已分别保存、全文回读一致；审核账号和联系字段逐项与继承值一致。说明采用简短直接的表达，明确可用项目、可选代码范围和待验项，不沿用旧“iOS无生理数据展示”的错误描述。

继承的简中截图集仅APP_IPHONE_67，初始四图均COMPLETE，无iPad截图。逐张查看本机原图后，发现“关于”图明确显示旧1062版本号；只移除新1.0.4草稿的该截图副本，保留三张现有睡眠/小睡/登录图，不编辑原图、旧发布版本或个人健康数据。最终三图均COMPLETE。实际销售范围实读仅CHN，FRA=false，不更改地区或扩大范围；保留现有年龄分级和隐私声明。

公开 iOS 配置实读：只读皮肤温度开启；心率/HRV/血氧/压力关闭；百科和商城关闭；睡眠AI生成关闭。三项手动测量在本次配置无有效授权，商城购买上限仍关闭。所有用户与审核者同一配置，本轮不切换任何生产开关，不以审核身份隐藏功能，也不承诺审核后隐蔽启用未审功能。

上述可选代码和当前关闭状态均在审核备注披露；生理记录本机保存、不增加生理上传，既有活动/睡眠与单独睡眠AI授权边界不变。公开隐私/协议的1110+说明已包含只读生理范围，不宣称医疗用途、临床验证或测量精度。

## 真实接口检查

`node tool/global_auth_smoke.mjs`：readiness、global能力、匿名members/me拒绝、公开协议/隐私正文与版本均通过；此脚本只读，不代表真实登录测试。

另用原ASC专用审核账号执行当前Say Ring邮箱密码合同，仅在确认产品协议正式版本 `say-ring-cn-2026-10-05-v3` 存在且reviewed后正常登录；随后GET members/me成功。两次登录均HTTP201/code200，首轮探针错误地只接受200，修正后access/refresh/member/expiry结构及会员读取通过。没有发验证码、改密码、注册账号或上传健康数据；令牌仅在进程内使用，账号凭据与会员资料不入Git。

能力中的login.email=false指向邮件验证码通道，本机源码邮箱密码入口不受该OTP能力控制；实际密码登录成功，不因字段误读而开启服务端功能或改变渠道。

## 检查失败及更正

- 首次读取build时使用不支持的include=appEncryptionDeclaration，HTTP400；移除该include后原版本build读取成功，无写入。
- 查询App加密关系和首版availability路径分别HTTP404；改用正式资源`/v1/appEncryptionDeclarations?filter[app]=...`及`/v1/apps/{id}/appAvailabilityV2`后成功，不把错误响应当空配置。
- 首次描述文件plist直接转JSON因Date/Data失败；改为plistlib解析，签名与设备列表检查完成后再交付。
- 首次审核登录探针只接受HTTP200，将正常201/code200误标失败；保留原失败记录，修正为2xx并复验登录及members/me成功。未绕过认证或重试错误密码。
- 苹果上传成功后build列表短暂为空，作为处理延迟继续只读轮询，不重复上传。

## 最终审核回执

**2026-10-19 07:42 CST，1.0.4（1120）已正式提交，实际状态WAITING_FOR_REVIEW。尚未审核通过或发布。**

- 构建1120处理VALID后，沿用原已批准构建的 `usesNonExemptEncryption=false` 选择；标准、非专有算法范围和既有SQLCipher/网络加密实现未变化，法国不可售已实读确认。不把该字段表述成“不使用加密”，也没有新增虚构加密文件。
- 1.0.4的build关系保存后GET回读为精确1120/build ID `45299ae1-6f3a-4380-8e1e-10a638e828df`。
- 新建Review Submission `e1039ffe-e0a6-4191-b554-c0d3fd6ec05c`，只包含本次1.0.4一个App项目，逐项读取关系后才提交。
- 正式PATCH submitted=true成功；苹果提交时间 `2026-10-18T23:42:14.997Z`，即北京时间2026-10-19 07:42:14。随后分别GET submission和version，均WAITING_FOR_REVIEW；releaseType仍AFTER_APPROVAL。
- [实际审核详情](https://appstoreconnect.apple.com/apps/6816549943/distribution/reviewsubmissions/details/e1039ffe-e0a6-4191-b554-c0d3fd6ec05c)。没有撤回1.0.3、另发重复提交或将商店审核说成TestFlight外部测试审核。
- 旧审核备注/账号/联系信息均已保留私有快照，只替换新版本备注；现有年龄/隐私/地区声明不减少。没有开启百科、商城、手动测量或AI来制造不同的审核体验。

此次未另行邀请测试员，也没有把1120安装到用户手机；先前1119保数据安装状态不变。苹果审批结果及时间仍由Apple决定，不承诺一次通过。

所有密钥、JWT、审核凭据、会话、签名包与日志仅留Git忽略且收紧权限的本机私有目录。本轮不卸载/重装手机、不清数据或绑定。

交付前再次fetch，当前分支与origin仍0/0，无外来改动；只提交本轮5个文档文件，`git diff --check`通过。不上推仍有整体验收待办的main；最终push与远端SHA回读以实际Git操作记录为准。
