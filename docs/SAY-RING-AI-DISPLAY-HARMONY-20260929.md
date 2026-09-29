# 2026-09-29 Say Ring 原生鸿蒙 AI 显示开关

## 原因与范围

- 原生鸿蒙包为 `cn.saydian.ring.hm`，产品 `say-ring`、API 根 `/global/api/saydian-app/v2`，属于当前 Say Ring 客户端。此前只有 Flutter 受后台显示开关控制，鸿蒙首页、个人中心和报告仍无条件显示。
- 修改前读取 AGENTS、国际交接、变更索引、最近 AI/HR05 记录、跨模块复盘与回归清单；已检查 Git 工作树、远端并执行 fetch。基线 `de5ff796626a1ebec5674db43e62f39cc31e863b`，保留并行 Flutter 改动和既有 UI 文档空行改动。
- 新增纯逻辑显示状态与原生同源公开读取/缓存服务，严格接受 `{product:'say-ring',hideAi:boolean}`；启动/回前台刷新，首个有效值前隐藏，失败保持已接受配置，成功后持久化。网络请求不带会员凭据、不跟随重定向。
- 首页 AI 卡片、个人页 AI 提问、健康报告入口及已打开页面受同一状态控制；隐藏时仅清理当前展示并返回普通页面，不删除账户、历史健康、服务端报告或权益。
- AccountClient 阻止隐藏期间 AI 聊天、报告读取/生成/导出、授予分析同意等新请求，并拒绝迟到响应和刷新重试。法律文本读取与撤回同意保持可用。
- API 23+ 请求设置 `maxRedirects:0`；API 17–22 复用既有 `LegacySafeHttp` 的固定国际同源、禁重定向与有界响应实现，不依赖低版本未提供的 NetworkKit 重定向属性。
- 不改 Flutter、主日志索引、已有 SDK/地图/登录逻辑，也不修本次发现的遗留全局传输路径兼容问题。显示配置使用独立的严格全局公开请求服务。

## 涉及文件

- `harmony-native/entry/src/main/ets/model/AppDisplay.ts`：严格产品/布尔契约、失败保留、单请求合并、成功缓存、观察者与请求代次。
- `harmony-native/entry/src/main/ets/services/AppDisplayService.ets`：公开读取和隔离的原生 Preferences 缓存。
- `harmony-native/entry/src/main/ets/entryability/EntryAbility.ets`：启动/回前台刷新。
- `harmony-native/entry/src/main/ets/services/AccountClient.ts`、`SaydianApi.ets`：生产实例接入统一门禁、异步响应与 401 重试保护。
- `harmony-native/entry/src/main/ets/pages/Index.ets`：首页/个人/报告入口、已开页面、迟到 AI 回复和报告 UI 门禁。
- `harmony-native/tests/app-display.test.mjs`：16 项行为/生产接线回归，使用合成账户和内容，不请求生产健康数据。

## 验证与边界

- 首次 `node --test harmony-native/tests/app-display.test.mjs harmony-native/tests/global-reports.test.mjs` 因 `AppDisplayCache` 仅类型接口被当作运行时导入而失败；已拆成 `import type`，同命令 25 项通过。此后补充 API 17–22 传输选择、生成中隐藏/再开启、PDF 迟到/401，以及第二次 401 不误退出账号的用例。
- 最终依次设置 `$env:TZ='UTC'`、`$env:TZ='Asia/Shanghai'`，分别执行 `node --test --test-reporter=spec harmony-native/tests/*.test.mjs`：每次 **497 项通过，0 失败，0 跳过**。
- 工具链：`E:\saydian\.toolchains\harmony-clt-26.0.0.821\command-line-tools\bin\hvigorw.bat`，`JAVA_HOME=E:\saydian\.toolchains\jdk17\jdk-17.0.20+8`。在 `harmony-native` 下串行执行 `--mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon` 和对应 `buildMode=release`。
- 最终 Debug ArkTS 与 HAP 编译成功（13.811 秒）；Release 编译成功（23.845 秒），生成 `harmony-native/entry/build/default/outputs/default/entry-default-unsigned.hap`（忽略的构建产物，不提交 Git）。构建存在既有第三方/资源/弃用、SDK 异常处理和部分第三方字节码未混淆提示；本次 Preferences 失败由状态层捕获，不声称零警告。
- `git diff --check -- harmony-native docs/SAY-RING-AI-DISPLAY-HARMONY-20260929.md` 通过（仅 Windows 行尾提示，无差异格式错误）。
- 使用本机 Harmony SDK 的 `hdc.exe list targets` 返回 `[Empty]`；未安装、未进行鸿蒙实机开关/网络/戒指验收。
- `build-profile.json5` 当前 `signingConfigs=[]`；只能生成未签名 HAP，不能安装或称为应用市场正式包。主机未提供可执行本次测试的已签名鸿蒙设备。
- 当前鸿蒙设备服务未接 HR05/CoolWear SDK，本次显示开关不改变该限制；不可用 Node 测试或编译代替真实戒指/鸿蒙业务验收。
- 遗留待处理：`NativeHttpTransport.request` 仍检查旧 `/api/` 前缀，与国际 `/global/api/` 契约不一致，旧 AI 聊天路径也不符合国际地址校验；本轮仅为显示配置独立接通公开读取，未将遗留登录/AI 业务声称为线上可用。
- 本分工不执行 Git 提交/推送，由主任务与 Flutter/服务端验收统一处理。
