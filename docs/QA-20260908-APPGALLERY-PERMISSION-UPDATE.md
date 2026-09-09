# 2026-09-08 Android 应用市场权限与在线更新整改记录

## 任务范围

- 整改应用市场审核指出的启动阶段提前申请精确位置权限问题。
- 整改应用首次运行、用户未主动使用设备功能时提前申请蓝牙权限问题。
- 修复服务端配置外部更新地址 `https://app.saydian.cn/down` 时，客户端提示“不在允许的安全域名内”的问题。
- 生成与此前市场候选包相同正式证书签名的 Android APK。

## Git 基线与提交

- 修改前远端跟踪基线：`c9c78f9e6e199bd2378234013f2e05dcfef8d428`。
- 权限整改提交：`be5430354a249c51b08d34617cecd181253887a4`。
- 在线更新整改提交：`6df1442a88b936ca3dee152b376d61530f54d16f`。
- 在线更新整改前已再次执行 `git fetch --prune`，但 GitHub HTTPS 连接超时；没有把未完成的网络同步写成“远端最新”。

## 问题与原因

### P1：启动阶段提前申请蓝牙/精确位置权限

自动恢复手表连接会在应用初始化时调用 Android 原生 `restoreConnection`。该方法此前与用户主动扫描共用权限申请路径：Android 12 及以上会弹出附近设备权限，Android 11 及以下会弹出精确位置权限。这与用户是否已同意隐私政策、是否主动进入设备连接流程无关。

### P1：服务端外部更新地址被客户端拦截

版本接口返回 `android_type=0`，表示由系统浏览器或应用市场打开外部页面；服务端地址为 `https://app.saydian.cn/down`。客户端此前对外部页面和 APK 二进制下载使用同一域名白名单，因此把合法的跨域外部页面误判为不可信地址。

## 修改内容

- 隐私政策未同意时，不启动手表连接恢复。
- 自动恢复连接只在相关权限已经授予、蓝牙已经开启时静默执行；自动流程不弹权限窗口，也不主动打开蓝牙。
- 用户主动点击“设备 → 开始查找”后，才走蓝牙/附近设备权限申请流程。
- Android 11 及以下仍保留 BLE 扫描所需定位权限声明，但只在用户主动扫描时申请。
- `android_type=0` 的外部更新页面允许使用服务端返回的有效 HTTPS 地址，并交给系统外部应用打开。
- `android_type=1` 的 APK 直接下载仍保留 HTTPS、下载域名、重定向和摘要校验，不因外部平台跳转放宽安装包安全门禁。
- 版本调整为 `0.1.20 (1002)`，与线上版本接口一致，避免新包装好后再次提示更新到自己。

## 验证结果

### 自动化

- `flutter analyze --no-pub`：通过，0 个问题。
- `flutter test --no-pub`：通过，534 项成功、0 失败。
- 在线更新专项：30 项成功，覆盖跨域 HTTPS 外部地址、HTTP 拒绝、跨域 APK 下载拒绝。
- Android 权限专项：覆盖隐私同意前不调用恢复、自动恢复不触发系统权限申请、主动扫描继续申请权限。

### 线上接口

- `GET https://app.saidian.cc/api/v1/site/version?v=25&platform=android`：返回 `version=1002`、`version_code=0.1.20`、`android_type=0`、目标地址 `https://app.saidian.cn/down`。
- 目标页面 `https://app.saidian.cn/down`：HTTP 200。
- 使用 `v=1002` 请求：返回 `data=null`，表示当前构建已经是最新版。

### 华为真机

- 设备：华为 JAD-AL00，Android 12 / API 31。
- 撤销附近设备和定位权限后冷启动并等待 10 秒：前台保持赛电 App，无系统权限窗口；蓝牙和定位权限均保持未授予。
- 主动进入“设备”并点击“开始查找”：此时才出现“是否允许 Saydian赛电 查找、连接附近设备”的系统弹窗。
- 允许附近设备权限后：蓝牙扫描/连接权限已授予，精确位置和粗略位置仍未授予。
- 本轮未清除账号、健康数据或应用数据。

## 正式 APK

- 文件：`artifacts/app-market-20260908/Saydian赛电-v0.1.20-build1002-AppGallery-20260908.apk`
- 包名：`cc.saidian.app`
- 应用名：`Saydian赛电`
- 版本：`0.1.20 (1002)`
- minSdk / targetSdk：26 / 36
- ABI：`armeabi-v7a`、`arm64-v8a`
- 文件大小：64,727,844 字节
- APK SHA-256：`3F29857F0EACDF6259C861BC7EE3135D644D4D4CC7A6076D4DBA8C7566810786`
- 签名证书：`CN=Saydian, OU=Mobile, O=Saydian, L=Shenzhen, ST=Guangdong, C=CN`
- 证书 SHA-256：`1a93741b4b28aa563927c3632b0da21609b892296e7aa201e7babe85129dda65`
- 与 2026-09-07 的上一份正式市场候选包证书一致：是。
- APK Signature Scheme v2：通过。
- Release 可调试标志：关闭。
- 16 KB ZIP 对齐检查：通过。
- 后台定位权限：未声明。
- `BLUETOOTH_SCAN`：声明 `neverForLocation`。

## 验收边界

- 真机权限时序使用同一权限整改源码的 Debug 包验证；最终正式签名包完成了编译、Manifest、签名、版本、ABI 与对齐静态验证，未为安装它而卸载当前 Debug 包或清除测试数据。
- 正式签名材料只在构建期间注入 Git 忽略路径，构建后已移出工作区；密码和私钥未提交 Git，也未写入本记录。
- GitHub 网络同步在本轮一度失败，最终提交推送状态应以任务结束前再次执行的 `git fetch/push` 结果为准。

## 审核依据

- 华为用户授权与隐私同意规范：`https://developer.huawei.com/consumer/cn/doc/doccenter-architecture/standard-privacy-user-consent`
- 华为应用隐私保护建议：`https://developer.huawei.com/consumer/cn/doc/doccenter-architecture/bpta-app-privacy-protection`
