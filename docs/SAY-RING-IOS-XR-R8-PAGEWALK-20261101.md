# iPhone XR / R8 重新连接与逐页检查（1.0.8 / 1201）

时间：2026-11-01（Asia/Shanghai）。分支 `codex/fix-client-audit-20261031`，本轮修改前提交 `6115305cf72a6916533be5f56fc8299d078bfc6a`。开始前工作树干净，已检查 `origin`、更新当前分支，并阅读项目交接、最近实施记录、问题复盘和回归清单。本轮不修改产品代码；只给只读真机巡检增加精确已记住戒指的保护，避免同型号戒指误配。

## 目标、数据保护和实物结果

- 在线设备为 iPhone XR；iPhone 15 Pro Max 不在线，安卓手机不在线。XR 已安装 `cn.saydian.ring` 1.0.8（1201），团队 `W7SXQ4A226`。测试前用 `devicectl` 将应用容器私有备份到 Git 外的 `~/Library/Application Support/SayRing/device-backups/xr-r8-pagewalk-20261101.qpINVd/before`；未卸载 App、解绑、清空戒指或重置账号。
- `integration_test/ios_read_only_page_walkthrough_test.dart` 增加 `SAYRING_QA_EXACT_REMEMBERED_RING=true` 检查：要求初始已记住的戒指名称符合本次 R8 请求，连接就绪和扫描后选择也必须保持同一精确设备标识。该开关只供巡检使用，不改变正式 App 的连接逻辑。
- 签名 Profile 巡检包通过 `tool/drive_ios_preserving_data.mjs --profile --keep-app-running` 原位运行。第一轮真实 SDK 显示 R8 已连接、能力就绪、电量已读；启动时应用已自动连上，因此本轮 `connectionAttempts=0`，不能把它写成一次新的手动连接测速。后台同步完成，账号归属和目标未改变。第二轮结束时仍连接，电量已读，同步处于空闲。
- 测试结束，将同一 1.0.8（1201）普通 `lib/main.dart` 签名 Profile 包原位覆盖装回 XR 并启动。系统回读包名、版本、团队正确。再次备份比较应用 `Documents`：原有 49 个文件均在，缺失 0，非巡检文件内容变化 0；多出 3 个巡检文件。未清除本机历史或照片。普通包刚启动时首页先显示待连接提示，故最终普通包的持续连接和自然断连恢复仍须另行观察；本轮可确认的是巡检期间实际 SDK 连接。

## 页面与操作检查

1. 主巡检 `integration_test/ios_read_only_page_walkthrough_test.dart` 通过，进入 27 个页面/流程：真实连接、健康首页、心率/血氧/皮温/HRV/压力/睡眠详情、睡眠概览、全部健康数据、远程关爱、健康百科、运动总览、消息、设备、健康监测只读、查找戒指/手势/相机入口只读、我的、个人资料、单位、账号、权限、反馈、客服和关于。截图逐张在私有目录核对，未见明显布局溢出。账号资料接口返回 200，消息页加载后显示正常空状态。
2. 补充巡检 `integration_test/ios_xr_secondary_pages_test.dart` 通过，进入 11 个页面/流程：活动目标、步数/距离/热量日周月趋势、睡眠日期切换、百科文章详情及特大字号、关于设备、连接说明、添加设备搜索帮助、邮箱密码和验证码入口。百科字号测试后恢复原设置。合计 **38 个当前可进入的页面/流程**；这不是所有产品功能都已实物验收。
3. 相机入口起初显示“正在打开相机”。将相机预览并入账号巡检的实验性用例在等待预览时超时，该测试改动已撤回，失败留在私有日志。随后运行现有 `integration_test/ios_camera_lifecycle_acceptance_test.dart`，在设备上建立真实原生前台、切至时钟再返回，预览成功初始化，前后台恢复检查通过；未拍照、未保存照片，未验证戒指实体手势触发快门。
4. 当前 R8 的能力/产品配置隐藏了血压、血糖、心电、身体和血液成分详情、来电/消息/闹钟/健康提醒入口、健康档案及商城。巡检把这些记为门禁未开放，不当作页面缺失，也不伪造硬件支持。

## 失败、修正与回归

- 首次生成 iOS 巡检包时，未显式传版本号，产物为 `0.1.21(1006)`；安装前发现并弃用。重新以 `--build-name=1.0.8 --build-number=1201` 生成签名 Profile 包，核对 `cn.saydian.ring`、团队及代码签名后才在 XR 运行。
- 首次 iOS Debug 构建复用旧 DerivedData，`jpush_flutter` 缺 `JPUSHService.h`；单独重建 JPush/JCore 的生成中间产物后，旧缓存又报预编译模块 `.scan` 缺失。换独立、全新 DerivedData 串行重建，**iOS Debug 成功**。这是本机缓存异常，未改 Pod 或产品源代码；失败日志仍保留在本地构建目录。
- `dart format` 与 `flutter analyze --no-pub` 通过。`TZ=UTC flutter test --no-pub --concurrency=2 --reporter compact`、`TZ=Asia/Shanghai ...` 各 **1711/1711** 通过。Android Debug 与 `SAIDIAN_ALLOW_QA_RELEASE=true` 的内部 QA Release 均成功构建，未安装/发布。iOS Profile 真机包与 iOS Debug 均成功构建；Debug 未作为独立 App 启动来冒充调试稳定性。
- 主巡检 2/2、补充巡检 3/3、相机原生生命周期 2/2 全部通过。所有真机截图、设备标识、账号资料和容器备份只存 Git 外私有目录；仓库仅提交测试代码及去标识的记录。

## 未验收边界

- R8 本轮未制造自然断连、锁屏、系统回收或长时间静置；旧记录中的近距离自然断连后恢复失败仍是独立待验项。也未证明具体新活动/睡眠样本已完整同步、健康数值准确、戒指手势真实触发拍照、隐藏功能可用或任何发布状态。
- 本轮未产生用户可见功能修复，因此不升版本、不上传 TestFlight、不更改下载页。只提交巡检保护和可复核记录。
