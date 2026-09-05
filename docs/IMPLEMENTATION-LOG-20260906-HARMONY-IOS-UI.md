# 2026-09-06 鸿蒙版全面对齐 iOS 界面

## 开始状态

- 分支：`codex/harmony-native-login-home`。
- 修改前提交：`1654a8a`。
- 修改前工作树干净，已执行远端更新检查；本地与 `origin/codex/harmony-native-login-home` 一致。
- 参考来源：当前 Flutter iOS 页面实现、赛电设计颜色令牌、历史同屏参考图和华为 nova 14 真机渲染。

## 修改原因与范围

- 原因：鸿蒙版此前的页面密度、空态、导航层级和“我的”入口与 iOS 不一致，需要在不伪造设备能力和健康数据的前提下统一。
- 主要文件：
  - `harmony-native/entry/src/main/ets/pages/Index.ets`
  - `harmony-native/tests/layout-contract.test.mjs`
  - `harmony-native/design-qa.md`
  - `harmony-native/docs/qa-assets/*20260906*`
- 影响范围：登录、注册、首页、设备、添加设备、健康总览、我的、账号、单位、远程关爱、消息、预警、商城、订单、支付、帮助、权限、联系和关于页。

## 实施结果

- 统一使用当前 iOS 品牌色与画布色，主页面采用相同的卡片层级、语义图标、文字等级和底部导航。
- 首页仅在设备支持且鸿蒙桥接可用时显示健康项目；无设备时只保留一个可点击空态，避免重复“暂无记录”。
- 设备扫描拆为独立页面；设备来源继续严格显示 `Vep`/`Yuc`，系统标识不冒充 MAC。
- 设备页移除与 iOS 不一致的手动测量区，测量入口保留在对应健康详情页。
- “我的”恢复 iOS 的资料、三项摘要、订单、常用入口和服务区；退出登录只在账号设置显示。
- 支付页按 iOS 收银台结构展示订单、支付方式、状态刷新和支付按钮，不把客户端返回当作支付成功。
- 鸿蒙平台特有权限、更新、支付与厂商 SDK 限制继续保留真实状态，不显示内部开发说明。
- 发行候选构建号由 5 递增至 6，应用元数据、更新检查和推送登记版本保持一致。

## 测试与失败记录

### 自动化

- `TZ=Asia/Shanghai node --test harmony-native/tests/*.test.mjs`：143/143 通过。
- `TZ=UTC node --test harmony-native/tests/*.test.mjs`：143/143 通过。
- `git diff --check`：通过。

### 编译

1. 首次调用把 `DEVECO_SDK_HOME` 错误设置为两个路径拼接，Hvigor 拒绝该路径；改为 DevEco SDK 根目录后完整编译通过。
2. 开发签名暂存工程首次只同步 `entry/src`，遗漏 AppScope 新图标，资源打包失败；补同步 AppScope 后关闭该失败。
3. 暂存工程仍使用旧依赖，无法解析微信 SDK；同步当前 `oh_modules` 和锁文件后，开发签名 Debug 构建通过。
4. 无签名完整构建与开发签名 Debug 构建均成功；保留的警告来自厂商 HAR 资源重名和既有异常处理提示。
5. 首次在仓库根目录直接校验候选目录内的相对路径 `SHA256SUMS`，因工作目录不正确而找不到文件；进入候选目录后两项均校验为 `OK`。

### 正式签名候选

- 产物目录：`harmony-native/build/releases/0.1.3-6-ios-ui-20260906/`。
- 正式签名 HAP 与 APP 均已生成，HAP 官方 `verify-app`、发布 Profile `verify-profile` 通过。
- 包内元数据：`cc.saidian.app.hm`、0.1.3（6）、`release`、`debug=false`。
- 发布 Profile：`type=release`、`apl=normal`，包名一致。
- APP 内嵌 HAP 与独立签名 HAP 哈希一致；两项 `SHA256SUMS` 复验通过。

### 真机

- 华为 nova 14 已覆盖安装开发签名版本，未卸载 App，登录态和本地数据保留。
- 已真机导航并截图：首页、设备、添加设备、全部健康数据、我的、账号、权限、帮助、联系、关于和单位设置。
- 将 iOS 参考与鸿蒙首页放入同一比较图检查；未发现 P0/P1/P2 的裁切、重叠、层级、颜色或交互目标问题。
- 本轮只做界面和导航回归，没有重新连接手表、发起真实支付或修改远程关爱数据。

## 平台差异与后续边界

- 状态栏、系统返回手势和系统符号使用鸿蒙原生实现，不做 iOS 像素仿造。
- W8/Yuc 仍缺厂商鸿蒙 SDK，只允许识别与标记，不开放假连接。
- AppGallery 更新、Harmony PaymentKit 和系统权限弹窗保留鸿蒙平台路径；前端信息层级与 iOS 对齐。
- 服务端未返回真实健康、订单、推送或支付数据时只显示真实空态或错误，不生成示例数据。
