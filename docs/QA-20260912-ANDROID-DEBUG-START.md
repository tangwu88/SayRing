# 2026-09-12 Android 真机 Debug 启动记录

## 范围与边界

- 基线：`main`、`origin/main` 与 merge-base 均为 `1023ce4fb257fb087f0f18bcb3e06462410e6305`，ahead/behind 为 `0/0`，启动前工作树干净。
- 目标：在已授权华为 Android 10 真机上，以国际版正式第一方域名配置启动 Flutter Debug，并保留登录、健康记录和手表绑定。
- 本轮不修改业务源码，不清 App 数据，不更改手表联系人、表盘、闹钟、通知、提醒、屏幕、健康设置或 OTA。

## 命令与结果

| 操作 | 结果 | 结论 |
| --- | --- | --- |
| `git status --short --branch`、`git fetch origin --prune --tags`、HEAD/merge-base/ahead-behind 核对 | 本地与远端一致，工作树干净 | 修改前更新门禁通过 |
| `adb devices`、设备系统及已安装包检查 | 1 台已授权设备，0 台未授权/离线；Android 10，已装 `0.1.21+1004` | 可安全覆盖安装并保留数据 |
| `flutter run --debug --no-pub`，显式注入 `SAYDIAN_API_BASE_URL=https://app.saydian.cn` 及国际更新清单路径 | Debug 构建成功并安装；Dart VM Service 与 DevTools 已启动 | 真机调试会话建立 |
| 华为安装器两步确认 | 只点击“继续安装”，未授予联系人或通话等额外权限 | 覆盖安装完成，既有数据保留 |
| 前台、登录与设备页检查 | App 进程及前台 Activity 正常，未回到登录页；设备页显示同步和断开入口，无连接失败或扫描入口 | 登录会话保留，手表自动恢复连接 |
| 当前进程日志聚合 | 0 个 fatal、0 个 ANR、0 条 `E/flutter` | 当前启动与连接链路无崩溃证据 |
| 网络日志核对 | 第一方 API 请求只到 `app.saydian.cn` 并返回 200；另有已允许的 HBand 官方表盘服务 `www.vphband.com` | 本轮未发现旧赛电第一方域名回退 |

## 观察到的非阻断项

1. 国际更新清单 `/global/api/saydian-app/v2/support/app-update` 仍返回 404；这是既有的“国际安装包清单尚未发布”状态，App 继续可用，不允许回退国内清单。
2. 闭源 HBand 扫描组件仍会在 Debug 控制台输出原始扫描字段。当前终端显示已清理；优化 Release 已由 R8 和 DEX 审计确认移除相关输出。若要求 Debug 也完全静默，需要合作方提供修正版 SDK，不能伪装成源码已修复。
3. Flutter 提示 `camera_android_camerax` 与 `jpush_flutter_android` 未来需迁移 Built-in Kotlin，并有 Android SDK XML 工具版本提示；本次构建成功，依赖升级应单独执行回归。
4. 启动阶段系统记录过跳帧提示；本轮仅建立调试会话，尚未进行可重复的启动性能采样，不能据单次日志判定性能缺陷。

## 最终现场状态

- Flutter Debug 会话保持运行，App 位于设备页，账号保持登录，手表保持已连接。
- 未执行设备写入、健康测量、账号变更或业务提交。
- 本文件及长期索引提交 Git；临时 UI XML、日志和设备标识不进入仓库。
