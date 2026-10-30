# iOS 1.0.7（1184）正式工具链重编

原因：1183实际分发签名成功，但苹果上传以Unsupported SDK or Xcode version拒绝本机27.2（27B52）/ SDK27.2（24B8118）。用户已明确授权先构建、上传和送审。保留1183失败产物与原始诊断、旧1175审核、所有手机/戒指数据及既有功能门禁。

修改前status干净，origin fetch成功，HEAD与开发分支origin均10e1c7923e49d58cd632b85953bd2ff678303082；已读AGENTS、handoff、最近1183记录、问题复盘和回归清单。运行源码仍与已通过CI41033828840的680ae3b相同。本轮不修改业务功能或项目最低系统目标，不重置设备、扩大权限、变更地区或接受协议。

只从苹果官方页面实际显示的下载链接取得Xcode27.1，另存独立目录，后续使用独立DEVELOPER_DIR。真实重新编译1.0.7（1184）、cn.saydian.ring、W7SXQ4A226及lib/main.dart，无QA定义。不得修改编译器/SDK身份字段来绕过校验。下载完整性、Apple签名、实际工具版本、构建命令/结果、归档、签名IPA、TestFlight与审核提交分别追加核验；在新构建处理可选前不撤回旧1175。

依据：[苹果官方下载](https://developer.apple.com/download/all/?q=Xcode)、[App Store Connect发布说明](https://developer.apple.com/help/app-store-connect/release-notes/)。27.1系列可用于App Store与TestFlight；本机27.2被拒以当前实际服务器回执为准。

## 正式工具链与真实归档

官方页面展开27.1后核实实际下载链接。无需读取浏览器凭据，使用浏览器正常下载；接口60秒超时后本次临时文件持续增长，最终完整Xcode_27.1.xip为2,027,369,056字节、SHA256 038ad29cc2cd87e7762aac596833943000fd3d5fb64be530e2ecdbe5449cd660。首次进程因目标工作目录尚未创建而未启动，创建独立空目录后正常解压；没有重复下载。xip输出Software Update且validation not attempted，所以另行执行严格深度codesign验证及Gatekeeper检查：Apple Software Signing/Apple Root CA链、Gatekeeper accepted/source Apple System。原/Applications/Xcode.app保留，未更改全局工具选择、删除文件、禁用校验或接受新协议。

独立DEVELOPER_DIR实际返回Xcode27.1（27A9275）、SDK27.1，first-launch检查退出0。固定源1a40d34cb512d0674a774f9b7088d90241b1f9a2，782项运行输入与1182一致；源码与文档工作树在编译前后均干净。以同样正常main/生产第一方参数执行1184 release config，30.8秒通过；独占串行xcodebuild Release archive，46.8秒通过，严格深度应用签名校验通过。个人机器部署目标覆盖15单独记录，仓库默认13兼容性仍引用原CI，不冒充本机13编译。

实际1184归档为cn.saydian.ring / 1.0.7（1184）/ W7SXQ4A226，DTXcode=2710、DTXcodeBuild=27A9275、DTSDKName=iphoneos27.1、DTSDKBuild=24A94232，MinimumOSVersion=15.0；这些是新工具真实生成，未改写。提醒音资产SHA256仍a6afc964076ca00309ed3e780a983a479a7f1d1c3776d69639f569f5623b2c78。初次本机摘要使用Python3.10才有的hashlib.file_digest失败，更正为当前Python3.9兼容的流式SHA256后核验成功，不影响构建输入。

将新归档完整保护到Xcode Archives目录并再次校验签名。打开新归档时Organizer仍选旧1183，读取详情识别后明确选中1184并复核详情，未继续旧选择。分发选择Custom→App Store Connect→Upload，关闭Manage version and build number，保留符号上传、关闭internal-only；自动签名使用已恢复的原账号。准备和签名阶段不等于上传完成，最终IPA/服务器校验/处理/提交结果继续追加。

## 最终1184分发包与苹果新回执

真实签名IPA再次核实1.0.7（1184）/ cn.saydian.ring / W7SXQ4A226、非调试、APNs production、App Store provisioning（无开发设备列表），严格深度签名及提醒音资产通过。文件38,931,568字节，SHA256 aacaff906c53d02eda28c649546337867609b90b9bb58f22b0c3797cf0721a47，实际SDK仍27.1（24A94232），没有篡改工具身份字段。匹配本次原生分发流水线后另存私有交付目录，再从Review IPA页执行Upload。

苹果这次不再返回Unsupported SDK错误，实际两项致命错误改为：CFBundleShortVersionString必须高于已批准1.0.7，以及1.0.7 pre-release train已经关闭。15项供应商dSYM警告仍单列。1184上传未被接受，不能写作TestFlight完成。重新导航而非依赖旧缓存后，App Store Connect显示1.0.7可分发、构建1175、自动发布；先前等待审核的页面是旧快照。没有撤回或修改已批准版本。

继续按用户“构建新版本上传送审”改用1.0.8（1185），相同运行源码在官方27.1重新编译，不仅替换IPA版本字段。版本与构建号由构建参数指定，仓库pubspec及项目默认目标不改；已批准1.0.7保留。1185结果见下一条记录。
