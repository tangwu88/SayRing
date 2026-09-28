# Say Ring Android 模拟器 Debug 记录（2026-09-28）

## 目标与范围

- 目标：在本机 Android 16 x86_64 模拟器上启动最新 `main` 的 Say Ring Flutter Debug，用于页面、本地状态和接口联调。
- 基线：`c52c12e153b2db898d333ae5bac34ed3bf40df4c`，启动前与 `origin/main` 一致，工作树干净。
- AVD：`Saydian_API_36`；ADB：`emulator-5554`；Android 16（API 36）x86_64。
- 包名：`cn.saydian.ring`；版本：`0.1.21+1004`。
- 模拟器不用于判定真实戒指、蓝牙、推送、支付或生产签名通过。

## 执行与结果

### 22:53 模拟器启动

- `flutter emulators` 未识别本地来源，但 `D:\Dev\Android\Sdk\emulator\emulator.exe -list-avds` 正确列出 `Saydian_API_36`。
- 使用官方 `emulator.exe @Saydian_API_36 -no-snapshot-save` 启动现有 AVD；未清除 AVD 数据或快照目录。
- `emulator-5554` 在约 12 秒内进入 ADB `device`，`sys.boot_completed=1`。
- 华为真机同时在线，后续 Flutter 命令明确指定 `emulator-5554`，未安装到真机。

### 22:54 x86_64 Debug 构建、安装与附加

- 命令：

  ```powershell
  $env:SAIDIAN_EMULATOR_DEBUG='true'
  D:\Dev\Flutter\3.44.9\bin\flutter.bat run --debug --no-pub `
    -d emulator-5554 `
    --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn `
    --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update `
    --dart-define=JPUSH_APP_KEY= `
    --dart-define=QWEATHER_API_KEY=
  ```

- `assembleDebug` 约 108.8 秒成功；安装约 8.3 秒成功。
- `lib/x86_64/libflutter.so` 正常加载，没有 `MissingLibraryException`。
- Flutter VM Service 与 DevTools 已附加；App 进程号为 `5620`。
- 登录页和数字键盘正常渲染，已显示最新蓝色科技主题。

### 22:57 启动日志、页面与域名检查

- 当前 App 进程未出现 `FATAL EXCEPTION`、`AndroidRuntime`、ANR、`MissingLibraryException` 或 Dart 未处理异常标记。
- 当前进程日志未发现旧 `saidian.cc` / `saydian.cc` 第一方域名；首轮业务接口请求 `app.saydian.cn` 返回 HTTP 200。
- 更新清单请求仍返回 HTTP 404，Say Ring 服务端更新发布继续未验收。
- `flutter_secure_storage` 检测到算法变化，成功完成 0 项迁移；模拟器当前显示登录页，未执行真实登录。
- 冷启动出现 233/79 帧跳过，软键盘动画也记录多次 jank；保留为性能检查项，不作为本轮启动失败。
- `camera_android_camerax` 与 `jpush_flutter_android` 仍有插件侧 Kotlin Gradle Plugin 未来兼容警告；当前 Debug 构建成功。

### 22:57 Android 16 前台检查脚本修正

- 旧检查只搜索 `dumpsys activity activities` 的 `mResumedActivity`，Android 16 输出未包含该行，随后直接调用 `.Trim()` 导致空值异常。
- App 进程、截图和后续日志检查仍正常，故该异常只影响诊断脚本。
- 改用 `dumpsys window windows` 检查焦点窗口，确认 `cn.saydian.ring/cc.saidian.saydian_app.MainActivity` 为当前输入和 IME 目标。
- 后续脚本必须先判断匹配结果是否为空，并按 Android 版本选用窗口焦点检查。

## 本轮未验收

- 未执行验证码、微信真实登录或账号切换。
- x86_64 模拟器不能验收 ARM 厂商 SDK、真实 BLE 扫描/连接、同步、测量和重连。
- 未执行极光真实通知、天气、支付或正式签名升级；对应密钥为空。
- 本轮只验收模拟器启动、x86_64 Debug 构建安装、Flutter 附加、登录页/键盘渲染及启动接口边界。
