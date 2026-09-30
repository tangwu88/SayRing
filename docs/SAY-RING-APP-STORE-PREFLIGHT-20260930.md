# Say Ring 苹果 App Store 提交前检查

## 请求与实际状态

- 用户要求提交应用市场，并已明确选择苹果 App Store。本轮只核对正确应用与提交条件；未上传包、修改商店元数据、添加审核草稿或点击最终提交。
- 已通过用户现有登录进入 App Store Connect：`Say Ring`，Apple ID `6816549943`，Bundle ID / SKU 均为 `cn.saydian.ring`，主要语言简体中文，iOS `1.0` 状态为“准备提交”。
- 同团队另一份“Saydian赛电”处于等待审核，其 Apple ID 不同；本轮未进入或修改该应用。
- 本轮 Git 从干净 `0f3b26452df6bcbddbed8d18c957f8354a5c7679` 安全快进至最新主线 `d47170d86a8d9fb0772d5e9e22e405b46a25eb87`，保留同事的登录品牌/微信图标变更。原始脏工作区未修改。

## 商店页面回读

- 版本页：iPhone 截图 0 张；描述、关键词、技术支持 URL、版权为空；无构建可选；审核专用登录账号和审核联系人字段为空。
- TestFlight 显示“提交构建版本以开始测试”，没有已上传的构建，不能把本地 Profile 包或其他 App 构建当作本产品可提审包。
- App 信息：类别、内容版权声明、年龄分级未完成；中国大陆 ICP 备案信息尚未填写；发行地区和收费策略没有在本轮获得用户确认。
- App 隐私：隐私政策 URL 为空，数据收集问卷尚未开始。健康/联系方式/SDK 数据实践需要按实际实现核实，不选择“不收集数据”充数。
- 现有默认版本发布选项为审核后自动发布；本轮未改变该策略、价格、地区或任何法律声明。

## 技术检查与阻断

- `security find-identity -v -p codesigning`：存在与当前团队匹配的 Apple Distribution 身份。没有导出私钥、删除/吊销证书或处理 Apple 密码。
- 只读解析本机固定 App ID 的 provisioning profiles：仅有设备受限的开发 profile，`aps-environment=development`；尚未发现 App Store distribution profile。此结论只说明本机当前安装状态，不等于账号无权创建发布 profile。
- `xcodebuild -version`：Xcode 26.6 / 17F113。工程版本 `0.1.21+1006` 与商店草稿 `1.0` 不同，归档前需统一，不上传不匹配版本。
- `env CONFIGURATION=Release SAIDIAN_PRODUCTION_RELEASE=true PRODUCT_BUNDLE_IDENTIFIER=cn.saydian.ring /bin/sh scripts/release/validate_xcode_release.sh` 返回 1：继承的正式发布脚本仍要求旧 `cc.saidian.app`。需将门禁适配固定产品 ID 并回归；不得换回旧包名或使用 QA 开关绕过正式门禁。
- `df -h /`：本轮剩余约 468–488 MiB。仅盘点当前项目可重建中间产物，没有删除缓存、构建产物、原始附件、其他项目或手机数据；尚未启动新的 archive/export/upload。
- 最新主线登录品牌改动的 iOS 包尚未重新编译与验收。旧本机 Profile 仍是开发调试产物，不能直接提交 App Store。
- 微信 Universal Link 仍未上线：公开 AASA 只有原 App 关联，专属链接 HTTP 404；此前服务端 CI `36687970963` 部署阶段取消，更新后的 `97eed39fe1b127596cac8db8a3bf645ac859902d` 正由 CI `36690555516` 处理。未重跑旧部署、回退新代码或并发操作服务器。
- 国际公开能力中的隐私政策版本为 `global-qa-2026-09-10`；需要核实最终适用的运营主体、中文公开隐私页及 SDK 披露后才能作为商店资料，不能仅据接口存在宣称法律文本已适用。
- 源码定向搜索未发现 Apple 登录实现；既有微信登录涉及 [Apple 审核指南 4.8](https://developer.apple.com/app-store/review/guidelines/uk/#login-services) 的等效隐私登录要求。需核实适用性并确定方案，不能擅自删除用户指定的微信登录或假称已经符合。

## 待用户补充与后续步骤

- 发行地区、是否免费下载；中国大陆发行所需的本 App ICP 备案资料（没有则如实说明）。
- 版权主体与审核联系人姓名/电话/邮箱；审核专用测试账号可由用户直接填入平台，不能提供个人 Apple 密码。
- 最终隐私声明、内容版权、年龄分级、医疗设备/出口合规等只基于真实资料；SDK/加密/服务端处理和硬件依赖需分别复核。
- 资料与发行范围确定后：修复正式打包门禁、准备受保护生产配置和 App Store profile、验证新包及微信回跳、采集真实截图、完成商店问卷，再上传/选择同版本构建并提交审核。
- Apple 的 [提交步骤](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app) 区分上传构建、添加以供审核和最终提交。本轮上述状态均未完成，不宣称已提审或可保证过审。

## 本轮验证边界

- 本轮只做网页/源码/签名元数据/公网的只读检查，以及正式门禁的可复现失败测试；没有改动 Dart、Swift、构建脚本或签名配置。
- 不重复执行新包全量编译、安装和手机测量，不沿用旧包结果冒充最新源码已验证；`git diff --check` 用于本次记录检查。
