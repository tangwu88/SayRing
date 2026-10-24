# 2026-10-24 XR R7 Pro 1141专项验收与归档

## 任务、基线与验收条件

用户要求XR已连接R7 Pro后，测试连接、活动和睡眠同步，没问题才上传最新版TestFlight并提交苹果审核。用户另确认最近没有佩戴此戒指入睡，因此无样本时只验真实无数据终态和界面，不补造睡眠。

开始时HEAD e2cfc10c6050edd169c0ded7cae93b4d70d44af0，工作树干净；status/remote、fetch origin --prune和pull --ff-only成功（Already up to date）。已复核AGENTS、国际交接、回归约束及1140/1141实施记录。生产业务源码、依赖、权限、服务器及初始化策略本轮均不修改；新增独立实物脚本及验证记录，不将失败候选推广main。

## 脚本和宿主证据

新增integration_test/ios_xr_r7pro_release_acceptance_test.dart：只使用当前owner最后成功握手的确切R7 Pro/HR05目标，不按名称挑选其他设备；核对真实能力握手、等待初始同步、完整手动同步回执、实际活动记录及睡眠/日期导航。报告仅协议状态/计数，健康payload在App私有Documents，后备份取回但不入Git；不卸载、不切账号、不解绑、不重置或重做首次清理。

首次全项目analyze发现新脚本单个if缺大括号，退出1（14.5秒）；补大括号、重新format后analyze零问题（12.9秒）。测试Profile配置/开发签名编译成功，并经strict/deep codesign、包名1.0.6(1141)/团队W7SXQ4A226/XR provision/get-task-allow校验；测试App.framework SHA256 d77e85131a42e1d2e980311bf2ea14f153413e76a364fe7db46e504207bac699。生产普通Profile未变，SHA256仍为9f4a2cec6832c4545814d921ea9798f1d5dfd799c94f0a44990afefa718466cc。

本轮读回e2cfc10对应远端CI [40100800632](https://github.com/tangwu88/SayRing/actions/runs/40100800632) 为completed/success；此前该相同生产源码已完成两时区各1470项、跨端编译和1141帮助/历史热量实物验收。本轮没有业务源码变化，不将旧全量重新描述为新执行，也不以CI替代本次连接/同步实测。

## 真实失败与现场

XR经devicectl检测在线、配对、passcodeRequired=false。先私有备份本App容器，显式打开本App；初次截图黑色，启动等待后首页可见，不能单凭launch退出0就声称页面正常。

经tool/drive_ios_preserving_data.mjs、明确已验签Profile与keep-app-running运行：driver100.6秒退出1。实物检查连接等待约62.7秒；exactTargetReady=false，ownerUnchanged=true，targetUnchanged=true。扫描发现5台设备，savedTargetAdvertised=false、scanIssue=null；没有原绑定目标握手，未进入活动或睡眠同步，不能把此前旧数据/扫描中的其他戒指当作通过。

测试期间原生截图同时看到iOS的“Some iCloud Data Isn’t Syncing”系统弹窗遮挡App。已请求用户点Not Now并保持App前台；用户明确回复“现在无法操作XR”。本轮不替用户修改iCloud、密码或健康同步设置，也不把此系统提示断言为原目标握手失败的唯一原因。当前缺少原目标现场与可操作UI两个条件，完整验收不通过。

失败后仍完成：私有后备份0.8秒、原位恢复普通1141 5.6秒、启动0.2秒，均exit 0；原账号/绑定不变。不能在系统弹窗仍可能遮挡时声称恢复后页面交互再次通过。原始日志、截图、元数据、容器和App仅留build/ios-1141-r7pro-20261024及build/ios-1141-20261024/device-r7pro-round1私有目录，均不提交Git。

## 归档与Apple状态

独立准备生产lib/main.dart的Release开发签名归档（不是测试入口）：配置20.5秒、archive43.4秒，exit 0。核验strict/deep签名、cn.saydian.ring、1.0.6(1141)、W7SXQ4A226和application-identifier；Release App.framework SHA256 07a0d2dca8148b040b92fd62be8ef01c3ed120022003620adb29ae5b8c8c68c0。

归档为build/ios-1141-r7pro-20261024/SayRing-1.0.6-1141-Development.xcarchive，外层Name明确DEVICE ACCEPTANCE PENDING。get-task-allow=true，属于开发签名归档，未导出App Store分发IPA、未打开Organizer诱导提前上传，未重复此前已知No Accounts导出失败流程。

通过现有Chrome会话只读核对正确Say Ring（6816549943）：1.0.6仍准备提交，当前可见TestFlight列表最高为1.0.5(1130)，本轮没有上传1141。原审核资料仍为1135草稿，需在实际送审时按双渠道密码/验证码、最新搜索帮助和单位保护更新；审核登录字段未打印或改动。没有选择构建、通知测试员、提交审核、接受协议或改变销售地区。

## 继续条件

用户能操作XR时先关闭iCloud弹窗，在Say Ring设备页确认原R7 Pro/HR05已连接并保持前台，再执行同一确切目标专项测试。需要真实握手、活动有效样本或真实无数据终态、睡眠完整回执/诚实空态；通过后才导出/上传、等待苹果处理、更新TestFlight、替换审核构建并正式提交。新源码若变化，须重新构建和验证，不能复用陈旧归档。失败和用户暂不能操作的事实均保留，不推main或宣布已发布。
