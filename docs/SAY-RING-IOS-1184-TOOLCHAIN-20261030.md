# iOS 1.0.7（1184）正式工具链重编

原因：1183实际分发签名成功，但苹果上传以Unsupported SDK or Xcode version拒绝本机27.2（27B52）/ SDK27.2（24B8118）。用户已明确授权先构建、上传和送审。保留1183失败产物与原始诊断、旧1175审核、所有手机/戒指数据及既有功能门禁。

修改前status干净，origin fetch成功，HEAD与开发分支origin均10e1c7923e49d58cd632b85953bd2ff678303082；已读AGENTS、handoff、最近1183记录、问题复盘和回归清单。运行源码仍与已通过CI41033828840的680ae3b相同。本轮不修改业务功能或项目最低系统目标，不重置设备、扩大权限、变更地区或接受协议。

只从苹果官方页面实际显示的下载链接取得Xcode27.1，另存独立目录，后续使用独立DEVELOPER_DIR。真实重新编译1.0.7（1184）、cn.saydian.ring、W7SXQ4A226及lib/main.dart，无QA定义。不得修改编译器/SDK身份字段来绕过校验。下载完整性、Apple签名、实际工具版本、构建命令/结果、归档、签名IPA、TestFlight与审核提交分别追加核验；在新构建处理可选前不撤回旧1175。

依据：[苹果官方下载](https://developer.apple.com/download/all/?q=Xcode)、[App Store Connect发布说明](https://developer.apple.com/help/app-store-connect/release-notes/)。27.1系列可用于App Store与TestFlight；本机27.2被拒以当前实际服务器回执为准。
