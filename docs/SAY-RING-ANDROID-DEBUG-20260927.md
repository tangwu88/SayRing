# Say Ring Android 真机 Debug 启动记录（2026-09-27）

## 目标与范围

- 目标：基于最新 `origin/main` 在已连接的华为手机上覆盖安装并启动 Say Ring Debug，保留现有账号与本机数据。
- 基线：`5faabecccda512bef39ea0a9b66cb3be3fad00e4`。
- 设备：HUAWEI PPA-LX3，Android 10（API 29），ADB 序列号 `2KTYD21714200059`。
- 包名：`cn.saydian.ring`；版本：`0.1.21+1004`。
- 本轮未修改业务源码、接口协议、健康数据或设备绑定。

## 执行与结果

### 23:11 Git、设备与环境预检

- 原因：避免安装到同时在线的 Android 模拟器，并确认工作树不会被覆盖。
- 范围：Git 状态、ADB/Flutter 设备列表、现有调试进程、已安装包信息。
- 结果：通过。
  - `main` 工作树干净，HEAD 与 `origin/main` 均为 `5faabec`。
  - 真机与模拟器同时在线；后续命令明确指定真机 `2KTYD21714200059`。
  - 手机上的旧 Say Ring 包为 `0.1.21+1004`，账号和应用数据保留。
  - 已存在的 Flutter 会话属于另一个项目且仅连接模拟器，未中断。

### 23:12 Debug 构建、覆盖安装与附加

- 命令：

  ```powershell
  D:\Dev\Flutter\3.44.9\bin\flutter.bat run --debug --no-pub `
    -d 2KTYD21714200059 `
    --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn `
    --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update `
    --dart-define=JPUSH_APP_KEY= `
    --dart-define=QWEATHER_API_KEY=
  ```

- 结果：通过。
  - `assembleDebug` 成功，生成 `build/app/outputs/flutter-apk/app-debug.apk`。
  - 华为系统出现“风险提示/继续安装”，确认本次 Say Ring Debug 安装后覆盖成功。
  - Flutter VM Service 与 DevTools 已附加，应用前台 Activity 为 `cc.saidian.saydian_app.MainActivity`。
  - 首页真实渲染完成，登录会话仍在；没有清除数据。

### 23:16 启动日志与域名检查

- 结果：部分通过。
  - 当前 App 进程未出现 `FATAL EXCEPTION`、`AndroidRuntime`、ANR 或 Dart 未处理异常标记。
  - 当前进程日志中发现 28 条 `app.saydian.cn` 标记，首轮业务请求返回 HTTP 200。
  - 当前进程日志未发现旧 `saidian.cc` / `saydian.cc` 第一方域名标记。
  - 更新清单请求仍返回 HTTP 404：`/global/api/saydian-app/v2/support/app-update?product=say-ring` 的服务端发布状态仍未验收。
  - 冷启动日志出现 318/133 帧跳过；不影响本轮启动，但保留为后续真机性能检查项。
  - Flutter 提示 `camera_android_camerax`、`jpush_flutter_android` 仍使用插件侧 Kotlin Gradle Plugin；当前构建通过，但后续 Flutter 升级前需跟踪插件兼容性。

### 23:16 诊断脚本失败与修正

- 首次失败：PowerShell 中误把只读保留变量 `$PID` 用作 App 进程变量，导致该次进程日志检查无效。
- 修正：改用 `$appPid`，重新取得 `cn.saydian.ring` 真实进程号并完整重跑崩溃、ANR 与域名检查。
- 结论：只采用修正后结果；后续脚本不得复用 `$PID`、`$HOME`、`$Host` 等 PowerShell 保留变量。

## 本轮未验收

- 未执行真实戒指扫描、连接、同步、测量、断开及三轮重连。
- 未执行微信真实授权、极光真实通知送达、支付或正式签名升级。
- `JPUSH_APP_KEY`、天气密钥均为空，本轮不把相应功能记为通过。
- 本轮目标仅为开启并保持 Android 真机 Debug；Flutter 会话退出后需重新附加才能继续热重载和实时日志。
