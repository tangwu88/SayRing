# 2026-10-01 Say Ring 邮箱登录修复记录

## 问题与范围

- Bug：iOS 登录页没有邮箱密码入口；邮箱验证码依赖的线上能力目前关闭。复现：打开 1016 登录页选择邮箱，仅能输入验证码；公开生产 `auth/capabilities?product=say-ring` 仍返回 `product=null`、`login.email=false`。预期：已有邮箱账号可在专属协议有效且明确同意后以密码登录；验证码只在投递能力开启时可用。实际：UI 无密码入口，线上专属协议未部署。等级：P1，影响审核访问与已有邮箱用户。
- 修改前工作树干净，`codex/macos-update-20260930` 与 `origin/codex/macos-update-20260930` 均为 `075086c7e5756968b0816c7de85bbbeb43bb8f47`；`git fetch --prune origin` 成功。只改 Say Ring Flutter 客户端和测试；Android 打包/真机按用户当前优先级后置。
- 客户端密码登录必须取得 `product=say-ring` 的能力与非空当前 `consentVersion`，要求用户确认年满 14 岁并主动同意协议。不能把旧通用国际版协议当成本产品协议。账号凭据与真实健康数据不写入仓库。

## 客户端修改

- `lib/ui/global_code_login_page.dart`：邮箱默认显示密码登录；仅 `login.email=true` 时可切换邮箱验证码。手机号验证码、微信 iOS 门禁和只读演示不变。错误消息不区分账号不存在与密码错误。
- `lib/services/global_api_client.dart`、`lib/services/app_controller.dart`：Say Ring 专用邮箱密码请求携带 `channel=email`、规范化邮箱、`product=say-ring`、语言、当前协议版本与显式同意；复用原有账号切换和会话保存防串写流程。普通国际版旧密码 API 不改。
- `test/global_code_login_page_test.dart`、`test/global_api_test.dart`：使用合成凭据覆盖 UI 年龄/协议门禁、401 通用错误和请求字段；未使用真实演示密码。

## 实际验证与待办

- 首轮新增 UI 测试因 ListView 懒加载找不到滚动区下方按钮而失败，改为 `scrollUntilVisible` 后重测。第二轮期望英文错误文案与资源文件不一致，改为资源文件实际文案。两次失败均非业务请求错误。
- 更改专用 API 方法前，定向 UI 测试 5/5、`flutter analyze --no-pub` 零问题、`TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact` 全量 1031/1031 通过。**这些结果属于新增专用 API 方法前的中间源码快照；最终源码须重跑，不能沿用为最终门禁。**
- 客户端签名 Profile `1017` 构建在加入专用 API 方法前已启动，结果即使成功也只能算中间快照；最终源码须重新构建并核验签名、包名与版本。
- 服务端任务只读确认：生产仍是旧国际 API，忽略 `product`；演示邮箱账号存在、ACTIVE、邮箱未验证。401 不能证明密码错误；未重试登录或修改账号。服务端候选 PR #4 尚未发布，专属协议尚未审核/激活。当前密码端点也不记录 Say Ring 专属同意；已交给服务端任务在候选分支实现最小契约与测试，不得绕过验证、迁移或部署门禁。
- 线上能力、专属法律文档、服务端专用密码契约与实际账号登录成功均未验收。iOS 包构建、测试、安装、审核提交须分别记录，不把代码修复说成线上可登录。

## 最终客户端回归

- 将密码登录请求切到专用方法后，`dart format` 检查 5 个本轮文件、0 额外格式变更；`flutter test --no-pub test/global_api_test.dart test/global_code_login_page_test.dart --reporter compact` 35/35；`flutter analyze --no-pub` 零问题。
- 最终源码 `TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact` 1032/1032，`TZ=Asia/Shanghai` 同命令 1032/1032；`git diff --check` 通过。
- 首次 `1017` 签名 Profile 构建与专用 API 方法编辑交错，仅作为中间结果。之后针对最终源码串行重跑同一目标的 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Profile -destination 'id=A3DC94EA-18E8-52EB-B953-60133E11D071' -derivedDataPath build/ios-profile-1017-derived-data -jobs 1 -allowProvisioningUpdates FLUTTER_BUILD_NAME=1.0 FLUTTER_BUILD_NUMBER=1017 build -quiet`，退出 0。实际 `Runner.app`：`cn.saydian.ring`、构建 1017、`UIDeviceFamily=[1]`、Apple Development 团队 `W7SXQ4A226`、`get-task-allow=true`；`codesign --verify --deep --strict` 通过。Runner 主二进制 SHA-256 `32ba08453210cae50b6359f4fb5718a6711080b2eabc26f1448aba866b65e331`。第三方 SDK 已有 deprecated/dSYM 模块缓存警告，未影响退出码。
- **未安装 1017、未退出手机现有账号或作真实密码登录**：线上专属能力仍 `product=null`，贸然登出可能无法回到当前账号；开发签名 Profile 不等于 App Store 分发归档。Android 原生测试、APK 和真机按用户要求后置。App Store Connect 仍是已验证的 1016 候选，未在本轮上传 1017 或重新提交审核。
