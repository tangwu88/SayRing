# 2026-10-28 百科与商城三端显示配置

## 授权、基线及根因

- 用户明确要求后台截图中的百科/商城显示对iOS、Android和鸿蒙同步。起始干净开发分支4aefb19ff970872aa97dcc05e949ab86905dd1aa；已status/remote/fetch，首轮低速失败，HTTP/1.1仅取当前分支重试成功，ahead/behind0/0。已读约定与最近同步/健康提醒记录。
- 线上只读核对：ios明确mall=false、health_library=true；android/harmonyos没有模块对象。Flutter生产仅iOS创建模块租约，原生鸿蒙没有读模块配置，这是安卓仍显示商城的根因。
- 后端在独立saydianserver工作树实现并提交b3f48952a60d785baae16780399c613131ff922d；复用旧设置行，不改生产开关，不扩展健康权限或交易平台。上线/CI与源码推送分别验收。

## 客户端实现

- Flutter生产Android和iOS都创建独立模块租约，并请求真实platform；严格校验product/platform/schema及两个布尔、有效期1～300秒。iOS旧构造参数保留兼容，健康只读租约仍只走ios，不将模块开关解释为测量或生理授权。
- 原商城/百科入口及内容门禁复用到安卓；账号商城请求同样拒绝撤销期间的迟到结果。支付页加入内容门禁，发起资格使用实际商城可见性/原购买上限；在能力、订单、支付签名每个异步阶段复核商城代次，隐藏后即使重开也不能将旧签名请求调给SDK。既有iOS购买上限不变。
- 原生鸿蒙新增ModuleDisplay模型、独立不持久化模块状态，缺失/无效/读取失败关闭，前台30秒刷新，最多300秒；生产使用SDK getUptime单调时钟并扣除请求耗时，后台/恢复时期限仍有效。
- 鸿蒙首页百科/商城、设备搜索商城入口、我的订单入口按配置显示，剩余首页入口平分宽度；隐藏时关闭已打开模块页面，清缓存/请求代次。NativeHttpTransport对商城/百科读取在发起前和返回后应用模型门禁；协议/隐私、认证、健康、AI独立，不被误拦。没有把缺原厂SDK的戒指能力或鸿蒙付款伪装成已接通。
- 鸿蒙更新为1.0.7(1154)，Android以构建参数同号。旧iOS协议兼容；旧安卓/鸿蒙必须升级，不能宣称后台能控制未实现该协议的旧版。

## 本机验证与失败修正

- 定向Flutter模块/付款40项通过：三端平台信封匹配、独立开关、关闭前不读内容、原购买上限，以及能力/订单/签名阶段撤销与撤销后重开的SDK零调起。
- 首轮分析发现新增测试if缺大括号，补齐；最终Analyzer零问题（20.3秒），UTC1556/1556（100秒）、Asia/Shanghai1556/1556（114秒）。未削弱支付、医疗或数据来源门禁。
- 鸿蒙首轮全量因原请求URL断言还缺platform=harmonyos失败，按新契约更新；新增单调SDK时钟后旧BasicServicesKit测试夹具缺systemDateTime导出，补齐合成单调时钟。最终两个时区各529/529、0跳过；实际ArkTS Debug81.6秒/Release37.4秒通过。此前非最终构建也完成，最终以下冻结包为准。
- 代码检查中发现一次补丁过宽上下文把商城判断插入公共PageRow，立即改回只包我的订单卡，公共PageRow保持原逻辑；未把错误候选打包或安装。
- 鸿蒙正式HAP和完整APP原证书双签、官方双验及未签外层负样本拒绝通过：市场APP9479352字节/SHA256 `9cba0c4ddcbd4256da30c63e8e17b42ea92a451cebcfdd337ee2bf6d7c846245`；HAP18780101字节/SHA256 `56e6bfb2b70d96996faedc16d6bf9d45860aa9a34def46a43ef7af7fc21435c0`。Git外目录`E:\SayRing-market-artifacts-20261028\harmony-module-1154\delivery`。
- Android Debug构建223.0秒、原证书Release391.0秒通过，正式证书/包名/version1.0.7/code1154/debug关闭/生产清单/双ARM ABI及ZIP对齐门禁通过；既有两项32位SDK ELF16KB限制未改变，临时key.properties已清除。APK72063783字节，SHA256 `334eff425284df42f92445d0ab7c07d1f5ccf33c82e104f5eb2f832cb9af6267`，仓库外`E:\SayRing-market-artifacts-20261028\module-1154`。实际手机覆盖安装及线上三端复查续记。
- Windows无Xcode，iOS没有本机签名构建；旧iOS配置协议兼容不等于完成新版本iPhone验收。原生鸿蒙手机未连接，编译/签名不是实物验收。
- 回执和日志均在Git外`E:\SayRing-module-controls-20261028`及对应产物目录，不提交生产凭据、真实订单或健康数据。后台CI、生产三端配置与Android手机复查分别完成后记录。
