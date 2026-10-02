# Say Ring 每次连接上报（2026-10-02）

## 基线与范围

- 用户要求设备每次连接记录及相关信息按 Health App 上报服务端。本轮只改 Say Ring；不修改截图中的其他会员或手表，不触碰 Health App 工作树、国内接口、App Store 审核记录。
- 基线 `73971a291dc8085b6c49bedd531a4786e849f7db`。修改前 `git status --short` 仅有本任务的巡检脚本和文档改动；`git remote -v` 为 SayRing，`git fetch origin` 成功且远端当前分支不变，未在脏工作树拉取。按用户最新要求不检查或改变 GitHub 仓库可见性。
- 对照 `/Users/mycodex/电商/saydian-app-global-appstore-20261001` 的设备上报接口与控制器，以及服务端法律隔离工作树中的 `DevicesService.bind`。参考源码只读。后者已有绑定 upsert 与 `DeviceConnectionEvent.create` 同一事务，时间由服务器生成；本次不新增或猜测服务端协议。

## 缺陷与实现

- P1：Say Ring 首次成功握手和原生自动恢复后均未调用设备上报；Health App 已调用。预期每次真实连接触发一次，上报不应等历史同步完成。
- 新增 `SaydianDeviceBindingApi` 与全球客户端实现，沿用 `POST /global/api/saydian-app/v2/devices`，发送设备 ID、真实名称、SDK 厂商、实报型号/固件、可用硬件 MAC 与能力清单。未知型号使用真实设备名而非猜测，未知 MAC 省略；不上传健康数值、照片、联系人或账号凭据。
- `DeviceInfo.verifiedHardwareMacAddress` 只验证 SDK 的 `hardwareAddress`，不采用用于展示的 native ID 回退，也不从任意字符串过滤出 MAC。iOS 外设 UUID 绝不当 MAC。
- `AppController` 的显式握手与原生恢复各在 ready 边界触发一次；重复恢复回调被既有状态机拦截，能力/设备详情刷新不另记连接。仅当前登录账号、当前会话和当前设备可提交；匿名本机/演示模式不上传。
- 本地接口额外接受捕获的 `expectedSession`，不改变 HTTP 字段。发送和 401 刷新重试均检查真实请求账号；换号/退出后不把旧握手归到新账号。
- 网络失败处理与 Health App 一致，为 best effort，不破坏已成功的 BLE 连接、不弹出误导的连接失败或记录敏感原始数据。**没有离线持久上报队列，断网失败不能声称服务端已留存每一条**；本轮不假造成功或补发时间。

## 测试轮次

- 首轮新测试因 const 表达式不能读取 `DeviceInfo.id` 编译失败；去掉该事件的 const 后重跑。真正 RED：两个控制器用例报告数为 0，两个 API 用例缺方法；匿名/失败握手不报的负例原本已通过。日志 `.build/sayring-device-report-red.log`。
- 实现后初始定向集合 53/53 通过，随后补充迟到能力回调账号注销栅栏和硬件 MAC 来源用例，集合为 55/55。再补 401 重试测试时，首版测试因夹具未提供 refreshToken 而收到预期的原始 401；加入测试刷新令牌后，设备与全局 API 定向集合 39/39 通过。日志 `.build/sayring-device-report-refresh-tests-final.log`。
- 加入退出登录期间迟到能力响应用例，第一版夹具先 await logout，再释放 connect 所等的能力响应，导致测试自己互等；保留日志并中断此轮以及当时开始的完整回归。修正为先启动 logout、释放能力响应，再等待两者完成，未改变生产退出逻辑。
- Analyzer 首轮有一条花括号 info；补齐后重跑。一次 apply_patch 因格式化后的上下文不匹配未执行，读取文件后重新应用，未覆盖别人的文件。
- 最新完整 Flutter 回归含连接/自动恢复、匿名隔离、账号迟到回调与 API 401 测试：`TZ=UTC flutter test --no-pub --concurrency=1 --reporter compact` 与 `TZ=Asia/Shanghai flutter test --no-pub --concurrency=1 --reporter compact` 各 1043/1043 通过。最终日志分别为 `.build/sayring-device-report-full-utc-final.log`、`.build/sayring-device-report-full-shanghai-final.log`。之前上海回归那轮因 401 测试夹具不含 refresh token 而中断，保留 `.build/sayring-device-report-full-shanghai.log`；修正夹具后两时区最终全量均通过。
- 最终定向验证：`flutter test --no-pub test/device_connection_reporting_test.dart test/global_api_test.dart --reporter compact` 39/39 通过；`flutter analyze --no-pub` 零问题；`dart format --output=none --set-exit-if-changed` 无改动；`python3 scripts/release/test_release_gate.py` 通过（最终日志 `.build/sayring-device-report-release-gate-final.log`）；`git diff --check` 通过。
- Profile 1021 串行构建成功：`build/ios-profile-1021-derived-data/Build/Products/Profile-iphoneos/Runner.app`。签名 `codesign --verify --deep --strict` 通过，Team ID `W7SXQ4A226`，Bundle ID `cn.saydian.ring`、Build `1021`、`UIDeviceFamily=[1]`、`get-task-allow=true`。插件仍有预存模块缓存和三方弃用警告。
- iPhone 15 Pro Max 覆盖安装和独立启动均成功，`devicectl` 回读 Say Ring `1.0 (1021)`。保留了旧安装路径，没有卸载；这轮没有用账号重登或清空数据。
- RunnerTests 真机 XCTest 分别先因 RunnerTests target 缺少 signing team 失败；加上 `DEVELOPMENT_TEAM=W7SXQ4A226 CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY='Apple Development'` 后，测试 runner 在建立 XCTest 连接前以 SIGSEGV early exit。日志 `.build/sayring-1021-ios-native-tests.log` 与 `.build/sayring-1021-ios-native-tests-signed.log`；因此原生 XCTest **未通过/未执行完**，不影响 Profile 实际签名安装启动，但不能报为原生测试通过。

## 真实验收边界

- 新功能尚需在有效登录账号下连接真实 R21，并从后台回读新增事件、型号、名称及实报信息；不能用图中的 Health 会员记录作为 Say Ring 验收。
- 线上 Say Ring 账号能力此前 `consentVersion/legal` 为空，登录真实联调受专属协议阻断。已将连接标识及记录用途通知用户已授权的服务端政策任务；不绕过同意门禁，不把草案写成发布。
- iPhone 页面巡检的真实本机模式可连接与读取本机数据，但本机模式本来就不上传，不能用它证明后台写入成功。三轮真实距离重连、头像登录回读和缺少的小睡样本继续待验。
- Android/Harmony 按用户当前优先级后置。App Store Connect 网页登录失效；本次不替换现有审核包，不声称上架成功。
