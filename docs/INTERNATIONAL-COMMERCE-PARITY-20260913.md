# 2026-09-13 国际 App 商城与 H5 能力对齐

## 修改前基线

- 分支：`feature/global-commerce-parity`
- 基线提交：`9530387680d71a0e1f3452093fd68e206f09939f`
- 远端：`https://github.com/tangwu88/saydian-app-global.git`
- 工作区在开工检查时干净；本轮仅本地开发与调试，不推送、不发布。

## 原因、范围与成功标准

- 原因：国际 App 商城仍为只读商品目录，H5 已具备购物车、地址、下单、订单、售后、收藏、优惠券、积分与帮助流程；线上 App V2 商品响应又缺少币种和小数位，导致价格只能显示“待确认”。
- 参考：同一服务端仓库的国际 H5 商城页面、状态规则及服务端真实 App V2 契约。H5 的独立登录、微信网页授权和员工推广中心属于网页专属能力，不复制进 App。
- 修改范围：Flutter 国际商城 API 契约、页面与八语文案、UUID/币种/会话/下单幂等保护、相关自动测试与本地 Android 调试。
- 成功标准：商品价格使用服务端币种；登录用户可完成购物车、国际地址、订单预览和安全下单流程；订单、物流、售后、收藏、优惠券、积分与帮助均有真实入口和可恢复状态；未配置的市场或支付渠道明确不可用且不伪造成功；所有第一方请求仍只到 `https://app.saydian.cn/global/api/saydian-app/v2`。

## 明确边界

- 本轮不改国内版商城，不复用国内整数 ID、固定人民币或省市区 ID 契约。
- 不把 H5 支付渠道冒充为原生 App 支付能力；仅按服务端返回的原生环境能力启用。
- 自动测试不创建真实订单、不支付、不退款、不发货；写操作只在授权的本地隔离环境和测试账号下人工验收。
- 未完成全部本地验收前不提交远端、不触发自动部署。

## 执行记录

### 2026-09-13 修改前检查

- 命令：`git status --short --branch`、`git log -1 --oneline`，并阅读国际交接、最近商城审计、复盘与回归清单。
- 结果：通过。功能分支工作区干净，基线提交与远端一致。
- 发现：服务端 App V2 已有商城主体接口，但 Flutter 只接商品列表和详情；App V2 商品未附 `currency` / `currencyExponent`；能力、售后预览、退货物流、积分和可领取优惠券等少数 H5 能力尚未暴露给 App V2。

### 2026-09-13 H5 消费者流程对齐

- 对照页面：主页、分类、搜索、商品、购物车、结算、地址、订单、订单详情、物流、售后、收藏、优惠券、优惠码、积分和帮助中心。
- App 落点：补齐商品币种/库存/规格/图文详情/评价/分享，购物车数量与选择，安全报价与下单，国际地址，订单分组与状态，物流，售后报价、私有凭证图、退货物流、评价、收藏、领券/优惠码、积分与帮助入口。
- 网页专属边界：H5 登录/微信网页授权、员工推广中心不复制进 App；网页支付渠道只有服务端明确返回 `android` / `ios` 可用环境时才会在 App 启用。
- 安全处理：商品、SKU、地址、订单、售后及文件 ID 均按不透明 UUID 校验；金额只使用服务端整数最小货币单位和小数位；未知下单/售后结果复用同一持久化幂等键，禁止重复提交。

### 2026-09-13 地址可恢复体验

- 发现：市场能力接口暂时失败时，地址列表也被一起隐藏，用户无法查看已有地址。
- 修复：地址与市场能力分别读取；已有地址始终可查看和删除，市场能力缺失时仅禁用新增/编辑并展示普通用户提示，不猜测默认国家。
- 新增测试：`existing addresses stay readable when market capabilities fail`。

### 2026-09-13 第一方域名复核

- 生产入口固定为 `https://app.saydian.cn`，国际 API 固定为 `/global/api/saydian-app/v2`；本地调试只允许显式开启的 `10.0.2.2`、`127.0.0.1` 或 `localhost` 端口。
- 图片、售后私有凭证和更新包均在发送前校验域名、路径和重定向；旧 `app.saidian.cc` / `sd.cc`、异常端口、HTTP 正式地址和跨域重定向会在传输前阻止。
- 源码中仍保留的旧域名文字属于共享国内客户端的兼容归一化与“必须拒绝”的测试夹具；国际 `GlobalSaydianApiClient` 由传输边界阻止调用旧路径或旧主机。官方手表表盘与天气服务保留独立白名单，不属于第一方业务接口。

## 验证记录

### 服务端契约

