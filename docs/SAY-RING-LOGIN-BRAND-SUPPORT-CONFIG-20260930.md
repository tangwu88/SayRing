# 2026-09-30 登录品牌与客服配置闭环

## 修改前检查

- 独立工作树：`E:\SayRing-contact-support-20260930`，从已同步的 `origin/main=724a7d792cbf92908133e69eadae3e074550f7eb` 创建分支 `codex/login-brand-support-config-20260930`；原工作区未改动。
- 已阅读 `AGENTS.md`、`docs/handoff.md`、最近实施记录、跨端问题复盘和回归检查清单。
- 本轮只调整登录页品牌展示与微信入口图标；联系客服页面继续使用 2026-09-30 已对齐参考项目的双联系卡片，不引入固定联系方式。

## 原因、范围与预期

- 登录页顶部 Say Ring 品牌标识改为黑色，避免继续使用默认品牌红；图片只做颜色遮罩，不替换原始 Logo 资源。
- 微信授权登录入口改用微信图标并使用官方绿色 `#07C160`；Flutter 当前国际验证码登录页、旧登录兼容页及原生鸿蒙登录页保持一致。
- 联系客服数据仍只读取国际后台公开配置；服务端旧错误数据由服务端兼容和后台专用编辑器修复，App 不回退到国内固定电话或公众号。

## 修改文件

- `lib/ui/brand_assets.dart`：品牌组合和标志支持显式颜色覆盖。
- `lib/ui/global_code_login_page.dart`、`lib/ui/pages.dart`：黑色 Logo 与微信绿色图标。
- `harmony-native/entry/src/main/ets/pages/Index.ets`：鸿蒙登录页同步黑色品牌标识与微信图标。
- `test/global_code_login_page_test.dart`、`test/login_page_test.dart`、`harmony-native/tests/layout-contract.test.mjs`：新增精确界面契约。

## 验证记录

- Flutter 定向测试：19 项通过。
- Flutter 静态检查：`flutter analyze --no-pub` 通过，无问题。
- Flutter 完整测试：UTC 与 `Asia/Shanghai` 各 939 项通过。
- Android 原生：`:app:testDebugUnitTest --offline` 通过；首次因本机单个 Qring Gradle transform 缓存被外部修改而失败，停止守护进程并将精确缓存目录移动到 `E:\saydian\.toolchains\gradle-quarantine` 后重跑通过。
- Android 构建：双 ARM Debug APK 与 QA Release APK 均成功；QA Release 受现有非正式发布门禁控制，不作为应用市场正式签名包。
- Harmony 契约定向测试：28 项通过；完整宿主测试 501 项通过。
- Harmony Debug 与 Release HAP 编译成功；Release 因现有 `build-profile` 未配置发布签名，不能作为应用市场正式包。
- `git diff --check`：通过。
- iOS：Windows 环境未执行 Xcode 编译或真机检查。

## 失败与修复保留

- Harmony 契约首轮因测试截取到同名函数且仍匹配旧按钮片段失败；改为精确截取登录组件并按当前条件渲染契约断言，重跑通过。
- 管理后台客服编辑器首轮测试沿用了不受支持的 `email` 示例；改为产品实际支持的公众号字段并保持严格白名单，重跑通过。
- Android 首轮构建未找到旧记录中的 JDK 根路径，确认实际 JDK 位于其版本子目录后继续；随后发现并隔离单个可再生成的 Gradle 损坏缓存，未删除项目或账号数据。

## 发布与未验收边界

- Git 提交、主线同步、服务端 CI 与线上版本将在本轮发布完成后补记。
- 未安装到手机，未执行真实微信授权；微信开放平台配置、真实客服拨号/复制与鸿蒙/iOS 真机仍需对应环境复验。
- 后台高德地图仅提供配置入口；未填写真实 Web 服务 Key 时前端地图保持未配置，不伪报可用。
