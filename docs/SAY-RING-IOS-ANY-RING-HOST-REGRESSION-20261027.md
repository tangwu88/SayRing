# 2026-10-27 iOS任一戒指巡检准备与离线回归

## 范围、源码与设备阻断

用户要求连接任一戒指，检查连接、活动/睡眠同步和各界面，发现问题直接修复。开始时7e23496074da65173908960cff2ada7ffa3887e7工作区干净；fetch发现当前分支已有新提交，阅读最新付款/睡眠及鸿蒙记录后，ff-only同步到8f35be0（完整SHA见Git父提交），不覆盖其他工作。已读AGENTS、国际交接、复盘、回归清单和修改索引。

本轮实时devicectl检查：XR及15 Pro Max均unavailable，之前的Dart VM地址也已不可达。用户明确回复“暂时无法连接，先做代码和回归检查”，故仅继续离线源码/自动回归与构建。本轮未备份新容器、安装或操作手机，未扫描/选择戒指，没有把前一轮1145启动或旧R12数据算成本轮实物通过。

## 确认并修正的巡检脚本问题

仅修改integration_test/ios_read_only_page_walkthrough_test.dart，依据此前真实hit-test/惰性列表失败记录与当前设备页路由源码修正：

1. 健康监测使用稳定device-feature-health_monitoring键，在设备列表滚动居中并确认可命中后点击；确认实际打开PermissionManagementPage，再读取真实设置。避免点击未命中仍返回而退出App。
2. 资料页先滚动到profile-save再确认按钮存在，避免将屏外未构建的ListView子项当页面缺失。
3. 我的页面各入口滚动后居中、确认hitTestable再点击，保留原页面类型及tester异常断言，不用宽松跳过伪装成功。
4. 同步空闲等待上限从60秒扩大至200秒，覆盖iOS原生150秒读取期限；仍有界并要求真正空闲，不修改SDK超时/完整性状态。

未更改产品界面、数据映射、SDK、绑定/首次清空守卫或功能能力门禁。iOS原生被动活动/历史投递已有精确连接和租约检查；未来日期拒绝、分段完整性及未知热量单位保护保留。新付款入口仍明确限制Android，不在iOS放开购买。没有依据无法实测的戒指状态猜测数据、调整日期或把静默当同步完成。

一次只读rg的不存在通配路径被zsh拒绝，改为搜索实际lib目录；不是App失败。脚本定位修改已静态分析，普通App另做编译检查；尚未在本轮真实iPhone执行，不能表述为三处真机问题已经复测通过。

## 本轮实际回归

私有执行器build/ios-any-ring-regression-20261027/run_host.py，每步保存独立日志/退出码后顺序继续：

| 检查 | 本轮结果 |
| --- | --- |
| 离线锁文件pub get | 通过，0.9秒 |
| dart format门禁 | 通过，1.2秒 |
| flutter analyze --no-pub lib test integration_test | 零问题，3.7秒 |
| UTC全量Flutter测试 | 1504/1504，44.9秒 |
| Asia/Shanghai全量Flutter测试 | 1504/1504，43.4秒 |
| Node协议/工具测试 | 141项，140通过、1个Windows专用跳过，零失败 |
| Harmony协议/模型测试 | 两时区各525/525 |
| Python发布工具测试 | 35/35，7.1秒 |
| Android Debug双ARM编译 | 通过，30.9秒 |
| Android内部QA Release双ARM编译 | 通过，74.6秒；不作为市场正式包 |
| Android原生JUnit | 62项零失败/错误/跳过，7.7秒 |

构建检查内部标记1.0.6（1151），并非公开发行或已安装版本。没有操作在线的安卓手机。原始命令、产物和日志仅在忽略目录保留。

## iOS编译与签名结果

主机矩阵完成后，独立串行执行build/ios-any-ring-regression-20261027/build_ios.py：正常lib/main.dart、无测试注入入口；显式build-name=1.0.6/build-number=1151、第一方API、原iOS功能门禁与本机开发配置。Flutter config-only后由xcodebuild使用W7SXQ4A226/Apple Development签名，不经过发行导出或商店上传。

- Debug配置26.3秒、开发签名12.0秒，均退出0。
- Profile配置24.0秒、开发签名25.8秒，均退出0。
- 两个App分别codesign --verify --deep --strict通过；Info.plist均为cn.saydian.ring/1.0.6/1151，签名团队均W7SXQ4A226。普通Profile保留在私有ios/normal-profile-1151.app，供恢复实物连接后使用；不是已经安装或测试过的App。
- Debug App.framework SHA256 ea20fd6ab2983bae5f53923c2ddb11d8ecdc98503074517cac75abca6b0f0c55；Profile SHA256 65d05315b2a5dffa8d849274ce495cde6ab2c77bce1c96d9b751a266e2145fe5。完整签名回执存ios-signature-checks.json。
- 现有插件迁移/模拟器架构和Java弃用提示保留，未为了消除提示改依赖。最终git diff --check通过。所有构建实际成功，没有回退旧包；没有执行任何手机安装。

新增/修改仅本记录、索引及巡检脚本，既有失败和待验结果均保留。抓取远端前已将未提交差异和新记录完整备份在私有目录；不丢弃其他工作。

## 待实物恢复后的验收

重新检测并备份实际iPhone容器，使用新鲜签名Profile及tool/drive_ios_preserving_data.mjs、显式预编译二进制和keep-app-running，结束后恢复同源正常main。保持真实账号及能力门禁，只对明确选择且实际握手的戒指检查：两轮同步、原始活动/睡眠时间与来源、去重/时间轴、设置读回、断连恢复和页面结果。无睡眠佩戴信息时不推断整夜准确性；需要用户动作的来电/消息/走步另行确认，不发真实付款或验证码。

当前未执行：本轮任一戒指连接、活动与睡眠实物同步、页面真机巡检及提醒触发。既有R7 Pro/R7 Ultra同步、运动缺失值/热量单位、R21未来睡眠日期与相机专项待验结论不因本轮主机测试通过而关闭。不上传TestFlight、不改公开下载或后台，不提升main。
