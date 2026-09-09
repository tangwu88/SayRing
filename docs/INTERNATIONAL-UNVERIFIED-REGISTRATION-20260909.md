# Saydian 国际版临时免验证码注册记录

日期：2026-09-09

App 基线：`e9c64713322fc0419414f7f6b43e9bd9d330c9b5`

服务端联调分支：`tangwu88/saydianserver:codex/global-api-foundation`

## 本轮要求与完成标准

- 注册时暂不要求邮箱或手机验证码，但仍要求邮箱或有效 E.164 国际手机号、密码以及用户协议/隐私政策同意。
- App 必须由服务端 `registration.verificationRequired=false` 明确驱动；能力未知、服务未部署或开关关闭时继续不可注册，不能由客户端自行跳过验证码。
- 找回密码保留验证码流程；未验证联系方式不能被包装为已验证，也不能绕过商城等验证门禁。
- Android 模拟器需完成真实本地 API 注册、会话进入首页、数据库状态核验和合成数据清理；不能只验证 Widget 外观。

## 源码修改

- Flutter 与 HarmonyOS 的账号能力模型新增 `verificationRequired`，默认 `true`，缺字段时保持安全默认。
- 当服务端明确返回 `false` 时，注册页隐藏验证码输入和发送按钮，直接提交 `/auth/register`；找回密码仍显示并校验验证码。
- 增加 Flutter/HarmonyOS 免验证码注册客户端、控制器方法、表单校验、重复账号提示及九份 ARB/生成本地化资源更新。
- Flutter 国际 API 客户端接入真实能力、验证码、带码注册、免码注册和重置密码 V2 路由；旧国际短信兼容入口继续失败关闭。
- Android 只在 Debug 且显式 `SAYDIAN_ALLOW_LOCAL_DEBUG_API=true` 时允许 `10.0.2.2`/localhost HTTP。Release 和其他主机仍只接受固定 HTTPS 生产根地址；新增的 network security 配置不进入 Release。
- 模拟器联调发现通知和商城首页仍走旧兼容路径并抛出未处理的严格路由异常；改为通知/商城 V2 读取，同时让尚未迁移的旧方法稳定返回“暂不可用”，不回退国内接口。

## 自动化与构建结果

- Flutter 定向账号/API/UI 测试：26/26 通过。
- `dart format --output=none --set-exit-if-changed lib test`：118 个文件，0 个变化。
- `flutter analyze --no-pub`：无问题。
- `flutter test --no-pub`：636/636 通过。
- HarmonyOS host tests：481/481 通过。
- Android `:app:testDebugUnitTest`：15 项，0 失败/错误/跳过。
- Android x86_64 Debug APK 构建通过：`185020878` 字节，SHA-256 `E94914E35E2CBDCE0985110350E0EA5563A718BCB8BC341FB280225CDB64CC19`。该包含本地 API Debug 参数，只用于隔离 QA，不可作为生产或商店包。

## 模拟器与本地 API 端到端结果

- `Saidian_API_36` / `emulator-5554` 安装并启动 `cn.saydian.app.global`；默认语言为英文。
- 邮箱与国际手机号注册页面均确认没有验证码控件，仍保留密码、协议同意及联系方式格式校验。
- 使用唯一合成邮箱从 UI 注册，真实调用 `127.0.0.1:8082` 的隔离国际 API，成功获得会话并进入首页。
- 数据库复核：邮箱验证时间为空、手机号验证时间为空、2 条当前 QA 协议同意记录、1 个会话，符合“能注册但未验证”的契约。
- 清理只命中该合成账号；最终隔离库用户/会话/同意记录均为 0，两份 QA 协议占位记录保留。模拟器 App 数据随后清除并停在干净英文登录页。
- 最终 MainActivity 为 top-resumed，清空后启动日志未发现 `FATAL EXCEPTION`、AndroidRuntime 致命异常或目标进程死亡。
- 截图与 APK 位于被 Git 忽略的 `build/debug-evidence/`、`build/app/outputs/`，不提交构建产物。

## 失败与修复记录

- 严格路由解析器最初抛出 `ArgumentError`，使旧通知/商城入口出现未处理异常；客户端统一转成可用性错误，并为已有 V2 路由补映射回归。
- 定向测试首次因 part 文件引用不存在的公开 `NotificationEventType` 编译失败；改用项目既有内部类型后通过。
- 分析器先后发现 `use_null_aware_elements` 和错误位置的空值感知运算符；最终使用 Dart 合法的 map 空值元素语法，完整分析通过。
- 首次 logcat 时间过滤参数不被当前 Android 工具接受；改为清空日志、重启、完整导出后做精确致命模式匹配。
- 本地 PostgreSQL 角色先误写为 `saidian_app`；改用隔离环境真实角色 `saydian_app`。模拟器键盘又漏录合成邮箱首字符，清理时依据唯一创建记录确认实际值后使用精确条件，未做通配删除。

## 不能据此声称完成的事项

- `https://app.saydian.cn` 生产国际认证服务尚未部署本分支；生产能力接口和免验证码注册仍不可用。
- 服务端部署模板默认关闭临时开关，当前本地协议仅为 QA 占位，未获正式法律审核。
- 真实邮箱/短信投递、密码找回、未验证账号升级、滥用防护现场验证、物理手机、手表、iPhone/HarmonyOS 真机和商店签名仍未验收。
- 临时免验证码不能成为永久安全设计；正式开放前需确定验证恢复与既有未验证账号处理策略。
