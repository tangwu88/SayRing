# 2026-09-03 个人资料与 W9 同步断连修复记录

## 范围与 Git 基线

- 问题 1（P1）：个人资料页进入时字段可能为空，点击保存无法形成可靠闭环。
- 问题 2（P1）：W9/W9S 已连接后执行健康数据同步，页面可能被一次断连回调切换为“未连接”。
- 修改前分支为 `main`，HEAD 为 `c5d8cd5be9f61bf3a31ba48236fc74e431e9bc71`，本地相对 `origin/main` 为 ahead 1。
- 修改前已执行 `git status --short --branch`、`git remote -v` 和两次 `git fetch --prune origin`；GitHub 连接分别返回空响应和连接重置，因此本轮只能以本地 `c5d8cd5` 作为离线基线，不能声称已同步到远端最新提交。
- 用户已有未跟踪目录 `docs/legal/` 全程保留，未修改、未删除、未纳入本次提交。

## 根因与修复

### 个人资料

- 服务端契约本身可用：授权测试账号的 `GET /api/v1/member/member/my` 与 `POST /api/v1/member/member/save` 均返回成功。
- 页面旧实现只在 `initState` 中读取一次控制器缓存。当个人中心导航先完成、资料接口稍后返回时，输入框会一直保持初始空值；用户随后保存的不是服务端完整资料。
- 个人资料页现在进入后主动刷新服务端资料，在用户尚未开始编辑时再写入昵称、性别、生日、身高、体重和头像。
- 读取期间禁用输入与保存按钮，并显示明确加载状态；读取失败保留错误提示和“重新读取”入口，不用空表单伪装成功。
- 新增组件测试，覆盖“控制器初始资料为空、接口稍后返回、字段回填后可保存”的真实时序。

### W9/W9S 同步后断连

- Veepoo 的底层连接监听可能在 GATT 刷新期间短暂发送 `STATUS_DISCONNECTED`。旧实现收到首个回调就立即取消同步、清空设备和向 Flutter 上报断开，因而一次瞬态回调会直接把已连接页面切成未连接。
- 原生桥接增加 2.5 秒断连确认窗口，并把候选回调绑定到当前设备地址和连接 generation。窗口内恢复连接时取消候选；到期后仍由 SDK 确认未连接才执行原有清理流程。
- Flutter 层同时校验断连事件的 `deviceId`，旧手表的延迟回调不会清空已经建立的新手表会话。
- 真实物理断连仍会在确认后进入未连接状态，没有长期伪装连接。

## 修改文件

- `lib/ui/pages.dart`
- `lib/services/app_controller.dart`
- `android/app/src/main/kotlin/cc/saidian/saydian_app/MainActivity.kt`
- `android/app/src/main/kotlin/cc/saidian/saydian_app/VeepooBatteryReadGate.kt`
- `android/app/src/test/kotlin/cc/saidian/saydian_app/VeepooBatteryReadGateTest.kt`
- `test/login_page_test.dart`
- `test/qa_user_flows_test.dart`
- 本记录

## 自动化与构建结果

- `dart analyze lib test`：通过，`No issues found`。
- `flutter test --no-pub`：374/374 通过。
- Android 主应用原生单测 `:app:testDebugUnitTest`：通过。
- 根工程 `testDebugUnitTest --offline` 会额外执行 `camera_android_camerax` 插件自身单测；本机未缓存该插件的 JUnit/Mockito/Robolectric 依赖，因此该聚合任务被离线依赖阻断。主应用模块定向执行后成功，不能把插件依赖缺失记录为业务代码失败。
- Windows 中文工程路径会使 `jni 1.0.2` 的 CMake/Ninja 把输出路径显示为乱码并误判 `libdartjni.so` 不存在；使用临时 ASCII `S:` 映射、停止旧 Gradle daemon 后构建成功，映射已自动取消，源码目录未改名。

## Android 真机结果

- 设备：华为 JAD-AL00，序列号 `L2E0222510006851`。
- 正式包 `cc.saidian.app` 使用不同签名，Android 安全拒绝测试签名覆盖，正式包及其数据未被卸载或清除。
- 使用仅构建期间添加、随后已完整撤销的 `.qa` applicationId 后缀生成并存包；临时包名改动未留在源码差异中。
- QA APK：`E:\saydian\qa-builds\saidian-profile-w9-fix-qa-20260903.apk`
  - 包名：`cc.saidian.app.qa`
  - 版本：`0.1.19 (23)`
  - 大小：153,767,618 字节
  - SHA-256：`7D62A9A20F1E1E4440D13CDA3541079C8574018066DCA8A9E833F1310859884F`
- QA 包覆盖安装成功。旧环境会话首次读取资料返回凭据无效；通过正常退出并重新登录授权测试账号后，资料页完整回填昵称、性别、生日、身高和体重。点击“保存资料”成功返回账号设置页，未出现接口错误或崩溃。
- 停止旧正式包释放蓝牙后，QA 包自动恢复 W9S：`SD-Watch-W9S`，电量 81%，页面显示“已连接”。多次点击“同步数据”后仍保持已连接；20 秒后再次检查仍为已连接。
- Android `bluetooth_manager` 同时确认 `cc.saidian.app.qa` 已注册 GATT client，并保持到测试 W9S 地址的连接；本轮日志未发现本应用 `FATAL EXCEPTION` 或 Flutter 未处理异常。

## 验收边界与后续注意

- 本轮已验证“资料加载并保存”和“同步操作后不再被瞬态回调切为未连接”。没有通过伪造断连来替代真实物理拔远/关闭蓝牙测试；真实断连清理另有原生单测和既有连接流程保障。
- 对外更新正式包仍需要与手机现有 `cc.saidian.app` 一致的正式签名密钥。当前 QA 包只用于真机联调，不得作为生产发布包。
- 后续若再出现同步断连，优先保留 `SaidianVeepoo` 日志中的 `Waiting to confirm disconnect`、`Ignored transient disconnect` 或 `Confirmed disconnect`，并同时记录系统 GATT 状态，避免只依据页面文字判断链路。