- `pnpm.cmd api:docs`：通过，342 条路由全部有说明并重新生成目录。
- `pnpm.cmd api:docs:check`：通过，生成结果与源码一致。
- `pnpm.cmd --filter @saydian/app-api typecheck`：通过。
- `pnpm.cmd --filter @saydian/app-api build`：通过。
- `pnpm.cmd contracts:client:check`：76 个已登记消费者路由存在、0 缺失；该工具仅证明路由存在，不代替字段解析或本轮全球 App 真机验收。
- App API 测试命令实际触发 API 全量 Vitest：755 项通过，4 项需数据库环境的集成测试跳过；无失败。
- `node --test tools/h5-field-contracts.test.mjs`：11/11 通过。
- `pnpm.cmd test:h5:flows`：61/61 通过，覆盖报价变更、未知下单结果恢复、账号切换、跨页锁、购物车和订单并发状态。
- `pnpm.cmd test:h5:contracts`：国际 H5 构建成功，跨端契约/隔离/浏览器夹具 38/38 通过；仅有 Sass 旧 API 与 `@import` 弃用预警。
- 过程失败与修复：接口文档生成曾依次报告 App 私有售后图片路由和新 Commerce 路由缺少说明；已补 API notes 与字段契约别名，重新生成、检查通过。

### Flutter 静态与专项测试

- `flutter analyze --no-pub`：通过，无问题。
- `flutter test test/global_commerce_api_test.dart --no-pub`：7/7 通过。
- `flutter test test/global_shop_flow_test.dart --no-pub`：最终 7/7 通过。
- `flutter test test/global_shop_pages_test.dart --no-pub`：11/11 通过，覆盖 375×812、390×844 与 1.0/1.5/2.0 字体缩放。
- 过程失败与修复：购物车窄屏曾出现 17 px 溢出，优惠券选择改为展开布局；新增 ARB 文案曾重复声明 `countryRegion` / `phoneNumber`，全量测试准确拦截后删除 9 份重复键并重新生成本地化代码。

### Flutter 全量回归

- `TZ=UTC flutter test --no-pub`：837/837 通过。
- `TZ=America/New_York flutter test --no-pub`：837/837 通过。
- `flutter test test/global_network_boundary_test.dart test/global_commerce_api_test.dart test/global_shop_media_test.dart --no-pub`：37/37 通过，覆盖 API、媒体和跨域重定向拒绝。
- 结果覆盖商城契约、域名/重定向保护、八语键完整性、登录会话、健康、设备及既有 App 流程；自动测试未创建真实订单或触发真实交易。

### Android 构建与本地安装

- `flutter build apk --debug --no-pub`：通过，`app-debug.apk`，185,587,865 bytes，SHA-256 `9C0F09C1841878D0FCDA573C23389A72569C9DDD0CBEC70966DF6FF29491B480`。
- 未声明模式的 `flutter build apk --release --no-pub`：按预期失败，`verifySaidianReleaseMode` 阻止误产正式包。
- `SAIDIAN_ALLOW_QA_RELEASE=true flutter build apk --release --no-pub`：通过，内部 QA `app-release.apk`，68,863,080 bytes，SHA-256 `616A1AAA3D0A4EC5838EB8081A730EF44C034805C2D9117111F30798B8974CCD`。
- 两包均为 `cn.saydian.app.global` / `Saydian` / `0.1.21 (1004)` / minSdk 26 / targetSdk 36，APK Signature Scheme v2 校验通过。
- 当前电脑没有可用 Android AVD；检测到华为 `PPA LX3`。手机现有包与本轮包证书 SHA-256 均为 `99b006c6394e55f78ad6d71867d5051384a0f64b839fea432e57a7ac9935819e`，可覆盖保留数据，但四次安装均被手机端 `INSTALL_FAILED_ABORTED: User rejected permissions` 阻断。未卸载、未清数据；开启“通过 USB 安装”并确认手机弹窗后需再次安装和冷启动验收。
- Gradle 仅提示 `camera_android_camerax` / `jpush_flutter_android` 未来需迁移 Flutter Built-in Kotlin，以及本机 Android SDK XML 工具版本差异；本轮构建成功，未为消除前瞻警告擅自升级插件。

## 当前交付状态

- 源码、测试和构建已在本地完成；新商城服务尚未部署，因此未执行真实线上注册、下单、支付、退款或售后写入。
- 本机 `127.0.0.1:8080/8082/3000` 均无就绪 API，且未安装 Docker、没有本地 `.env`；没有借用线上数据库或生产凭据伪装本地联调。服务端契约由进程内全量测试验证，真实隔离库写入仍待具备本地基础设施后验收。
- 本轮分支未推送、未合并、未触发线上自动部署，符合“全部本地完成后再统一更新线上”的约定。
