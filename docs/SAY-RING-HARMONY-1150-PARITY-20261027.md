# 2026-10-27 鸿蒙同步安卓本轮修改与1150正式签名包

## 范围和基线

- 用户要求鸿蒙根据本轮安卓调整、打包可用于上架的正式版并推送Git。基线`702fea8cac451d598121092c44aec2e0cd55cf91`，当前开发分支`codex/login-camera-r7ultra-1136-20261024`，工作树起始干净；已读AGENTS、交接、复盘、回归清单及1132鸿蒙对齐记录。
- status/remote已核对；GitHub专用SSH443重新fetch和ls-remote均被`Permission denied (publickey)`拒绝，不能声称已与远端最新同步。已异步请用户完成其已打开的SayRing Deploy key写授权，同时继续本地实现和打包，不覆盖远端或其他项目。
- 本轮只同步安卓1149涉及的可实现业务：国际版订单查看、客户睡眠说明。相机保留原逻辑，没有带入1147/1148诊断拦截。Android/iOS运行源码、后端配置、维护状态、下载发布均不改；不发验证码、付款、重置或清空数据。

## 问题、实现和边界

- P1：鸿蒙“我的订单”仍调旧数字ID/V1接口，生产国际传输拒绝。新增`RingOrderPresentation.ts`保留UUID、服务端最小金额单位/币种/小数位、快照商品名、实际状态及付款资格；未知金额不补零、未知状态不当待付款，不按本地价格计算。新增AccountClient的V2只读订单方法，过滤参数与Android相同。
- `Index.ets`订单入口使用新列表与详情，提供分类、失败/空状态、刷新、返回；账号变化清空视图并拒绝旧响应。仅GET，保持旧整数ID接口隔离，不以改数字为UUID的方式兼容。
- P2：睡眠失败不直接显示异常对象，空记录和失败分别说明，增加日常睡眠记录说明。没有推测REM、评分、缺失时段或改变实际值。
- 版本更新为1.0.6(1150)，`AppScope/app.json5`与`AppUpdateService.ets`一致；保持bundle `cn.saydian.ring.hm`、原正式证书和包图标。
- 支付阻断已核实：后端`billing.service.ts`目前接受android/ios/h5/mini_program/web，不接受harmony；公开支付能力的environments也没有harmony。现有Alipay鸿蒙SDK存在不等于国际订单支付接口已支持该平台。保留`GLOBAL_PAYMENTS_ENABLED=false`，不伪报android、回退V1/H5或强开渠道；待支付订单提示可使用安卓版同账号付款。本轮不声称鸿蒙支付宝付款已实现。
- QRing/LuckRing仍无原生鸿蒙SDK，沿用用户此前“先对齐可实现部分”边界；编译与正式签名不能代替这些戒指连接、测量、相机遥控或手势实物验收。

## 验证、失败和修正

- 新增`tests/ring-order-parity.test.mjs`：7项通过，覆盖真实协调器的固定国际GET/认证路径、UUID/身份不匹配、未知/无效金额及跨币种小数位、状态/维护门禁、账号退出后的迟到响应、筛选契约与睡眠客户文案。
- 第一次辅助编辑使用WindowsApps的python别名失败且没有修改文件，改用精确apply_patch完成。
- 首轮鸿蒙全量525项：524通过、1失败；新订单横向筛选Scroll未顶对齐，被既有布局契约发现。补`.align(Alignment.Top)`，保留原断言，重跑两个时区各525/525、0失败/0跳过；UTC约4.3秒、Asia/Shanghai约4.7秒。原失败日志保留仓库外。
- CLT26.0.0.821/JDK17沿用原环境；ArkTS Debug `hvigorw --mode module -p product=default -p buildMode=debug assembleHap --no-daemon`通过，阶段74.4秒/Hvigor62.8秒；Release `--mode project -p product=default -p buildMode=release assembleApp --no-daemon`通过，阶段24.4秒/Hvigor22.7秒。SDK既有重复资源/弃用警告保留，未升级供应商包。不把node宿主测试写成ArkTS或真机通过。Android1149运行源码未改，沿用上一轮实际构建/分析/双时区1504项证据，不伪称本轮重跑iOS。
- 原正式P12/Profile先签HAP，以官方app_packing_tool和本次项目pack.info/pac.json打完整APP，再使用官方hap-sign-tool签外层；`scripts/release/Verify-SayRingHarmony.ps1 -ExpectedVersion 1.0.6 -ExpectedBuild 1150`通过，外APP/内部HAP均验签、release/app_gallery Profile、bundle/debug/版本身份及内HAP字节保留门禁通过。未签外层APP负向样本被signature not found明确拒绝，避免再次交付未签外层导致991。受保护密码/密钥未打印或入Git。
- `hdc list targets`为`[Empty]`，无原生鸿蒙手机，不声称完成页面、戒指或付款真机验收，也没有上传AGC获取991/审核受理回执。
- 正式签名包冻结在仓库外`E:\SayRing-market-artifacts-20261027\harmony-1150\delivery`：市场APP `SayRing-HarmonyOS-1.0.6-1150-release-signed.app`，9473473字节，SHA256 `7a53a06b8343cca0a12161a6d87751e957ad76b0ba50eec82f81639d80c419a6`；HAP `SayRing-HarmonyOS-1.0.6-1150-release.hap`，18765259字节，SHA256 `7e28c7f8678d708b04bc8fa3a7c7fcf2e9e5123b5ab3d72135560530b0465689`。上传完整APP，不解压重压；HAP的app_gallery签名实际侧载受系统策略限制，不能冒充调试Profile安装包。
- Git续查：本机GCM已有tangwu88，显式HTTPS用户名及OpenSSL连接成功。已重新`fetch origin --prune`；当前开发远端仍`7e23496074da65173908960cff2ada7ffa3887e7`，本地702fea8是其直接后继，未出现需合并的远端变化。此前SSH授权失败不再阻止此HTTPS交付，不使用另一个账号，不改全局SSH/凭据。

## 待验收

- 原生鸿蒙手机页面、登录、记录和设备验收；没有原厂鸿蒙戒指SDK的能力仍不可用。
- 鸿蒙国际支付平台/供应商参数与真实联调，需后续完整前后端接入，不能靠这次正式签名开放。
- Git远端授权、fetch/推送SHA、华为AGC接收与最终审核结果分别核对；双签门禁通过不等于审核通过。
