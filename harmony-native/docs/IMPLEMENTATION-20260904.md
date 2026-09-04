# 原生鸿蒙登录与首页首版

## 修改前基线

- 用户仅授权本侧会话在独立目录移植，先运行登录和首页。
- 原目录 `/Users/mycodex/电商/赛电APP` 保持只读，原分支及真机调试不变。
- 独立副本同步 `origin/codex/ios-full-migration`，HEAD `8554753e1b0f4aa1ea608f6ac3b95c7cf97a0e52`；已含 `origin/main`，领先 6 个既有记录提交。
- 本次分支 `codex/harmony-native-login-home`；只新增 `harmony-native/` 和对应记录，不改 Flutter、Android、iOS 源码。

## 范围及预期

- ArkTS + ArkUI Stage 模型；HarmonyOS 原生 HAP，不是 APK 或 WebView 套壳。
- 真实登录 `/api/v1/site/login`、刷新 `/api/v1/site/refresh`、只读资料 `/api/v1/member/member/my`，沿用现有 multipart、`group=app`、双鉴权头契约。
- 原生首页保留赛电品牌素材，健康项空态、未适配能力说明、用户资料、公开健康百科、协议读取和本机退出。
- 登录秘密存储于 Asset Store Kit；不保存密码、不复用原项目或手机中的账号、Token、健康记录，不记录请求体。
- 会话代次防止迟到登录/资料跨账号；资料 API 失败不当作健康值 0。
- 仅申请 INTERNET；手表蓝牙、同步、测量、远程关爱、支付、推送、在线升级暂未适配，必须明确说明。

## 验证记录

- Git 独立克隆、fetch --prune、pull --ff-only：通过；原项目未写入。
- 实施前阅读既有复盘、回归清单及最新 iPhone/W9S 记录；不把旧真机结果算作鸿蒙通过。
- 开发工具自带 Node 24.14.1、HarmonyOS 7.0 API 26 SDK 与原生模拟器可用。
- 官方网页部分抓取超时；开发以本机官方 SDK 类型声明、官方模板和现有接口源码为依据。
- 公开接口只读检查：用户协议、隐私协议均为 HTTP 200 / 业务码 200；健康百科返回 4 项；不带登录凭证读取个人资料为 HTTP 200 / 业务码 401，客户端按登录失效处理。

### 2026-09-04 构建问题与修复（保留失败记录）

1. 首次依赖初始化停在 npm 审计网络请求；只结束本次启动的构建进程，使用单次命令的 `npm_config_audit=false`、`npm_config_fund=false` 和超时配置后继续。未改变用户全局 npm 配置。
2. 首次工程路径含中文，构建报 `00306003`。仅将新建副本移至 `/Users/saydian/DevEcoStudioProjects/SaydianHarmony`；原工程保持原位。
3. 将系统镜像版本 `7.0.0(26.0.0)` 用作编译 SDK 参数，报 `00303312`；改成 `26.0.0(26)` 又触发 API 版本解析错误；将最低版本简写成 `6.1.0` 则报 `00306042`。
   依据随 IDE 安装的 SDK 元数据、版本映射和构建校验规则，最终省略 `compileSdkVersion`，配置 `targetSdkVersion: "26.0.0"`、`compatibleSdkVersion: "6.1.0(23)"`。API 26 起与 API 10–25 的版本表示法不同。
4. ArkTS 编译拒绝重新抛出任意类型的异常 `arkts-limited-throw`；改为先判断 `ApiError`，其他异常转换为安全提示。安全存储解码改用 `decodeToString`，写入增加明确异常处理。
5. 首次模块 SemVer 警告在 IDE 同步后未再出现；最终构建只保留“未配置签名”警告。模拟器正常接受未签名调试 HAP；未修改系统验签策略，未生成或借用生产签名。
6. `aa -h` 不支持顶层帮助参数，使用其提示的 `aa help` / `aa start -h`；HiLog 的 `-x` 与 `-z` 不能组合，改用 `-x` 加精确进程过滤。未清空系统日志。

### 实际完成的验证

- 官方 Hvigor `assembleHap`：成功，33 个任务；ArkTS 编译及资源打包完成。
- Node 主机契约测试：22/22 通过；涵盖输入、HTTP/业务错误、会话字段、刷新身份约束、过期时间、multipart 和安全配置。它们不是模拟器 UI 或真实账号测试。
- HAP 压缩完整性检查：通过。
- 模拟器：`Saydian_HarmonyOS7_Phone`，Mate 70 Pro，HarmonyOS 7.0.0 / API 26；仅操作 `127.0.0.1:5555`。
- 安装 `cc.saidian.saydian.harmony.dev`：`install bundle successfully`；启动 `EntryAbility`：`start ability successfully`。
- 17:50 首次启动日志 `Native login and home ready`；进程存在，任务状态为 `FOREGROUND`。当次按应用进程筛选的 ERROR/FATAL 日志为空；这仅证明启动观察期未发现错误，不代表完整稳定性验收。
- DevEco Studio 已打开独立原生工程并识别目标模拟器。设备投屏不列出本地模拟器；当前电脑自动化也无法直接识别独立模拟器窗口，因此未把登录页截图或人工交互写为已通过。
- 已提示用户在模拟器中手动登录，不索取聊天中的密码；账号登录、Asset Store 写入/恢复、真实个人资料及 UI 交互等待用户操作后验证。
- 原项目再次核对：`codex/ios-full-migration`，HEAD 仍为 `8554753e1b0f4aa1ea608f6ac3b95c7cf97a0e52`，工作树干净。

### 调试产物

- 工程：`/Users/saydian/DevEcoStudioProjects/SaydianHarmony/harmony-native`
- HAP：`entry/build/default/outputs/default/entry-default-unsigned.hap`（仅本机模拟器调试，不提交二进制产物）
- SHA-256：`64d2207f8617c565648af2d0ce078ba234a6cbc5d7e4df19e818a98e18277ef4`
- 本机源码检查点备份：`/tmp/saydian-harmony-checkpoint.5UFONA/native-source.tgz`。它仅包含本次原生工程，排除构建缓存；临时目录不作为正式归档。

## 尚未完成

- 真实账号成功登录和读取需要用户在原生 App 中手动登录。
- 真机签名、真实鸿蒙手机安装、完整页面交互和冷启动凭证恢复尚未验收；当前模拟器 HAP 不可视为手机发行包。
- 当前不是完整功能移植，不是正式发布版；厂商原生 SDK、健康存储迁移、推送/支付/升级另行适配与验收。
- 本轮不执行安卓/iOS 构建、手机操作或手表操作；与用户明确的侧会话隔离范围一致。
- 原仓库跨平台发布门禁未重跑，因此本轮不标记发布通过，不提交或推送原开发分支及 main。独立分支中原生新增文件保留待继续验收。
