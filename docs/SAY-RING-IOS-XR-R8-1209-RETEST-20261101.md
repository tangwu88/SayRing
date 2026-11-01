# 最新集成代码 1209 在 iPhone XR / R8 复测

时间：2026-11-01（Asia/Shanghai）。开始时本地 `codex/fix-client-audit-20261031` 与远端同为 `74b868a0ffc7521bc4e991a7158804d594a0c07e`，工作树干净。`git fetch --prune origin` 后确认最新集成分支 `b76f57ebf1b9a862e94b59e6dc6dd97e921bb3d2` 是它的后代，包含此前 R8 巡检及新增 20 个提交；用 `git switch -c codex/integrate-latest-20261031 --track origin/codex/integrate-latest-20261031` 切到本地跟踪分支，`git pull --ff-only` 显示已是最新。原分支、主线及远端历史未改写。本轮产品代码没有变更。

## 手机和构建

- 仅 iPhone XR 在线，15 Pro Max 不在线。XR 原装 `cn.saydian.ring` 1.0.8（1201），本轮使用同一账号记住的原 R8。测试前用 `devicectl device copy from --domain-type appDataContainer --domain-identifier cn.saydian.ring --source .` 私有备份；未卸载、退出账号、解绑或重置戒指。
- 首次备份命令收尾误用 zsh 只读变量 `status`，外层返回 1；随后核对 `backup.log` 为 `File received from Device`、私有容器约 13 MB，备份实际已收到。后续脚本改用 `result_code`。旧编译缓存删除请求被自动审批拒绝，实际未删除任何文件；本轮 Debug 构建直接在可用空间中成功。
- 三份 QA Profile 与独立普通 `lib/main.dart` Profile 均明确 `--build-name=1.0.8 --build-number=1209`，经 Xcode 串行构建；验签、`cn.saydian.ring`、团队 `W7SXQ4A226` 和不同 `FLUTTER_TARGET` 均核对。真机统一使用 `tool/drive_ios_preserving_data.mjs --profile --use-application-binary=<验签IPA>`，包装器强制保留 App、不运行默认卸载清理。

## 实物结果

1. `integration_test/ios_read_only_page_walkthrough_test.dart` 使用 `SAYRING_QA_CONNECT_ANY=true`、`SAYRING_QA_RING_NAME=R8`、`SAYRING_QA_EXACT_REMEMBERED_RING=true`、`SAYRING_QA_EXTENDED=true`，**2/2 通过**。实际 SDK 能力 ready，名称及已记住的精确目标相符，账号归属不变，电量已读，同步结束。启动时已自动连上，`connectionAttempts=[]`；本轮没有新的手动首次连接耗时样本。
2. 主巡检进入 27 个当前可用页面/流程，包含健康与各指标详情、睡眠、活动、消息、设备、监测、查找、手势、相机、个人资料与设置。`integration_test/ios_xr_secondary_pages_test.dart` **3/3 通过**，进入活动目标、步数/距离/热量日周月、睡眠日期、百科文章及特大字号、设备/搜索帮助、邮箱密码和验证码入口等 11 个页面/流程；资料接口为 200。结束时原账号/目标未变、R8 仍连接、电量已读、同步空闲。合计 **38 个当前可进入页面/流程通过**。
3. `integration_test/ios_qring_reconnect_test.dart` **2/2 通过**：同一绑定上三轮通过设备页主动断开、点击重连；每轮都获得新 SDK 握手和电量确认，目标与账号不变，等待同步结束。这是受控软件断开，不替代近距离自然断连、锁屏或系统回收恢复。
4. 私有截图抽查：设备页显示 R8 已连接，手势页读到“短视频”模式，相机页显示遥控就绪与预览，睡眠日期页显示正常空状态。设备页截图时同步仍在进行，后续状态确认结束。没有实际用戒指动作触发快门；无新活动或睡眠样本可核对完整性、数值准确性。能力/公开配置关闭的入口没有强行开启。

## 恢复、回归与边界

- 测后用 `devicectl device install app` 原位覆盖普通 `lib/main.dart` Profile 并启动，系统回读 1.0.8（1209）。测试前 `Documents` 的 52 个文件全部保留，缺失 0，非巡检文件内容变化 0；测试证据文件按预期更新。普通首页可打开，目前显示今日活动/睡眠为空，不把空状态算作新样本同步通过。
- `flutter analyze --no-pub` 零问题；`TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact` 与 `TZ=Asia/Shanghai ...` 各 **1737/1737 通过**。iOS Profile QA/普通入口和 iOS Debug 均构建成功；Debug 未独立运行来冒充调试稳定性。Android 构建/安装按当前先测苹果的范围未执行；未上传 TestFlight、未改下载页或服务器。
- 仍待实测：R8 近距离自然断连后恢复、锁屏/系统回收、真实新活动与睡眠样本、戒指实体相机/手势效果及未开放能力。本轮三轮主动重连不能关闭这些待验项。

## 可复核命令与私有证据

- iOS 每个入口先执行 `flutter build ios --config-only --profile --no-pub --build-name=1.0.8 --build-number=1209 --target=<对应入口>`，再执行 `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Profile -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/ios-xr-r8-1209-20261101/DerivedData IPHONEOS_DEPLOYMENT_TARGET=15.0 SAIDIAN_DEVELOPMENT_TEAM=W7SXQ4A226 build`；Debug 用同一命令的 Debug 配置。驱动以精确 XR 设备 ID、`--driver=test_driver/integration_test.dart` 和各自验签 IPA 执行。
- 完整设备标识、账号/健康资料、截图、日志及容器备份保存在 Git 外 `~/Library/Application Support/SayRing/device-backups/xr-r8-latest-1209-20261101.9L9Avi`；仓库只提交去标识记录。
