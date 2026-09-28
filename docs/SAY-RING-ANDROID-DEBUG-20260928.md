# Say Ring Android 真机 Debug 启动记录（2026-09-28）

## 目标与范围

- 目标：在华为 PPA-LX3 上重新启动最新 `main` 的 Say Ring Flutter Debug。
- 基线：`cc79aeb9e42950320e8f5f73928a26c6cec3f7f1`，启动前与 `origin/main` 一致，工作树干净。
- 设备：HUAWEI PPA-LX3，Android 10（API 29），ADB 序列号 `2KTYD21714200059`。
- 包名：`cn.saydian.ring`；版本：`0.1.21+1004`。
- 本轮未修改业务源码、接口协议、账号、健康数据或设备绑定。

## 执行与结果

### 10:04 环境与会话检查

- 手机 ADB 状态为 `device`；本轮只有该华为真机在线。
- 昨日 App 进程与 Flutter 调试进程均已结束，因此没有启动重复会话。
- `git fetch origin --prune --tags` 后本地与远端差异为 `0 0`，无需合并。

### 10:05 Debug 构建、安装与附加

- 命令：

  ```powershell
  D:\Dev\Flutter\3.44.9\bin\flutter.bat run --debug --no-pub `
    -d 2KTYD21714200059 `
    --dart-define=SAYDIAN_API_BASE_URL=https://app.saydian.cn `
    --dart-define=SAYDIAN_UPDATE_MANIFEST_URL=https://app.saydian.cn/global/api/saydian-app/v2/support/app-update `
    --dart-define=JPUSH_APP_KEY= `
    --dart-define=QWEATHER_API_KEY=
  ```

- `assembleDebug` 在约 22 秒内成功；华为两阶段安装确认后覆盖安装成功。
- Flutter VM Service 与 DevTools 已附加；App 前台 Activity 为 `cc.saidian.saydian_app.MainActivity`，进程号为 `15148`。
- 当前页面为手机号/邮箱验证码登录页；只能确认本机当前没有恢复出有效登录会话，未执行登录，不能据此判断服务端账号异常或数据丢失。

### 10:06 安装确认坐标脚本失败与修正

- 首次解析按钮边界后直接相加字符串，错误生成坐标 `270998,10431090`；坐标位于屏幕外，没有触发任何按钮或其他手机操作。
- 修正为先把四个边界值转换为整数再计算中心点，正确确认第一阶段 `768,2132`；第二阶段按实际界面确认 `783,2141`。
- 后续自动化必须先输出原始边界与最终坐标，并验证坐标处于设备屏幕范围内后再点击。

### 10:08 启动日志与页面检查

- 当前 App 进程未出现 `FATAL EXCEPTION`、`AndroidRuntime`、ANR 或 Dart 未处理异常标记。
- 首轮业务接口请求访问 `app.saydian.cn` 并返回 HTTP 200；当前进程日志未发现旧 `saidian.cc` / `saydian.cc` 第一方域名。
- 更新清单请求仍返回 HTTP 404，服务端 Say Ring 更新发布仍未验收。
- `flutter_secure_storage` 检测到算法变化并执行迁移，日志显示解密到 0 项、迁移完成；未清除 App 数据，但不能据此证明旧会话原本存在或应该恢复。
- 冷启动出现 322/132 帧跳过；该性能问题继续保留，不作为本轮启动失败。
- `camera_android_camerax` 与 `jpush_flutter_android` 的插件侧 Kotlin Gradle Plugin 兼容警告仍存在；当前构建成功。

## 本轮未验收

- 未执行验证码、微信真实登录或账号切换。
- 未执行戒指扫描、连接、同步、测量、断开及三轮重连。
- 未执行极光真实通知、天气、支付或正式签名升级；对应密钥为空。
- 本轮仅验收 Debug 构建、覆盖安装、Flutter 附加、登录页渲染和启动日志边界。
