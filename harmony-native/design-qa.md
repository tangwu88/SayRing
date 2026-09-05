# SayDian 赛电鸿蒙版 iOS 对齐设计 QA

## 目标与边界

- 目标：鸿蒙版的页面结构、信息层级、品牌色、圆角卡片、主要交互和前端文案与当前 iOS Flutter 端保持一致。
- iOS 基准：`lib/ui/app_theme.dart`、`lib/ui/pages.dart`、`lib/ui/shop_pages.dart` 与 `docs/home-visual-comparison-20260818.png` 左侧参考设计。
- 鸿蒙实现：`entry/src/main/ets/pages/Index.ets`。
- 平台例外：保留鸿蒙系统状态栏、返回手势、系统符号、权限弹窗、AppGallery 更新入口与 Harmony PaymentKit；鸿蒙暂无 Yucheng SDK，因此名称含 W8 的设备仍标记为 `Yuc`，但不显示可连接假状态。
- 验证设备：华为 nova 14，物理截图 1084 × 2412 px。

## 同屏比对

- 首页同屏比对：`docs/qa-assets/ios-harmony-home-comparison-20260906.png`。
- iOS 参考和鸿蒙截图保持相同手机纵向比例；首页头部、AI 健康管家、四个快捷入口、健康标题和底部导航在同一比较输入中检查。
- iOS 参考图含示例健康值，鸿蒙真机当时未连接手表，因此健康区域按产品规则只显示一个真实空态；未伪造指标或趋势。

## 真机页面证据

- 首页：`docs/qa-assets/harmony-ios-aligned-home-20260906.jpg`
- 设备：`docs/qa-assets/harmony-ios-aligned-device-20260906.jpg`
- 添加设备：`docs/qa-assets/harmony-ios-aligned-search-20260906.jpg`
- 全部健康数据：`docs/qa-assets/harmony-ios-aligned-healthall-20260906.jpg`
- 我的（顶部与完整服务区）：`docs/qa-assets/harmony-ios-aligned-mine-20260906.jpg`、`docs/qa-assets/harmony-ios-aligned-mine-bottom-20260906.jpg`
- 账号设置：`docs/qa-assets/harmony-ios-aligned-account-20260906.jpg`
- 关于我们：`docs/qa-assets/harmony-ios-aligned-about-20260906.jpg`
- 权限管理：`docs/qa-assets/harmony-ios-aligned-permissions-20260906.jpg`
- 帮助与反馈：`docs/qa-assets/harmony-ios-aligned-help-20260906.jpg`
- 联系客服：`docs/qa-assets/harmony-ios-aligned-contact-20260906.jpg`
- 单位设置：`docs/qa-assets/harmony-ios-aligned-units-20260906.jpg`

## 逐项结论

- 首页：与 iOS 一致采用问候区、AI 卡、四入口、健康数据、运动记录和底部法律提示；未连接时不再重复多个“暂无记录”。
- 设备：未连接态与 iOS 一致采用添加设备主卡、连接说明和安全提示；扫描独立进入“添加设备”，顶部提供返回和刷新。
- 我的：与 iOS 一致采用资料卡、三项摘要、订单、常用入口和五项服务；账号退出移入账号设置，首页不展示开发或后台说明。
- 健康：只展示“设备支持且桥接已实现”的真实项目；无数据、未连接与不支持三种状态分开；复合指标和心电不生成虚假平均值。
- 商城、订单和支付：沿用 iOS 的商品卡、订单卡和支付收银台层级；微信与支付宝选择、状态刷新和主支付按钮位置一致，仍以服务端真实参数为准。
- 远程关爱、消息、预警、百科、帮助、权限、联系和关于页：统一使用 iOS 的白色卡片、语义色图标、简洁说明和 44 px 以上操作区域。
- 登录和注册：使用同一品牌 Logo、输入顺序、协议确认、注册入口及微信授权入口；客户端不含微信密钥。
- 无障碍与适配：系统文字缩放上限为 2 倍；关键按钮最小点击高度不低于 44；1084 × 2412 真机截图未发现截断、重叠或底部导航遮挡。

## Findings

- P0：无。
- P1：无。
- P2：无。
- P3：鸿蒙系统状态栏、系统符号轮廓与 iOS SF Symbols 存在平台原生差异，按约束保留，不属于界面缺陷。
- 扫描超时补充回归：状态已改由响应式连接阶段驱动，华为 nova 14 真机在 12 秒后能从搜索中自动进入“暂未发现设备”。

## 验证结果

- Asia/Shanghai：144/144 自动化测试通过。
- UTC：144/144 自动化测试通过。
- Debug 与无签名完整编译：通过。
- 0.1.3（6）开发签名覆盖安装：通过，保留原登录态和本地数据。
- 0.1.3（6）正式签名 HAP/APP：生成并通过官方签名、Profile、版本、包名和内嵌 HAP 一致性校验。
- 页面导航与真机渲染：健康、设备、添加设备、全部健康数据、我的、账号、权限、帮助、联系、关于和单位设置均通过；无设备时扫描超时空态通过。
- 编译仍有厂商 HAR 的资源重名及异常处理警告；没有新增 ArkTS 编译错误，不影响本轮界面验收。

final result: passed
